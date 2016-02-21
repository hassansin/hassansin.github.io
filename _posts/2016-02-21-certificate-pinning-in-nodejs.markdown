---
layout: post
title:  "Certificate Pinning in NodeJS"
date:   2016-02-21 13:01:49 +0000
categories: node.js
tags: node.js security
---

Certificate Pinning adds an extra layer of security to your application. Specially if you are writing an API client and need to send/receive some highly sensitive information from the API server. Secure HTTP (HTTPS) verifies if the certificate is valid and the hostname matches with the certificate. But it does not verify if the advertised certificate is TRULY belonged that host. This gives a chance to Man-in-the-middle(MITM) attack where an attacker can inject a VALID certificate that actually does not belong to the host. Without certificate pinning, you are blindly trusting the certificate providing to you.

You can learn more about Certificate pinning in the [OWASP guide](https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning)


## How does it work in theory?

To pin the certificate, first get the original certificate for your host and hard-code it in your application. Then when making a request to the host, retrieve the server's certificate and match it with the certificate embedded in the code. If doesn't match, abort the connection. Make sure you do this before you start to read/write to the server. Otherwise, all this would be futile as the attacker would have already got hold of your precious data.

In practice, however, we'll use __certificate fingerprint__ to verify. A fingerprint is the hash of the certificate and is much shorter.

## Get certificate fingerprint

Before we start, we need to get the server certificate fingerprint. If you already have access to the certificate, then skip the first step.

I'll use *https://api.github.com* throughout the example.

1. **Fetch public certificate:** You'll need a secure connection for this. Somewhere you are sure that no one is eavesdropping on the network.

    ```sh
    echo -n | openssl s_client -connect api.github.com:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > cert.pem
    ```
    This would generate a `cert.pem` containing public certificate of api.github.com

2. **Generate certificate fingerprint:** Use the certificate to generate fingerprint:

    ```sh
    openssl x509 -noout -in cert.pem -fingerprint
    ```
    You will get an output like:

    ```
    SHA1 Fingerprint=CF:05:98:89:CA:FF:8E:D8:5E:5C:E0:C2:E4:F7:E6:C3:C7:50:DD:5C
    ```

## Certificate pinning with `https` module

Let's do the certificate pinning using Node.js `https` module. It is very important to keep in mind that we need to do this even before sending any data to the host.

```javascript
const https = require('https');
// Embed valid fingerprints in the code
const FINGERPRINTSET = [
  'CF:05:98:89:CA:FF:8E:D8:5E:5C:E0:C2:E4:F7:E6:C3:C7:50:DD:5C'
];

var options = {
  hostname: 'api.github.com',
  port: 443,
  path: '/',
  method: 'GET',
  headers: {
    'User-Agent': 'Node.js/https'
  }
};

var req = https.request(options, res => {
  res.on('data', d => {
    process.stdout.write(d);
  });
})
.on('error', e => {
  console.error(e);
});

req.on('socket', socket => {
  socket.on('secureConnect', () => {
    var fingerprint = socket.getPeerCertificate().fingerprint;

    // Check if certificate is valid
    if(socket.authorized === false){
      req.emit('error', new Error(socket.authorizationError));
      return req.abort();
    }

    // Match the fingerprint with our saved fingerprints
    if(FINGERPRINTSET.indexOf(fingerprint) === -1){
      // Abort request, optionally emit an error event
      req.emit('error', new Error('Fingerprint does not match'));
      return req.abort();
    }
  });
});

req.end();

```

Here is the breakdown of the above code:

1. First, we are saving the fingerprint in the constant `FINGERPRINTSET`. It is a good idea to save all the fingerprints if you have multiple certificates.

2. Next we are listening to the `socket` event. This is emitted as soon as a socket is assigned to the request. But the certificate is not yet available. We will get certificate information after a successful handshake is made and `secureConnect` event is emitted. It is important to mention that, a socket is also available in `res` object in our request callback. **But it also means we already have connected to the server and transferred any secret data during the `POST` request**. So aborting request at this stage won't prevent the attacker reading your data.

3. Next we are checking if the certificate is invalid by `socket.authorized === false` and aborting the request.

4. If the certificate is valid, we then check if the fingerprint matches with our embedded `FINGERPRINTSET`. If it's not, abort the request and optionally throw an error event.



## Problem with TLS Session caching

So far so good, we have successfully implemented certificate pinning. But there is one problem with it. TLS sockets can be reused if you make requests to the same host in quick succession. I don't know the exact time duration a socket can stay alive but if you make several requests one after another, you'll see the second request fails almost all the time.

It's because when a tls session is reused, all certificate information is stripped from the socket. See the link to [this issue](https://github.com/nodejs/node/issues/3940) to understand why.

So, there are two ways to workaround this problem. Unfortunately, none of them are documented in the node.js official documentation.

1. **Skip fingerprint validation if session is reused:**

    We can use `socket.isSessionReused()` method to see if the session is reused. This method is not documented and used internally in the node.js source.

    ```javascript
    //...

    req.on('socket', socket => {
      socket.on('secureConnect', () => {
        var fingerprint = socket.getPeerCertificate().fingerprint;

        // Check if certificate is valid
        if(socket.authorized === false){
          req.emit('error', new Error(socket.authorizationError));
          return req.abort();
        }

        // Match the fingerprint with our saved fingerprints only for a new tls session
        if(FINGERPRINTSET.indexOf(fingerprint) === -1 && !socket.isSessionReused()){
          // Abort request, optionally emit an error event
          req.emit('error', new Error('Fingerprint does not match'));
          return req.abort();
        }
      });
    });
    ```

2. **Disable session reuse:**

    This is more secure than the previous method. Here we'll disable session by using a HTTPS Agent. The Agent constructor takes a `maxCachedSessions` property. We'll set it to `0` to prevent caching.

    ```javascript
    //...

      var options = {
        hostname: 'api.github.com',
        port: 443,
        path: '/',
        method: 'GET',
        headers: {
          'User-Agent': 'Node.js/https'
        },
        //disable session caching
        agent: new https.Agent({
          maxCachedSessions: 0
        })
      };

    //...
    ```

    Here it's important to mention that, disabling session cache means performing certificate handshake on every request. This can lead to increased usage of hardware resources, especially if the application has pretty high traffic.


## Using [`request`](https://github.com/request/request) module:

With `request` module, the process is almost same. Except, the certificate validation (NOT fingerprint validation) part can be handed over to the module itself using `strictSSL:true` property.

```javascript
const Agent = require('https').Agent,
  request = require('request');

// Embed valid fingerprints in the code
const FINGERPRINTSET = [
  'CF:05:98:89:CA:FF:8E:D8:5E:5C:E0:C2:E4:F7:E6:C3:C7:50:DD:5C'
];

var options = {
  url: 'https://api.github.com',
  headers: {
    'User-Agent': 'Node.js/https'
  },
  // Disable session caching
  agent: new Agent({
    maxCachedSessions: 0
  }),
  // Certificate validation
  strictSSL: true,
};

var req = request(options, (err, response, body) => {
  if(err)
    console.log(err);
  else
    console.log(body);
});

req.on('socket', socket => {
  socket.on('secureConnect', () => {
    var fingerprint = socket.getPeerCertificate().fingerprint;

    // Match the fingerprint with our saved fingerprints
    if(FINGERPRINTSET.indexOf(fingerprint) === -1){
      // Abort request, optionally emit an error event
      req.emit('error', new Error('Fingerprint does not match'));
      return req.abort();
    }
  });
});
```