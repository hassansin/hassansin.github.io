#!/bin/bash

[[ -z "$1" ]] && echo "missing title in argument" && exit

d1="$(date +'%Y-%m-%d')"
d2="$(date +'%Y-%m-%d %H:%M %z')"
title="$1"
file="_posts/${d1}-${title//[^[:alnum:]]/-}.md"
header="---
layout: post
title:  ${title}
date:   ${d2}
categories: 
tags: 
---


## Title


### Sub-Title


<embed width="700" height="610" src="https://play.golang.org/p/0N9v5zmp3F" />

## References

1.
2.

"

[[ ! -f "$file" ]] && echo "$header" > "$file"
