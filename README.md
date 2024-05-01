# FFT hardware written in BSV (and also C++).

**_NOTE_**: This codebase uses MIT's lab2 harness from 6.375 as it's base.

This codebase contains FFT hardware models written in Bluespec System Verilog. You may build verilog by using the Bluespec compiler (linked below). There is also a C++ version which can be used for high-level synthesis.

## Prerequisites
1. Text Editor
2. Bluespec Compiler - https://github.com/B-Lang-org/bsc/releases/tag/2024.01

Steps to build verilog from BSV:

```shell
make verilog
```

Steps to build verilog from C++:

```shell
cd cpp ; vivado_hls -f script.tcl
```

If you need help with using this code elsewhere, or something doesn't work at your end, too bad.