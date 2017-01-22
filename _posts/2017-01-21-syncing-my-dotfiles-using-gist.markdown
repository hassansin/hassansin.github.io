---
layout: post
title:  "Syncing my dotfiles between my home and office pcs using gist"
date:   2017-01-21 20:00:00 +0000
categories: gist dotfiles
tags: gist dotfiles
---

I recently have started learning the VIM with tmux and been using it both at my home and office. As I experiment with different vim configuration and plugins, I frequently find myself editing the vim and tmux configuration. I use Gist to keep the backups of the dotfiles. Sometimes I upload my config to the gist at office and then coming back at home, I pull it and sync the home pc. Sometime I do the opposite. This back and forth updating of the gist gets very annoying sometimes. So like all lazy programmers out there, I quickly wrote this bash function and put it my `.zshrc`. Now everytime I update a config, I just run following command:

{% highlight shell %}
cat ~/.zshrc | gist put $DOTFILES_GISTID .zshrc
{% endhighlight %}

and the back at my other pc, I just do :

{%highlight shell%}
gist get $DOTFILES_GISTID .zshrc > ~/.zshrc
{% endhighlight %}

to sync up the file.

I know there are many other dotfile syncing tools out there, but I needed something simple and manageable right from my zsh config. It Just does what I need, not another feature-rich tool, 99% of which remains unused. Maybe I'll put these two commands in aliases and save some keystrokes, but for now, I'll stick with `Ctrl+r`.

Here is the bash function I used. It uses `jq` to parse the json response from [api.github.com/gist](https://developer.github.com/v3/gists/#edit-a-gist). I know it's another dependent tool, but that's fine for me as I always have jq installed in my pcs. 

{% highlight shell %}
export DOTFILES_GISTID=2a2bd32c9c2e514c17da4b2ec8b3851c
gist(){
    if [ -z $1 -o -z $2 -o -z $3 ]; then
       echo 'usage: gist put|get|delete gistid filename';
    elif [ $1 = "put" ]; then
        jq -R -s 'split("\n") | join("\n") | {files: {"'"$3"'": {content: .}}}' | \
        curl -s -u hassansin -XPATCH https://api.github.com/gists/$2 -d @- | \
        jq -r -e  'if .description then "updated: " + .description else . end'
    elif [ $1 = "get" ]; then
        curl -s "https://api.github.com/gists/$2" | jq -r -e '.files."'"$3"'".content'
    elif [ $1 = "delete" ]; then
        jq -n '{files: {"'"$3"'": {content: ""}}}' | \
        curl -s -u hassansin -XPATCH https://api.github.com/gists/$2 -d @- |\
        jq -r -e  'if .description then "updated: " + .description else . end'
    fi
}
{% endhighlight %}

