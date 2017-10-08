---
layout: post
title:  "Request-response model over asynchronous protocol using Go channels"
date:   2017-10-07 13:01:49 +0000
categories: go
tags: go
published: true
custom_js:
  - 'https://cdnjs.cloudflare.com/ajax/libs/gist-embed/2.4/gist-embed.min.js'
---

## Asynchronous Communication

In any asynchronous communication, the client sends a request and then moves on to other tasks, without waiting for the response to come back from the other end. It's also referred to as [fire-and-forget pattern](http://www.enterpriseintegrationpatterns.com/patterns/conversation/FireAndForget.html) in Enterprise Integration Patters:

> Fire-and-Forget is most effective with asynchronous communication channels, which do not require the Originator to wait until the message is delivered to the Recipient. Instead, the Originator can pursue other tasks as soon as the messaging system has accepted the message.

Some example would be AMQP protocol, STOMP protocol, UDP packets, Websockets etc. 

## Request-Response Pattern
In contrast, in the [request-response](https://en.wikipedia.org/wiki/Request%E2%80%93response) communication the client sends a request and the  receiver processes the request and sends a response back to the client. Now this can be implemented in both synchronous and asynchronous way. 

In synchronous way, the client that sends the request and waits until a response is returned from the receiver. For example in HTTP protocol the client uses the same connection for sending the request to the server and receiving the response from it. In languages like Node.js, the http request-response might seem like as asynchronous communication, but it's because of the v8 event-loop magic. Under the hood the request is being carried on over a synchronous channel by the OS.

On the other hand, we can implement the same pattern over an asynchronous communication channel. The client sends a message to the receiver and moves on. The receiver processes it and sends back another message to the client some time later. So two messages are involved for a single transaction. On top of that these messages can happen any time and there is no native support for one message to indicate it is related to another. It is the responsibility of the requestor to match the response message with appropriate request. More from the EIP: [Asynchronous Request-Response](http://www.enterpriseintegrationpatterns.com/patterns/conversation/RequestResponse.html)

> As with most conversations, when using Asynchronous Request-Response over asynchronous message channels, the requestor is responsible for matching the Response message to the appropriate Request. Because the asynchronous nature of the conversation, the Requestor can engage in more than one Asynchronous Request-Response conversation at one time, which results in response messages potentially arriving in a different order than the requests were sent. This can happen because some requests may be processed more quickly (or by a different service instance) than others. The Requestor should therefore equip messages with a unique Correlation Identifier to tie the messages to the conversation.

Remote Procedure Calls(RPC) is an example of request-response pattern done over an async channel.

## Example Implementation in Go

In this post, I'll implement the request-response pattern using Go channels. For simplicity, I'll use Websockets as the asynchronous communication channel. There's a websocket echo server at [www.websocket.org/echo.html](http://www.websocket.org/echo.html) that we could use as the receiver. It'll just respond back with the exact same message we send.

Some challenges that we've to overcome:

1. The response message may never arrive, so we need a timeout interval and return an error if no response arrives within the interval

2. The requestor may make multiple requests at a time and can get the response messages in different order. We need a way to identify a response message with the request.

3. The requestor may receive messages that aren't related to any request it made. Will require a way to discard a message when no corresponding request found.

4. We could make requests from multiple goroutines simultaneously using the same client. So we'll need some support for thread safety.

5. We'll use [Gorilla Websocket](https://github.com/gorilla/websocket) package for our client. It supports only one concurrent reader and writer. So we'll need locking mechanism to ensure this.



### Types

First let's define types for request and response objects. There is an `ID` field of type `uint64` in both request and response objects. This is our unique identifier for each request-response pair. We'll implement a counter that'll increment during each request and use the counter value as the request id. The server needs to reply back with the same id. This is done easily in our demo since we are using a Websocket echo server which reply back with the same payload as request.

```go
// Request represents a request from client
type Request struct {
	ID      uint64      `json:"id"`
	Message interface{} `json:"message"`
}

// Response is the reply message from the server
type Response struct {
	ID      uint64      `json:"id"`
	Message interface{} `json:"message"`
}
```

In our demo, we have only one concurrent client. So we can easily get away with an integer counter as the unique identifier. If we have multiple concurrent clients, then we have to be more clever when generating the unique id. Otherwise we could end up having same id for multiple requests from multiple clients. This is very important if the client and server uses different communication channels like in AMQP protocol. 



Next we define a type for an active call. It has fields for request & response objects. Also have a boolean channel to indicate whether the call is complete or not. Channel could be of any type, we only need it to block until we get the response. And an `error` field to indicate if there was an error during the call.

```go
// Call represents an active request
type Call struct {
	Req   Request
	Res   Response
	Done  chan bool
	Error error
}
```

We defined another type for the websocket client. It has an `id` field to be used by the next request. And the most important one is the `pending` map. The map will have all the active calls mapped with their request id.

```go
type WSClient struct {
	mutex   sync.Mutex
	conn    *websocket.Conn
	pending map[uint64]*Call
	id      uint64
}
```

### Making the request

Now let's see what happens when we make any request:

```go
func (c *WSClient) Request(payload interface{}) (interface{}, error) {
	c.mutex.Lock()
	id := c.id
	c.id++
	req := Request{ID: id, Message: payload}
	call := NewCall(req)
	c.pending[id] = call
	err := c.conn.WriteJSON(&req)
	if err != nil {
		delete(c.pending, id)
		c.mutex.Unlock()
		return nil, err
	}
	c.mutex.Unlock()
	select {
	case <-call.Done:
	case <-time.After(2 * time.Second):
		call.Error = errors.New("request timeout")
	}

	if call.Error != nil {
		return nil, call.Error
	}
	return call.Res.Message, nil
}
```

1. Since there can be concurrent requests per client, we need to ensure proper locking of the global states. The global states that are both read/updated are: `WSClient.id` and `WSClient.pending` fields.

2. Also due to the constraints for Write operation in Gorilla Websocket library, we also need to lock the `websocket.WriteJSON()` method.

3. We are incrementing the id counter, prepare the `Call` object for the request and store it in the `WSClient.pending` map. Then we starting writing to the websocket.

4. Next we start receiving from the channel which is a blocking operation. We also set a timeout so that we don't wait forever here.

5. Lastly we either send a successful response or an error.


### Reading for Response

We read from the websocket channel in a separate goroutine. The read operation is done only once at a time. So we don't need to lock the read operation. As we get the response, we first find the id from the response. Then we look into the global `pending` map for the active call with same id. If a pending request is found, we save the response and send a value through the `Done` channel to indicate the completion of the transaction.

```go
func (c *WSClient) read() {
	var err error
	for err == nil {
		var res Response
		err = c.conn.ReadJSON(&res)
		if err != nil {
			err = fmt.Errorf("error reading message: %q", err)
			continue
		}
		// fmt.Printf("received message: %+v\n", res)
		c.mutex.Lock()
		call := c.pending[res.ID]
		delete(c.pending, res.ID)
		c.mutex.Unlock()
		if call == nil {
			err = errors.New("no pending request found")
			continue
		}
		call.Res = res
		call.Done <- true
	}
	c.mutex.Lock()
	// Terminate all calls
	for _, call := range c.pending {
		call.Error = err
		call.Done <- true
	}
	c.mutex.Unlock()
}
```

### In Action

Lets test our implementation by making bunch of concurrent requests. In each request we send a random integer. We then assert if we get the same random integer from the response. Here is the test code:

```go
func main() {
	client := New()
	err := client.Connect("ws://echo.websocket.org")
	if err != nil {
		panic(err)
	}

	var wg sync.WaitGroup
	wg.Add(20)
	for i := 1; i <= 20; i++ {
		go func() {
			want := rand.Intn(100)
			res, err := client.Request(want)
			if err != nil {
				fmt.Println("error transaction: %d", err)
				wg.Done()
				return
			}
			got := int(res.(float64))
			if got != want {
				panic(fmt.Errorf("got: %d\nwant: %d\n", got, want))
			}
			fmt.Printf("transaction %d : %d\n", want, got)
			wg.Done()
		}()
	}
	wg.Wait()

	defer func() {
		err = client.Close()
		if err != nil {
			panic(err)
		}
	}()
}

```

and the output...

```text
transaction 40 : 40
transaction 59 : 59
transaction 81 : 81
transaction 87 : 87
transaction 47 : 47
transaction 18 : 18
transaction 81 : 81
transaction 25 : 25
transaction 56 : 56
transaction 0 : 0
transaction 37 : 37
transaction 94 : 94
transaction 11 : 11
transaction 11 : 11
transaction 45 : 45
transaction 62 : 62
transaction 89 : 89
transaction 28 : 28
transaction 74 : 74
transaction 6 : 6
```

The full source is available as a gist [gist.github.com/hassansin/81e6054ff28d5ef4cdbdad9d668df7a0](https://gist.github.com/hassansin/81e6054ff28d5ef4cdbdad9d668df7a0)
<div data-gist-show-spinner="true" data-gist-file="request-response.go" data-gist-id="81e6054ff28d5ef4cdbdad9d668df7a0" data-gist-hide-footer="true"></div>


**References:**

1. client.go from the `net/rpc` package: [golang.org/src/net/rpc/client.go](https://golang.org/src/net/rpc/client.go) . Most of the concept is borrowed from this package.

2. [www.enterpriseintegrationpatterns.com](http://www.enterpriseintegrationpatterns.com) to support all theoritical aspects of post.
