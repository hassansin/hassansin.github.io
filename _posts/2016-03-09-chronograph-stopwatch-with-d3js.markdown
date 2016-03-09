---
layout: post
title:  "Chronograph Stopwatch with D3.js"
date:   2016-03-09 13:01:49 +0000
categories: d3.js dataviz
tags: d3.js dataviz
custom_js:
  - 'https://cdnjs.cloudflare.com/ajax/libs/gist-embed/2.4/gist-embed.min.js'
---


A small project to get started with D3.js. It covers some D3 fundamentals like scaling, transition, grouping, shapes, symbols, arcs etc. There is a play/stop button made with symbols to interact with the stopwatch. To reset the stopwatch, mouse over the button for two seconds.


<iframe sandbox="allow-scripts allow-forms allow-same-origin" src="demo/stopwatch.html" marginwidth="0" marginheight="0" style="height:300px;border:none;" scrolling="no"></iframe>

View it at [bl.ocks.org](http://bl.ocks.org/hassansin/b140fcba99f126299eae)



Here are a couple of notes that I found interesting while doing this project:

## Grouping related elements

This is really an important concept to group related elements with `g` element. `g` is like the `<div/>` tag in html, but it doesn't have any visual effect on your document. All the child elements inside the `g` element inherit attributes from it. We can utilize this fact to achieve a few things:

- **Translating SVG origin:**

    It is sometimes difficult to think when the origin is in the top-left corner. I'm used to picture the origin in the center and rotate counter-clockwise. But in SVG, the origin is in top-left corner and rotation occurs in a clockwise manner. You can use `translate` transformation to move the origin to the center.

    For example, in the stopwatch, the primary face dial is centered on the svg by `'translate('+ w/2 +','+ h/2 +')',`. Here I did a translation on the `g` container instead of individual elements. So everything in the group will have the origin at the center. This makes it easy to place the clock needle and the clock the markers.

    <div data-gist-show-spinner="true" data-gist-file="stopwatch.js" data-gist-id="b140fcba99f126299eae" data-gist-line="129-135"></div>

- **Rotate elements together:**

    Similarly, putting elements in the `g` element makes it easy to rotate a group of elements together. The clock needle and wheel are two separate elements, but during animation, I only rotate their `g` container and that makes both child elements rotated at the same time:


    <div data-gist-show-spinner="true" data-gist-file="stopwatch.js" data-gist-id="b140fcba99f126299eae" data-gist-line="439-460" data-gist-highlight-line="442"></div>


## Javascript timers aren't accurate

Initially I thought of using javascript `setInterval` with an interval of 10 milliseconds. That would give me a precision of  1/100th of a second. But it didn't work well. Here is the naive code:

{% highlight javascript %}
var timer;

function startStopTimer(){
  if(isStarted){
    updateButton('start');
    clearInterval(hInterval);
  }
  else{
    updateButton('stop');
    hInterval = setInterval(function(){
      mseconds++;
      updateDial(mseconds*3.6, 'dial-tertiary', tertiary);
      if(mseconds === 100){
        seconds++;
        updateDial(6*minutes + seconds*0.1, 'dial-secondary', secondary);
        mseconds = 0;
      }
      if(seconds === 60){
        seconds = 0;
        minutes++;
      }
      if(minutes === 60){
        minutes = 0;
        hours++;
      }
      if(mseconds % 5 ===0){
        updateDial(6*seconds + mseconds*0.06, 'dial-primary', primary);
      }
    },10);
  }
  isStarted = !isStarted;
}
{% endhighlight %}

It has a problem that the interval time lags over time. Javascript being run in a single thread in browsers, there is no guarantee that the callback will be called in exactly 10 milliseconds interval. It depends on whether the browser or the processor is busy with doing other things. And if I switch browser tabs or window in Chrome, `setInterval` stops completely. Here's what [MDN](https://developer.mozilla.org/en-US/docs/Web/API/WindowTimers/setInterval#Inactive_tabs) says about Firefox:

> Starting in Gecko 5.0 (Firefox 5.0 / Thunderbird 5.0 / SeaMonkey 2.2), intervals are clamped to fire no more often than once per second in inactive tabs.

So the fix is to use the system time by `Date.now()` and find the total elapsed time from the start of the clock. Also, it doesn't affect the accuracy if browser tab is inactive.


<div data-gist-show-spinner="true" data-gist-file="stopwatch.js" data-gist-id="b140fcba99f126299eae" data-gist-line="391-405"></div>

Another option is to use [D3 Timer](https://github.com/d3/d3-timer) module instead of `setTimeout`. It uses [`window.requestAnimationFrame`](https://developer.mozilla.org/en-US/docs/Web/API/window/requestAnimationFrame) smooth animation, but falls back to setTimeout for larger(24ms) delays. The `tick` function above with D3 timeout would look like this:

{% highlight javascript %}

function tick(){
  now = Date.now();
  elapsedTime = elapsedTime + now - startTime;
  startTime = now;

  var ms = elapsedTime/10,
      seconds = ms/100,
      minutes = seconds/60;

  updateNeedle(g1.needle, minuteMarkerScale(seconds));
  updateNeedle(g2.needle, minuteMarkerScale(minutes));
  updateNeedle(g3.needle, milliSecondScale(ms));
  timeoutHandle = d3_timer.timeout(tick,1);
}

// to stop the timer use `timeoutHandle.stop()` instead of `clearTimeout(timeoutHandle)`

{% endhighlight %}