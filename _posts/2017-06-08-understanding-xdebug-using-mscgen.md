---
layout: post
title:  "Understanding XDebug using Message Sequence Charts (mscgen)"
date:   2017-06-08 13:01:49 +0000
categories: php
tags: xdebug mscgen
custom_js:
  - '/assets/mscgen-inpage.js'
---

These Message Sequence charts will help us to better understand the communication that happens between the IDE and XDebug during a debugging session. These charts are generated using the awesome [`mscgen_js`](https://mscgen.js.org/index.html) library.

## Single User/Static IP

1. IDE/Editor starts a debug client server on PORT 9000
2. User sends session initiation command to the XDebug using GET/POST/COOKIE parameters or environment variables
3. XDebug connects to remote IDE using `xdebug.remote_host` and `xdebug.remote_port` values. It sends an `init` packet and waits without executing any code.
4. IDE negotiates features or set any breakpoints
5. IDE send commands to interactively walk through the code
6. When finished, XDebug sends response back to browser.

<script type="text/x-mscgen" class="mscgen_js" data-named-style='lazy'>
msc {
  hscale=2.3;

  a [label="IDE + Browser\nIP: 192.168.10.15\nidekey=xyz"],
  b [label="PHP/Xdebug\nIP: 52.203.114.223\n\n:80"];

  b note b [label="php.ini\nxdebug.remote_connect_back=0\nxdebug.remote_port=9000\nxdebug.remote_host=192.168.10.15\nxdebug.remote_mode=req"];
  a box a [id=1, label="Start Debug Server\n:9000"];
  |||;
  a >> b [id=2, label="HTTP Request\nhttp://52.203.114.223?XDEBUG_SESSION_START=xyz"];

  b box b[label="Halt code execution"];

  b => a [id=3, label="init [idekey = xyz]\n192.168.10.15:9000"];

  a => b [id=4, label="Features negotiation & set breakpoints"];
  ...;
  a <:> b [id=5, label="DBGp Protocol"];
  ...;
  b >> a [id=6, label="HTTP Response"];
}

</script>

## Multi User/Unknown IP

1. IDE/Editor starts a debug client server on PORT 9000
2. User sends session initiation command to the XDebug using GET/POST/COOKIE parameters
3. XDebug connects to remote IDE using `$_SERVER['HTTP_X_FORWARDED_FOR']` or `$_SERVER['REMOTE_ADDR']` values. It sends an `init` packet and waits without executing any code.
4. IDE negotiates features or set any breakpoints
5. IDE send commands to interactively walk through the code
6. When finished, XDebug sends response back to browser.

<script type="text/x-mscgen" class="mscgen_js" data-named-style='lazy'>
msc { 
  hscale=2.3;
 
  a [label="IDE + Browser\nIP: 192.168.10.15\nidekey=xyz"],
  b [label="PHP/Xdebug\nIP: 52.203.114.223\n\n:80"];
    
  
  b note b [label="php.ini\nxdebug.remote_connect_back=1\nxdebug.remote_port=9000\nxdebug.remote_mode=req"];
  a box a [id =1, label="Start Debug Server\n:9000"];
  |||;
  a >> b [id=2, label="HTTP Request\nhttp://52.203.114.223?XDEBUG_SESSION_START=xyz"];
  
  b box b[label="Halt code execution"];
  
  b box b[label="Find client IP\n$_SERVER['REMOTE_ADDR']\n192.168.10.15"];  
  
  b => a [id=3, label="init [idekey = xyz]\n192.168.10.15:9000"];  
  
  a => b [id=4, label="Features negotiation & set breakpoints"];
  ...;
  a <:> b [id=5, label="DBGp Protocol"];
  ...;
  b >> a [id=6, label="HTTP Response"];  
}
</script>
## DBGp Proxy

1. IDE/Editor starts a debug client server on PORT 9002
2. IDE sends a `proxyinit` command to the proxy server on port `9001` along with a `idekey` and an address to connect back to IDE on port `9002`
3. Proxy server stores the `idekey` and the IDE address where deubg clien is listening
4. User sends session initiation command to the XDebug using GET/POST/COOKIE parameters
5. XDebug connects to proxy server using `xdebug.remote_host` and `xdebug.remote_port` values. It sends an `init` packet with `idekey` and waits without executing any code.
6. Proxy server looks up the `idekey` and finds the IDE address. It then sends the same `init` command to the IDE
7. IDE negotiates features or set any breakpoints with the proxy server and proxy server sends the same commands to the XDebug
8. IDE send commands to proxy server to interactively walk through the code. Proxy server proxies all commands and response to XDebug
9. When finished, XDebug sends response back to browser.

<script type="text/x-mscgen" class="mscgen_js" data-named-style='lazy'>
msc {
  hscale="2";

  a [label="IDE + Browser\nIP: 192.168.10.15"],
  b [label="Proxy Server\nIP:  216.58.212.78\n:9001\n9000"],
  c [label="PHP/Xdebug\nIP: 52.203.114.223\n\n:80"];

  c note c [label="php.ini\nxdebug.remote_connect_back=0\nxdebug.remote_host=216.58.212.78\nxdebug.remote_port=9000\nxdebug.remote_mode=req", linecolor="black", textbgcolor="#FFFFCC"];
  a box a [id=1, label="Start Debug Server\n:9002", linecolor="black", textbgcolor="white"];
  a => b [id=2, label="proxyinit -p 192.168.10.15:9002 -k xyz -m 1"];
  b abox b [id=3, label="store key & ip map\nxyz => 192.168.10.15:9002\n...", linecolor="black", textbgcolor="white"];
  |||;
  a >> c [id=4, label="HTTP Request\nhttp://52.203.114.223?XDEBUG_SESSION_START=xyz", linecolor="#555"];
  c box c [label="Halts code execution", linecolor="black", textbgcolor="white"];
  c => b [id=5, label="init [idekey=xyz]\n216.58.212.78:9000"];
  b => a [id=6, label="init [idekey=xyz]\n192.168.10.15:9002"];
  a => b [id=7, label="Features negotiation & set breakpoints"];
  b => c [id=7, label="Features negotiation & set breakpoints"];
  ...;
  a <:> b [id=8, label="DBGp Protocol"];
  b <:> c [id=8, label="DBGp Protocol"];
  ...;
  c >> a [id=9, label="HTTP Response", linecolor="#555"];
}
</script>

## Just-in-time Debugging (JIT)

1. IDE/Editor starts a debug client server on PORT 9000
2. XDebug starts code execution and stops when an error occurs
3. XDebug connects to remote IDE using `xdebug.remote_host` and `xdebug.remote_port` values. It sends an `init` packet with `idekey`
4. IDE negotiates features or set any breakpoints
5. IDE send commands to interactively walk through the code
6. When finished, XDebug sends response back to browser.

<script type="text/x-mscgen" class="mscgen_js" data-named-style='lazy'>
msc {
  hscale=2.3;

  a [label="IDE + Browser\nIP: 192.168.10.15\nidekey=xyz"],
  b [label="PHP/Xdebug\nIP: 52.203.114.223\n\n:80"];

  b note b [label="php.ini\nxdebug.remote_connect_back=0\nxdebug.remote_port=9000\nxdebug.remote_host=192.168.10.15\nxdebug.remote_mode=jit"]
;
  a box a [id=1, label="Start Debug Server\n:9000"];
  |||;
  a >> b [label="HTTP Request\nhttp://52.203.114.223"];
  b box b[id=2, label="Start code execution"];
  ...;
  b box b[id=2, label="Error occurs"];
  b => a [id=3, label="init \n192.168.10.15:9000"];

  a => b [id=4, label="Features negotiation & set breakpoints"];
  ...;
  a <:> b [id=5, label="DBGp Protocol"];
  ...;
  b >> a [id=6, label="HTTP Response"];
}

</script>
