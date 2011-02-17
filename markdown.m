
/**********************************************************************

  markdown.m - markdown in Cocoa using a PEG grammar.
  (c) 2011 David Whetstone (david at humblehacker dot com).
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
#import <Foundation/Foundation.h>
#import "markdown_lib.h"
#import "markdown_peg.h"
#include <getopt.h>

/**********************************************************************

  The main program is just a wrapper around the library functions in
  markdown_lib.c.  It parses command-line options, reads the text to
  be converted from input files or stdin, converts the text, and sends
  the output to stdout or a file.  Character encodings are ignored.

 ***********************************************************************/

#define VERSION "0.4.12Cocoa"
#define COPYRIGHT "Copyright (c) 2011 David Whetstone.  Original code is \n" \
                  "Copyright (c) 2008-2009 John MacFarlane.  License GPLv2+ or MIT.\n" \
                  "This is free software: you are free to change and redistribute it.\n" \
                  "There is NO WARRANTY, to the extent permitted by law."

/* print version and copyright information */
void version()
{
  printf("markdown version %s\n"
         "%s\n",
         VERSION,
         COPYRIGHT);
}

typedef enum {
    NO_HELP,
    HELP_BASIC,
    HELP_EXTENSIONS,
    HELP_ALL
} help_options;

void usage(help_options options) {
    version();

    static const char usage[] =
      "Usage:                                                               \n"
      "  markdown [OPTION...] [FILE...]                                     \n";

    static const char help[] =
      "Help Options:                                                        \n"
      "  -h, --help              Show help options                          \n"
      "  --help-all              Show all help options                      \n"
      "  --help-extensions       show available syntax extensions           \n";

    static const char application[] =
      "Application Options:                                                 \n"
      "  -v, --version           print version and exit                     \n"
      "  -o, --output=FILE       send output to FILE (default is stdout)    \n"
      "  -t, --to=FORMAT         convert to FORMAT (default is html)        \n"
      "  -x, --extensions        use all syntax extensions                  \n"
      "  --filter-html           filter out raw HTML (except styles)        \n"
      "  --filter-styles         filter out HTML styles                     \n"
      "                                                                     \n"
      "Converts text in specified files (or stdin) from markdown to FORMAT. \n"
      "Available FORMATs:  html, latex, groff-mm                            \n";

    static const char extensions[] =
      "Syntax extensions                                                    \n"
      "  --smart                 use smart typography extension             \n"
      "  --notes                 use notes extension                        \n";

    printf("%s\n", usage);

    if (options == HELP_BASIC || options == HELP_ALL)
        printf("%s\n", help);

    if (options == HELP_EXTENSIONS || options == HELP_ALL)
        printf("%s\n", extensions);

    if (options == HELP_BASIC || options == HELP_ALL)
        printf("%s\n", application);

    exit (1);
}

int main (int argc, char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    FILE *output = NULL;
    int extensions = 0;
    int output_format = HTML_FORMAT;

    /* Code for command-line option parsing. */
    static int help_opt = NO_HELP;
    static int ext_opt = EXT_NONE;

    static struct option longopts[] =
    {
      { "version",          no_argument,        NULL,       'v'                },
      { "output",           required_argument,  NULL,       'o'                },
      { "to",               required_argument,  NULL,       't'                },
      { "help",             no_argument,        &help_opt,  HELP_BASIC         },
      { "help-all",         no_argument,        &help_opt,  HELP_ALL           },
      { "help-extensions",  no_argument,        &help_opt,  HELP_EXTENSIONS    },
      { "extensions",       no_argument,        &ext_opt,   EXT_ALL            },
      { "filter-html",      no_argument,        &ext_opt,   EXT_FILTER_HTML    },
      { "filter-styles",    no_argument,        &ext_opt,   EXT_FILTER_STYLES  },
      { "smart",            no_argument,        &ext_opt,   EXT_SMART          },
      { "notes",            no_argument,        &ext_opt,   EXT_NOTES          },
      { NULL }
    };


    int ch;
    while ((ch = getopt_long(argc, argv, "hvo:t:x", longopts, NULL)) != -1) {
        switch (ch) {
            case 'v':
                version();
                return EXIT_SUCCESS;

            case 'o':
                if (optarg == NULL || strcmp(optarg, "-") == 0)
                    output = stdout;
                else if (!(output = fopen(optarg, "w"))) {
                    perror(optarg);
                    return 1;
                }
                break;

            case 't':
                if (optarg == NULL)
                    output_format = HTML_FORMAT;
                else if (strcmp(optarg, "html") == 0)
                    output_format = HTML_FORMAT;
                else if (strcmp(optarg, "latex") == 0)
                    output_format = LATEX_FORMAT;
                else if (strcmp(optarg, "groff-mm") == 0)
                    output_format = GROFF_MM_FORMAT;
                else {
                    fprintf(stderr, "%s: Unknown output format '%s'\n", getprogname(), optarg);
                    exit(EXIT_FAILURE);
                }
                break;

            case 'x':
                extensions = EXT_ALL;
                break;

            case 0:
                if (help_opt)
                    usage(help_opt);

                if (ext_opt)
                    extensions |= ext_opt;

                break;

            default:
                usage(HELP_BASIC);
                break;
        };
    };

    argc -= optind;
    argv += optind;

    if (!output)
        output = stdout;

    NSMutableString *inputbuf = [[[NSMutableString alloc] init] autorelease];

    /* Read input from stdin or input files into inputbuf */

    FILE *input = NULL;
    char curchar;
    if (argc == 0) {        /* use stdin if no files specified */
        while ((curchar = fgetc(stdin)) != EOF)
            [inputbuf appendCharacter:curchar];
        fclose(stdin);
    }
    else {                     /* open all the files on command line */
        int numargs = argc;
        while (numargs--) {
            if ((input = fopen(argv[argc-numargs-1], "r")) == NULL) {
                perror(argv[argc-numargs]);
                exit(EXIT_FAILURE);
            }
            while ((curchar = fgetc(input)) != EOF)
                [inputbuf appendCharacter:curchar];
            fclose(input);
        }
    }

    const char * out = markdown_to_string(inputbuf, extensions, output_format);
    fprintf(output, "%s\n", out);

    [pool drain];
    return (EXIT_SUCCESS);
}

/* vim:set ts=4 sw=4: */
