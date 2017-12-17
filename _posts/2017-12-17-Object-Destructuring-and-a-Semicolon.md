---
layout: post
title:  Object Destructuring and a Semicolon
date:   2017-12-17 17:17 +0600
categories: javascript
tags: javascript
---

I've spent hours to figure this out. My project is configured to us [standardjs](https://standardjs.com), so there is no semicolon after each line.

Now consider the following example of object destructuring where variable is declared before assignment:

```js
let href
({href} = window.location)
console.log(href)
```
Notice the round braces ( ... ) around the assignment statement is required syntax when using object literal destructuring assignment without a declaration.

Let's do another destructuring right below it:

```js
let href, pathname
({href} = window.location)
({pathname} = window.location)
console.log(href, pathname)
```
And that gives you a `SyntaxError`:

```text
Uncaught SyntaxError: Unexpected token (
```
So what's going on here? It even complains if I do the destructuring right after a function call like:

```js
let href
somefunc()
({href} = window.location)
```

Turns out that I missed a little note in the [MDN documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Destructuring_assignment#Object_destructuring):

> NOTE: Your ( ..) expression needs to be preceded by a semicolon or it may be used to execute a function on the previous line.

Without the semicolon, when parsing, Javascript engine considers both lines as a single call expression. First line is the `Callee` and second line is parsed as `arguments` to it. You can run it through any parsers available at [astexplorer.net](https://astexplorer.net/) and get a similar AST like following(removed some properties for brevity):

```json
{
  "body": [
    {
      "type": "ExpressionStatement",
      "expression": {
        "type": "CallExpression",
        "callee": {
          "type": "CallExpression",
          "callee": {
            "type": "Identifier",
            "name": "somefunc"
          }
        },
        "arguments": [
          {
            "type": "AssignmentExpression",
            "operator": "=",
            "left": {
              "type": "ObjectPattern",
              "properties": [
                {
                  "type": "Property",
                  "key": {
                    "type": "Identifier",
                    "name": "href"
                  }
                }
              ]
            },
            "right": {
              "type": "MemberExpression",
              "object": {
                "type": "Identifier",
                "name": "window"
              },
              "property": {
                "type": "Identifier",
                "name": "location"
              }
            }
          }
        ]
      }
    }
  ]
}
```
So the fix here is to put a semi-color right before the destructuring expression and surprisingly the linter doesn't mind this semicolon either:

```js
let href
somefunc()
;({href} = window.location)
```


## References

1. [astexplorer.net](https://astexplorer.net/)
2. [Object Destructuring on MDN](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Destructuring_assignment#Object_destructuring)


