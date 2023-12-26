# Shadertoy Screensaver

Based on https://github.com/shaiggon/Shadertoy-Screensaver

![Screenshot of the screensaver](screenshot/screenshot.png?raw=true)

Displays arbitrary [Shadertoy](https://shadertoy.com) shaders by giving shader IDs and
use them as a macOS screensaver. Supports list of shaders and randomizes them across monitors.

## Installation

Open the project in Xcode and build it. Double click on the created `Shadertoy-Screensaver.saver` to install it.

## Usage

In the options give the Shadertoy shader IDs - the list of IDs (separated by comma) of the shaders you want to show. For example
for the shader in URL [https://www.shadertoy.com/view/dtG3z1](https://www.shadertoy.com/view/dtG3z1)
the shader ID is `dtG3z1`. And for two shaders it could be `DtyfRh,mtyGWy` You also need to provide the API key that you can request from
[https://www.shadertoy.com/myapps](https://www.shadertoy.com/myapps). After pressing `Fetch` the
shaders will be downloaded. And hitting close will use them as your screensaver.


## TODO

* Allow user to load shaders from disk to allow using shaders which are not available via the API
* HDR support
* Specify FPS limit
* Random number generator/sahder variable
* One to one mapping of GL uniforms to the ones used in Shadertoy
* Multiple buffers (now just supports on image shaders)
* Clean up code
* Easier installation
* Fix this: This might cause some shaders not working exactly as they work in your browser. For example on Shadertoy an uninitialized
variable may be initialized to zero while the same variable might be garbage in this project.
