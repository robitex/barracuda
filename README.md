# `barracuda` project

This Lua library is for drawing barcode symbols. The project delivers
package/module to typeset barcode from within a LuaTeX document. Therefore is
also possible to use `barracuda` with a Lua standalone interpreter and drawing
barcode with different graphic format using media like a file.

Internal module is structured to ensure good performance and to allow a
complete user control over barcode symbol parameters :thumbsup: .

Although development is in alpha stage, `barracuda` has a good level of
correctness.

# Barcode symbologies

So far, are supported Code 39, Code 128 and EAN family symbology. Other 1D
encoding format will be added soon to the project, then it will be the time for
2D barcode types.

# A very simple LaTeX example

The package `barracuda.sty` under the cover uses Lua code so you need to compile
source files with LuaTeX or LuajitTeX with the LaTeX format. Here, there is a
minimal example:

```latex
% !TeX program = LuaLaTeX
\documentclass{article}
\usepackage{barracuda}
\begin{document}
A\barracuda{code39}{123QWE}A
\end{document}
```

# License

Please, for more detail refer to LICENSE.txt file.

Copyright (C) 2019 Roberto Giacomelli
