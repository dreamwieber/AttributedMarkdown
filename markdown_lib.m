/**********************************************************************

  markdown_lib.m - markdown in Cocoa using a PEG grammar.
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#import "markdown_peg.h"

#define TABSTOP 4

/* preformat_text - allocate and copy text buffer while
 * performing tab expansion. */
static NSMutableString *preformat_text(NSString *text) {
    NSMutableString *buf = [[[NSMutableString alloc] init] autorelease];
    unichar next_char;
    int len = 0;
    int charstotab = TABSTOP;
    for (NSUInteger i = 0; i < text.length; ++i) {
        next_char = [text characterAtIndex:i];
        switch (next_char) {
        case '\t':
            while (charstotab > 0)
                [buf appendCharacter:' '], len++, charstotab--;
            break;
        case '\n':
            [buf appendCharacter:'\n'], len++, charstotab = TABSTOP;
            break;
        default:
            [buf appendCharacter:next_char], len++, charstotab--;
        }
        if (charstotab == 0)
            charstotab = TABSTOP;
    }
    [buf appendString:@"\n\n"];
    return(buf);
}

/* print_tree - print tree of elements, for debugging only. */
static void print_tree(element * elt, int indent) {
    int i;
    char * key;
    while (elt != NULL) {
        for (i = 0; i < indent; i++)
            fputc(' ', stderr);
        switch (elt->key) {
            case LIST:               key = "LIST"; break;
            case RAW:                key = "RAW"; break;
            case SPACE:              key = "SPACE"; break;
            case LINEBREAK:          key = "LINEBREAK"; break;
            case ELLIPSIS:           key = "ELLIPSIS"; break;
            case EMDASH:             key = "EMDASH"; break;
            case ENDASH:             key = "ENDASH"; break;
            case APOSTROPHE:         key = "APOSTROPHE"; break;
            case SINGLEQUOTED:       key = "SINGLEQUOTED"; break;
            case DOUBLEQUOTED:       key = "DOUBLEQUOTED"; break;
            case STRING:             key = "STRING"; break;
            case LINK:               key = "LINK"; break;
            case IMAGE:              key = "IMAGE"; break;
            case CODE:               key = "CODE"; break;
            case HTML:               key = "HTML"; break;
            case EMPH:               key = "EMPH"; break;
            case STRONG:             key = "STRONG"; break;
            case PLAIN:              key = "PLAIN"; break;
            case PARA:               key = "PARA"; break;
            case LISTITEM:           key = "LISTITEM"; break;
            case BULLETLIST:         key = "BULLETLIST"; break;
            case ORDEREDLIST:        key = "ORDEREDLIST"; break;
            case H1:                 key = "H1"; break;
            case H2:                 key = "H2"; break;
            case H3:                 key = "H3"; break;
            case H4:                 key = "H4"; break;
            case H5:                 key = "H5"; break;
            case H6:                 key = "H6"; break;
            case BLOCKQUOTE:         key = "BLOCKQUOTE"; break;
            case VERBATIM:           key = "VERBATIM"; break;
            case HTMLBLOCK:          key = "HTMLBLOCK"; break;
            case HRULE:              key = "HRULE"; break;
            case REFERENCE:          key = "REFERENCE"; break;
            case NOTE:               key = "NOTE"; break;
            default:                 key = "?";
        }
        if ( elt->key == STRING ) {
            fprintf(stderr, "0x%x: %s   '%s'\n", (int)elt, key, elt->contents.str.defaultCString);
        } else {
            fprintf(stderr, "0x%x: %s\n", (int)elt, key);
        }
        if (elt->children)
            print_tree(elt->children, indent + 4);
        elt = elt->next;
    }
}

/* process_raw_blocks - traverses an element list, replacing any RAW elements with
 * the result of parsing them as markdown text, and recursing into the children
 * of parent elements.  The result should be a tree of elements without any RAWs. */
static element * process_raw_blocks(element *input, int extensions, element *references, element *notes) {
    element *current = NULL;
    element *last_child = NULL;
    current = input;

    while (current != NULL) {
        if (current->key == RAW) {
            current->key = LIST;
            /* \001 is used to indicate boundaries between nested lists when there
             * is no blank line.  We split the string by \001 and parse
             * each chunk separately. */
            NSArray *chunks = [current->contents.str componentsSeparatedByString:@"\001"];
            for (NSString *contents in chunks) {
                if (!last_child) {
                    current->children = parse_markdown(contents, extensions, references, notes);
                    last_child = current->children;
                } else {
                    while (last_child->next != NULL)
                        last_child = last_child->next;
                    last_child->next = parse_markdown(contents, extensions, references, notes);
                }
            }
            [current->contents.str release];
            current->contents.str = nil;
        }
        if (current->children != NULL)
            current->children = process_raw_blocks(current->children, extensions, references, notes);
        current = current->next;
    }
    return input;
}

/* markdown_to_nstring - convert markdown text to the output format specified.
 * Returns an autoreleased NSMutableString. */
NSMutableString * markdown_to_nsstring(NSString *text, int extensions, int output_format) {
    NSMutableString *out = [[[NSMutableString alloc] init] autorelease];

    NSMutableString *formatted_text = preformat_text(text);

    element *references = parse_references(formatted_text, extensions);
    element *notes = parse_notes(formatted_text, extensions, references);
    element *result = parse_markdown(formatted_text, extensions, references, notes);
    result = process_raw_blocks(result, extensions, references, notes);

    print_element_list(out, result, output_format, extensions);

    free_element_list(result);
    free_element_list(references);
    return out;
}

/* markdown_to_string - convert markdown text to the output format specified.
 * Returns a null-terminated string, which must be freed after use. */
const char * markdown_to_string(NSString *text, int extensions, int output_format) {
    NSMutableString *out = markdown_to_nsstring(text, extensions, output_format);
    return out.UTF8String;
}

@implementation NSString (Sugar)

- (const char *)defaultCString {
    return [self cStringUsingEncoding:[NSString defaultCStringEncoding]];
}

@end

@implementation NSMutableString (Sugar)

- (void)appendCharacter:(unichar)ch {
    [self appendFormat:@"%c", ch];
}

@end


/* vim:set ts=4 sw=4: */
