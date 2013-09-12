/**********************************************************************

  markdown_lib.m - markdown in Cocoa using a PEG grammar.
  (c) 2012 Gregory Wieber & Jim Radford
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

NSMutableAttributedString* markdown_to_attr_string(NSString *text, int extensions, NSDictionary* attributes) {
    NSMutableAttributedString *out = [[[NSMutableAttributedString alloc] init] autorelease];
    
    NSMutableString *formatted_text = preformat_text(text);
    
    element *references = parse_references(formatted_text, extensions);
    element *notes = parse_notes(formatted_text, extensions, references);
    element *result = parse_markdown(formatted_text, extensions, references, notes);
    result = process_raw_blocks(result, extensions, references, notes);
    
    [out beginEditing];
    
    NSDictionary *_attributes[] = {
        [LIST] =        [attributes objectForKey:[NSNumber numberWithInt:LIST]],
        [RAW] =         [attributes objectForKey:[NSNumber numberWithInt:RAW]],
        [SPACE]=        [attributes objectForKey:[NSNumber numberWithInt:SPACE]],
        [LINEBREAK]=    [attributes objectForKey:[NSNumber numberWithInt:LINEBREAK]],
        [ELLIPSIS]=     [attributes objectForKey:[NSNumber numberWithInt:ELLIPSIS]],
        [EMDASH]=       [attributes objectForKey:[NSNumber numberWithInt:EMDASH]],
        [ENDASH]=       [attributes objectForKey:[NSNumber numberWithInt:ENDASH]],
        [APOSTROPHE]=   [attributes objectForKey:[NSNumber numberWithInt:APOSTROPHE]],
        [SINGLEQUOTED]= [attributes objectForKey:[NSNumber numberWithInt:SINGLEQUOTED]],
        [DOUBLEQUOTED]= [attributes objectForKey:[NSNumber numberWithInt:DOUBLEQUOTED]],
        [STRING]=       [attributes objectForKey:[NSNumber numberWithInt:STRING]],
        [LINK]=         [attributes objectForKey:[NSNumber numberWithInt:LINK]],
        [IMAGE]=        [attributes objectForKey:[NSNumber numberWithInt:IMAGE]],
        [CODE]=         [attributes objectForKey:[NSNumber numberWithInt:CODE]],
        [HTML]=         [attributes objectForKey:[NSNumber numberWithInt:HTML]],
        [EMPH]=         [attributes objectForKey:[NSNumber numberWithInt:EMPH]],
        [STRONG]=       [attributes objectForKey:[NSNumber numberWithInt:STRONG]],
        [PLAIN]=        [attributes objectForKey:[NSNumber numberWithInt:PLAIN]],
        [PARA]=         [attributes objectForKey:[NSNumber numberWithInt:PARA]],
        [LISTITEM]=     [attributes objectForKey:[NSNumber numberWithInt:LISTITEM]],
        [BULLETLIST]=   [attributes objectForKey:[NSNumber numberWithInt:BULLETLIST]],
        [ORDEREDLIST]=  [attributes objectForKey:[NSNumber numberWithInt:ORDEREDLIST]],
        [H1]=           [attributes objectForKey:[NSNumber numberWithInt:H1]],
        [H2]=           [attributes objectForKey:[NSNumber numberWithInt:H2]],
        [H3]=           [attributes objectForKey:[NSNumber numberWithInt:H3]],
        [H4]=           [attributes objectForKey:[NSNumber numberWithInt:H4]],
        [H5]=           [attributes objectForKey:[NSNumber numberWithInt:H5]],
        [H6]=           [attributes objectForKey:[NSNumber numberWithInt:H6]],
        [BLOCKQUOTE]=   [attributes objectForKey:[NSNumber numberWithInt:BLOCKQUOTE]],
        [VERBATIM]=     [attributes objectForKey:[NSNumber numberWithInt:VERBATIM]],
        [HTMLBLOCK]=    [attributes objectForKey:[NSNumber numberWithInt:HTMLBLOCK]],
        [HRULE]=        [attributes objectForKey:[NSNumber numberWithInt:HRULE]],
        [REFERENCE]=    [attributes objectForKey:[NSNumber numberWithInt:REFERENCE]],
        [NOTE]=         [attributes objectForKey:[NSNumber numberWithInt:NOTE]],
    };

    
    print_element_list_attr(out, result, extensions, _attributes, @{});
    [out endEditing];
    
    free_element_list(result);
    free_element_list(references);
    return out;
}

@implementation NSString (Sugar)

- (const char *)defaultCString {
    return [self cStringUsingEncoding:[NSString defaultCStringEncoding]];
}

@end

@implementation NSMutableString (Sugar)

- (void)appendCharacter:(unichar)ch {
    [self appendFormat:@"%C", ch];
}

@end


/* vim:set ts=4 sw=4: */
