---
layout: post
title:  "Managing Node.js Dependencies Inside Docker Containers"
date:   2016-02-19 13:01:49 +0000
categories: docker node.js
tags: node.js docker
---

command:  bash -c '[ package.json -nt node_modules ] && npm install --production ; node lib/mailbox-monitor'