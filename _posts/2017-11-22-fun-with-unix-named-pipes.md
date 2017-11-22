---
layout: post
title:  "Fun with Unix Named Pipes"
date:   2017-11-22 13:01:49 +0000
categories: unix
tags: unix
---

Named pipes are very useful Linux feature that enables quick and cheap inter-process communication. A named pipe is a special type of file within the file system that behaves like the traditional pipes in Unix system.

## Features of named pipes

Some characteristics of names pipes and their differences over regular files or Unix sockets:

1. Both reader  & writer processes need to open the file simultaneously, otherwise opening of file for read/write operations will be blocked. 

    >It has to be open at both ends simultaneously before you can proceed to do any input or output operations on it. Opening a FIFO for reading normally blocks until some other process opens the same FIFO for writing, and vice versa. [1]

2. Unlike regular files, no data is written in the disk when passing data between reader and writer. The kernel internally pipes the data between reader and writer processes.

    >The FIFO special file has no contents on the file system; the file system entry merely serves as a reference point so that processes can access the pipe using a name in the file system.[2]

3. Unlike sockets, named pipes are usually one-directional. We can open a named pipe with both read and write flag within the same process but there is a risk of deadlock if not handled properly. See node.js example below of doing bi-directional communication with named pipes.

4. When piping data to multiple readers, a reader is randomly selected and piped with the writer. The kernel maintains exactly ONE pipe object for each FIFO special file at any time. Unlike sockets, it's not possible to broadcast data to multiple readers using named pipes.

5. Unlike anonymous pipes which exist as long as the process exists, a named pipe can exist as long as the file exists in the file system. It can also be deleted if no longer needed.

## Some fun uses of named pipes:

### Real-time telecooperation via terminal:

Using [`script`](http://man7.org/linux/man-pages/man1/script.1.html) and `mkfifo` we can share our terminal activity in real-time with other user. 

![screen-share](/assets/named-pipes/fifo-screen.gif)


### Bi-directional communication

Be careful when opening a named pipe with both read and write flag (e.g. `r+`) from the same process. It doesn't enable bi-directional pipe but would actually cause a deadlock and loopback data within the same process. Consider the following example that doesn't block and wait for other process to read from the named pipe. Instead it pipes the data to the same process:

```js
// Bad example that causes deadlock
const fs = require('fs')

// open in both read & write mode
// isn't blocked for other process to open the pipe
const fd = fs.openSync('./pipe', 'r+') 

for(let i=0;i<10;i++){
	const input = 'hello world!';
	console.log('sending:', input)
	fs.writeSync(fd, input)

	const b = new Buffer(1024)
	fs.readSync(fd, b, 0, b.length)
	console.log('received:', b.toString())
}
```

To avoid this deadlock, we can open separate file handlers with read-only and write-only flags. 


**app1.js**

```js
const fs = require('fs')


const input = 'hello world!';
console.log('sending:', input)
const fw = fs.openSync('./pipe', 'w') // blocked until a reader attached
fs.writeSync(fw, input)
console.log('sent!')


console.log('waiting for reply')
const fr = fs.openSync('./pipe', 'r') // blocked until a writer attached
const b = new Buffer(1024)
fs.readSync(fr, b, 0, b.length)
console.log('received:', b.toString())
```

**app2.js**

```js
const fs = require('fs')

const fr = fs.openSync('./pipe', 'r') // blocked until writer attached
const b = new Buffer(1024)
fs.readSync(fr, b, 0, b.length)
console.log('received:', b.toString())

setTimeout(()=>{
	console.log('sending:', b.toString().toUpperCase())
	const fw = fs.openSync('./pipe', 'w') //blocked until reader attached
    fs.writeSync(fw, b.toString().toUpperCase())
}, 3000)
```

![bidirectional](/assets/named-pipes/fifo-bidirectional.gif)

### Transfer large files between processes without temporary files 

A named pipe can be used to transfer large amount data from one application to another without the use of an intermediate temporary file. This is useful if either of the processes doesn't support anonymous piping (e.g. stdin/stdout pipes). 

For example, we can [load data into MySQL tables using mkfifo](https://dev.mysql.com/doc/refman/5.5/en/load-data.html):

```sh
$ mkfifo -m 0666 /tmp/pipe
$ gzip -d < file.gz > /tmp/pipe
$ mysql -e "LOAD DATA INFILE '/tmp/pipe' INTO TABLE t1" db1
```

### Random piping to multiple simultaneous readers

If multiple processes try to read from the same pipe, the kernel seems like randomly selects a reader and pipes to it. So it's not possible to broadcast the same data to multiple readers simultaneously. For example try different combinations of following `reader.sh` and `writer.sh` scripts (e.g multiple readers, multiple writers) and notice the output.

**writer.sh**

```sh
#!/bin/bash

if [ ! -p pipe ];then
    mkfifo pipe
fi

col="$(( $RANDOM * 6 / 32767 + 1 ))"
while true
do
   i=$((i+1))
   echo -e "\e[0;3${col}m$i"
   sleep 1
done > pipe

```
**reader.sh**


```sh
tail -n +1 -f pipe
```

![randomness](/assets/named-pipes/fifo-randomness.gif)

### References:

1. [https://linux.die.net/man/3/mkfifo](https://linux.die.net/man/3/mkfifo)
2. [https://linux.die.net/man/7/fifo](https://linux.die.net/man/7/fifo)
3. [http://www.linuxjournal.com/article/2156](http://www.linuxjournal.com/article/2156)


