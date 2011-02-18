What is this?
=============

This is an implementation of John Gruber's [markdown][] for Cocoa. It 
uses a [parsing expression grammar (PEG)][] to define the syntax. This 
should allow easy modification and extension. It currently supports output
in HTML, LaTeX, or groff_mm formats, and adding new formats is relatively
easy.

[parsing expression grammar (PEG)]: http://en.wikipedia.org/wiki/Parsing_expression_grammar 
[markdown]: http://daringfireball.net/projects/markdown/

It is pretty fast. A 179K text file that takes 5.7 seconds for
Markdown.pl (v. 1.0.1) to parse takes less than 0.2 seconds for this
markdown. It does, however, use a lot of memory (up to 4M of heap space
while parsing the 179K file, and up to 80K for a 4K file). (Note that
the memory leaks in earlier versions of this program have now been
plugged.)

Both a library and a standalone program are provided.

peg-markdown is written and maintained by John MacFarlane (jgm on
github), with significant contributions by Ryan Tomayko (rtomayko).
It is released under both the GPL and the MIT license; see LICENSE for
details.  peg-markdown was adapted for Cocoa by David Whetstone.

Installing
==========


Extensions
==========

peg-markdown supports extensions to standard markdown syntax.
These can be turned on using the command line flag `-x` or
`--extensions`.  `-x` by itself turns on all extensions.  Extensions
can also be turned on selectively, using individual command-line
options. To see the available extensions:

    ./markdown --help-extensions
 
The `--smart` extension provides "smart quotes", dashes, and ellipses.

The `--notes` extension provides a footnote syntax like that of
Pandoc or PHP Markdown Extra.

Using the library
=================

The library exports two functions:

    NSString * markdown_to_nsstring(NSString *text, int extensions, int output_format);
    char * markdown_to_string(NSString *text, int extensions, int output_format);

The only difference between these is that `markdown_to_nsstring` returns an
autoreleased `NSString` (Cocoa's string class), while `markdown_to_string` returns 
a regular character pointer.  The memory allocated for the latter is good until
the enclosing pool is drained.

`text` is the markdown-formatted text to be converted.  Note that tabs will
be converted to spaces, using a four-space tab stop.  Character encodings are
ignored.

`extensions` is a bit-field specifying which syntax extensions should be used.
If `extensions` is 0, no extensions will be used.  If it is `0xFFFFFF`,
all extensions will be used.  To set extensions selectively, use the
bitwise `&` operator and the following constants:

 - `EXT_SMART` turns on smart quotes, dashes, and ellipses.
 - `EXT_NOTES` turns on footnote syntax.  [Pandoc's footnote syntax][] is used here.
 - `EXT_FILTER_HTML` filters out raw HTML (except for styles).
 - `EXT_FILTER_STYLES` filters out styles in HTML.

  [Pandoc's footnote syntax]: http://johnmacfarlane.net/pandoc/README.html#footnotes

`output_format` is either `HTML_FORMAT`, `LATEX_FORMAT`, or `GROFF_MM_FORMAT`.

To use the library, include `markdown_lib.h`.  See `markdown.m` for an example.

Hacking
=======

It should be pretty easy to modify the program to produce other formats
than HTML or LaTeX, and to parse syntax extensions.  A quick guide:

  * `markdown_parser.leg` contains the grammar itself.

  * `markdown_output.m` contains functions for printing the `Element`
    structure in various output formats.

  * To add an output format, add the format to `markdown_formats` in
    `markdown_lib.h`.  Then modify `print_element` in `markdown_output.m`,
    and add functions `print_XXXX_string`, `print_XXXX_element`, and
    `print_XXXX_element_list`. Also add an option in the main program
    that selects the new format. Don't forget to add it to the list of
    formats in the usage message.

  * To add syntax extensions, define them in the PEG grammar
    (`markdown_parser.leg`), using existing extensions as a guide. New
    inline elements will need to be added to `Inline =`; new block
    elements will need to be added to `Block =`. (Note: the order
    of the alternatives does matter in PEG grammars.)

  * If you need to add new types of elements, modify the `keys`
    enum in `markdown_peg.h`.

  * By using `&{ }` rules one can selectively disable extensions
    depending on command-line options. For example,
    `&{ extension(EXT_SMART) }` succeeds only if the `EXT_SMART` bit
    of the global `syntax_extensions` is set. Add your option to
    `markdown_extensions` in `markdown_lib.h`, and add an option in
    `markdown.m` to turn on your extension.

  * Note: Avoid using `[^abc]` character classes in the grammar, because
    they cause problems with non-ascii input. Instead, use: `( !'a' !'b'
    !'c' . )`

