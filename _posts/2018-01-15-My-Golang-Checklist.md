---
layout: post
title:  My Golang Checklist
date:   2018-01-15 18:24 +0600
categories: Go
tags: Go
published: false
---


## Mutex:

* Place the mutex above the fields that it will protect as a best practice. [↪](https://hackernoon.com/dancing-with-go-s-mutexes-92407ae927bf)
* Hold a mutex lock only for as long as necessary. [↪](https://hackernoon.com/dancing-with-go-s-mutexes-92407ae927bf)
* Utilize defer to Unlock your mutex where a given function has multiple locations that it can return. [↪](https://hackernoon.com/dancing-with-go-s-mutexes-92407ae927bf)
* `go test -race -v ./…`[↪](https://hackernoon.com/dancing-with-go-s-mutexes-92407ae927bf)
* hide or encapsulate the method of synchronization used. [↪](https://hackernoon.com/dancing-with-go-s-mutexes-92407ae927bf)
* When to use: cache, state  [↪](https://github.com/golang/go/wiki/MutexOrChannel)
* If the receiver is a struct that contains a sync.Mutex or similar synchronizing field, the receiver must be a pointer to avoid copying. [↪](https://github.com/golang/go/wiki/CodeReviewComments#receiver-type)


## Context:

* All long, blocking operations take context.Context. Context is a standard way to give users of your library control over when actions should be interrupted. [↪](https://medium.com/@cep21/how-to-correctly-use-context-context-in-go-1-7-8f2c0fafdf39)


## Testing:

* Tests should fail with helpful messages saying what was wrong, with what inputs, what was actually got, and what was expected. [↪](https://github.com/golang/go/wiki/CodeReviewComments#useful-test-failures)

```go
if got != tt.want {
	t.Errorf("Foo(%q) = %d; want %d", tt.in, got, tt.want) // or Fatalf, if test can't test anything more past this point
}
```

* Run race detector during tests & development [↪](https://blog.golang.org/race-detector)

[1] https://go-proverbs.github.io/
[2] https://github.com/golang/go/wiki/CodeReviewComments
[3] https://hackernoon.com/dancing-with-go-s-mutexes-92407ae927bf
[4] https://medium.com/@cep21/aspects-of-a-good-go-library-7082beabb403


