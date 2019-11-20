# `barracuda` project

This Lua library is for drawing barcode symbols. The project delivers
modules to typeset barcode from within a LuaTeX document. Therefore is
also possible to use `barracuda` with a Lua standalone interpreter to draw
barcodes with different graphic format such as `SVG`.

![a SVG encoded Code39 symbol](/test/test-ga-svg/test-code39.svg)

Internal module is structured to ensure good performance and to allow a
complete user control over barcode symbol parameters :thumbsup: .

Although development is in beta stage, `barracuda` has a good level of
features.

## Barcode symbologies

So far, are supported

- Code 39
- Code 128
- ITF 2of5
- EAN family

Other 1D encoding format will be added to the project, then it will be the
time for 2D barcode types.

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

## License

Please, for more detail refer to LICENSE.txt file.

Copyright (C) 2019 Roberto Giacomelli
