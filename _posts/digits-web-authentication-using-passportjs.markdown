---
layout: post
title:  "Digits Web Login with Passport.js"
date:   2016-03-09 13:01:49 +0000
categories: nodejs
tags: nodejs
custom_js:
  - 'https://cdnjs.cloudflare.com/ajax/libs/gist-embed/2.4/gist-embed.min.js'
---

Twitter's [Digits Web SDK](https://docs.fabric.io/web/digits/getting-started.html) enables users to login to any site using their mobiles. It's quick and secure as well as very easy to integrate with any website. This post demonstrates how to integrate Digits with NodeJS backend using popular authentication middleware [PassportJS](http://passportjs.org/).

Let's make a very simple app with `expressjs`, `nedb`. nedb is used for a simple in-memory database. It's API is subset of MongoDB's. The full code is available as a [Gist](https://gist.github.com/hassansin/c20c0ba87a06659adb90).


## Theory: Oauth Echo


##


## Install Dependencies:

As mentioned already, we'll need `expressjs` and `nedb` for our application. I'll use `passport-local` strategy to authenticate the Oauth Echo Response sent by Digits. Here is how `package.json` looks like:

<div data-gist-show-spinner="true" data-gist-file="package.json" data-gist-id="c20c0ba87a06659adb90"></div>


## Add Digits Web Login Button

First, we need to create a Fabric application at [Fabric.io](https://www.fabric.io). Unfortunately, right now there is no way to create a standalone web application. You'll need an iOS and Android SDK to get started.

Next, get the consumer key of your application and create a login page. In the login page below, I added the Digits Javascript SDK, then initilized the SDK with the consumer key. Notice the `callbackURL`, it should match with the Callback URL in Digits dashboard.

<div data-gist-show-spinner="true" data-gist-file="login.html" data-gist-id="c20c0ba87a06659adb90" data-gist-line="19-28"></div>

## Passport Startegy for Digits

When user confirms the code sent to their phone, Digits will redirect to `callbackURL` with OAuth Echo response. More specifically, it'll provide us `X-Auth-Service-Provider` and `X-Verify-Credentials-Authorization` as query variables.

<div data-gist-show-spinner="true" data-gist-file="passport.js" data-gist-id="c20c0ba87a06659adb90"></div>


The homepage will provide protected resource. For now we'll dump the the user's Digits profile as JSON. If user isn't logged in, we'll show a login button.
