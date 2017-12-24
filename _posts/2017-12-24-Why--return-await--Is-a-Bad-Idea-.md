---
layout: post
title:  Why Using `return await` Is a Bad Idea?
date:   2017-12-24 05:08 +0600
categories: javascript
tags: javascript
---
The ESLint rule [`no-return-await`](https://eslint.org/docs/rules/no-return-await) disallows the use of `return await` inside an async function. It says:

> Since the return value of an `async function` is always wrapped in `Promise.resolve`, `return await` doesn’t actually do anything except add extra time before the overarching Promise resolves or rejects.

This post is an attempt to figure out this statement using Nodejs experimental [Async hooks](https://nodejs.org/api/async_hooks.html). Async hooks allows us to register callbacks when an asynchronous resource e.g. a promise is created or resolved. Following is a little helper script to help us see when a promise is created, what triggered the promise, when it is resolved etc. Notice the use of `fs.writeSync` instead of `console.log` which is an asynchronous operation and could cause an infinite recursion if used with Async hooks.

```js
//promise-hooks.js
const hooks = require('async_hooks')
const fs = require('fs')

let indent = 0

module.exports = hooks.createHook({
  promiseResolve (asyncId) {
    const indentStr = ' '.repeat(indent)
    fs.writeSync(1, `${indentStr}promise resolved: ${asyncId}\n`)
  },
  init (asyncId, type, triggerAsyncId, resource) {
    const eid = hooks.executionAsyncId()
    const indentStr = ' '.repeat(indent)
    fs.writeSync(1, `${indentStr}${type}(${asyncId}), trigger: ${triggerAsyncId}, resource: ${resource.parentId}, execution: ${eid}\n`)
  },
  before (asyncId) {
    const indentStr = ' '.repeat(indent)
    fs.writeSync(1, `${indentStr}before:  ${asyncId}\n`)
    indent += 2
  },
  after (asyncId) {
    indent -= 2
    const indentStr = ' '.repeat(indent)
    fs.writeSync(1, `${indentStr}after:   ${asyncId}\n`)
  },
  destroy (asyncId) {
    const indentStr = ' '.repeat(indent)
    fs.writeSync(1, `${indentStr}destroy: ${asyncId}\n`)
  }
})

```

First, let's try out an async function that returns a string, without any `await` expression:

```js
const hooks = require('./promise-hooks')
hooks.enable()
async function hello (){
    return "World"
}
hello()
```

The output would look like this:

```txt
PROMISE(5), trigger: 1, resource: undefined, execution: 1
promise resolved: 5
```

Above could be explained as : The root resource (with ID 1) triggered the creation of a new `PROMISE` type resource with ID 5 and then a promise resource with ID 5 is resolved. So there's **ONE** promise instance created for the above async function. It's obvious since when an async function is called [it always returns a promise](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function).

Now let's see what happens when we just add an `await` expression in return statement in above function:

```js
const hooks = require('./promise-hooks')
hooks.enable()
async function hello (){
    return await "World"
}
hello()
```

```txt
PROMISE(5), trigger: 1, resource: undefined, execution: 1
PROMISE(6), trigger: 5, resource: 5, execution: 1
PROMISE(7), trigger: 6, resource: 6, execution: 1
promise resolved: 6
before:  7
  promise resolved: 5
  promise resolved: 7
after:   7
```

Whoa! That's TWO EXTRA promise instances just by adding that `await` keyword within the return statement. That's two extra CPU ticks(microtasks?) wasted on waiting before returning the string. But why two, instead of just one `Promise.resolve` to resolve whatever value is passed to the `await` expression? To understand this, let's transpile the above code with [babel](https://babeljs.io/repl/#?babili=false&browsers=&build=&builtIns=true&code_lz=IYZwngdgxgBAZgV2gFwJYHsIwBYFMA2-6MAFAJQwDeAUDDAE67IL1YDkA6uvfgCZvUAvtTyF05akA&debug=false&circleciRepo=&evaluate=false&lineWrap=true&presets=stage-0&prettier=true&targets=Node-9&version=6.26.0). The transpiled code looks like following:

```js
let hello = (() => {
  var _ref = _asyncToGenerator(function*() {
    return "World";
  });

  return function hello() {
    return _ref.apply(this, arguments);
  };
})();

function _asyncToGenerator(fn) {
  return function() {
    var gen = fn.apply(this, arguments);
    return new Promise(function(resolve, reject) {
      function step(key, arg) {
        try {
          var info = gen[key](arg);
          var value = info.value;
        } catch (error) {
          reject(error);
          return;
        }
        if (info.done) {
          resolve(value);
        } else {
          return Promise.resolve(value).then(
            function(value) {
              step("next", value);
            },
            function(err) {
              step("throw", err);
            }
          );
        }
      }
      return step("next");
    });
  };
}

hello();
```


Looks like `async/await` is similar to combining generators and promises. Let's simplify this and remove everything except promises. This is how our `hello` function would _finally_ look like:

```js
const hooks = require('./promise-hooks')
hooks.enable()
function hello (){
    return new Promise((resolve, reject) => {
        Promise.resolve("World").then(value => resolve(value))
    }
}
hello()
```

Running above traspiled would give us almost similar output as we've seen in the non-transpiled version: 

```txt
PROMISE(5), trigger: 1, resource: undefined, execution: 1
PROMISE(6), trigger: 1, resource: undefined, execution: 1
promise resolved: 6
PROMISE(7), trigger: 6, resource: 6, execution: 1
before:  7
  promise resolved: 5
  promise resolved: 7
after:   7
```
Here we can see  where these three promises come from. First one is created by `new Promise()`, second one for `Promise.resolve()` and the third one comes from the `then()` callback. Remember that the `await` expression pauses execution and waits for the operation to finish? That's what the line `Promise.resolve(...).then(...)` does. This makes sense when you are waiting inside an async function and do something else with the resolved value. But when using `return await` together, that means you're waiting TWO times for the same operation -  one within the async function and then again when this async function is called from different place of your code. And that's just waste of CPU cycles.


## References

1. [eslint.org/docs/rules/no-return-await](https://eslint.org/docs/rules/no-return-await)
2. [blog.risingstack.com/node-js-at-scale-understanding-node-js-event-loop](https://blog.risingstack.com/node-js-at-scale-understanding-node-js-event-loop/)
3. [async function on MDN](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function)

