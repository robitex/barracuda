# `barracuda` project

This Lua library is for drawing barcode symbols. The project delivers
modules to typeset barcode from within a LuaTeX document. Therefore is
also possible to use `barracuda` with a Lua standalone interpreter to draw
barcodes with different graphic format such as `SVG`.

![a SVG formatted Code39 symbol](/test/test-ga-svg/test-code39.svg)

Internal module is structured to ensure good performance and to allow a
complete user control over barcode symbol parameters :thumbsup: .

Although development is in beta stage, `barracuda` has a good level of
stability.

## Barcode symbologies

So far, are supported

- Code 39
- Code 128
- Interleaved 2 of 5
- EAN family

Other 1D encoding format will be added to the project, then it will be the
turn for 2D barcode type.

## A very simple LaTeX example

The package `barracuda.sty` under the cover uses Lua code so you need to compile
your source files with LuaTeX or LuajitTeX with the LaTeX format. In other
words, use LuaLaTeX.

Here, there is a minimal example:

```latex
% !TeX program = LuaLaTeX
\documentclass{article}
\usepackage{barracuda}
\begin{document}
\barracuda{code39}{123ABC}
\end{document}
```

## Documentation

Details and package reference can be found in the manual delivered in the `doc`
project directory, even if it is very minimal at the moment.

## Installation

The `barracuda` package can be used with pure Lua interpreter or from within a
TeX source file for a Lua-powered typesetting engile like LuaTeX. In the first
case you can manually copy the project files in a suitable directory of your
system. Otherwise, you can install the package via `tlmgr` once configured the
`tlcontrib` repository. More detailed istruction will come soon.

In fact, to work with `barracuda` no matter what is your Operating System.

## License

Please, for more legal detail refer to LICENSE.txt file.

Copyright (C) 2019 Roberto Giacomelli
