/**********************************************************************

  markdown_output.c - functions for printing Elements parsed by 
                      markdown_peg.
  (c) 2008 John MacFarlane (jgm at berkeley dot edu).

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License or the MIT
  license.  See LICENSE for details.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

 ***********************************************************************/

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <Foundation/Foundation.h>
#import "markdown_peg.h"

static int extensions;

static void print_html_string(NSMutableString *out, NSString *str, bool obfuscate);
static void print_html_element_list(NSMutableString *out, element *list, bool obfuscate);
static void print_html_element(NSMutableString *out, element *elt, bool obfuscate);
static void print_latex_string(NSMutableString *out, NSString *str);
static void print_latex_element_list(NSMutableString *out, element *list);
static void print_latex_element(NSMutableString *out, element *elt);
static void print_groff_string(NSMutableString *out, NSString *str);
static void print_groff_mm_element_list(NSMutableString *out, element *list);
static void print_groff_mm_element(NSMutableString *out, element *elt, int count);

/**********************************************************************

  Utility functions for printing

 ***********************************************************************/

static int padded = 2;      /* Number of newlines after last output.
                               Starts at 2 so no newlines are needed at start.
                               */

static NSMutableArray *endnotes = nil; /* List of endnotes to print after main content. */
static int notenumber = 0;  /* Number of footnote. */

/* pad - add newlines if needed */
static void pad(NSMutableString *out, int num) {
    while (num-- > padded)
        [out appendString:@"\n"];
    padded = num;
}

/**********************************************************************

  Functions for printing Elements as HTML

 ***********************************************************************/

/* print_html_string - print string, escaping for HTML  
 * If obfuscate selected, convert characters to hex or decimal entities at random */
static void print_html_string(NSMutableString *out, NSString *str, bool obfuscate) {
  NSUInteger i;
  unichar ch;
  for (i = 0; i < str.length; ++i) {
    ch = [str characterAtIndex:i];
        switch (ch) {
        case '&':
            [out appendString:@"&amp;"];
            break;
        case '<':
            [out appendString:@"&lt;"];
            break;
        case '>':
            [out appendString:@"&gt;"];
            break;
        case '"':
            [out appendString:@"&quot;"];
            break;
        default:
            if (obfuscate) {
                if (rand() % 2 == 0)
                    [out appendFormat:@"&#%d;", (int) ch];
                else
                    [out appendFormat:@"&#x%x;", (unsigned int) ch];
            }
            else
                [out appendCharacter:ch];
        }
    }
}

/* print_html_element_list - print a list of elements as HTML */
static void print_html_element_list(NSMutableString *out, element *list, bool obfuscate) {
    while (list != NULL) {
        print_html_element(out, list, obfuscate);
        list = list->next;
    }
}

/* add_endnote - add an endnote to global endnotes list. */
static void add_endnote(element *elt) {
    if (endnotes == nil)
        endnotes = [[NSMutableArray alloc] init];
   [endnotes insertObject:[NSValue valueWithPointer:(const void*)elt] atIndex:0];
}

