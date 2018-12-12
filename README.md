# `barracuda` project

This Lua library is for drawing barcode symbol. The project delivers
package/module to typeset barcode from within a LuaTeX document. Therefore is
also possible to use `barracuda` with a Lua standalone interpreter and drawing
barcode with different graphic format using media like a file.

Internal module is structured to allow good performance and to ensure a
complete user control over barcode symbol parameters.

Although development is in alpha stage, `barracuda` has a good level of
correctness :thumbsup: 

# Barcode symbologies

So far, only the Code 39 specification is supported but very soon other 1D
encoding format will be added to the project.

# A very simple LaTeX example (also known as `barracuda` taste)

```latex
% !TeX program = LuaLaTeX

\documentclass{article}
\usepackage{barracuda}

\begin{document}
A\barracuda{code39}{123QWE}A
\end{document}
```


