# `barracuda` project

This a pure Lua library is for drawing barcode symbols. The project components
are able to typeset barcode from within a LuaTeX document. Therefore is also
possible to use `barracuda` with a Lua standalone interpreter to draw barcodes
with different graphic format such as `SVG` (see an example below). This package
does not have dependences.

![a Code39 symbol in SVG format](/test/test-ga-svg/test-code39.svg)

Internal modules are structured to ensure good performance and to give a
complete user control over barcode symbol parameters :thumbsup: .

Although development is in beta stage, `barracuda` has a good level of
stability.

## Current version

Version: v0.0.10
Date: 2020-02-04

## Barcode symbologies list

So far, the barcode symbologies included in the package are:

- Code 39
- Code 128
- Interleaved 2 of 5
- EAN family (ISBN, ISSN, EAN8, EAN13, and the add-ons EAN5 and EAN2)

Other 1D encoding symbology will be added to the project, then it will be the
turn of 2D barcode types like Datamatrix, QRCode or PDF417.

## A very simple LaTeX example

The LaTeX package `barracuda.sty` under the cover uses Lua code so you need to
compile your source files with LuaTeX or LuajitTeX with the LaTeX format.

For instance, here is a minimal working example for LuaLaTeX:

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
project directory, even if actually it is very minimal at the moment.

Directory `test` contains files useful also for code examples.

## Installation

The `barracuda` package can be used with pure Lua interpreter or from within a
TeX source file for Lua-powered typesetting engine like LuaTeX. In the first
case you can manually copy `src` folder content to a suitable directory of
your system. Otherwise, you can install the package via `tlmgr` for your TeX
Live distribution.

If you have installed TeX Live with the `full` schema, `barracuda` is just
available and no further action is required. Please, take into account that
only the tagged version (in the `git` sense) of the package will be sent to
CTAN. This means that intermediate development version between consecutive
releases can be found only at <https://github.com/robitex/barracuda> .

TeX Live distribution or Lua interpreter executable are available for a very
large number of Operating Systems so it is also for `barracuda`.

Step by step istruction can be found in the INSTALL.txt file.

## Contribute

Contributes are welcome in any form and for any topics. You can contact me
directly via email at giaconet.mailbox@gmail.com or via a pull request direct to
the repository <https://github.com/robitex/barracuda> or writing a public
message via the web page <https://github.com/robitex/barracuda/issues> for
todos, bugs, feature requests, and more (press the bottom `New issue`).

Anyway, as a starting point take a look of PLANNER.txt file for the development
program.

## License

`barracuda` project is released under the
[GNU GPL v2](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).
Please, for more legal details refer to LICENSE.txt file or visit the web page
<https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>

Copyright (C) 2020 Roberto Giacomelli