/* print_html_element - print an element as HTML */
static void print_html_element(NSMutableString *out, element *elt, bool obfuscate) {
    int lev;
    switch (elt->key) {
    case SPACE:
        [out appendFormat:@"%@", elt->contents.str];
        break;
    case LINEBREAK:
        [out appendString:@"<br/>\n"];
        break;
    case STRING:
        print_html_string(out, elt->contents.str, obfuscate);
        break;
    case ELLIPSIS:
        [out appendString:@"&hellip;"];
        break;
    case EMDASH:
        [out appendString:@"&mdash;"];
        break;
    case ENDASH:
        [out appendString:@"&ndash;"];
        break;
    case APOSTROPHE:
        [out appendString:@"&rsquo;"];
        break;
    case SINGLEQUOTED:
        [out appendString:@"&lsquo;"];
        print_html_element_list(out, elt->children, obfuscate);
        [out appendString:@"&rsquo;"];
        break;
    case DOUBLEQUOTED:
        [out appendString:@"&ldquo;"];
        print_html_element_list(out, elt->children, obfuscate);
        [out appendString:@"&rdquo;"];
        break;
    case CODE:
        [out appendString:@"<code>"];
        print_html_string(out, elt->contents.str, obfuscate);
        [out appendString:@"</code>"];
        break;
    case HTML:
        [out appendFormat:@"%@", elt->contents.str];
        break;
    case LINK:
          if ([elt->contents.link->url rangeOfString:@"mailto:"].location == 0)
            obfuscate = true;  /* obfuscate mailto: links */
        [out appendString:@"<a href=\""];
        print_html_string(out, elt->contents.link->url, obfuscate);
        [out appendString:@"\""];
        if (elt->contents.link->title.length > 0) {
            [out appendString:@" title=\""];
            print_html_string(out, elt->contents.link->title, obfuscate);
            [out appendString:@"\""];
        }
        [out appendString:@">"];
        print_html_element_list(out, elt->contents.link->label, obfuscate);
        [out appendString:@"</a>"];
        break;
    case IMAGE:
        [out appendString:@"<img src=\""];
        print_html_string(out, elt->contents.link->url, obfuscate);
        [out appendString:@"\" alt=\""];
        print_html_element_list(out, elt->contents.link->label, obfuscate);
        [out appendString:@"\""];
        if (elt->contents.link->title.length > 0) {
            [out appendString:@" title=\""];
            print_html_string(out, elt->contents.link->title, obfuscate);
            [out appendString:@"\""];
        }
        [out appendString:@" />"];
        break;
    case EMPH:
        [out appendString:@"<em>"];
        print_html_element_list(out, elt->children, obfuscate);
        [out appendString:@"</em>"];
        break;
    case STRONG:
        [out appendString:@"<strong>"];
        print_html_element_list(out, elt->children, obfuscate);
        [out appendString:@"</strong>"];
        break;
    case LIST:
        print_html_element_list(out, elt->children, obfuscate);
        break;
    case RAW:
        /* Shouldn't occur - these are handled by process_raw_blocks() */
        assert(elt->key != RAW);
        break;
    case H1: case H2: case H3: case H4: case H5: case H6:
        lev = elt->key - H1 + 1;  /* assumes H1 ... H6 are in order */
        pad(out, 2);
        [out appendFormat:@"<h%1d>", lev];
        print_html_element_list(out, elt->children, obfuscate);
        [out appendFormat:@"</h%1d>", lev];
        padded = 0;
        break;
    case PLAIN:
        pad(out, 1);
        print_html_element_list(out, elt->children, obfuscate);
        padded = 0;
        break;
    case PARA:
        pad(out, 2);
        [out appendString:@"<p>"];
        print_html_element_list(out, elt->children, obfuscate);
        [out appendString:@"</p>"];
        padded = 0;
        break;
    case HRULE:
        pad(out, 2);
        [out appendString:@"<hr />"];
        padded = 0;
        break;
    case HTMLBLOCK:
        pad(out, 2);
        [out appendFormat:@"%@", elt->contents.str];
        padded = 0;
        break;
    case VERBATIM:
        pad(out, 2);
        [out appendFormat:@"%s", "<pre><code>"];
        print_html_string(out, elt->contents.str, obfuscate);
        [out appendFormat:@"%s", "</code></pre>"];
        padded = 0;
        break;
    case BULLETLIST:
        pad(out, 2);
        [out appendFormat:@"%s", "<ul>"];
        padded = 0;
        print_html_element_list(out, elt->children, obfuscate);
        pad(out, 1);
        [out appendFormat:@"%s", "</ul>"];
        padded = 0;
        break;
    case ORDEREDLIST:
        pad(out, 2);
        [out appendFormat:@"%s", "<ol>"];
        padded = 0;
        print_html_element_list(out, elt->children, obfuscate);
        pad(out, 1);
        [out appendString:@"</ol>"];
        padded = 0;
        break;
    case LISTITEM:
        pad(out, 1);
        [out appendString:@"<li>"];
        padded = 2;
        print_html_element_list(out, elt->children, obfuscate);
        [out appendString:@"</li>"];
        padded = 0;
        break;
    case BLOCKQUOTE:
        pad(out, 2);
        [out appendString:@"<blockquote>\n"];
        padded = 2;
        print_html_element_list(out, elt->children, obfuscate);
        pad(out, 1);
        [out appendString:@"</blockquote>"];
        padded = 0;
        break;
    case REFERENCE:
        /* Nonprinting */
        break;
    case NOTE:
        /* if contents.str == 0, then print note; else ignore, since this
         * is a note block that has been incorporated into the notes list */
        if (elt->contents.str == 0) {
            add_endnote(elt);
            ++notenumber;
                [out appendFormat:@"<a class=\"noteref\" id=\"fnref%d\" href=\"#fn%d\" title=\"Jump to note %d\">[%d]</a>",
                notenumber, notenumber, notenumber, notenumber];
        }
        break;
    default: 
        fprintf(stderr, "print_html_element encountered unknown element key = %d\n", elt->key); 
        exit(EXIT_FAILURE);
    }
}

