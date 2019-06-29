% labelreport.cls
%
% Version: v0.0.6
%
% Copyright (C) 2019 Roberto Giacomelli <giaconet dot mailbox at gmail dot com>
%
%    This work may be distributed and/or modified under the
%    conditions of the LaTeX Project Public License, either
%    version 1.3 of this license or any later version.
%    The latest version of this license is in
%    http://www.latex-project.org/lppl.txt and version 1.3
%    or later is part of all distributions of LaTeX version
%    2005/12/01 or later.
%
% This work has the LPPL maintenance status `maintained'.
% 
% The Current Maintainer of this work is Roberto Giacomelli
%
% This work consists of these files:
% labelreport.cls
%
%
\NeedsTeXFormat{LaTeX2e}[1995/12/01]
\ProvidesClass{labelreport}[2019/01/28 v0.0.6 A class for label printing]
%
%%% Loading class section
%
\LoadClass{article}
%
%%% Loading package section
%
\RequirePackage{geometry}














%
%%% Main code section
%
% Definition of the label counters:
%
\newcount\lblrep@i%             a generic loop counter :-)
\newcount\lblrep@row%           label place number on the row (from zero)
\newcount\lblrep@col%           label place number on the column (from zero)
\newcount\lblrep@totrow%        the total number of labels in a row (minus 1)
\newcount\lblrep@totcol%        the total number of labels in a column (minus 1)
\newcount\lblrep@endcol%        ending column place (until option)
\newcount\lblrep@endrow%        ending row place (until option)
\newcount\lblrep@r%             temporary row counter (from, until options)
\newcount\lblrep@c%             temporary column counter (from, until options)
\newcount\lblrep@end%           temporary end place
\newcount\lblrep@cur%           temporary current place
\newcount\lblrep@pos%           the label place on the page (fill mode dependent)
\newcount\lblrep@num%           the number of labels counter
\newcount\lblrep@numstart%      number of printed labels at start of the page
\newcount\lblrep@series%        the number of single label series
\newcount\lblrep@hferr%         page number with Header/Footer horizontal overfull
%
%%% The Grid object
%
% Definition of the grid dimension registers (private Grid field)
\newdimen\lblrep@Grid@dx%       the label dimension in x direction
\newdimen\lblrep@Grid@dy%       the label dimension in y direction
\newdimen\lblrep@Grid@mx%       x coord of the left bottom corner of the first label
\newdimen\lblrep@Grid@my%       y coord of the left bottom corner of the first label
\newdimen\lblrep@Grid@ox%       distance in x direction to locale system origin
\newdimen\lblrep@Grid@oy%       distance in y direction to locale system origin
\newdimen\lblrep@Grid@s%        Radius of internal dd label
\newdimen\lblrep@Header@y%      y position of the Header line
\newdimen\lblrep@Footer@y%      y position of the Footer line
\newdimen\lblrep@HF@center%     x position of the center of marks
\newdimen\lblrep@Header@sep%    distance from the header labels to the mark baseline
\newdimen\lblrep@Footer@sep%    distance from the footer labels to the mark baseline
\newdimen\lblrep@HF@xgrid%      width of the labels grid equal to the width of Header and Footer
\newdimen\lblrep@HF@xmin%       Header and Footer (left and right) minimal margin
%
% private macro for parsing the shape functions arguments
% save the #2 length in lblrep@Grid@#1 macro
\def\lblrep@Grid@parseleni#1(#2){%
  \pst@getlength{#2}{\lblrep@tmp}
  \expandafter\let\csname lblrep@Grid@#1\endcsname\lblrep@tmp%
}
%
\def\lblrep@Grid@parselenii#1#2(#3;#4){%
  \lblrep@Grid@parseleni#1(#3)
  \lblrep@Grid@parseleni#2(#4)
}
%
\def\lblrep@Grid@parseleniii#1#2#3(#4;#5;#6){%
  \lblrep@Grid@parseleni#1(#4)
  \lblrep@Grid@parseleni#2(#5)
  \lblrep@Grid@parseleni#3(#6)
}
%
% private definition of 'functions' string to parse the key arg
\def\lblrep@Grid@key@xyr{xyr}
\def\lblrep@Grid@key@xy{xy}
\def\lblrep@Grid@key@d{d}
\def\lblrep@Grid@key@dd{dd}
%
% private Grid macro: definition of the label border and others
\def\lblrep@Grid@edge@xyr{% label shape=xyr
  \def\lblrep@Grid@labelborder{%
    \psframe[linewidth=0.3pt,
             cornersize=absolute,
             linearc=\lblrep@Grid@r\p@]
             (0,0)
             (\lblrep@Grid@x\p@,\lblrep@Grid@y\p@)%
  }
  \lblrep@Grid@ox=\z@
  \lblrep@Grid@oy=\z@
}
%
\def\lblrep@Grid@edge@xy{% label shape=xy
   \pst@getlength{0}{\lblrep@Grid@r}
   \def\lblrep@Grid@labelborder{%
      \psframe[linewidth=0.3pt]
         (0,0)
         (\lblrep@Grid@x\p@,\lblrep@Grid@y\p@)%
   }
   \lblrep@Grid@ox=\z@
   \lblrep@Grid@oy=\z@
}
%
\def\lblrep@Grid@edge@d{% label shape=d
   \let\lblrep@Grid@y\lblrep@Grid@x
   \lblrep@Grid@ox=\lblrep@Grid@x\p@
   \divide\lblrep@Grid@ox\tw@
   \lblrep@Grid@oy=\lblrep@Grid@ox%
   %
   \def\lblrep@Grid@labelborder{%
      \pscircle[linewidth=0.3pt]
         (\lblrep@Grid@ox,\lblrep@Grid@oy){\lblrep@Grid@ox}%
   }
}
%
\def\lblrep@Grid@edge@dd{% label shape=dd
   \ifdim\lblrep@Grid@a\p@>\lblrep@Grid@b\p@
      \let\lblrep@Grid@x\lblrep@Grid@a
      \let\lblrep@Grid@y\lblrep@Grid@a
      \lblrep@Grid@ox=\lblrep@Grid@a\p@
      \lblrep@Grid@s=\lblrep@Grid@b\p@
   \else
      \let\lblrep@Grid@x\lblrep@Grid@b
      \let\lblrep@Grid@y\lblrep@Grid@b
      \lblrep@Grid@ox=\lblrep@Grid@b\p@
      \lblrep@Grid@s=\lblrep@Grid@a\p@
   \fi
   \divide\lblrep@Grid@ox\tw@
   \lblrep@Grid@oy=\lblrep@Grid@ox
   \divide\lblrep@Grid@s\tw@
   %
   \def\lblrep@Grid@labelborder{%
          \pscircle[linewidth=0.3pt]
              (\lblrep@Grid@ox,\lblrep@Grid@oy){\lblrep@Grid@ox}%
          \pscircle[linewidth=0.3pt]
              (\lblrep@Grid@ox,\lblrep@Grid@oy)
              {\lblrep@Grid@s}%
   }
}
%
% private command to parsing the shape functions
\def\lblrep@Grid@setupshape#1(#2){%
  \def\lblrep@tmp{#1}
  \ifx\lblrep@tmp\lblrep@Grid@key@xyr
     \lblrep@Grid@parseleniii xyr(#2)
     \lblrep@Grid@edge@xyr
  \else
    \ifx\lblrep@tmp\lblrep@Grid@key@xy
      \lblrep@Grid@parselenii xy(#2)
      \lblrep@Grid@edge@xy
    \else
      \ifx\lblrep@tmp\lblrep@Grid@key@d
        \lblrep@Grid@parseleni x(#2)
        \lblrep@Grid@edge@d
      \else
        \ifx\lblrep@tmp\lblrep@Grid@key@dd
          \lblrep@Grid@parselenii ab(#2)
          \lblrep@Grid@edge@dd
        \else
          \ClassError{pst-labelreport}{Unknow function '#1()' for shape property}
           {Unknow function '#1()' for shape, see the manual for explanation}
        \fi
      \fi
    \fi
  \fi
}
%
% private macro to build all of the label grid layout
% called at the start of the document
% (and this overriding the previous Grid property values)
\def\lblrep@Grid@buildlayout{%
  % resolving the horizontal grid layout
  \lblrep@Grid@dx=\lblrep@Grid@x\p@
  \advance\lblrep@Grid@dx-.001pt% necessary to resolve round problem
  \lblrep@i=0
  \@whiledim\lblrep@Grid@dx<\paperwidth\do{%
     \advance\lblrep@i\@ne
     \advance\lblrep@Grid@dx\lblrep@Grid@xsep\p@
     \advance\lblrep@Grid@dx\lblrep@Grid@x\p@
  }
  \lblrep@totcol=\lblrep@i
  \lblrep@Grid@dx=\dimexpr\lblrep@Grid@x\p@+\lblrep@Grid@xsep\p@\relax
  \lblrep@Grid@mx=\dimexpr(\paperwidth-
                  (\lblrep@Grid@dx*\lblrep@totcol-\lblrep@Grid@xsep\p@))/2\relax
  %
  % horizontal (pseudo)margin setup
  \lblrep@HF@center=\dimexpr\paperwidth/2\relax
  \ifdim\lblrep@Grid@mx>\lblrep@HF@xmin
     \lblrep@HF@xgrid=\dimexpr\paperwidth-\lblrep@Grid@mx*2\relax
  \else
     \lblrep@HF@xgrid=\dimexpr\paperwidth-\lblrep@HF@xmin*2\relax
  \fi
  %
  % resolving the vertical grid layout
  \lblrep@Grid@dy=\lblrep@Grid@y\p@
  \advance\lblrep@Grid@dy-.001pt% necessary to resolve round problem
  \lblrep@i=0
  \@whiledim\lblrep@Grid@dy<\paperheight\do{%
     \advance\lblrep@i\@ne
     \advance\lblrep@Grid@dy\lblrep@Grid@ysep\p@
     \advance\lblrep@Grid@dy\lblrep@Grid@y\p@%
  }
  \lblrep@totrow=\lblrep@i
  \lblrep@Grid@dy=\dimexpr\lblrep@Grid@y\p@+\lblrep@Grid@ysep\p@\relax
  \lblrep@Grid@my=\dimexpr(\paperheight-
                  (\lblrep@Grid@dy*\lblrep@totrow-\lblrep@Grid@ysep\p@))/2\relax
  %
  % vertical (pseudo)margin setup
  \lblrep@Header@y=\lblrep@Grid@my
  \advance\lblrep@Header@y-\lblrep@Header@sep
  \lblrep@Footer@y=\paperheight
  \advance\lblrep@Footer@y-\lblrep@Grid@my
  \advance\lblrep@Footer@y\lblrep@Footer@sep
  %
  \advance\lblrep@Grid@my\lblrep@Grid@y\p@
  \advance\lblrep@totcol\m@ne
  \advance\lblrep@totrow\m@ne
}
%
% definition of the Grid properties
\define@key{lblrepGrid}{unit}{\psset{unit=#1}}
\define@key{lblrepGrid}{xsep}[0]{\pst@getlength{#1}{\lblrep@Grid@xsep}}
\define@key{lblrepGrid}{ysep}[0]{\pst@getlength{#1}{\lblrep@Grid@ysep}}
\define@key{lblrepGrid}{shape}{\lblrep@Grid@setupshape#1}
\define@boolkey{lblrepGrid}[lblrep@Grid@]{showgrid}[true]{}
%
% set the optional key default values
\setkeys{lblrepGrid}{xsep,ysep}
\setkeys{lblrepGrid}{showgrid=false}
%
% public interface: grid setup command
\newcommand{\setGrid}[1]{%
   \setkeys{lblrepGrid}{#1}%
}
\@onlypreamble\setGrid
%
% Single grid setup command with dot notation
\def\Grid.#1(#2){%
  \@ifnextchar){\setkeys{lblrepGrid}{#1=#2)}\@gobble}
               {\setkeys{lblrepGrid}{#1=#2}}
}
\@onlypreamble\Grid
%
% this command draw the label grid on the page
% it's called by showgrid=true option
\def\lblrep@Grid@drawlabelframe{%
  \advance\lblrep@totcol\@ne
  \advance\lblrep@totrow\@ne
  \pstPutAbs[position=lb](\lblrep@Grid@mx,-\lblrep@Grid@my){% this comment char is important
    \multirput(0,0)(0,-\lblrep@Grid@dy){\the\lblrep@totrow}{%
      \multirput(0,0)(\lblrep@Grid@dx,0){\the\lblrep@totcol}{%
      \lblrep@Grid@labelborder}%
    }%
  }
  \advance\lblrep@totcol\m@ne
  \advance\lblrep@totrow\m@ne
}
%%% end of the Grid object code
%
%%% The Fill object
%
% a flag (of the 'etoolbox' package) that is a fill mode
% change request, performed only at the next new page
\newtoggle{modechanged}\toggletrue{modechanged}
%
% definition of the Fill properties
%
% macro variable to save the name of active fill mode
\def\lblrep@Fill@activemode{}
%
% Horizontal labels fill mode
\def\lblrep@fillmode@hmode{hmode}
\define@key{lblrepFill}{hmode}[]{%
   \ifx\lblrep@fillmode@hmode\lblrep@Fill@activemode
      \ClassWarning{pst-labelreport}
        {Horizontal mode is already active. Option ignored!}
   \else
      \ifnum\lblrep@num>\lblrep@numstart
         \ClassWarning{pst-labelreport}
            {This page is not empty. The 'hmode' will be activated at the next new page.}
         \toggletrue{modechanged}
         \let\lblrep@Fill@activemode\lblrep@fillmode@hmode
      \else
         \let\lblrep@Fill@activemode\lblrep@fillmode@hmode
         \lblrep@Fill@setuphmode
         \ifnum\lblrep@num=0
            \lblrep@Fill@initplace
         \fi
      \fi
   \fi
}
%
% Vertical labels fill mode
%
\def\lblrep@fillmode@vmode{vmode}
\define@key{lblrepFill}{vmode}[]{%
   \ifx\lblrep@fillmode@vmode\lblrep@Fill@activemode
      \ClassWarning{pst-labelreport}
        {Vertical mode is already active. Option ignored!}
   \else
      \ifnum\lblrep@num>\lblrep@numstart
         \ClassWarning{pst-labelreport}
            {This page is not empty. The 'vmode' will be activated at the next new page.}
         \toggletrue{modechanged}
         \let\lblrep@Fill@activemode\lblrep@fillmode@vmode
      \else
         \let\lblrep@Fill@activemode\lblrep@fillmode@vmode
         \lblrep@Fill@setupvmode
         \ifnum\lblrep@num=0
            \lblrep@Fill@initplace
         \fi
      \fi
   \fi
}
%
\define@key{lblrepFill}{from}{\lblrep@Fill@fromsetup{#1}}
\define@key{lblrepFill}{until}{\lblrep@Fill@untilsetup{#1}}
%
% private macro to create a new page
\def\lblrep@Fill@newpage{%
   % save the number of printed labels
   \lblrep@numstart=\lblrep@num
   %
   % setup fill mode (if requested)
   \iftoggle{modechanged}{% true
      \csname lblrep@Fill@setup\lblrep@Fill@activemode\endcsname
      \togglefalse{modechanged}
   }{}% false case denied
   %
   \iflblrep@Grid@showgrid
      \lblrep@Grid@drawlabelframe%
   \fi
   %
   \togglefalse{hfoverfull}
   \lblrep@Header@print
   \lblrep@Footer@print
   \iftoggle{hfoverfull}{\advance\lblrep@hferr\@ne}{}
   %
   \newpage}
%
% hmode setup start
\def\lblrep@Fill@setuphmode{% horizontal label filling
   \def\lblrep@Fill@preparenextplace{% hmode
      \advance\lblrep@col\@ne
      \ifnum\lblrep@row=\lblrep@endrow
         \count@=\lblrep@endcol
      \else
         \count@=\lblrep@totcol
      \fi
      \ifnum\lblrep@col>\count@
         \lblrep@col=0
         \advance\lblrep@row\@ne
         \ifnum\lblrep@row>\lblrep@endrow
           \lblrep@Fill@newpage
           \lblrep@endcol=\lblrep@totcol
           \lblrep@endrow=\lblrep@totrow
           \lblrep@row=0
       \fi
     \fi
   }
   % macros to trasform a position number to the double r and c
   % from the current value of the counter \lblrep@pos
   \def\lblrep@Fill@frompostorc{% hmode
      \advance\lblrep@totcol\@ne
      %
      \advance\lblrep@pos\m@ne
      \count@=\lblrep@pos
      \divide\lblrep@pos\lblrep@totcol
      \lblrep@r=\lblrep@pos
      \multiply\lblrep@pos\lblrep@totcol
      \advance\count@-\lblrep@pos
      \lblrep@c=\count@
      %
      \advance\lblrep@totcol\m@ne
   }
   \def\lblrep@Fill@curposend{% hmode
      \advance\lblrep@totcol\@ne
      % r,c -> pos
      \lblrep@pos=\lblrep@r
      \multiply\lblrep@pos\lblrep@totcol
      \advance\lblrep@pos\lblrep@c
      % row,col -> cur
      \lblrep@cur=\lblrep@row
      \multiply\lblrep@cur\lblrep@totcol
      \advance\lblrep@cur\lblrep@col
      \advance\lblrep@cur\@ne
      % endrow,endcol -> end
      \lblrep@end=\lblrep@endrow
      \multiply\lblrep@end\lblrep@totcol
      \advance\lblrep@end\lblrep@endcol
      % end of operations
      \advance\lblrep@totcol\m@ne
   }
   % hmode setting to default start label place
  \def\lblrep@Fill@initplace{% hmode
      \lblrep@row=0
      \lblrep@col=\m@ne}
   % draw back the place positionone
   \def\lblrep@Fill@drawback{%
      \ifnum\lblrep@col=0
         \advance\lblrep@row\m@ne
         \lblrep@col=\lblrep@totcol
      \else
         \advance\lblrep@col\m@ne
      \fi}
}% hmode setup end
%
% vmode setup start
\def\lblrep@Fill@setupvmode{% vertical label filling
   \def\lblrep@Fill@preparenextplace{% vmode
      \advance\lblrep@row\@ne
      \ifnum\lblrep@col=\lblrep@endcol
         \count@=\lblrep@endrow
      \else
         \count@=\lblrep@totrow
      \fi
      \ifnum\lblrep@row>\count@
         \lblrep@row=0
         \advance\lblrep@col\@ne
         \ifnum\lblrep@col>\lblrep@endcol
             \lblrep@Fill@newpage
             \lblrep@col=0
             \lblrep@endcol=\lblrep@totcol
             \lblrep@endrow=\lblrep@totrow
        \fi
      \fi
   }
   % private macro to perform the 'coordinate' trasformation
   \def\lblrep@Fill@frompostorc{% vmode
      \advance\lblrep@totrow\@ne
      %
      \advance\lblrep@pos\m@ne
      \count@=\lblrep@pos
      \divide\lblrep@pos\lblrep@totrow
      \lblrep@c=\lblrep@pos
      \multiply\lblrep@pos\lblrep@totrow
      \advance\count@-\lblrep@pos
      \lblrep@r=\count@
      %
      \advance\lblrep@totrow\m@ne
   }
   \def\lblrep@Fill@curposend{% vmode
      \advance\lblrep@totrow\@ne
      % r,c -> pos
      \lblrep@pos=\lblrep@c
      \multiply\lblrep@pos\lblrep@totrow
      \advance\lblrep@pos\lblrep@r
      % row,col -> cur
      \lblrep@cur=\lblrep@col
      \multiply\lblrep@cur\lblrep@totrow
      \advance\lblrep@cur\lblrep@row
      \advance\lblrep@cur\@ne
      % endrow,endcol -> end
      \lblrep@end=\lblrep@endcol
      \multiply\lblrep@end\lblrep@totrow
      \advance\lblrep@end\lblrep@endrow
      % end of operations
      \advance\lblrep@totrow\m@ne
   }
   % vmode setting to default start label place
   \def\lblrep@Fill@initplace{% vmode
      \lblrep@row=\m@ne
      \lblrep@col=0}
   \def\lblrep@Fill@drawback{%
      \ifnum\lblrep@row=0
         \advance\lblrep@col\m@ne
         \lblrep@row=\lblrep@totrow
      \else
         \advance\lblrep@row\m@ne
      \fi}
}% vmode setup end
%
% private macro: parse the row column place coordinate
\def\lblrep@Fill@gettwonum(#1;#2){%
  \lblrep@r=#1
  \lblrep@c=#2
}
% private macro string for parsing Fill function
\def\lblrep@Fill@key@rc{rc}
%
% private command to parsing the position functions
\def\lblrep@Fill@posfunc#1(#2){%
  \def\lblrep@tmp{#1}
  \ifx\lblrep@tmp\lblrep@Fill@key@rc
    \lblrep@Fill@gettwonum(#2)
  \else
    \ClassError{pst-labelreport}{Unknow function '#1()' for position property}
     {Unknow function '#1()' for position, see the manual for explanation}
  \fi
}
%
% parsing the -from- argument
%
% this macro contains code adapted from the command \@ifisanumber
% by Enrico Gregorio, from the book ``Appunti di programmazione TeX e LaTeX''
% http://profs.sci.univr.it/~gregorio/introtex.pdf
% with the permission of the Author. Thank you Enrico!
\def\lblrep@Fill@fromsetup#1{%
   \setbox0=\hbox{\global\lblrep@pos=\number0#1}%
   \ifdim\wd0=\z@
      % the arg is a number so
      % check the value range, \lblrep@pos = user position
      % I hope that the user not specifies a negative number!!!
      \ifnum\lblrep@pos<1
         \ClassError{pst-labelreport}
          {'from' option: The position number must be positive
           \MessageBreak The value inserted is \the\lblrep@pos}
          {'from' option: The position number must be positive
           \MessageBreak The value inserted is \the\lblrep@pos}
      \fi
      \advance\lblrep@totrow\@ne
      \advance\lblrep@totcol\@ne
      \@tempcnta=\lblrep@totrow
      \multiply\@tempcnta\lblrep@totcol
      \ifnum\lblrep@pos>\@tempcnta
         \ClassError{pst-labelreport}
          {'from' option: The position number is greater\MessageBreak
           than the page places.\MessageBreak
           The value inserted is \the\lblrep@pos\space greater than \the\@tempcnta}
          {'from' option: The position number is greater\MessageBreak
           than the page places.\MessageBreak
           The value inserted is \the\lblrep@pos\space greater than \the\@tempcnta}
      \fi
      % restore zero based values of the registers totrow and totcol
      \advance\lblrep@totrow\m@ne
      \advance\lblrep@totcol\m@ne
      %
      \lblrep@Fill@frompostorc
   \else
      % the arg is not a number, maybe is a function...
      \lblrep@Fill@posfunc#1
      % check the min limit
      \ifnum\lblrep@r<1
          \ClassError{pst-labelreport}
           {'from' option: the row must be greater than zero
            \MessageBreak The value inserted is \the\lblrep@r}
           {'from' option: the row must be greater than zero
            \MessageBreak The value inserted is \the\lblrep@r}
      \fi
      \ifnum\lblrep@c<1
          \ClassError{pst-labelreport}
           {'from' option: column must be greater than zero
            \MessageBreak The value inserted is \the\lblrep@c}
           {'from' option: column must be greater than zero
            \MessageBreak The value inserted is \the\lblrep@c}
      \fi
      % check the max limit
      \advance\lblrep@totrow\@ne
      \ifnum\lblrep@r>\lblrep@totrow
         \ClassError{pst-labelreport}
          {The 'from' row must be equal or less than \the\lblrep@totrow
           \MessageBreak The value inserted is \the\lblrep@r}
          {The 'from' row must be equal or less than \the\lblrep@totrow
           \MessageBreak The value inserted is \the\lblrep@r}
      \fi
      \advance\lblrep@totrow\m@ne
      \advance\lblrep@totcol\@ne
      \ifnum\lblrep@c>\lblrep@totcol
         \ClassError{pst-labelreport}
         {The 'from' column must be equal or less than \the\lblrep@totcol
          \MessageBreak The value inserted is \the\lblrep@c}
         {The 'from' column must be equal or less than \the\lblrep@totcol
          \MessageBreak The value inserted is \the\lblrep@c}
      \fi
      \advance\lblrep@totcol\m@ne
      \advance\lblrep@r\m@ne
      \advance\lblrep@c\m@ne
   \fi
   %
   % set the values of position counter
   \lblrep@Fill@curposend
   % testing the limit cur < pos < end
   \ifnum\lblrep@pos=\lblrep@cur
      \ClassWarning{pst-labelreport}
       {The 'from' position is located at\MessageBreak
        the current label place.\MessageBreak Option ignored}
   \else
      \ifnum\lblrep@pos<\lblrep@cur
         \ClassWarning{pst-labelreport}
          {The 'from' position is located before\MessageBreak
           the current label place.\MessageBreak Option ignored}
      \else
         \ifnum\lblrep@pos>\lblrep@end
            \ClassWarning{pst-labelreport}
             {The 'from' position is located after\MessageBreak
              the end label place.\MessageBreak Option ignored}
         \else
            % finally set the position counters
            \lblrep@row=\lblrep@r
            \lblrep@col=\lblrep@c
            \lblrep@Fill@drawback
         \fi
      \fi
   \fi
}% end of 'from setup'
%
% 'until' macro code: moves the end label place on the page
\def\lblrep@Fill@untilsetup#1{%
\setbox0=\hbox{\global\lblrep@pos=\number0#1}%
\ifdim\wd0=\z@
   % the arg is a number so
   % check the value range, \lblrep@pos = user position
   \ifnum\lblrep@pos<1
      \ClassError{pst-labelreport}
       {'until' option: The position number must be positive
        \MessageBreak The value inserted is \the\lblrep@pos}
       {'until' option: The position number must be positive
        \MessageBreak The value inserted is \the\lblrep@pos}
   \fi
   \advance\lblrep@totrow\@ne
   \advance\lblrep@totcol\@ne
   \@tempcnta=\lblrep@totrow
   \multiply\@tempcnta\lblrep@totcol
   \ifnum\lblrep@pos>\@tempcnta
       \ClassError{pst-labelreport}
       {'until' option: The position number is greater\MessageBreak
        than the page places.\MessageBreak
        The value inserted is \the\lblrep@pos\space greater than \the\@tempcnta}
       {'until' option: The position number is greater\MessageBreak
        than the page places.\MessageBreak
        The value inserted is \the\lblrep@pos\space greater than \the\@tempcnta}
   \fi
   % restore zero based values of the registers totrow and totcol
   \advance\lblrep@totrow\m@ne
   \advance\lblrep@totcol\m@ne
   %
   \lblrep@Fill@frompostorc
\else
   % the arg is not a number, maybe is a function...
   \lblrep@Fill@posfunc#1
   % check the min limit
   \ifnum\lblrep@r<1
       \ClassError{pst-labelreport}
        {'until' option: the row must be greater than zero
         \MessageBreak The value inserted is \the\lblrep@r}
        {'until' option: the row must be greater than zero
         \MessageBreak The value inserted is \the\lblrep@r}
   \fi
   \ifnum\lblrep@c<1
      \ClassError{pst-labelreport}
       {'until' option: the column must be greater than zero
        \MessageBreak The value inserted is \the\lblrep@c}
       {'until' option: the column must be greater than zero
        \MessageBreak The value inserted is \the\lblrep@c}
   \fi
   % check the max limit
   \advance\lblrep@totrow\@ne
   \ifnum\lblrep@r>\lblrep@totrow
       \ClassError{pst-labelreport}
        {The 'until' row must be equal or less than \the\lblrep@totrow
         \MessageBreak The value inserted is \the\lblrep@r}
        {The 'until' row must be equal or less than \the\lblrep@totrow
         \MessageBreak The value inserted is \the\lblrep@r}
   \fi
   \advance\lblrep@totrow\m@ne
   \advance\lblrep@totcol\@ne
   \ifnum\lblrep@c>\lblrep@totcol
      \ClassError{pst-labelreport}
       {The 'until' column must be equal or less than \the\lblrep@totcol
        \MessageBreak The value inserted is \the\lblrep@c}
       {The 'until' column must be equal or less than \the\lblrep@totcol
        \MessageBreak The value inserted is \the\lblrep@c}
   \fi
   \advance\lblrep@totcol\m@ne
   \advance\lblrep@r\m@ne
   \advance\lblrep@c\m@ne
\fi
%
% call macro to set the position counter
\lblrep@Fill@curposend
% now check the limits cur < pos < end
\advance\lblrep@cur\m@ne
\ifnum\lblrep@pos=\lblrep@end
   \ClassWarning{pst-labelreport}
    {The 'until' position is located at\MessageBreak
     the current 'end place'.\MessageBreak Option ignored}
\else
   \ifnum\lblrep@pos<\lblrep@cur
      \ClassWarning{pst-labelreport}
       {The 'until' position is located before\MessageBreak
        the current label place.\MessageBreak Option ignored}
   \else
      \ifnum\lblrep@pos>\lblrep@end
         \ClassWarning{pst-labelreport}
          {The 'until' position is located after\MessageBreak
           the end label place.\MessageBreak Option ignored}
      \else
         % finally set the position counters
         \lblrep@endrow=\lblrep@r
         \lblrep@endcol=\lblrep@c
      \fi
   \fi
\fi
}% end of 'until setup'
%
% setup the Fill default properties
% the default fill mode is 'horizontal'
\setkeys{lblrepFill}{hmode}
%
% public macro: break the filling of the page
\newcommand{\breakfill}{%
   % check if same labels was printed on the current page
   \ifnum\lblrep@num>\lblrep@numstart
      \lblrep@Fill@newpage%
      \lblrep@Fill@initplace%
   \else
      \ClassWarning{pst-labelreport}{On an empty page
        a 'breakfill' can't be performed. Command ignored.}
   \fi
}
%
% Fill setup global command
\newcommand{\setFill}[1]{%
  \setkeys{lblrepFill}{#1}
}
% Single Fill setup command (dot notation)
\def\Fill.#1(#2){%
  \@ifnextchar){\setkeys{lblrepFill}{#1=#2)}\@gobble}
               {\setkeys{lblrepFill}{#1=#2}}
}
%
%%% end of the Fill object code
%
%
%%% The Field object
%
% parser defitions of fields value
\DeclareCmdListParser{\lblrep@parser@comma}{,}%
\DeclareCmdListParser{\lblrep@parser@semicolon}{;}%
\DeclareCmdListParser{\lblrep@parser@colon}{:}%
%
\def\lblrep@buildfields[#1]#2{%
   \expandafter\def\csname lblrep@setfield@#1\endcsname##1{%
   \expandafter\edef\csname lblrep@field@#2\endcsname{\deblank{##1}}}%
}%
%
\newcommand{\fields}[1]{%
   \lblrep@parser@comma+[\lblrep@buildfields]{#1}}%
%
\def\lblrep@setfields[#1]#2{%
   \csname lblrep@setfield@#1\endcsname{#2}}%
%
\def\get#1{%
   \expandafter\ifx\csname lblrep@field@#1\endcsname\relax
      \ClassError{pst-labelreport}{The field '#1' is not defined!}
         {The field '#1' is not defined!}
   \else
      \csname lblrep@field@#1\endcsname%
   \fi
}
%
\def\set#1#2{% #1=name, #2=val
   \def\lblrep@tmpa{<num>}
   \def\lblrep@tmpb{#1}
   \ifx\lblrep@tmpa\lblrep@tmpb
      \ClassWarning{pst-labelreport}{The <num> system field is not writable. Command ignored.}
   \else
      \def\lblrep@tmpa{<series>}
      \def\lblrep@tmpb{#1}
      \ifx\lblrep@tmpa\lblrep@tmpb
          \ClassWarning{pst-labelreport}{The <series> system field is not writable. Command ignored.}
      \else
          \expandafter\def\csname lblrep@field@#1\endcsname{#2}
      \fi
   \fi
}
%
% Field keys definition
\define@choicekey+{lblrepField}{sepsymbol}{comma,semicolon,colon}{%
      \expandafter
         \let\expandafter
             \lblrep@parserfield\csname lblrep@parser@#1\endcsname%
   }{%
      \ClassWarning{pst-labelreport}{Erroneous separation symbol name '#1',
         only 'comma', 'semicolon', 'colon' keys are allowed}
   }
%
% Field setup public command
\newcommand{\setField}[1]{%
  \setkeys{lblrepField}{#1}
}
% Single Field setup command (dot notation)
\def\Field.#1(#2){%
  \@ifnextchar){\setkeys{lblrepField}{#1=#2)}\@gobble}
               {\setkeys{lblrepField}{#1=#2}}
}
%
% default setup section
\setkeys{lblrepField}{sepsymbol=comma}
%
% definition of the system field <qty> (default value -> 1)
\set{<qty>}{1}
%
% definition of the system field <num>
\expandafter\def\csname lblrep@field@<num>\endcsname{\the\lblrep@num}
%
% definition of the system field <series>
\expandafter\def\csname lblrep@field@<series>\endcsname{\the\lblrep@series}
%
%%% end of the Field object code
%
%
%%% The Label object
%
% key definitions
\define@key{lblrepLabel}{use}{%
   \expandafter\ifx\csname lblrep@lbl@#1\endcsname\relax
      \ClassError{pst-labelreport}{The label '#1' is not defined}
        {The label '#1' is not defined}
   \else
      \def\lblrep@Label@defname{#1}
   \fi
}
%
% a macro to parse the syntax 'name' extends 'name'
\def\lblrep@Label@parselabelname#1 extends #2\@nil{%
   \edef\lblrep@Label@soon{\deblank{#1}}
   \def\lblrep@tmp{#2}%
   \ifx\lblrep@tmp\empty
      \let\lblrep@Label@father\empty
   \else
      \expandafter\lblrep@Label@pn\lblrep@tmp%
   \fi
}
\def\lblrep@Label@pn#1 extends {%
   \edef\lblrep@Label@father{\deblank{#1}}%
}
%
% command to draw the label
\newcommand{\designLabel}[2][@]{%
   \lblrep@Label@parselabelname#1 extends \@nil
   \ifx\lblrep@Label@father\empty
      \expandafter\def\csname lblrep@lbl@\lblrep@Label@soon\endcsname{#2}%
   \else
      \expandafter\let\expandafter\lblrep@tmp\csname
           lblrep@lbl@\lblrep@Label@father\endcsname
      \g@addto@macro\lblrep@tmp{#2}
      \expandafter\let\csname lblrep@lbl@\lblrep@Label@soon\endcsname\lblrep@tmp
      \let\lblrep@tmp\empty
   \fi
   % set the new label as default
   \let\lblrep@Label@defname\lblrep@Label@soon
}
%
\@onlypreamble\designLabel
%
% default label name
\def\lblrep@Label@defname{@}
%
% \lbl command definition
\newcommand{\lbl}[2][\lblrep@Label@defname]{%
   % check label name
   \expandafter\ifx\csname lblrep@lbl@#1\endcsname\relax
         \ClassError{pst-labelreport}{The label '#1' is not defined!}
         {The label '#1' is not defined!}
   \fi
   % preparing fields value
   \lblrep@parserfield+[\lblrep@setfields]{#2}%
   % step id system counter
   \advance\lblrep@series\@ne
   % drawing loop
   \lblrep@i=\number\csname lblrep@field@<qty>\endcsname\relax
   \@whilenum\lblrep@i>0\do{%
      % increment global label counter
      \advance\lblrep@num\@ne
      % call to the page and place manager
      \lblrep@Fill@preparenextplace
      % draw label
      \pstPutAbs[position=lb](\dimexpr\lblrep@Grid@mx+\lblrep@Grid@dx*\lblrep@col\relax,
        -\dimexpr\lblrep@Grid@my+\lblrep@Grid@dy*\lblrep@row\relax){% this comment char is important
           \begin{pspicture*}(-\lblrep@Grid@ox,-\lblrep@Grid@oy)%
                             (\dimexpr-\lblrep@Grid@ox+\lblrep@Grid@x\p@\relax,%
                              \dimexpr-\lblrep@Grid@oy+\lblrep@Grid@y\p@\relax)
              \csname lblrep@lbl@#1\endcsname
           \end{pspicture*}%
         }%
      % decrementing loop counter
      \advance\lblrep@i\m@ne
   }% end of while loop
}% **** end of the \lbl command
%
% labels as in visual debugging
\newcommand{\showLabel}{}
\@onlypreamble\showLabel
%
%
% Field setup public command
\newcommand{\setLabel}[1]{%
  \setkeys{lblrepLabel}{#1}
}
% Single Field setup command (dot notation)
\def\Label.#1(#2){%
  \@ifnextchar){\setkeys{lblrepLabel}{#1=#2)}\@gobble}
               {\setkeys{lblrepLabel}{#1=#2}}
}
%
%%% end of Label section code
%
%
%%% The page style objects: Header and Footer
% implemented with absolute positioning
%
% private macro to store a dimen with optional unit used by xkeyval macro
\def\lblrep@HF@setsep#1#2{%
  \pst@getlength{#1}{\lblrep@tmp}
  #2=\lblrep@tmp\p@%
}
% private macro to add to sep a dimen with optional unit used by xkeyval macro
\def\lblrep@HF@addtosep#1#2{%
  \pst@getlength{#1}{\lblrep@tmp}
  \advance#2\lblrep@tmp\p@%
}
%
% private macro for keys
\def\lblrep@HF@key@lcr{lcr}
%
% private macro to parse the lcr function
\def\lblrep@HF@parselcr(#1;#2;#3)#4{%   #4 -> Header/Footer
   % left
   \expandafter\def\csname lblrep@#4@left\endcsname{#1}%   store variable
   % center
   \expandafter\def\csname lblrep@#4@center\endcsname{#2}% store variable
   % right
   \expandafter\def\csname lblrep@#4@right\endcsname{#3}%  store variable
}
%
% private macro to parsing the 'lcr' function argument in Header
\def\lblrep@Header@setupmarks#1(#2){%
   \def\lblrep@tmp{#1}
   \ifx\lblrep@tmp\lblrep@HF@key@lcr
      \lblrep@HF@parselcr(#2){Header}
   \else
      \ClassError{pst-labelreport}{Unknow Header function '#1()' for marks property}
                 {Unknow Header function '#1()' for marks, see the manual for explanation}
   \fi
}
% private macro to parsing the 'lcr' function argument in Footer
\def\lblrep@Footer@setupmarks#1(#2){%
   \def\lblrep@tmp{#1}
   \ifx\lblrep@tmp\lblrep@HF@key@lcr
      \lblrep@HF@parselcr(#2){Footer}
   \else
      \ClassError{pst-labelreport}{Unknow Footer function '#1()' for marks property}
                 {Unknow Footer function '#1()' for marks, see the manual for explanation}
   \fi
}
% a flag for overfull marks event
\newtoggle{hfoverfull}
%
% check the overfull on Header/Footer
% this private macro is called
% every time a Header/Footer is print on page
\def\lblrep@HF@checkmarks#1{%
   \settowidth{\@tempdimc}{\csname lblrep@#1@center\endcsname}
   \ifdim\@tempdimc>0pt
       \dimen@=\dimexpr\lblrep@HF@xgrid/2\relax
       \divide\@tempdimc\tw@
       \settowidth{\@tempdima}{\csname lblrep@#1@left\endcsname}
       \advance\@tempdima\@tempdimc
       \ifdim\@tempdima>\dimen@
          \toggletrue{hfoverfull}
       \fi
       \settowidth{\@tempdima}{\csname lblrep@#1@right\endcsname}
       \advance\@tempdima\@tempdimc
       \ifdim\@tempdima>\dimen@
          \toggletrue{hfoverfull}
       \fi
   \else
       \settowidth{\@tempdima}{\csname lblrep@#1@left\endcsname}
       \settowidth{\@tempdimb}{\csname lblrep@#1@right\endcsname}
       \advance\@tempdima\@tempdimb
       \ifdim\@tempdima>\lblrep@HF@xgrid
           \toggletrue{hfoverfull}
       \fi
   \fi
}
%
% definition of the Header and Footer object properties:
\define@key{lblrepHeader}{left}{\def\lblrep@Header@left{#1}}
\define@key{lblrepHeader}{center}{\def\lblrep@Header@center{#1}}
\define@key{lblrepHeader}{right}{\def\lblrep@Header@right{#1}}
\define@key{lblrepHeader}{sep}{\lblrep@HF@setsep{#1}{\lblrep@Header@sep}}
\define@key{lblrepHeader}{addtosep}{\lblrep@HF@addtosep{#1}{\lblrep@Header@sep}}
\define@key{lblrepHeader}{marks}{\lblrep@Header@setupmarks#1}
%
\define@key{lblrepFooter}{left}{\def\lblrep@Footer@left{#1}}
\define@key{lblrepFooter}{center}{\def\lblrep@Footer@center{#1}}
\define@key{lblrepFooter}{right}{\def\lblrep@Footer@right{#1}}
\define@key{lblrepFooter}{sep}{\lblrep@HF@setsep{#1}{\lblrep@Footer@sep}}
\define@key{lblrepFooter}{addtosep}{\lblrep@HF@addtosep{#1}{\lblrep@Footer@sep}}
\define@key{lblrepFooter}{marks}{\lblrep@Footer@setupmarks#1}
%
% mark on page in absolute position
% header macro
\def\lblrep@Header@print{%
   \lblrep@HF@checkmarks{Header}
   \pstPutAbs[position=B](\lblrep@HF@center,-\lblrep@Header@y){%
       \hbox to \lblrep@HF@xgrid{%
           \hbox to 0pt{\lblrep@Header@left\hskip 0pt minus 1fil}%
           \hss\lblrep@Header@center\hss%
           \hbox to 0pt{\hskip 0pt minus -1fil\relax\lblrep@Header@right}%
       }
   }
}
%
% footer macro
\def\lblrep@Footer@print{%
   \lblrep@HF@checkmarks{Footer}
   \pstPutAbs[position=B](\lblrep@HF@center,-\lblrep@Footer@y){%
       \hbox to \lblrep@HF@xgrid{%
           \hbox to 0pt{\lblrep@Footer@left\hskip 0pt minus 1fil}%
           \hss\lblrep@Footer@center\hss%
           \hbox to 0pt{\hskip 0pt minus -1fil\relax\lblrep@Footer@right}%
       }
   }
}
%
% Header and Footer default settings
% (the setup of sep register are in the buildlayout macro)
% marks default value are empty
\def\lblrep@Header@left{}
\def\lblrep@Header@center{}
\def\lblrep@Header@right{}
%
\def\lblrep@Footer@left{}
\def\lblrep@Footer@center{}
\def\lblrep@Footer@right{}
%
% reset of the overfull Header/Footer counter
\lblrep@hferr=0
%
% the minimun Header/Footer left/right margin is 8pt
% (the interface of this property is not provided)
\lblrep@HF@xmin=8pt
% standard Header baseline sep
\lblrep@Header@sep=10pt
% standard Footer baseline sep
\lblrep@Footer@sep=\dimexpr 1em+8pt\relax
%
% Header macro user interface
%
% Header setup global command
\newcommand{\setHeader}[1]{%
  \setkeys{lblrepHeader}{#1}
}
% Single Header setup command (dot notation)
\def\Header.#1(#2){%
  \@ifnextchar){\setkeys{lblrepHeader}{#1=#2)}\@gobble}
               {\setkeys{lblrepHeader}{#1=#2}}
}
%
% Footer macro user interface
%
% Footer setup global command
\newcommand{\setFooter}[1]{%
  \setkeys{lblrepFooter}{#1}
}
% Single Footer setup command (dot notation)
\def\Footer.#1(#2){%
  \@ifnextchar){\setkeys{lblrepFooter}{#1=#2)}\@gobble}
               {\setkeys{lblrepFooter}{#1=#2}}
}
%
% resolve the last page reference:
% code adapted from the lastpage package not usable
% in pst-labelreport
%
\def\lblrep@mylastpage{}
\def\thelastpage{%
   \pageref{mylastpage}%
   \global\def\thelastpage{\pageref{mylastpage}}%
   \global\def\lblrep@mylastpage{%
      \immediate\write\@auxout{\string
      \newlabel{mylastpage}{{}{\thepage}}}%
   }%
}
%
% close code section
%
% these commands sets the page margins to 0pt and page style as empty!
\geometry{margin=0pt}
\pagestyle{empty}
%
% \@spaces is four \space
\def\lblrep@ConsoleInfo#1{%
   \GenericWarning{\@spaces\@spaces\@spaces\@spaces\@spaces\@spaces\@spaces}
                  {Class pst-labelreport Info: #1\@gobble}}
%
\AtBeginDocument{%
   \lblrep@Grid@buildlayout
   %
   % set the last place in the page
   \lblrep@endrow=\lblrep@totrow
   \lblrep@endcol=\lblrep@totcol
}
%
\AtEndDocument{%
   \iflblrep@Grid@showgrid
     \lblrep@Grid@drawlabelframe
   \fi%
   \togglefalse{hfoverfull}
   \lblrep@Header@print
   \lblrep@Footer@print
   \iftoggle{hfoverfull}{\advance\lblrep@hferr\@ne}{}
   %
   \lblrep@mylastpage%
   %
   \ifnum\lblrep@hferr>0
   \ClassWarning{pst-labelreport}{There are \the\lblrep@hferr\space
      page/s with Header/Footer horizontal overfull on \thepage\space}
   \fi
   \advance\lblrep@totcol\@ne
   \advance\lblrep@totrow\@ne
   %
   \lblrep@ConsoleInfo{I printed a total of \the\lblrep@num\space label/s%
                       \MessageBreak
                       on a grid of \the\lblrep@totcol\space column/s by
                       \the\lblrep@totrow\space row/s}
}
\endinput
%%
%% End of the source file `labelreport.cls'.
