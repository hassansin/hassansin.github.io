---
layout: post
title:  Finding out Which Files Are Watched by Webpack Using Strace
date:   2017-12-29 20:10 +0600
categories: javascript, unix
tags: javascript, webpack, unix, strace
---

Recently I was trying to find out which files are being watched by Webpack while setting up a ReactJS project. I looked up in the documentation where it says:

> ... webpack will continue to watch for changes in any of the resolved files.

Hmm that's very brief but makes sense. It only watches files that are in the `entry` point and all the resolved files while compiling the entry files. But still I had some questions regarding those resolved files and only way to answer them is to see the list of files being watched. Unfortunately I couldn't find any cli flags or [`NODE_DEBUG`](https://nodejs.org/api/util.html#util_util_debuglog_section) values to somehow generate that list of files.

Luckily I knew that on Linux `inotify` is used to watch files. Since that's a system call, I could probably use `strace` to find out those files. I prepared a small similar project but with a lot less dependencies to start with. And here's the output from strace:

```sh
▶ strace -f ./node_modules/.bin/webpack --watch

# skipped
[pid 30459] read(12, "// Copyright Joyent, Inc. and ot"..., 1738) = 1738
[pid 30459] close(12)                   = 0
ectory)
[pid 30459] inotify_init1(IN_NONBLOCK|IN_CLOEXEC) = 12
[pid 30459] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/whatwg-fetch", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|
IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 1
[pid 30459] futex(0x21b9868, FUTEX_WAKE_PRIVATE, 1 <unfinished ...>
[pid 30466] <... futex resumed> )       = 0
[pid 30459] <... futex resumed> )       = 1
[pid 30466] futex(0x21b9800, FUTEX_WAIT_PRIVATE, 2, NULL <unfinished ...>
# skipped
```

It actually dumped a LOT more stuff on my screen, but I'm interested with only the part that says something about `inotify`. So turns out `inotify_init1` and `inotify_add_watch` are two syscalls used to initialize the watching process and add files to it. That means I can now filter the strace output to display only these system calls:

{:.max-height}
```sh
▶ strace -fe inotify_add_watch ./node_modules/.bin/webpack --watch

strace: Process 1400 attached
strace: Process 1401 attached
strace: Process 1402 attached
strace: Process 1403 attached
strace: Process 1404 attached
strace: Process 1405 attached
strace: Process 1406 attached
strace: Process 1407 attached
strace: Process 1408 attached

Webpack is watching the files…

Hash: 8533c8e92337bc71899b
Version: webpack 3.10.0
Time: 3273ms
           Asset     Size  Chunks             Chunk Names
./dist/bundle.js  83.5 kB       0  [emitted]  main
   [6] ./src/bar.js 126 bytes {0} [built]
   [7] multi ./src/app.js ./src/bar.js 40 bytes {0} [built]
   [8] ./src/app.js 304 bytes {0} [built]
    + 12 hidden modules
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 1
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 2
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/object-assign", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 3
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/process", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 4
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 5
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/lib", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 6
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/react/cjs", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 7
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/react", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 8
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/whatwg-fetch", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 9
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/src", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 10
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/.babelrc", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 11
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/.gitignore", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 12
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/package.json", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 13
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/webpack.config.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 14
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/yarn.lock", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 15
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/src/app.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 16
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/src/bar.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 17
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/process/.eslintrc", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 18
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/process/LICENSE", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 19
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/process/README.md", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 20
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/process/index.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 21
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/process/package.json", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 22
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/process/browser.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 23
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/process/test.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 24
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/object-assign/index.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 25
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/object-assign/license", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 26
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/object-assign/package.json", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 27
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/object-assign/readme.md", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 28
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/CHANGELOG.md", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 29
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/LICENSE", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 30
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/README.md", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 31
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/checkPropTypes.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 32
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/factory.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 33
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/factoryWithThrowingShims.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 34
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/factoryWithTypeCheckers.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 35
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/index.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 36
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/package.json", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 37
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/prop-types.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 38
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/prop-types.min.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 39
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/react/LICENSE", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 40
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/react/README.md", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 41
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/react/index.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 42
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/react/package.json", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 43
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/whatwg-fetch/LICENSE", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 44
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/whatwg-fetch/README.md", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 45
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/whatwg-fetch/fetch.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 46
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/whatwg-fetch/package.json", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 47
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/react/cjs/react.development.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 48
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/react/cjs/react.production.min.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 49
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/prop-types/lib/ReactPropTypesSecret.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 50
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/CSSCore.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 51
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/CSSCore.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 52
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/DataTransfer.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 53
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/DataTransfer.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 54
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Deferred.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 55
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Deferred.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 56
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/ErrorUtils.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 57
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/ErrorUtils.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 58
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/EventListener.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 59
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/EventListener.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 60
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/ExecutionEnvironment.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 61
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/ExecutionEnvironment.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 62
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Keys.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 63
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Keys.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 64
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Map.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 65
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Map.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 66
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/PhotosMimeType.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 67
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/PhotosMimeType.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 68
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Promise.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 69
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Promise.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 70
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Promise.native.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 71
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Promise.native.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 72
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/PromiseMap.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 73
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/PromiseMap.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 74
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Scroll.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 75
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Set.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 76
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Set.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 77
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Style.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 78
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Style.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 79
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/TokenizeUtil.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 80
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/TouchEventUtils.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 81
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/TokenizeUtil.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 82
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/URI.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 83
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/URI.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 84
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeBidi.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 85
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/TouchEventUtils.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 86
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/Scroll.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 87
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeBidi.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 88
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeBidiDirection.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 89
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeBidiDirection.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 90
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeBidiService.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 91
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeBidiService.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 92
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeCJK.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 93
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeHangulKorean.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 94
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeHangulKorean.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 95
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeUtils.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 96
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeCJK.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 97
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeUtils.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 98
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeUtilsExtra.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 99
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UserAgent.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 100
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UnicodeUtilsExtra.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 101
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UserAgent.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 102
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UserAgentData.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 103
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/UserAgentData.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 104
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/VersionRange.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 105
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/_shouldPolyfillES6Collection.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 106
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/_shouldPolyfillES6Collection.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 107
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/VersionRange.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 108
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/areEqual.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 109
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/areEqual.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 110
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/base62.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 111
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/base62.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 112
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/camelize.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 113
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/camelize.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 114
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/camelizeStyleName.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 115
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/camelizeStyleName.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 116
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/compactArray.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 117
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/compactArray.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 118
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/concatAllArray.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 119
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/concatAllArray.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 120
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/containsNode.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 121
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/containsNode.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 122
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/countDistinct.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 123
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/countDistinct.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 124
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/crc32.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 125
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/createArrayFromMixed.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 126
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/createArrayFromMixed.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 127
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/createNodesFromMarkup.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 128
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/crc32.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 129
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/createNodesFromMarkup.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 130
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/cx.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 131
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/cx.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 132
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/distinctArray.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 133
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/distinctArray.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 134
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/emptyFunction.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 135
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/emptyFunction.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 136
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/emptyObject.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 137
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/emptyObject.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 138
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/enumerate.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 139
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/enumerate.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 140
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/equalsIterable.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 141
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/equalsIterable.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 142
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/equalsSet.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 143
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/everyObject.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 144
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/equalsSet.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 145
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/everyObject.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 146
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/everySet.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 147
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/fetch.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 148
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/everySet.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 149
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/fetch.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 150
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/fetchWithRetries.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 151
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/fetchWithRetries.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 152
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/filterObject.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 153
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/filterObject.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 154
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/flatMapArray.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 155
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/flatMapArray.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 156
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/flattenArray.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 157
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/focusNode.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 158
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/focusNode.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 159
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/forEachObject.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 160
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/flattenArray.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 161
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/forEachObject.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 162
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getActiveElement.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 163
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getDocumentScrollElement.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 164
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getDocumentScrollElement.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 165
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getActiveElement.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 166
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getElementPosition.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 167
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getElementPosition.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 168
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getElementRect.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 169
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getMarkupWrap.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 170
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getMarkupWrap.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 171
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getElementRect.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 172
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getScrollPosition.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 173
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getScrollPosition.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 174
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getStyleProperty.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 175
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getStyleProperty.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 176
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getUnboundedScrollPosition.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 177
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getUnboundedScrollPosition.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 178
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getViewportDimensions.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 179
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/getViewportDimensions.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 180
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/groupArray.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 181
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/groupArray.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 182
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/hyphenate.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 183
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/hyphenateStyleName.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 184
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/invariant.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 185
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/invariant.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 186
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/isEmpty.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 187
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/isEmpty.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 188
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/isNode.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 189
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/hyphenateStyleName.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 190
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/isNode.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 191
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/isTextNode.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 192
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/joinClasses.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 193
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/joinClasses.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 194
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/isTextNode.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 195
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/keyMirror.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 196
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/keyMirror.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 197
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/keyMirrorRecursive.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 198
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/keyOf.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 199
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/keyMirrorRecursive.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 200
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/keyOf.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 201
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/mapObject.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 202
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/maxBy.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 203
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/mapObject.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 204
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/maxBy.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 205
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/memoizeStringOnly.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 206
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/memoizeStringOnly.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 207
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/minBy.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 208
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/monitorCodeUse.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 209
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/monitorCodeUse.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 210
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/minBy.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 211
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/nativeRequestAnimationFrame.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 212
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/nativeRequestAnimationFrame.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 213
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/nullthrows.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 214
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/partitionArray.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 215
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/partitionArray.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 216
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/nullthrows.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 217
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/partitionObject.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 218
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/partitionObject.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 219
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/partitionObjectByKey.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 220
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/performance.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 221
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/partitionObjectByKey.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 222
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/performance.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 223
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/performanceNow.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 224
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/removeFromArray.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 225
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/performanceNow.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 226
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/removeFromArray.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 227
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/requestAnimationFrame.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 228
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/requestAnimationFrame.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 229
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/resolveImmediate.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 230
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/resolveImmediate.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 231
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/setImmediate.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 232
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/setImmediate.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 233
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/hyphenate.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 234
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/shallowEqual.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 235
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/someObject.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 236
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/shallowEqual.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 237
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/someSet.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 238
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/someObject.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 239
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/someSet.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 240
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/warning.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 241
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/sprintf.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 242
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/warning.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 243
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/xhrSimpleDataSerializer.js", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 244
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/xhrSimpleDataSerializer.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 245
[pid  1399] inotify_add_watch(12, "/home/hassansin/Workspace/tmp/webpack-watch/node_modules/fbjs/lib/sprintf.js.flow", IN_MODIFY|IN_ATTRIB|IN_MOVED_FROM|IN_MOVED_TO|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MOVE_SELF) = 246
```

Lot better, with a little trick using `sed`, `grep` and `tr`, I managed to make it even more readable. Here are the files listed nicely with their relative paths. I added some comments in the output to make more sense to them.

{:.max-height}
```sh
▶ strace -fe inotify_add_watch ./node_modules/.bin/webpack 2>&1 | sed -u "s#$(pwd)#.#g" | grep -o --line-buffered '".*"' | tr -d '"'

## below are directories it's watching
.                                           # root directory
./node_modules/fbjs/lib                     # directories containing resolved files
./node_modules/object-assign
./node_modules/process
./node_modules/prop-types
./node_modules/prop-types/lib
./node_modules/react/cjs
./node_modules/react
./node_modules/whatwg-fetch
./src                                       # entry point directory

## below are all the files in above directories.. 
## no recursion though, only first level files

./.babelrc                                  # files from root dir
./.gitignore
./package.json
./webpack.config.js
./yarn.lock
./src/app.js                                # files from entry point dir
./src/bar.js                                # files from entry point dir
./node_modules/object-assign/index.js
./node_modules/object-assign/license
./node_modules/object-assign/package.json
./node_modules/object-assign/readme.md
./node_modules/process/.eslintrc
./node_modules/process/LICENSE
./node_modules/process/README.md
./node_modules/process/browser.js
./node_modules/process/index.js
./node_modules/process/package.json
./node_modules/process/test.js
./node_modules/prop-types/CHANGELOG.md
./node_modules/prop-types/README.md
./node_modules/prop-types/factory.js
./node_modules/prop-types/factoryWithTypeCheckers.js
./node_modules/prop-types/checkPropTypes.js
./node_modules/prop-types/index.js
./node_modules/prop-types/factoryWithThrowingShims.js
./node_modules/prop-types/package.json
./node_modules/prop-types/prop-types.min.js
./node_modules/prop-types/LICENSE
./node_modules/prop-types/prop-types.js
./node_modules/whatwg-fetch/LICENSE
./node_modules/whatwg-fetch/README.md
./node_modules/whatwg-fetch/fetch.js
./node_modules/whatwg-fetch/package.json
./node_modules/react/LICENSE
./node_modules/react/README.md
./node_modules/react/index.js
./node_modules/react/package.json
./node_modules/fbjs/lib/CSSCore.js
./node_modules/fbjs/lib/CSSCore.js.flow
./node_modules/fbjs/lib/DataTransfer.js
./node_modules/fbjs/lib/DataTransfer.js.flow
./node_modules/fbjs/lib/Deferred.js
./node_modules/fbjs/lib/Deferred.js.flow
./node_modules/fbjs/lib/ErrorUtils.js
./node_modules/fbjs/lib/ErrorUtils.js.flow
./node_modules/fbjs/lib/EventListener.js
./node_modules/fbjs/lib/ExecutionEnvironment.js
./node_modules/fbjs/lib/ExecutionEnvironment.js.flow
./node_modules/fbjs/lib/EventListener.js.flow
./node_modules/fbjs/lib/Keys.js
./node_modules/fbjs/lib/Keys.js.flow
./node_modules/fbjs/lib/Map.js
./node_modules/fbjs/lib/Map.js.flow
./node_modules/fbjs/lib/PhotosMimeType.js
./node_modules/fbjs/lib/PhotosMimeType.js.flow
./node_modules/fbjs/lib/Promise.js
./node_modules/fbjs/lib/Promise.js.flow
./node_modules/fbjs/lib/Promise.native.js
./node_modules/fbjs/lib/Promise.native.js.flow
./node_modules/fbjs/lib/PromiseMap.js
./node_modules/fbjs/lib/Scroll.js
./node_modules/fbjs/lib/Scroll.js.flow
./node_modules/fbjs/lib/PromiseMap.js.flow
./node_modules/fbjs/lib/Set.js
./node_modules/fbjs/lib/Set.js.flow
./node_modules/fbjs/lib/Style.js
./node_modules/fbjs/lib/Style.js.flow
./node_modules/fbjs/lib/TokenizeUtil.js
./node_modules/fbjs/lib/TokenizeUtil.js.flow
./node_modules/fbjs/lib/TouchEventUtils.js
./node_modules/fbjs/lib/TouchEventUtils.js.flow
./node_modules/fbjs/lib/URI.js
./node_modules/fbjs/lib/URI.js.flow
./node_modules/fbjs/lib/UnicodeBidi.js
./node_modules/fbjs/lib/UnicodeBidi.js.flow
./node_modules/fbjs/lib/UnicodeBidiDirection.js
./node_modules/fbjs/lib/UnicodeBidiService.js
./node_modules/fbjs/lib/UnicodeBidiDirection.js.flow
./node_modules/fbjs/lib/UnicodeBidiService.js.flow
./node_modules/fbjs/lib/UnicodeCJK.js
./node_modules/fbjs/lib/UnicodeHangulKorean.js
./node_modules/fbjs/lib/UnicodeHangulKorean.js.flow
./node_modules/fbjs/lib/UnicodeCJK.js.flow
./node_modules/fbjs/lib/UnicodeUtils.js
./node_modules/fbjs/lib/UnicodeUtils.js.flow
./node_modules/fbjs/lib/UnicodeUtilsExtra.js
./node_modules/fbjs/lib/UnicodeUtilsExtra.js.flow
./node_modules/fbjs/lib/UserAgent.js
./node_modules/fbjs/lib/UserAgent.js.flow
./node_modules/fbjs/lib/UserAgentData.js
./node_modules/fbjs/lib/UserAgentData.js.flow
./node_modules/fbjs/lib/VersionRange.js
./node_modules/fbjs/lib/VersionRange.js.flow
./node_modules/fbjs/lib/_shouldPolyfillES6Collection.js
./node_modules/fbjs/lib/areEqual.js
./node_modules/fbjs/lib/_shouldPolyfillES6Collection.js.flow
./node_modules/fbjs/lib/areEqual.js.flow
./node_modules/fbjs/lib/base62.js
./node_modules/fbjs/lib/base62.js.flow
./node_modules/fbjs/lib/camelize.js
./node_modules/fbjs/lib/camelize.js.flow
./node_modules/fbjs/lib/camelizeStyleName.js
./node_modules/fbjs/lib/camelizeStyleName.js.flow
./node_modules/fbjs/lib/compactArray.js
./node_modules/fbjs/lib/compactArray.js.flow
./node_modules/fbjs/lib/concatAllArray.js
./node_modules/fbjs/lib/concatAllArray.js.flow
./node_modules/fbjs/lib/containsNode.js
./node_modules/fbjs/lib/containsNode.js.flow
./node_modules/fbjs/lib/countDistinct.js
./node_modules/fbjs/lib/countDistinct.js.flow
./node_modules/fbjs/lib/crc32.js
./node_modules/fbjs/lib/crc32.js.flow
./node_modules/fbjs/lib/createArrayFromMixed.js
./node_modules/fbjs/lib/createArrayFromMixed.js.flow
./node_modules/fbjs/lib/createNodesFromMarkup.js
./node_modules/fbjs/lib/createNodesFromMarkup.js.flow
./node_modules/fbjs/lib/cx.js
./node_modules/fbjs/lib/cx.js.flow
./node_modules/fbjs/lib/distinctArray.js
./node_modules/fbjs/lib/emptyFunction.js
./node_modules/fbjs/lib/emptyFunction.js.flow
./node_modules/fbjs/lib/distinctArray.js.flow
./node_modules/fbjs/lib/emptyObject.js
./node_modules/fbjs/lib/emptyObject.js.flow
./node_modules/fbjs/lib/enumerate.js
./node_modules/fbjs/lib/enumerate.js.flow
./node_modules/fbjs/lib/equalsIterable.js
./node_modules/fbjs/lib/equalsIterable.js.flow
./node_modules/fbjs/lib/equalsSet.js
./node_modules/fbjs/lib/equalsSet.js.flow
./node_modules/fbjs/lib/everyObject.js
./node_modules/fbjs/lib/everyObject.js.flow
./node_modules/fbjs/lib/everySet.js
./node_modules/fbjs/lib/everySet.js.flow
./node_modules/fbjs/lib/fetch.js
./node_modules/fbjs/lib/fetch.js.flow
./node_modules/fbjs/lib/fetchWithRetries.js
./node_modules/fbjs/lib/fetchWithRetries.js.flow
./node_modules/fbjs/lib/filterObject.js.flow
./node_modules/fbjs/lib/filterObject.js
./node_modules/fbjs/lib/flatMapArray.js.flow
./node_modules/fbjs/lib/flatMapArray.js
./node_modules/fbjs/lib/flattenArray.js.flow
./node_modules/fbjs/lib/focusNode.js
./node_modules/fbjs/lib/focusNode.js.flow
./node_modules/fbjs/lib/flattenArray.js
./node_modules/fbjs/lib/forEachObject.js
./node_modules/fbjs/lib/forEachObject.js.flow
./node_modules/fbjs/lib/getActiveElement.js
./node_modules/fbjs/lib/getActiveElement.js.flow
./node_modules/fbjs/lib/getDocumentScrollElement.js
./node_modules/fbjs/lib/getDocumentScrollElement.js.flow
./node_modules/fbjs/lib/getElementPosition.js
./node_modules/fbjs/lib/getElementPosition.js.flow
./node_modules/fbjs/lib/getElementRect.js
./node_modules/fbjs/lib/getElementRect.js.flow
./node_modules/fbjs/lib/getMarkupWrap.js
./node_modules/fbjs/lib/getMarkupWrap.js.flow
./node_modules/fbjs/lib/getScrollPosition.js
./node_modules/fbjs/lib/getScrollPosition.js.flow
./node_modules/fbjs/lib/getStyleProperty.js
./node_modules/fbjs/lib/getStyleProperty.js.flow
./node_modules/fbjs/lib/getUnboundedScrollPosition.js
./node_modules/fbjs/lib/getUnboundedScrollPosition.js.flow
./node_modules/fbjs/lib/getViewportDimensions.js
./node_modules/fbjs/lib/getViewportDimensions.js.flow
./node_modules/fbjs/lib/groupArray.js
./node_modules/fbjs/lib/groupArray.js.flow
./node_modules/fbjs/lib/hyphenate.js.flow
./node_modules/fbjs/lib/hyphenateStyleName.js
./node_modules/fbjs/lib/hyphenateStyleName.js.flow
./node_modules/fbjs/lib/invariant.js
./node_modules/fbjs/lib/invariant.js.flow
./node_modules/fbjs/lib/isEmpty.js
./node_modules/fbjs/lib/hyphenate.js
./node_modules/fbjs/lib/isEmpty.js.flow
./node_modules/fbjs/lib/isNode.js
./node_modules/fbjs/lib/isTextNode.js
./node_modules/fbjs/lib/isTextNode.js.flow
./node_modules/fbjs/lib/joinClasses.js.flow
./node_modules/fbjs/lib/joinClasses.js
./node_modules/fbjs/lib/isNode.js.flow
./node_modules/fbjs/lib/keyMirror.js
./node_modules/fbjs/lib/keyMirror.js.flow
./node_modules/fbjs/lib/keyMirrorRecursive.js
./node_modules/fbjs/lib/keyOf.js
./node_modules/fbjs/lib/keyOf.js.flow
./node_modules/fbjs/lib/mapObject.js
./node_modules/fbjs/lib/mapObject.js.flow
./node_modules/fbjs/lib/maxBy.js
./node_modules/fbjs/lib/maxBy.js.flow
./node_modules/fbjs/lib/keyMirrorRecursive.js.flow
./node_modules/fbjs/lib/memoizeStringOnly.js
./node_modules/fbjs/lib/memoizeStringOnly.js.flow
./node_modules/fbjs/lib/minBy.js
./node_modules/fbjs/lib/minBy.js.flow
./node_modules/fbjs/lib/monitorCodeUse.js
./node_modules/fbjs/lib/monitorCodeUse.js.flow
./node_modules/fbjs/lib/nativeRequestAnimationFrame.js
./node_modules/fbjs/lib/nativeRequestAnimationFrame.js.flow
./node_modules/fbjs/lib/nullthrows.js
./node_modules/fbjs/lib/nullthrows.js.flow
./node_modules/fbjs/lib/partitionArray.js
./node_modules/fbjs/lib/partitionArray.js.flow
./node_modules/fbjs/lib/partitionObject.js
./node_modules/fbjs/lib/partitionObject.js.flow
./node_modules/fbjs/lib/partitionObjectByKey.js
./node_modules/fbjs/lib/partitionObjectByKey.js.flow
./node_modules/fbjs/lib/performance.js.flow
./node_modules/fbjs/lib/performanceNow.js
./node_modules/fbjs/lib/performanceNow.js.flow
./node_modules/fbjs/lib/removeFromArray.js
./node_modules/fbjs/lib/performance.js
./node_modules/fbjs/lib/requestAnimationFrame.js
./node_modules/fbjs/lib/removeFromArray.js.flow
./node_modules/fbjs/lib/requestAnimationFrame.js.flow
./node_modules/fbjs/lib/resolveImmediate.js
./node_modules/fbjs/lib/setImmediate.js.flow
./node_modules/fbjs/lib/resolveImmediate.js.flow
./node_modules/fbjs/lib/setImmediate.js
./node_modules/fbjs/lib/shallowEqual.js
./node_modules/fbjs/lib/shallowEqual.js.flow
./node_modules/fbjs/lib/someObject.js.flow
./node_modules/fbjs/lib/someSet.js
./node_modules/fbjs/lib/someObject.js
./node_modules/fbjs/lib/someSet.js.flow
./node_modules/fbjs/lib/sprintf.js
./node_modules/fbjs/lib/warning.js
./node_modules/fbjs/lib/warning.js.flow
./node_modules/fbjs/lib/xhrSimpleDataSerializer.js
./node_modules/fbjs/lib/sprintf.js.flow
./node_modules/fbjs/lib/xhrSimpleDataSerializer.js.flow
./node_modules/react/cjs/react.development.js
./node_modules/react/cjs/react.production.min.js
./node_modules/prop-types/lib/ReactPropTypesSecret.js
```

Now I can concentrate on finding out what's going on. Here are my findings:

* It's watching all the files in project root, although my entry point files are inside `./src` directory.
* It not only watches the resolved files but also everything inside the directory where the files are resolved. Like markdown, LICENSE,.flow files etc.
* It's also watching the resolved directories for changes, not just the files.
* It's not watching directories recursively, only first level files in the directory.

So question is why it's watching the root directory even though there's no file resolved directly from this directory? Turns out when using `babel-loader` it tries to load the `.babelrc` file and that probably makes Webpack to treat it as a resolved file. I no longer see the root files in this list after moving all the content from `.babelrc` to `webpack.config.js` and deleting the file:


{:.max-height}
```bash
▶ strace -fe inotify_add_watch ./node_modules/.bin/webpack 2>&1 | sed -u "s#$(pwd)#.#g" | grep -o --line-buffered '".*"' | tr -d '"'

# no root directory this time
./node_modules/fbjs/lib
./node_modules/object-assign
./node_modules/process
./node_modules/prop-types
./node_modules/prop-types/lib
./node_modules/react/cjs
./node_modules/react
./node_modules/whatwg-fetch
./src

# no files from root directory
./src/app.js
./src/bar.js
./node_modules/object-assign/index.js
./node_modules/object-assign/license
./node_modules/object-assign/package.json
./node_modules/object-assign/readme.md
./node_modules/process/.eslintrc
./node_modules/process/LICENSE
./node_modules/process/README.md
./node_modules/process/index.js
./node_modules/process/package.json
./node_modules/process/test.js
./node_modules/process/browser.js
./node_modules/prop-types/CHANGELOG.md
./node_modules/prop-types/LICENSE
./node_modules/prop-types/README.md
./node_modules/prop-types/checkPropTypes.js
./node_modules/prop-types/factory.js
./node_modules/prop-types/factoryWithThrowingShims.js
./node_modules/prop-types/factoryWithTypeCheckers.js
./node_modules/prop-types/index.js
./node_modules/prop-types/package.json
./node_modules/prop-types/prop-types.min.js
./node_modules/prop-types/prop-types.js
./node_modules/react/LICENSE
./node_modules/react/README.md
./node_modules/react/index.js
./node_modules/react/package.json
./node_modules/whatwg-fetch/LICENSE
./node_modules/whatwg-fetch/README.md
./node_modules/whatwg-fetch/fetch.js
./node_modules/whatwg-fetch/package.json
./node_modules/fbjs/lib/CSSCore.js
./node_modules/fbjs/lib/CSSCore.js.flow
./node_modules/fbjs/lib/DataTransfer.js.flow
./node_modules/fbjs/lib/Deferred.js
./node_modules/fbjs/lib/Deferred.js.flow
./node_modules/fbjs/lib/ErrorUtils.js
./node_modules/fbjs/lib/ErrorUtils.js.flow
./node_modules/fbjs/lib/EventListener.js.flow
./node_modules/fbjs/lib/ExecutionEnvironment.js
./node_modules/fbjs/lib/EventListener.js
./node_modules/fbjs/lib/DataTransfer.js
./node_modules/fbjs/lib/ExecutionEnvironment.js.flow
./node_modules/fbjs/lib/Keys.js
./node_modules/fbjs/lib/Keys.js.flow
./node_modules/fbjs/lib/Map.js
./node_modules/fbjs/lib/Map.js.flow
./node_modules/fbjs/lib/PhotosMimeType.js
./node_modules/fbjs/lib/PhotosMimeType.js.flow
./node_modules/fbjs/lib/Promise.js
./node_modules/fbjs/lib/Promise.js.flow
./node_modules/fbjs/lib/Promise.native.js
./node_modules/fbjs/lib/Promise.native.js.flow
./node_modules/fbjs/lib/PromiseMap.js
./node_modules/fbjs/lib/PromiseMap.js.flow
./node_modules/fbjs/lib/Scroll.js
./node_modules/fbjs/lib/Scroll.js.flow
./node_modules/fbjs/lib/Set.js
./node_modules/fbjs/lib/Set.js.flow
./node_modules/fbjs/lib/Style.js
./node_modules/fbjs/lib/Style.js.flow
./node_modules/fbjs/lib/TokenizeUtil.js
./node_modules/fbjs/lib/TokenizeUtil.js.flow
./node_modules/fbjs/lib/TouchEventUtils.js
./node_modules/fbjs/lib/TouchEventUtils.js.flow
./node_modules/fbjs/lib/URI.js
./node_modules/fbjs/lib/URI.js.flow
./node_modules/fbjs/lib/UnicodeBidi.js
./node_modules/fbjs/lib/UnicodeBidi.js.flow
./node_modules/fbjs/lib/UnicodeBidiDirection.js
./node_modules/fbjs/lib/UnicodeBidiDirection.js.flow
./node_modules/fbjs/lib/UnicodeBidiService.js
./node_modules/fbjs/lib/UnicodeBidiService.js.flow
./node_modules/fbjs/lib/UnicodeCJK.js
./node_modules/fbjs/lib/UnicodeCJK.js.flow
./node_modules/fbjs/lib/UnicodeHangulKorean.js
./node_modules/fbjs/lib/UnicodeHangulKorean.js.flow
./node_modules/fbjs/lib/UnicodeUtils.js
./node_modules/fbjs/lib/UnicodeUtils.js.flow
./node_modules/fbjs/lib/UnicodeUtilsExtra.js.flow
./node_modules/fbjs/lib/UnicodeUtilsExtra.js
./node_modules/fbjs/lib/UserAgent.js
./node_modules/fbjs/lib/UserAgent.js.flow
./node_modules/fbjs/lib/UserAgentData.js
./node_modules/fbjs/lib/UserAgentData.js.flow
./node_modules/fbjs/lib/VersionRange.js
./node_modules/fbjs/lib/VersionRange.js.flow
./node_modules/fbjs/lib/_shouldPolyfillES6Collection.js
./node_modules/fbjs/lib/_shouldPolyfillES6Collection.js.flow
./node_modules/fbjs/lib/areEqual.js
./node_modules/fbjs/lib/areEqual.js.flow
./node_modules/fbjs/lib/base62.js
./node_modules/fbjs/lib/base62.js.flow
./node_modules/fbjs/lib/camelize.js
./node_modules/fbjs/lib/camelize.js.flow
./node_modules/fbjs/lib/camelizeStyleName.js
./node_modules/fbjs/lib/camelizeStyleName.js.flow
./node_modules/fbjs/lib/compactArray.js
./node_modules/fbjs/lib/compactArray.js.flow
./node_modules/fbjs/lib/concatAllArray.js
./node_modules/fbjs/lib/concatAllArray.js.flow
./node_modules/fbjs/lib/containsNode.js
./node_modules/fbjs/lib/containsNode.js.flow
./node_modules/fbjs/lib/countDistinct.js
./node_modules/fbjs/lib/countDistinct.js.flow
./node_modules/fbjs/lib/crc32.js
./node_modules/fbjs/lib/crc32.js.flow
./node_modules/fbjs/lib/createArrayFromMixed.js
./node_modules/fbjs/lib/createArrayFromMixed.js.flow
./node_modules/fbjs/lib/createNodesFromMarkup.js
./node_modules/fbjs/lib/createNodesFromMarkup.js.flow
./node_modules/fbjs/lib/cx.js
./node_modules/fbjs/lib/cx.js.flow
./node_modules/fbjs/lib/distinctArray.js
./node_modules/fbjs/lib/distinctArray.js.flow
./node_modules/fbjs/lib/emptyFunction.js
./node_modules/fbjs/lib/emptyFunction.js.flow
./node_modules/fbjs/lib/emptyObject.js
./node_modules/fbjs/lib/emptyObject.js.flow
./node_modules/fbjs/lib/enumerate.js.flow
./node_modules/fbjs/lib/enumerate.js
./node_modules/fbjs/lib/equalsIterable.js
./node_modules/fbjs/lib/equalsIterable.js.flow
./node_modules/fbjs/lib/equalsSet.js.flow
./node_modules/fbjs/lib/everyObject.js
./node_modules/fbjs/lib/everyObject.js.flow
./node_modules/fbjs/lib/everySet.js.flow
./node_modules/fbjs/lib/everySet.js
./node_modules/fbjs/lib/equalsSet.js
./node_modules/fbjs/lib/fetch.js
./node_modules/fbjs/lib/fetch.js.flow
./node_modules/fbjs/lib/fetchWithRetries.js
./node_modules/fbjs/lib/fetchWithRetries.js.flow
./node_modules/fbjs/lib/filterObject.js
./node_modules/fbjs/lib/filterObject.js.flow
./node_modules/fbjs/lib/flatMapArray.js
./node_modules/fbjs/lib/flatMapArray.js.flow
./node_modules/fbjs/lib/flattenArray.js
./node_modules/fbjs/lib/flattenArray.js.flow
./node_modules/fbjs/lib/focusNode.js
./node_modules/fbjs/lib/focusNode.js.flow
./node_modules/fbjs/lib/forEachObject.js
./node_modules/fbjs/lib/forEachObject.js.flow
./node_modules/fbjs/lib/getActiveElement.js
./node_modules/fbjs/lib/getActiveElement.js.flow
./node_modules/fbjs/lib/getDocumentScrollElement.js
./node_modules/fbjs/lib/getElementPosition.js
./node_modules/fbjs/lib/getElementPosition.js.flow
./node_modules/fbjs/lib/getElementRect.js
./node_modules/fbjs/lib/getElementRect.js.flow
./node_modules/fbjs/lib/getMarkupWrap.js
./node_modules/fbjs/lib/getMarkupWrap.js.flow
./node_modules/fbjs/lib/getScrollPosition.js
./node_modules/fbjs/lib/getStyleProperty.js
./node_modules/fbjs/lib/getStyleProperty.js.flow
./node_modules/fbjs/lib/getScrollPosition.js.flow
./node_modules/fbjs/lib/getDocumentScrollElement.js.flow
./node_modules/fbjs/lib/getUnboundedScrollPosition.js.flow
./node_modules/fbjs/lib/getUnboundedScrollPosition.js
./node_modules/fbjs/lib/getViewportDimensions.js
./node_modules/fbjs/lib/groupArray.js
./node_modules/fbjs/lib/groupArray.js.flow
./node_modules/fbjs/lib/hyphenate.js.flow
./node_modules/fbjs/lib/hyphenate.js
./node_modules/fbjs/lib/hyphenateStyleName.js.flow
./node_modules/fbjs/lib/hyphenateStyleName.js
./node_modules/fbjs/lib/getViewportDimensions.js.flow
./node_modules/fbjs/lib/invariant.js.flow
./node_modules/fbjs/lib/invariant.js
./node_modules/fbjs/lib/isEmpty.js
./node_modules/fbjs/lib/isNode.js
./node_modules/fbjs/lib/isNode.js.flow
./node_modules/fbjs/lib/isEmpty.js.flow
./node_modules/fbjs/lib/isTextNode.js
./node_modules/fbjs/lib/isTextNode.js.flow
./node_modules/fbjs/lib/joinClasses.js
./node_modules/fbjs/lib/joinClasses.js.flow
./node_modules/fbjs/lib/keyMirror.js
./node_modules/fbjs/lib/keyMirror.js.flow
./node_modules/fbjs/lib/keyMirrorRecursive.js
./node_modules/fbjs/lib/keyMirrorRecursive.js.flow
./node_modules/fbjs/lib/keyOf.js
./node_modules/fbjs/lib/keyOf.js.flow
./node_modules/fbjs/lib/mapObject.js
./node_modules/fbjs/lib/mapObject.js.flow
./node_modules/fbjs/lib/maxBy.js
./node_modules/fbjs/lib/maxBy.js.flow
./node_modules/fbjs/lib/memoizeStringOnly.js.flow
./node_modules/fbjs/lib/memoizeStringOnly.js
./node_modules/fbjs/lib/minBy.js
./node_modules/fbjs/lib/minBy.js.flow
./node_modules/fbjs/lib/monitorCodeUse.js
./node_modules/fbjs/lib/monitorCodeUse.js.flow
./node_modules/fbjs/lib/nativeRequestAnimationFrame.js
./node_modules/fbjs/lib/nativeRequestAnimationFrame.js.flow
./node_modules/fbjs/lib/nullthrows.js
./node_modules/fbjs/lib/nullthrows.js.flow
./node_modules/fbjs/lib/partitionArray.js
./node_modules/fbjs/lib/partitionArray.js.flow
./node_modules/fbjs/lib/partitionObject.js
./node_modules/fbjs/lib/partitionObject.js.flow
./node_modules/fbjs/lib/partitionObjectByKey.js
./node_modules/fbjs/lib/partitionObjectByKey.js.flow
./node_modules/fbjs/lib/performance.js
./node_modules/fbjs/lib/performance.js.flow
./node_modules/fbjs/lib/performanceNow.js
./node_modules/fbjs/lib/performanceNow.js.flow
./node_modules/fbjs/lib/removeFromArray.js
./node_modules/fbjs/lib/removeFromArray.js.flow
./node_modules/fbjs/lib/requestAnimationFrame.js
./node_modules/fbjs/lib/requestAnimationFrame.js.flow
./node_modules/fbjs/lib/resolveImmediate.js
./node_modules/fbjs/lib/resolveImmediate.js.flow
./node_modules/fbjs/lib/setImmediate.js
./node_modules/fbjs/lib/setImmediate.js.flow
./node_modules/fbjs/lib/shallowEqual.js
./node_modules/fbjs/lib/someObject.js
./node_modules/fbjs/lib/shallowEqual.js.flow
./node_modules/fbjs/lib/someObject.js.flow
./node_modules/fbjs/lib/someSet.js
./node_modules/fbjs/lib/someSet.js.flow
./node_modules/fbjs/lib/sprintf.js
./node_modules/fbjs/lib/sprintf.js.flow
./node_modules/fbjs/lib/warning.js
./node_modules/fbjs/lib/warning.js.flow
./node_modules/fbjs/lib/xhrSimpleDataSerializer.js
./node_modules/fbjs/lib/xhrSimpleDataSerializer.js.flow
./node_modules/react/cjs/react.production.min.js
./node_modules/react/cjs/react.development.js
./node_modules/prop-types/lib/ReactPropTypesSecret.js
```

Now that I know which files are in Webpack's watchlist, how do I ignore some files from being watched? For example, I don't want it to watch those files in `node_modules` directory. After skimming through the source code, it looks like Webpack uses `watchpack` which in turn uses `chokidar` to watch files. Going through issue list, found out I could pass chokidar `ignored` option in Webpack's `watchOptions` to ignore files:

```js
//webpack.config.js
{
  entry: fs.readdirSync('./src').filter(file => file.match(/\.jsx?$/)).map(file => path.resolve('./src', file)),
  output: {
    filename: './dist/bundle.js'
  },
  module: {
    rules: [
      {
        test: /\.jsx?$/,
        include: [
          path.resolve(__dirname, 'src')
        ],
        loader: 'babel-loader',
        options: {
          presets: ['env', 'react']
        }
      }
    ]
  },
  watch: true,
  watchOptions: {
    ignored: /node_modules/
  }
}
```

We could also pass a function to `ignored` property and get a more fine-tuned filter. After applying the filter, I've only three files in my watchlist! This is exactly what I need, I don't want Webpack to watch my files in `node_modules` unless I'm debugging them.

```sh
▶ strace -fe inotify_add_watch ./node_modules/.bin/webpack 2>&1 | sed -u "s#$(pwd)#.#g" | grep -o --line-buffered '".*"' | tr -d '"'

./src
./src/app.js
./src/bar.js
```

Good news is even though Webpack watches this huge list of files, it re-builds only when a change occurs in any of the resolved files. Changing non-resolved files or adding new files doesn't trigger a new build unless the new file is a part of the resolved file list. Following is a little demonstration of that:

![webpack-watch](/assets/webpack-watch.gif)


Watching a lot of files might not be a performance hit if we are using `inotify`. But when using `polling` instead, it might be an issue. Since with polling, Webpack would have to continuously make `stat()` syscall on each file to check whether it's been modified or not. In that scenarios ignoring `node_modules` would definitely improve performance.

## References

1. [inotify_add_watch](https://linux.die.net/man/2/inotify_add_watch)
2. [Webpack Watch mode](https://webpack.js.org/configuration/watch/)
3. [non-recursive watching by Watchpack & Chokidar](https://github.com/webpack/watchpack/blob/d5c14552942efcf24344d200c13ce048799b92e6/lib/DirectoryWatcher.js#L49-L61)
4. [NodeWatchFileSystem](https://github.com/webpack/webpack/blob/a06496829bb0e8d5c7a3b531d21df730556752fd/lib/node/NodeWatchFileSystem.js)