static void print_html_endnotes(NSMutableString *out) {
    int counter = 0;
    element *note_elt;
    if (endnotes == nil) 
        return;
    [out appendString:@"<hr/>\n<ol id=\"notes\">"];
    for (NSValue *note in [endnotes reverseObjectEnumerator]) {
        note_elt = (element*)[note pointerValue];
        counter++;
        pad(out, 1);
        [out appendFormat:@"<li id=\"fn%d\">\n", counter];
        padded = 2;
        print_html_element_list(out, note_elt->children, false);
        [out appendFormat:@" <a href=\"#fnref%d\" title=\"Jump back to reference\">[back]</a>", counter];
        pad(out, 1);
        [out appendString:@"</li>"];
    }
    pad(out, 1);
    [out appendString:@"</ol>"];
    [endnotes release];
}

/**********************************************************************

  Functions for printing Elements as LaTeX

 ***********************************************************************/

/* print_latex_string - print string, escaping for LaTeX */
static void print_latex_string(NSMutableString *out, NSString *str) {
    unichar ch;
    for (NSUInteger i = 0; i < str.length; ++i) {
        ch = [str characterAtIndex:i];
        switch (ch) {
          case '{': case '}': case '$': case '%':
          case '&': case '_': case '#':
            [out appendFormat:@"\\%c", ch];
            break;
        case '^':
            [out appendString:@"\\^{}"];
            break;
        case '\\':
            [out appendString:@"\\textbackslash{}"];
            break;
        case '~':
            [out appendString:@"\\ensuremath{\\sim}"];
            break;
        case '|':
            [out appendString:@"\\textbar{}"];
            break;
        case '<':
            [out appendString:@"\\textless{}"];
            break;
        case '>':
            [out appendString:@"\\textgreater{}"];
            break;
        default:
                [out appendCharacter:ch];
        }
    }
}

/* print_latex_element_list - print a list of elements as LaTeX */
static void print_latex_element_list(NSMutableString *out, element *list) {
    while (list != NULL) {
        print_latex_element(out, list);
        list = list->next;
    }
}

/* print_latex_element - print an element as LaTeX */
static void print_latex_element(NSMutableString *out, element *elt) {
    int lev;
    switch (elt->key) {
    case SPACE:
        [out appendFormat:@"%@", elt->contents.str];
        break;
    case LINEBREAK:
        [out appendString:@"\\\\\n"];
        break;
    case STRING:
        print_latex_string(out, elt->contents.str);
        break;
    case ELLIPSIS:
        [out appendString:@"\\ldots{}"];
        break;
    case EMDASH: 
        [out appendString:@"---"];
        break;
    case ENDASH: 
        [out appendString:@"--"];
        break;
    case APOSTROPHE:
        [out appendString:@"'"];
        break;
    case SINGLEQUOTED:
        [out appendString:@"`"];
        print_latex_element_list(out, elt->children);
        [out appendString:@"'"];
        break;
    case DOUBLEQUOTED:
        [out appendString:@"``"];
        print_latex_element_list(out, elt->children);
        [out appendString:@"''"];
        break;
    case CODE:
        [out appendString:@"\\texttt{"];
        print_latex_string(out, elt->contents.str);
        [out appendString:@"}"];
        break;
    case HTML:
        /* don't print HTML */
        break;
    case LINK:
        [out appendFormat:@"\\href{%s}{", elt->contents.link->url];
        print_latex_element_list(out, elt->contents.link->label);
        [out appendString:@"}"];
        break;
    case IMAGE:
        [out appendFormat:@"\\includegraphics{%s}", elt->contents.link->url];
        break;
    case EMPH:
        [out appendString:@"\\emph{"];
        print_latex_element_list(out, elt->children);
        [out appendString:@"}"];
        break;
    case STRONG:
        [out appendString:@"\\textbf{"];
        print_latex_element_list(out, elt->children);
        [out appendString:@"}"];
        break;
    case LIST:
        print_latex_element_list(out, elt->children);
        break;
    case RAW:
        /* Shouldn't occur - these are handled by process_raw_blocks() */
        assert(elt->key != RAW);
        break;
    case H1: case H2: case H3:
        pad(out, 2);
        lev = elt->key - H1 + 1;  /* assumes H1 ... H6 are in order */
        [out appendString:@"\\"];
        while(lev--)
            [out appendString:@"sub"];
        [out appendString:@"section{"];
        print_latex_element_list(out, elt->children);
        [out appendString:@"}"];
        padded = 0;
        break;
    case H4: case H5: case H6:
        pad(out, 2);
        [out appendString:@"\\noindent\\textbf{"];
        print_latex_element_list(out, elt->children);
        [out appendString:@"}"];
        padded = 0;
        break;
    case PLAIN:
        pad(out, 1);
        print_latex_element_list(out, elt->children);
        padded = 0;
        break;
    case PARA:
        pad(out, 2);
        print_latex_element_list(out, elt->children);
        padded = 0;
        break;
    case HRULE:
        pad(out, 2);
        [out appendString:@"\\begin{center}\\rule{3in}{0.4pt}\\end{center}\n"];
        padded = 0;
        break;
    case HTMLBLOCK:
        /* don't print HTML block */
        break;
    case VERBATIM:
        pad(out, 1);
        [out appendString:@"\\begin{verbatim}\n"];
        print_latex_string(out, elt->contents.str);
        [out appendString:@"\n\\end{verbatim}"];
        padded = 0;
        break;
    case BULLETLIST:
        pad(out, 1);
        [out appendString:@"\\begin{itemize}"];
        padded = 0;
        print_latex_element_list(out, elt->children);
        pad(out, 1);
        [out appendString:@"\\end{itemize}"];
        padded = 0;
        break;
    case ORDEREDLIST:
        pad(out, 1);
        [out appendString:@"\\begin{enumerate}"];
        padded = 0;
        print_latex_element_list(out, elt->children);
        pad(out, 1);
        [out appendString:@"\\end{enumerate}"];
        padded = 0;
        break;
    case LISTITEM:
        pad(out, 1);
        [out appendString:@"\\item "];
        padded = 2;
        print_latex_element_list(out, elt->children);
        [out appendString:@"\n"];
        break;
    case BLOCKQUOTE:
        pad(out, 1);
        [out appendString:@"\\begin{quote}"];
        padded = 0;
        print_latex_element_list(out, elt->children);
        pad(out, 1);
        [out appendString:@"\\end{quote}"];
        padded = 0;
        break;
    case NOTE:
        /* if contents.str == 0, then print note; else ignore, since this
         * is a note block that has been incorporated into the notes list */
        if (elt->contents.str == 0) {
            [out appendString:@"\\footnote{"];
            padded = 2;
            print_latex_element_list(out, elt->children);
            [out appendString:@"}"];
            padded = 0; 
        }
        break;
    case REFERENCE:
        /* Nonprinting */
        break;
    default: 
        fprintf(stderr, "print_latex_element encountered unknown element key = %d\n", elt->key); 
        exit(EXIT_FAILURE);
    }
}

