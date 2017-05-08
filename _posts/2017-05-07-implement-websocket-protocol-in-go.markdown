
---
layout: post
title:  "Implementing WebSocket Protocol in Go"
date:   2017-05-07 12:00:01 +0000
categories: go
tags: go websocket
---

# Implementing WebSocket Protocol in Go

The target of this post is to write a simple websocket echo server based on `net/http` library. Also understanding HTTP hijacking, binary encoding/decoding in Go. Websocket is relative simple protocol to implement. It uses HTTP protocol for initial handshaking. After the handshaking it basically uses raw TCP to read/write data. We'll be using the [Websocket Protocol Specification](https://tools.ietf.org/html/rfc6455) as a reference to the implementation.

Full source code is available [here](https://github.com/hassansin/go-websocket-echo-server)

## Overview

The implementation can divided into 4 parts:

* Opening handshake
* Receive data frames from client
* Send data frames to client
* Closing handshake

Limitations of the implementations:

* Doesn't validate UTF-8 encoded fragments
* Doesn't handle compression

## Handshaking

So the first thing is to setup a HTTP server using Go's `net/http` package. Then we attach a handler to listen any incoming http requests. The initial handshake request has to be started by the client, so we need interpret the client request to make sure if it's a websocket request or a normal http request. 

The handshake from the client looks as follows:

{% highlight go  %}
GET /chat HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Origin: http://example.com
{% endhighlight %}

### Hijacking HTTP Request

Once we know that it's a websocket request, the server needs to reply back with a handshake response. But we can't write back the response using the `http.ResponseWriter` as it will also close the underlying tcp connection once we start sending the response. What is need is called [HTTP Hijacking](https://golang.org/pkg/net/http/#Hijacker). Hijacking allows us to take over the underlying tcp connection handler and bufioWriter. This gives us the freedom to read and write data at will without closing the tcp connection.


{% highlight go %}
func New(w http.ResponseWriter, req *http.Request) (*Ws, error) {
    hj, ok := w.(http.Hijacker)
    if !ok {
        return nil, errors.New("webserver doesn't support http hijacking")
    }
    conn, bufrw, err := hj.Hijack()
    if err != nil {
        return nil, err
    }
    return &Ws{conn, bufrw, req.Header, 1000}, nil
}
{% endhighlight %}

### Server Handshake Response

Now to complete the handshake server must response back with appropriate headers. The handshake response looks like following

{% highlight text %}
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
{% endhighlight %}
The value of `Sec-WebSocket-Accept` is calculated as following:

> For this header field(Sec-WebSocket-Key), the server has to take the value (as present
   in the header field, e.g., the base64-encoded [RFC4648] version minus
   any leading and trailing whitespace) and concatenate this with the
   Globally Unique Identifier (GUID, [RFC4122]) "258EAFA5-E914-47DA-
   95CA-C5AB0DC85B11" in string form, which is unlikely to be used by
   network endpoints that do not understand the WebSocket Protocol.  A
   SHA-1 hash (160 bits) [FIPS.180-3], base64-encoded (see Section 4 of
   [RFC4648]), of this concatenation is then returned in the server's
   handshake.

We then write back these headers back to client. Note the `\r\n` after each header and empty blank line after all the headers.

{% highlight go %}
func getAcceptHash(key string) string {
    h := sha1.New()
    h.Write([]byte(key))
    h.Write([]byte("258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
    return base64.StdEncoding.EncodeToString(h.Sum(nil))
}

func (ws *Ws) Handshake() error {
    hash := getAcceptHash(ws.header.Get("Sec-WebSocket-Key"))
    lines := []string{
        "HTTP/1.1 101 Web Socket Protocol Handshake",
        "Server: go/echoserver",
        "Upgrade: WebSocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Accept: " + hash,
        "", // required for extra CRLF
        "", // required for extra CRLF 
    }
    return ws.write([]byte(strings.Join(lines, "\r\n")))
}
{% endhighlight %}


## Data Frame Transfer

After completing the handshake without any error, we are ready to read/write data from the client. Websocket spec defines a [specific frame format](https://tools.ietf.org/html/rfc6455#section-5.2) to be used between client & servers. Bit patterns of each frame is described below.

{% highlight text %}
       0                   1                   2                   3
      0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-------+-+-------------+-------------------------------+
     |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
     |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
     |N|V|V|V|       |S|             |   (if payload len==126/127)   |
     | |1|2|3|       |K|             |                               |
     +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
     |     Extended payload length continued, if payload len == 127  |
     + - - - - - - - - - - - - - - - +-------------------------------+
     |                               |Masking-key, if MASK set to 1  |
     +-------------------------------+-------------------------------+
     | Masking-key (continued)       |          Payload Data         |
     +-------------------------------- - - - - - - - - - - - - - - - +
     :                     Payload Data continued ...                :
     + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
     |                     Payload Data continued ...                |
     +---------------------------------------------------------------+   
{% endhighlight %}

The spec also defines how to decode the client payload using the masking key [here](https://tools.ietf.org/html/rfc6455#section-5.3). Based on these information it's pretty easy to define the decoder & encoder functions:

**Decoding Steps**:

1. Read first two-bytes
    a. find if the frame is a fragment
    b. find opcode
    c. find if the payload is masked
    d. find the payload `length`
2. if `length` is less than 126, goto step#5
3. if `length` equals to 126, read next two bytes in network byte order. This is the new payload `length` value
4. if `length` equals to 127, read next eight bytes in network byte order. This is the new payload `length` value
5. Read next 4 bytes as masking key
6. Read next `length` bytes as masked payload data
7. Decode the masked payload with masking key

{% highlight go %}

// Recv receives data and returns a Frame
func (ws *Ws) Recv() (Frame, error) {
    frame := Frame{}
    head, err := ws.read(2)
    if err != nil {
        return frame, err
    }

    frame.IsFragment = (head[0] & 0x80) == 0x00
    frame.Opcode = head[0] & 0x0F
    frame.Reserved = (head[0] & 0x70)

    frame.IsMasked = (head[1] & 0x80) == 0x80

    var length uint64
    length = uint64(head[1] & 0x7F)

    if length == 126 {
        data, err := ws.read(2)
        if err != nil {
            return frame, err
        }
        length = uint64(binary.BigEndian.Uint16(data))
    } else if length == 127 {
        data, err := ws.read(8)
        if err != nil {
            return frame, err
        }
        length = uint64(binary.BigEndian.Uint64(data))
    }
    mask, err := ws.read(4)
    if err != nil {
        return frame, err
    }
    frame.Length = length

    payload, err := ws.read(int(length)) // possible data loss
    if err != nil {
        return frame, err
    }

    for i := uint64(0); i < length; i++ {
        payload[i] ^= mask[i%4]
    }
    frame.Payload = payload
    return frame, err
}

{% endhighlight %}
**Encoding Steps**:

1. make a slice of bytes of length 2
2. Save fragmentation & opcode information in first byte
3. if payload `length` is less than 126, store the `length` in second byte
4. if payload `length` is greater than 125 and less than 2^16:
    a. store 126 in second byte
    b. convert the payload `length` into a 2-byte slice in network byte order
    c. append the length bytes to the header bytes
5. if payload `length` is greater than 2^16
    a. store 127 in second byte
    b. convert the payload `length` into a 8-byte slice in network byte order
    c. append the length bytes to the header bytes
6. Finally append the payload data


{% highlight go %}
// Send sends a Frame
func (ws *Ws) Send(fr Frame) error {
    data := make([]byte, 2)
    data[0] = 0x80 | fr.Opcode
    if fr.IsFragment {
        data[0] &= 0x7F
    }

    if fr.Length <= 125 {
        data[1] = byte(fr.Length)
        data = append(data, fr.Payload...)
    } else if fr.Length > 125 && float64(fr.Length) < math.Pow(2, 16) {
        data[1] = byte(126)
        size := make([]byte, 2)
        binary.BigEndian.PutUint16(size, uint16(fr.Length))
        data = append(data, size...)
        data = append(data, fr.Payload...)
    } else if float64(fr.Length) >= math.Pow(2, 16) {
        data[1] = byte(127)
        size := make([]byte, 8)
        binary.BigEndian.PutUint64(size, fr.Length)
        data = append(data, size...)
        data = append(data, fr.Payload...)
    }
    return ws.write(data)
}

{% endhighlight %}

## Closing Handshake

Closing is done by sending a close frame with close status as payload. An optional close reason can be also sent in the payload. If client initiates the closing sequence,then the server should also send a close frame in response. Finally the underlying TCP connection is closed.

{% highlight go %}

// Close sends close frame and closes the TCP connection
func (ws *Ws) Close() error {
    f := Frame{}
    f.Opcode = 8
    f.Length = 2
    f.Payload = make([]byte, 2)
    binary.BigEndian.PutUint16(f.Payload, ws.status)
    if err := ws.Send(f); err != nil {
        return err
    }
    return ws.conn.Close()
}
{% endhighlight %}


**Resources:**

1. [https://tools.ietf.org/html/rfc6455](https://tools.ietf.org/html/rfc6455)
2. [https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers)
