---
layout: post
title:  Cache Replacement Algorithms in Go
date:   2017-12-10 10:27 +0600
categories: 
tags: 
---


Cache replacement algorithms specifies different ways to evict an item from the cache with it is full. There are bunch of algorithms available used in different scenarios. This post describes my naïve implementation of some of these cache algorithms. The goal is to understand different cache replacement policies by implementing simpler version of these algorithms.

## Optimal Replacement:

The best algorithm is called Bélády's algorithm because it'll always discard an item from the cache if it is no longer needed in future. Of course this is theoretical and can't be implemented in real-life since it is generally impossible to predict how far in the future information will be needed.


## FIFO/LIFO:
In FIFO the item that enter the cache first is evicted first without any regard of how often or how many times it was accessed before. LIFO behaves in exact opposite way - evicts the most recent item from the cache.

The implementation is pretty simple, we used a map for the cache and a doubly linked list to implement the FIFO/LIFO queue. When the cache is full, we remove the cached item that is at the front of the FIFO queue - since it was added first and add the new item at the tail. Because of the hash table, the lookups, adds & deletes are fast and constant time.

<embed width="700" height="610" src="https://play.golang.org/p/W6R8-yEDzs" />

## Least Recently Used (LRU):

Here we replace the item that has been unused for the longest time. Implementation is almost same as FIFO cache - used a map and doubly linked list. Only difference is that any time there is a [cache hit](https://en.wikipedia.org/wiki/Cache_(computing)#CACHE-HIT), we move it to the front of the queue. Items at the front are most recently used items and items at the tail are the least recently used items. And when the cache is full, we remove the item that is at the tail of queue and put the new element at head of the queue. It also has constant lookups, adds, delete operations.

<embed width="700" height="610" src="https://play.golang.org/p/7rhWwEWn61" />

## Least Frequently Used (LFU):

In LFU, we count how many times an item was accessed and evict the item that has least access count. I used a map and a minimum priority queue to implement it. Priority queue sorts the items in a binary tree based on their hit counts. Item at the root of the heap has the least hit count. Instead of removing the root, we update it's values and reset hit count and [Fix](https://golang.org/pkg/container/heap/#Fix) the tree. calling `heap.Fix()` is equivalent to, but less expensive than, calling `heap.Remove()` followed by a `heap.Push()`of the new value. This implementation has complexity of ` O(log(n))` where `n = heap.Len()`, so it's a bit expensive than above two cache implementations. An `O(1)` implementation for it is also available at [here](http://dhruvbird.com/lfu.pdf)

<embed width="700" height="610" src="https://play.golang.org/p/HtJ3thS25-" />


## LRU and LFU combined:

Finally let's combine LFU and LRU together so that when multiple items in the cache have the same hit counts, we'll only evict the oldest one. We can modify the LFU implementation a bit and add a global sequential id to each item. When accessing/adding an item we increment the id and store it in the item. So the items that are recently accessed will have a higher sequential ids than the older ones. Now we can compare the sequential ids when two items have the same hit counts.

<embed width="700" height="610" src="https://play.golang.org/p/O581a53S7M" />

## References
1. [https://en.wikipedia.org/wiki/Cache_replacement_policies](https://en.wikipedia.org/wiki/Cache_replacement_policies)
2. [https://www.usenix.org/legacy/events/usenix01/full_papers/zhou/zhou_html/node3.html](https://www.usenix.org/legacy/events/usenix01/full_papers/zhou/zhou_html/node3.html)
