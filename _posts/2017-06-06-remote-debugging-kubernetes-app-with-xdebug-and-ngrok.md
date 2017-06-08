---
layout: post
title:  "Remote Debugging Kubernetes Application with Xdebug and ngrok"
date:   2017-06-06 13:01:49 +0000
categories: php
tags: php xdebug kubernetes
---

Remote debugging a php application inside a kubernetes pod could be difficult. Most often our IDE is behind a NAT router that prevents direct communication between the pod and the IDE. In this case, out best bet is to [deploy a DBGp proxy server](https://derickrethans.nl/debugging-with-multiple-users.html) on the NAT machine that connects our IDE with the pod. But not all XDebug clients support it - there is no SublimeText package or VIM plugin that supports DBGp proxy. Even worse is you don't have control to configure the NAT machine and install the proxy server.

[Reverse port-forwarding with an SSH tunnel](https://derickrethans.nl/debugging-with-xdebug-and-firewalls.html) between the remote & local machine would be the solution in situations like this. But we cannot SSH into a kubernetes pod.

Kubernetes supports port-forwarding but that only works one way i.e. it'll forward ports from local to the pod. But we need the other way around - run a server locally and listen to it in the pod. There is an [open issue](https://github.com/kubernetes/kubernetes/issues/20227) to have a support for this.  Until they add the feature we need to find another way.

[ngrok](https://ngrok.io) could expose our local network to internet by creating a secure tunnel between a public endpoint and a locally running network service. ngrok TCP tunnels allow you to expose any networked service that runs over TCP. To start a TCP tunnel:

{% highlight bash %}
ngrok tcp 9000
{% endhighlight %}

After running the command, we'll see an status like following:

{% highlight text %}
ngrok by @inconshreveable

Session Status online
Version 2.2.4
Region United States (us)
Web Interface http://127.0.0.1:4040
Forwarding tcp://0.tcp.ngrok.io:16751 -> localhost:9000

Connections ttl opn rt1 rt5 p50 p90
  14 0 0.00 0.00 7.09 25.71
{% endhighlight %}

You can find the public endpoint that exposes our local XDebug client running on port 9000. Now we need to copy this endpoint and put it in our php.ini and deploy the php application again:

{% highlight ini %}
xdebug.remote_host=0.tcp.ngrok.io
xdebug.remote_port=16751
xdebug.remote_connect_back=0
xdebug.remote_log=/var/log/xdebug.log
{% endhighlight %}

It's better to load these values from environment variables. Before starting the server, replace the php.ini settings with corresponding environment variables. A sample docker start script would like following:

{% highlight bash %}
if [ -n "$REMOTE_HOST" ]; then sed -i "s/\(remote_host=\).*/\1$REMOTE_HOST/" /usr/local/etc/php/php.ini; fi
if [ -n "$REMOTE_PORT" ]; then sed -i "s/\(remote_port=\).*/\1$REMOTE_PORT/" /usr/local/etc/php/php.ini; fi
if [ -n "$REMOTE_MODE" ]; then sed -i "s/\(remote_mode=\).*/\1$REMOTE_MODE/" /usr/local/etc/php/php.ini; fi
if [ -n "$REMOTE_CONNECT_BACK" ]; then sed -i "s/\(remote_connect_back=\).*/\1$REMOTE_CONNECT_BACK/" /usr/local/etc/php/php.ini; fi

php -c /usr/local/etc/php/ -S 0.0.0.0:80 -t public public/index.php
{% endhighlight %}

We can also change these settings using `ini_set()` from within code, but I didn't try if that works.


Now start debugging and if you have enabled remote logging, you'll see logs like following:

{% highlight text %}
Log opened at 2017-06-05 04:36:13
I: Connecting to configured address/port: 0.tcp.ngrok.io:16751.
I: Connected to client. :-)
-> <init xmlns="urn:debugger_protocol_v1" xmlns:xdebug="http://xdebug.org/dbgp/xdebug" fileuri="file:///var/www/html/public/index.php" language="
PHP" xdebug:language_version="5.6.30" protocol_version="1.0" appid="12" idekey="PHPSTORM"><engine version="2.5.4"><![CDATA[Xdebug]]></engine><aut
hor><![CDATA[Derick Rethans]]></author><url><![CDATA[http://xdebug.org]]></url><copyright><![CDATA[Copyright (c) 2002-2017 by Derick Rethans]]></
copyright></init>

<- feature_set -i 1 -n show_hidden -v 1
-> <response xmlns="urn:debugger_protocol_v1" xmlns:xdebug="http://xdebug.org/dbgp/xdebug" command="feature_set" transaction_id="1" feature="show
_hidden" success="1"></response>

<- feature_set -i 2 -n max_children -v 32
-> <response xmlns="urn:debugger_protocol_v1" xmlns:xdebug="http://xdebug.org/dbgp/xdebug" command="feature_set" transaction_id="2" feature="max_
children" success="1"></response>

<- feature_set -i 3 -n max_data -v 1024
-> <response xmlns="urn:debugger_protocol_v1" xmlns:xdebug="http://xdebug.org/dbgp/xdebug" command="feature_set" transaction_id="3" feature="max_
data" success="1"></response>

<- feature_set -i 4 -n max_depth -v 3
-> <response xmlns="urn:debugger_protocol_v1" xmlns:xdebug="http://xdebug.org/dbgp/xdebug" command="feature_set" transaction_id="4" feature="max_
depth" success="1"></response>

<- breakpoint_set -i 5 -t line -f file%3A///var/www/html/app/src/Action/HomeAction.php -n 22
-> <response xmlns="urn:debugger_protocol_v1" xmlns:xdebug="http://xdebug.org/dbgp/xdebug" command="breakpoint_set" transaction_id="5" id="120049
"></response>
{% endhighlight %}
