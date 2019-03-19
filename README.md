-   [Blockgrep](#Blockgrep)
-   [SYNOPSIS](#SYNOPSIS)
    -   [Options](#Options)
-   [BLOCKS](#BLOCKS)
    -   [CUSTOM BLOCK PATTERNS](#CUSTOM-BLOCK-PATTERNS)
    -   [CUSTOM METACHARACTERS](#CUSTOM-METACHARACTERS)
-   [OPTIONS](#OPTIONS)
-   [DESCRIPTION](#DESCRIPTION)
-   [EXAMPLES](#EXAMPLES)

Blockgrep
=========

Grep for a given pattern within blocks in files.

SYNOPSIS
========

blockgrep \[OPTIONS\] *PATTERN* \[*FILE*...\]

Searches for *PATTERN* in each *FILE* (or *STDIN*, if no filenames are supplied).

Unlike other greps, **blockgrep** outputs blocks (typically of code) which contain a match.

Options
-------

Those marked with a \[\*\] are defaults

      -h|--help                      Help on usage
      -i|--ignore-case               [*] Case-insensitive matching (*default)
      -s|--no-ignore-case            Case sensitive matching
      -m|--print-block-start         [*] Show the line that matched block start
      -I|--print-block-end           [*] Print the line that ended the block
      -S|--block-start-regex REGEX   Supply a regex to match block starts
      -E|--block-end-regex REGEX     Supply a regex to match block endings
      -d|--ignore-indent             Ignore indentation and only look at block end regex
      --block-start-matches          If you're using -S, you may want to allow for PATTERN also matching in the block start.
      --separator <SEPARATOR>        Text used to separate output blocks
      --block-line-filter <COMMAND>  Filter block contents through this command

BLOCKS
======

By default, *PATTERN* is used to recognize the start of a block.

The end of a block is defined by a change of indent, or certain keywords or symbols, such as `end`, `done`, `fi`, or `}`

CUSTOM BLOCK PATTERNS
---------------------

You can give your own block definitions using **--block-start-regex** and **--block-end-regex**.

In this case **blockgrep** will print the entirety of each block that contains a line matching *PATTERN*

You can also ignore indentation changes using **--ignore-indent**

CUSTOM METACHARACTERS
---------------------

In **--block-end-regex** and *PATTERN* you can use a couple of extra metacharacters beyond [the usual set used by Perl](https://perldoc.perl.org/perlre.html)

-   **\\I** *(capital i)*

    This stands in for 'match the indentation level used by the block start' This is useful to make sure we match, for example, the correct closing brace.

    **Example:**

    Find `if` statements and print any that contain a `return`

            blockgrep 'return' --block-start-regex 'if\s+\(.+' --block-end-regex '\I\}' file.c

-   **\\i**

    This stands in for 'match the indentation level used by the block contents', which is technically the indentation used by the first line after the block start.

OPTIONS
=======

Any toggle options can be negated by prefixing "no" onto the option. e.g. **--no-print-block-start** or **--no-pstart**

**--help**  
Print a brief help message and exits.

**--print-block-start**  
*shortcut* **--pstart**

Print the line matching &lt;pattern&gt; that starts the block. This is true by default. You can disable this with **--no-pstart** or **--no-print-block-start**

**--print-block-end**  
*shortcut* **--pend**

Print the line that ends the block. This is enabled by default and can be disabled, as with the previous option, by using **--no-print-block-end**

**--block-start-regex** &lt;REGEX&gt;  
*shortcut* **-S**

Supply a custom (PCRE) regular expression to match block starts.

If this is supplied, then blocks which contain *PATTERN* will be printed. Otherwise, if this is not supplied, then *PATTERN* is used to recognize where blocks start.

So you can either:

*OR*

**--block-end-regex** &lt;REGEX&gt;  
*shortcut* **-E**

Supply a custom (PCRE) regular expression to match block endings The default pattern, at time of writing is equivalent to the following:

qr{ (?: ^ \\I \# Begining of line, followed by indentation matching block start indent (?: (?: done|end|fi)\\b | \\} \# A keyword or '}' ) ) |&lt;\\/ \# Or none of the above, and an end tag }x

**--separator** &lt;SEPARATOR&gt;  
Provide custom text to be printed between blocks in program output. The default separator is a line of dashes, 60 characters long If you don't want any separators use the empty string

e.g. `--separator=''`

**--block-line-filter** &lt;COMMAND&gt;  
*shortcut* **--filter**

Using this option you can filter block content (not the starting or ending lines) through an external command.

DESCRIPTION
===========

**blockgrep** will acts like grep, but will print the block that follows each match.

A block is defined by a start and end expressions.

By default PATTERN is used as the start expression, and the block continues until the first change of indentation, or until a matching end expression is found.

The end expression can be set by --block-end-regex, and has a sensible default value for common programming languages. [See --block-end-regex](#block-end-regex)

EXAMPLES
========

blockgrep function file.c

blockgrep 'parse\_options' --block-start-regex '^\\s\*sub\\s+' --block-line-filter='perltidy' t/example.pl
