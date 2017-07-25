---
layout: post
title:  "Constructor like functions in Go"
date:   2017-07-24 13:01:49 +0000
categories: go
tags: go
---

Go doesn’t have any OOP like constructors but it suggests to use constructor-like functions for intializing types. In this post I’ll list some use cases of constructor functions. These are just some idiomatic uses of the constructor, not any language bound constraints. All the examples are taken from the Go built-in libraries.

## Intialize types with with non-zero default values

Declaring variables, or calling of `new`, or using composite literal without any explicit value, or calling of `make` - in all these cases we get a zero valued variable. But sometimes you want your variables to be initialized with some sensible non-zero values. This is the most common use case of constructors. We can find this type of usage in almost all the built-in packages. For example in `encoding/json` package:

{% highlight go %}
func NewDecoder(r io.Reader) *Decoder {
	return &Decoder{r: r}
}
{% endhighlight %}


You can also use the constructor functions if you have some non-trivial initialization. For example, in [ring](https://golang.org/pkg/container/ring/) list, only way to create a ring list of n element is through the constructor function. Without the constructor function, you end up having a ring list with only one element.

<embed width="700" height="610" src="https://play.golang.org/p/0N9v5zmp3F"/>

## Multiple constructors with different initial values

Often we may need to construct our types based on different initial contents. We can either use one constructor with multiple optional parameters or use multiple constructors with different parameters. For example, look at the following definitions from [`bytes`](https://golang.org/pkg/bytes/#NewBuffer) package:

{% highlight go %}
func NewBuffer(buf []byte) *Buffer //initialize the buffer using []byte as initial content
func NewBufferString(s string) *Buffer //initialize the buffer using string as initial content
{% endhighlight %}

Another example from the [`bufio`](https://golang.org/pkg/bufio/#NewReader)  package:

{% highlight go %}
// NewReaderSize returns a new Reader whose buffer has at least the specified size.
func NewReaderSize(rd io.Reader, size int) *Reader
// NewReader returns a new Reader whose buffer has the default size.
func NewReader(rd io.Reader) *Reader
{% endhighlight %}


## Prevent users from directly modifying your private types e.g. Encapsulation

   We can declare a type as private and also return an interface type from the constructor function. This way users won’t be able to manipulate our type directly. Only way to work with the type is to use the interface methods. For example, following is a snippet from the package [`md5`](https://golang.org/pkg/crypto/md5/#New). Only way to work with the type is to use the constructor function and use the `hash.Hash32` interface methods for any operation.

{% highlight go %}
// Private type and private fields
type digest struct {
	s [4]uint32
	// some other private fields
}

// Return type for New() is an interface type
func New() hash.Hash {
	d := new(digest)
	d.Reset()
	return d
}
{% endhighlight %}

Using an interface type as return type is crucial here, otherwise we can directly change any public fields of the struct, even though the type itself is private.

Here is another example from the [`errors`](https://golang.org/src/errors/errors.go) package:

{% highlight go %}
// New returns an error that formats as the given text.
func New(text string) error {
	return &errorString{text}
}

// errorString is a trivial implementation of error.
type errorString struct {
	s string
}

func (e *errorString) Error() string {
	return e.s
}
{% endhighlight %}

where the predeclared type `error` is defined as an interface:

{% highlight go %}

type error interface {
	Error() string
}
{% endhighlight %}

----

Finally I'v seen people implementing Factory method patterns using constructors. I'm not listing it here since I'm not a big fan of this pattern. Too much abstraction freezes my brain :(
