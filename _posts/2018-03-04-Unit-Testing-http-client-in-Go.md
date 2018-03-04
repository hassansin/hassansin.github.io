---
layout: post
title:  Unit Testing http client in Go
date:   2018-03-04 08:36 +0600
categories: Go
tags: Go
---

In this post, I'll show two approaches to write unit tests when making external HTTP calls without using any mocking library. Suppose we have the following contrived API struct to call external services. We'll write unit tests for the `DoStuff()` method that calls some API, handles any errors and probably do some complex logic with response. We just need to test our error handling and business logic part without making any actual API calls.

```go
package api

import (
	"io/ioutil"
	"net/http"
)

type API struct {
	Client  *http.Client
	baseURL string
}

func (api *API) DoStuff() ([]byte, error) {
	resp, err := api.Client.Get(api.baseURL + "/some/path")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	// handling error and doing stuff with body that needs to be unit tested
	return body, err
}


```

## 1. Using `httptest.Server`:

[`httptest.Server`](https://golang.org/pkg/net/http/httptest/#Server) allows us to create a local HTTP server and listen for any requests. When starting, the server chooses any available open port and uses that. So we need to get the URL of the test server and use it instead of the actual service URL.

```go
package api_test

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDoStuffWithTestServer(t *testing.T) {
	// Start a local HTTP server
	server := httptest.NewServer(http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {
		// Test request parameters
		equals(t, req.URL.String(), "/some/path")
		// Send response to be tested
		rw.Write([]byte(`OK`))
	}))
	// Close the server when test finishes
	defer server.Close()

	// Use Client & URL from our local test server
	api := API{server.Client(), server.URL}
	body, err := api.DoStuff()

	ok(t, err)
	equals(t, []byte("OK"), body)

}

```

## 2. By Replacing `http.Transport`


Transport specifies the mechanism by which individual HTTP requests are made. Instead of using the default [`http.Transport`](https://golang.org/pkg/net/http/#Transport), we'll replace it with our own implementation. To implement a transport, we'll have to implement [`http.RoundTripper`](https://golang.org/pkg/net/http/#RoundTripper) interface. From the documentation:

> RoundTripper is an interface representing the ability to execute a single HTTP transaction, obtaining the Response for a given Request.

This interface has just one method `RoundTrip(*Request) (*Response, error)`. So it's pretty straightforward to implement it. Here's an example of how to test the HTTP client with our own Transport implementation:

```go
package api_test

import (
	"bytes"
	"io/ioutil"
	"net/http"
	"testing"

)

// RoundTripFunc .
type RoundTripFunc func(req *http.Request) *http.Response

// RoundTrip .
func (f RoundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return f(req), nil
}

//NewTestClient returns *http.Client with Transport replaced to avoid making real calls
func NewTestClient(fn RoundTripFunc) *http.Client {
	return &http.Client{
		Transport: RoundTripFunc(fn),
	}
}

func TestDoStuffWithRoundTripper(t *testing.T) {

	client := NewTestClient(func(req *http.Request) *http.Response {
		// Test request parameters
		equals(t, req.URL.String(), "http://example.com/some/path")
		return &http.Response{
			StatusCode: 200,
			// Send response to be tested
			Body:       ioutil.NopCloser(bytes.NewBufferString(`OK`)),
 			// Must be set to non-nil value or it panics
			Header:     make(http.Header),
		}
	})

	api := API{client, "http://example.com"}
	body, err := api.DoStuff()
	ok(t, err)
	equals(t, []byte("OK"), body)

}
```

It's more code than the prevous one but, using this approach we don't have to spin up a HTTP server before each test and replace the service url with test server url. Suppose we're using an SDK package for a service that doesn't allow us to replace the service base url. The latter approach would be only way to go.

## References

1. [github.com/benbjohnson/testing](https://github.com/benbjohnson/testing): Snippets for `ok(t, error)` and `equals(t, interface{}, interface{})` methods used in the example
2. [`ioutil.NopCloser`](https://golang.org/pkg/io/ioutil/#NopCloser): To convert any `io.Reader` to `io.ReadCloser`


