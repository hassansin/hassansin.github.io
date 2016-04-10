---
layout: post
title:  "Working with MongoDB TTL (Time-To-Live) Index"
date:   2016-04-09 16:00:00 +0000
categories: mongodb
tags: mongodb
custom_js:
  - 'https://cdnjs.cloudflare.com/ajax/libs/gist-embed/2.4/gist-embed.min.js'
---


MongoDB 2.2 or higher supports TTL (Time-To-Live) indexes. `TTL Monitor` is a separate thread that runs periodically (usually every minute) and scans a collection, that has a `TTL index` defined, for any expired documents and removes them in the background.

Application of TTL indexes can be in Shopping Carts, Login sessions, Event logs etc where the data needs to be retained only for a certain period of time.

This post shows various aspects of TTL indexes collected from my experience on working with TTL indexes, MongoDB documentation, Source code at GitHub, MongoDB Jira issues.

## TTLMonitor Sleep Interval

By Default, the TTLMonitor thread runs once in every 60 seconds. You can find out the sleep interval using following admin command.


<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="2-3" data-gist-hide-footer="true"></div>

To change this interval, supply another admin command with the desired interval:

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="5-6" data-gist-hide-footer="true"></div>

On my server, the maximum value it could take was `2147483650` seconds - maximum of 32 bit integer.


## TTLMonitor Thread Log

By default, the TTLMonitor log is disabled. To view the activity of TTLMonitor, enable logging for 'index' component with verbosity level of 1:

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="8" data-gist-hide-footer="true"></div>

This will log activity for TTLMonitor every time it runs:

<div data-gist-show-spinner="true" data-gist-file="output.txt" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="3-9" data-gist-hide-footer="true"></div>

## Disabling TTLMonitor

You can disable TTLMonitor thread at mongod startup or by an admin command from mongo shell:

During mongod startup:

```
$ mongod --setParameter ttlMonitorEnabled=false
```

From Mongo Shell:

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="10" data-gist-hide-footer="true"></div>

Because TTL thread runs in every minute by default, it can affect the performance slightly, especially for High Availablity systems.

## Expire documents after a specified number of seconds

From [MongoDB documentation](https://docs.mongodb.org/manual/tutorial/expire-data/#expire-documents-after-a-specified-number-of-seconds):

> To expire data after a specified number of seconds has passed since the indexed field, create a TTL index on a field that holds values of BSON date type or an array of BSON date-typed objects and specify a positive non-zero value in the expireAfterSeconds field. A document will expire when the number of seconds in the expireAfterSeconds field has passed since the time specified in its indexed field. [1]

In the following example, I'm creating an index at `created_at` field, with `expireAfterSeconds` set to 60 seconds. Any document that has that field value less than 60 seconds of current time will be deleted by the TTLMonitor.

The actual query that mongod performs to find the the documents is something like this:

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="14-23" data-gist-hide-footer="true"></div>

Reference: [ttl.cpp source](https://github.com/mongodb/mongo/blob/b531f537cf383ec6a70ddbee9f6d2902e7498b96/src/mongo/db/ttl.cpp#L273-L308)

To show that TTL index doesn't work for fields other than BSON Date type, I've created half of the documents with BSON Date and other half with integer timestamp. After a minute, which is the `expireAfterSeconds` value, we'll see only half of the documents are deleted.

This is interesting feature - it allows us to exclude certain documents in a collection to be not affected by TTL index and keep them even after they are expired.

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="26-52" data-gist-hide-footer="true"></div>

## Expire Documents at a Specific Clock Time or Dynamic TTL

In some cases, we might need to have different documents to have different expire times instead of the fixed time period. This will help us achieving document level TTL indexing. This feature will give fine-grained control over the documents.

This is very easy to implement. We need a TTL index with `expireAfterSeconds=0` and set the indexed field value of each document to a future date. Then when inserting document, we need to add its expected expiring time with the current time and save it to the indexed field.

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="56-72" data-gist-hide-footer="true"></div>

The output shows the number of documents available in every 5 seconds

<div data-gist-show-spinner="true" data-gist-file="output.txt" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="14-26" data-gist-hide-footer="true"></div>

## TTL Thread Stats

You can see overal how many documents were deleted by TTLMonitor Thread since start by `db.serverStatus()`. It also shows how many times the thread ran to process documents.
<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="76-80" data-gist-hide-footer="true"></div>

Since, TTL sleep interval is 60 seconds, and total TTL passes since start is 24818, our server uptime should be around 24818*60 = 1489080 seconds

But `db.serverStatus().uptime` is `1490921` seconds. So out TTL interval counter lags by about 1841 seconds or 30 minutes.


## TTL index on Capped collection

TTL index doesn't work in capped collection because capped collection doesn't allow any remove operation. Here is a simple demonstration:

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="85-91" data-gist-hide-footer="true"></div>

Here is the log that shows us the reason:

<div data-gist-show-spinner="true" data-gist-file="output.txt" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="30-35" data-gist-hide-footer="true"></div>

## Compound Indexes do not support TTL

## Update TTL Index options

- To update an existing Non-TTL index to TTL index, you have to drop the existing index and create a new TTL index.

- To update an existing TTL index with an new `expireAfterSeconds` option, you can use the `collMod` command:

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="96-105" data-gist-hide-footer="true"></div>

Here is the output of the commands:

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="107-127" data-gist-hide-footer="true"></div>

- To update an existing TTL index with a bad value of `expireAfterSeconds`, e.g. a string value instead of integer, you can't use `collMod` command to fix it. Instead, the index should be deleted first and create another TTL index with proper integer value.

## TTL with Partial Indexes

As of MongoDB 3.2, a collection can be partially indexed using a specified  filter expression, [`partialFilterExpression`](https://docs.mongodb.org/manual/core/index-partial/). TTL index can also be used with partial indexes.

Following example shows how it affects partial indexes. First, a partial TTL index is created on `created_at` field only if another field `z` exists in the document. Then two documents are inserted - one with a `z` field and another without it. After a minute, we see that only the document with `z` field is expired and removed by TTL thread.

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="131-146" data-gist-hide-footer="true"></div>

## Adding TTL to primary index(_id) or converting existing indexes to TTL

Not yet implemented : see more at [https://jira.mongodb.org/browse/SERVER-9305](https://jira.mongodb.org/browse/SERVER-9305)


## TTL Monitor on Replica Sets

From Documentation:

> On replica sets, the TTL background thread only deletes documents on the primary. However, the TTL background thread does run on secondaries. Secondary members replicate deletion operations from the primary.

Here is primary and secondary server status output hosted at MLab. Output shows that TTLMonitor thread runs at both servers but documents are deleted by TTL thread only at primary server.

**Primary**

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="150-160" data-gist-hide-footer="true"></div>

**Secondary**

<div data-gist-show-spinner="true" data-gist-file="commands.js" data-gist-id="bcb7cdfdcdb74f7c2427b7a0a23686b6" data-gist-line="163-172" data-gist-hide-footer="true"></div>