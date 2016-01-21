# gi3-edit ("Mark")
This is a basic text editor meant to straddle the line between classic GUI features that we're used to,
and the power of keyboard-driven interfaces. Or something.

Mostly what it is is a minimal text editor meant to provide all the features of gedit while playing nice with i3.

The gi3 (rhymes with pie) project may be something I pursue in the future, kinda creating a cohesive 
desktop environment for i3.

## Usage

Ctrl-Shift-P will open a dmenu of available actions. If you try to use this for real, you'll probably break something.

## Compiling
This uses [autovala](https://github.com/rastersoft/autovala) to construct the build system. It should be something like:

```
$ autovala update
$ mkdir install
$ cd install
$ cmake ..
$ make
```

But you should probably read the docs.