/**********************************************************************

  Functions for printing Elements as groff (mm macros)

 ***********************************************************************/

static bool in_list_item = false; /* True if we're parsing contents of a list item. */

/* print_groff_string - print string, escaping for groff */
static void print_groff_string(NSMutableString *out, NSString *str) {
    unichar ch;
    for (NSUInteger i = 0; i < str.length; ++i) {
        ch = [str characterAtIndex:i];
        switch (ch) {
        case '\\':
            [out appendString:@"\\e"];
            break;
        default:
                [out appendCharacter:ch];
        }
    }
}

/* print_groff_mm_element_list - print a list of elements as groff ms */
static void print_groff_mm_element_list(NSMutableString *out, element *list) {
    int count = 1;
    while (list != NULL) {
        print_groff_mm_element(out, list, count);
        list = list->next;
        count++;
    }
}

/* print_groff_mm_element - print an element as groff ms */
static void print_groff_mm_element(NSMutableString *out, element *elt, int count) {
    int lev;
    switch (elt->key) {
    case SPACE:
        [out appendFormat:@"%@", elt->contents.str];
        padded = 0;
        break;
    case LINEBREAK:
        pad(out, 1);
        [out appendString:@".br\n"];
        padded = 0;
        break;
    case STRING:
        print_groff_string(out, elt->contents.str);
        padded = 0;
        break;
    case ELLIPSIS:
        [out appendString:@"..."];
        break;
    case EMDASH:
        [out appendString:@"\\[em]"];
        break;
    case ENDASH:
        [out appendString:@"\\[en]"];
        break;
    case APOSTROPHE:
        [out appendString:@"'"];
        break;
    case SINGLEQUOTED:
        [out appendString:@"`"];
        print_groff_mm_element_list(out, elt->children);
        [out appendString:@"'"];
        break;
    case DOUBLEQUOTED:
        [out appendString:@"\\[lq]"];
        print_groff_mm_element_list(out, elt->children);
        [out appendString:@"\\[rq]"];
        break;
    case CODE:
        [out appendString:@"\\fC"];
        print_groff_string(out, elt->contents.str);
        [out appendString:@"\\fR"];
        padded = 0;
        break;
    case HTML:
        /* don't print HTML */
        break;
    case LINK:
        print_groff_mm_element_list(out, elt->contents.link->label);
        [out appendFormat:@" (%s)", elt->contents.link->url];
        padded = 0;
        break;
    case IMAGE:
        [out appendString:@"[IMAGE: "];
        print_groff_mm_element_list(out, elt->contents.link->label);
        [out appendString:@"]"];
        padded = 0;
        /* not supported */
        break;
    case EMPH:
        [out appendString:@"\\fI"];
        print_groff_mm_element_list(out, elt->children);
        [out appendString:@"\\fR"];
        padded = 0;
        break;
    case STRONG:
        [out appendString:@"\\fB"];
        print_groff_mm_element_list(out, elt->children);
        [out appendString:@"\\fR"];
        padded = 0;
        break;
    case LIST:
        print_groff_mm_element_list(out, elt->children);
        padded = 0;
        break;
    case RAW:
        /* Shouldn't occur - these are handled by process_raw_blocks() */
        assert(elt->key != RAW);
        break;
    case H1: case H2: case H3: case H4: case H5: case H6:
        lev = elt->key - H1 + 1;
        pad(out, 1);
        [out appendFormat:@".H %d \"", lev];
        print_groff_mm_element_list(out, elt->children);
        [out appendString:@"\""];
        padded = 0;
        break;
    case PLAIN:
        pad(out, 1);
        print_groff_mm_element_list(out, elt->children);
        padded = 0;
        break;
    case PARA:
        pad(out, 1);
        if (!in_list_item || count != 1)
            [out appendString:@".P\n"];
        print_groff_mm_element_list(out, elt->children);
        padded = 0;
        break;
    case HRULE:
        pad(out, 1);
        [out appendString:@"\\l'\\n(.lu*8u/10u'"];
        padded = 0;
        break;
    case HTMLBLOCK:
        /* don't print HTML block */
        break;
    case VERBATIM:
        pad(out, 1);
        [out appendString:@".VERBON 2\n"];
        print_groff_string(out, elt->contents.str);
        [out appendString:@".VERBOFF"];
        padded = 0;
        break;
    case BULLETLIST:
        pad(out, 1);
        [out appendString:@".BL"];
        padded = 0;
        print_groff_mm_element_list(out, elt->children);
        pad(out, 1);
        [out appendString:@".LE 1"];
        padded = 0;
        break;
    case ORDEREDLIST:
        pad(out, 1);
        [out appendString:@".AL"];
        padded = 0;
        print_groff_mm_element_list(out, elt->children);
        pad(out, 1);
        [out appendString:@".LE 1"];
        padded = 0;
        break;
    case LISTITEM:
        pad(out, 1);
        [out appendString:@".LI\n"];
        in_list_item = true;
        padded = 2;
        print_groff_mm_element_list(out, elt->children);
        in_list_item = false;
        break;
    case BLOCKQUOTE:
        pad(out, 1);
        [out appendString:@".DS I\n"];
        padded = 2;
        print_groff_mm_element_list(out, elt->children);
        pad(out, 1);
        [out appendString:@".DE"];
        padded = 0;
        break;
    case NOTE:
        /* if contents.str == 0, then print note; else ignore, since this
         * is a note block that has been incorporated into the notes list */
        if (elt->contents.str == 0) {
            [out appendString:@"\\*F\n"];
            [out appendString:@".FS\n"];
            padded = 2;
            print_groff_mm_element_list(out, elt->children);
            pad(out, 1);
            [out appendString:@".FE\n"];
            padded = 1; 
        }
        break;
    case REFERENCE:
        /* Nonprinting */
        break;
    default: 
        fprintf(stderr, "print_groff_mm_element encountered unknown element key = %d\n", elt->key); 
        exit(EXIT_FAILURE);
    }
}

/**********************************************************************

  Parameterized function for printing an Element.

 ***********************************************************************/

void print_element_list(NSMutableString *out, element *elt, int format, int exts) {
    /* Initialize globals */
    endnotes = nil;
    notenumber = 0;

    extensions = exts;
    padded = 2;  /* set padding to 2, so no extra blank lines at beginning */
    switch (format) {
    case HTML_FORMAT:
        print_html_element_list(out, elt, false);
        if (endnotes != nil) {
            pad(out, 2);
            print_html_endnotes(out);
        }
        break;
    case LATEX_FORMAT:
        print_latex_element_list(out, elt);
        break;
    case GROFF_MM_FORMAT:
        print_groff_mm_element_list(out, elt);
        break;
    default:
        fprintf(stderr, "print_element - unknown format = %d\n", format); 
        exit(EXIT_FAILURE);
    }
}

/* vim:set ts=4 sw=4: */
