BLOCKGREP
=========

[Blockgrep](#Blockgrep)
[SYNOPSIS](#SYNOPSIS)
[OPTIONS](#OPTIONS)
[DESCRIPTION](#DESCRIPTION)
[EXAMPLES](#EXAMPLES)

------------------------------------------------------------------------

Blockgrep
--------------

Grep for a given pattern, then print lines until end of block.

The end of a block is defined by a change of indent, or certain keywords
or symbols, such as ’end’, ’done’, ’fi’, ’}’ or '</'

SYNOPSIS
-------------

`blockgrep [options] <PATTERN> [<FILES>]`

Greps FILES or STDIN for PATTERN, outputting blocks found.

~~~
  Options ([*] marks defaults)
    −h|−−help                      Help on usage
    −i|−−ignore−case               [*] Case−insensitive matching
    −s|−−no−ignore−case            Case sensitive matching
    −m|−−print−block−start         [*] Print matching line that start blockgrep
    −M|−−no−print−block−start      Don't print line that starts block
    −I|−−print−block−end−indent    Print line that ends block by indent change
    −R|−−print−block−end−regex     [*] Print line that ends block matching/regex
    −e|−−block−end−regex <REGEX>   Supply a (PCRE) regex to match block endings
    −−separator <SEPARATOR>        Text used to separate output blocks
    −−block−line−filter <COMMAND>  Filter block contents through this command
~~~

OPTIONS
------------

**−help**

Print a brief help message and exits.

**−print−block−start**

Print the line matching &lt;pattern&gt; that starts the block. This is
true by default.

**−−print−block−end−indent**

If a block is ended because of a change of indentation, then print the
line that ends the block (default is false)

**−−print−block−end−regex**

If a block is ended because matching a regular expression then print the
line that ends the block (default is true). The default regex should
match ’fi|done|end|\\}’. You can change this with −−block−end−regex

**−−block−end−regex** &lt;REGEX&gt;

Supply a custom ( PCRE ) regular expression to match block endings

**−−separator** &lt;SEPARATOR&gt;

Provide custom text to be printed between blocks in program output. The
default separator is a line of dashes, 60 characters long

**−−block−line−filter** &lt;COMMAND&gt;

Using this option you can filter block content (not the starting or
ending lines) through an external command.

DESCRIPTION
----------------

**blockgrep** will acts like grep, but will print the block that follows
each match. A block is defined by default as the text following the
match, up til the first change of indentation, or matching keyword or
symbol. By default the keywords ’end’, ’done’, ’fi’, and the symbol ’}’
are counted as block enders.

The default behaviour is to print all matching lines from the start of a
matching block, until the end, including any block ending
symbols/keywords. If a block is ended by a change of indentation, then
by default the line that changes indentation is not printed. This can be
changed using the −−print−block−end−indent option.

EXAMPLES
-------------
~~~
blockgrep function file.c

pacmd −−list−cards | blockgrep profile −−no−print−block−start \
−−block−line−filter=’cut −d: −f2’

~~~

