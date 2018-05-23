# node_installer

This script is meant to provide simple global installation of node & npm.

## Supported systems

* Linux
* macOS

## Prerequisites

* `wget` or `curl`

## Installation

* as root:

  `curl -sS https://raw.githubusercontent.com/salsita/node_installer/master/install.sh | bash`

  or

  `wget -qO- https://raw.githubusercontent.com/salsita/node_installer/master/install.sh | bash`

* with `sudo`:

  `curl -sS https://raw.githubusercontent.com/salsita/node_installer/master/install.sh | sudo bash`

  or

  `wget -qO- https://raw.githubusercontent.com/salsita/node_installer/master/install.sh | sudo bash`

## Usage

```
Usage as root or with sudo:
  node_installer 8.9.1 # this installs 8.9.1 version
  node_installer clean # this cleans your system from older installations done via this script
  node_installer help # prints this help
```

## Global modules

Global modules can be installed as you are used to via `npm install -g <module>`, but root is required.
All global binaries are linked into `/usr/local/bin`.
*When you run `node_installer clean`, it will only clean you node version, all linked binaries will stay there as broken links,
you will have to delete them manually.*

## Licence

The MIT License (MIT)

Copyright (c) 2016, 2017 Salsita Software

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
