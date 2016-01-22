/**********************************************************************

  markdown_output.c - functions for printing Elements parsed by 
                      markdown_peg.
  (c) 2012 Gregory Wieber & Jim Radford
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
#import "markdown_peg.h"
#import "platform.h"

static int extensions;

static void print_attr_string(NSMutableAttributedString *out, NSString *str, NSDictionary *current);
static void print_attr_element_list(NSMutableAttributedString *out, element *list, NSDictionary *attributes[], NSDictionary *current);
static void print_attr_element(NSMutableAttributedString *out, element *elt, NSDictionary *attributes[], NSDictionary *current);
/**********************************************************************

  Utility functions for printing

 ***********************************************************************/

static int indentation = 0;
static int padded = 2;      /* Number of newlines after last output.
                               Starts at 2 so no newlines are needed at start.
                               */

static NSMutableArray *endnotes = nil; /* List of endnotes to print after main content. */
static int notenumber = 0;  /* Number of footnote. */

/* pad - add newlines if needed */
__unused static void pad(NSMutableString *out, int num) {
    while (num-- > padded)
        [out appendString:@"\n"];
    padded = num;
}

/**********************************************************************

  Functions for printing Elements as HTML

 ***********************************************************************/

/* print_html_string - print string, escaping for HTML  
 * If obfuscate selected, convert characters to hex or decimal entities at random */
__unused static void print_html_string(NSMutableString *out, NSString *str, bool obfuscate) {
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

static void print_attr_string(NSMutableAttributedString *out, NSString *str, NSDictionary* current) {
    [out appendAttributedString:[[[NSAttributedString alloc]initWithString:str attributes:current] autorelease]];
}


static NSMutableDictionary *merge(NSDictionary *into, NSDictionary *with) {
    if (![with isKindOfClass:[NSDictionary class]]) {
        return [NSMutableDictionary dictionaryWithDictionary:into];
    }
    
    NSMutableDictionary *ret = [[[NSMutableDictionary alloc]initWithDictionary:into] autorelease];
    [ret addEntriesFromDictionary:with];
    
    // 'cascading' styles
    TARGET_PLATFORM_FONT* inheritedFont = [into objectForKey:NSFontAttributeName];
    if (inheritedFont) {
        TARGET_PLATFORM_FONT* elementFont = [with objectForKey:NSFontAttributeName];
        if (elementFont) {

            CTFontRef inheritedCTFont =  CTFontCreateWithName((CFStringRef)inheritedFont.fontName, inheritedFont.pointSize, NULL);
            CTFontRef elementCTFont = CTFontCreateWithName((CFStringRef)elementFont.fontName, inheritedFont.pointSize, NULL);
            
            // combine the font traits
            CTFontSymbolicTraits inheritedTraits = CTFontGetSymbolicTraits(inheritedCTFont);
            CTFontSymbolicTraits elementTraits = CTFontGetSymbolicTraits(elementCTFont);
            CTFontRef outCTFont = CTFontCreateCopyWithSymbolicTraits(elementCTFont, inheritedFont.pointSize, NULL, inheritedTraits | elementTraits, elementTraits | inheritedTraits);
            
            // make a new UIFont/NSFont
            NSString *newFontName = [(NSString *)CTFontCopyName(outCTFont, kCTFontPostScriptNameKey) autorelease];
            TARGET_PLATFORM_FONT* newFont = [TARGET_PLATFORM_FONT fontWithName:newFontName size:inheritedFont.pointSize];

            if (newFont) {
                [ret setObject:newFont forKey:NSFontAttributeName];
            }

            if (inheritedCTFont) CFRelease(inheritedCTFont);
            if (elementCTFont) CFRelease(elementCTFont);
            if (outCTFont) CFRelease(outCTFont);

        } else {
            [ret setObject:inheritedFont forKey:NSFontAttributeName];
        }
    }
    
    NSParagraphStyle* inheritedParagraphStyle = [into objectForKey:NSParagraphStyleAttributeName];
    if (inheritedParagraphStyle) {
        NSParagraphStyle* elementParagraphStyle = [with objectForKey:NSParagraphStyleAttributeName];
        if (elementParagraphStyle) {
            NSMutableParagraphStyle* newParagraphStyle = [[inheritedParagraphStyle mutableCopy] autorelease];
            newParagraphStyle.headIndent+= elementParagraphStyle.headIndent;
            newParagraphStyle.firstLineHeadIndent+= elementParagraphStyle.firstLineHeadIndent;
            /*if (indentation) {
                newParagraphStyle.headIndent=indentation * inheritedParagraphStyle.headIndent;
                newParagraphStyle.firstLineHeadIndent=indentation * inheritedParagraphStyle.firstLineHeadIndent;
            }*/
            [ret setObject:newParagraphStyle forKey:NSParagraphStyleAttributeName];
        }
    }
        
    return ret;
}

static void print_attr_element_list(NSMutableAttributedString *out, element *list, NSDictionary *attributes[], NSDictionary *current) {
    while (list != NULL) {
        print_attr_element(out, list, attributes, current);
        list = list->next;
    }
}


/* add_endnote - add an endnote to global endnotes list. */
__unused static void add_endnote(element *elt) {
    if (endnotes == nil)
        endnotes = [[NSMutableArray alloc] init];
   [endnotes insertObject:[NSValue valueWithPointer:(const void*)elt] atIndex:0];
}

static void print_attr_element(NSMutableAttributedString *out, element *elt, NSDictionary *attributes[], NSDictionary *current) {

    switch (elt->key) {
        case SPACE:         print_attr_string(out, @" ",current);  break;
        case LINEBREAK:     print_attr_string(out, @"\n",current);  break;
        case STRING:        print_attr_string(out, elt->contents.str, current);  break;
        case ELLIPSIS:      print_attr_string(out, @"\u2026",current); break;
        case EMDASH:        print_attr_string(out, @"\u2014",current); break;
        case ENDASH:        print_attr_string(out, @"\u2013",current); break;
        case APOSTROPHE:    print_attr_string(out, @"\u02BC",current); break;
        case SINGLEQUOTED:
            print_attr_string(out, @"\u2018",current);
            print_attr_element_list(out, elt->children, attributes, current);
            print_attr_string(out, @"\u2019",current);
            break;
        case DOUBLEQUOTED:
            print_attr_string(out, @"\u201C",current);
            print_attr_element_list(out, elt->children, attributes, current);
            print_attr_string(out, @"\u201D",current);
            break;
        case CODE:
            print_attr_string(out, elt->contents.str, merge(current, attributes[elt->key]));
            break;
        case HTML:
            //[out appendFormat:@"%@", elt->contents.str];
            break;
        case LINK:;
            NSURL *url = [NSURL URLWithString:elt->contents.link->url];
            if (url) {
                NSDictionary *linkAttibutes = @{@"attributedMarkdownURL": url};
                print_attr_element_list(out, elt->contents.link->label, attributes, merge(current, merge(attributes[elt->key], linkAttibutes)));
            } else {
                NSDictionary *attributesBroken = @{NSForegroundColorAttributeName: [TARGET_PLATFORM_COLOR redColor]}; // Make this attributes[BROKEN]
                print_attr_element_list(out, elt->contents.link->label, attributes, merge(current, attributesBroken));
                print_attr_string(out, [NSString stringWithFormat: @" (%@)", elt->contents.link->url], current);
            }
            break;
        case IMAGE:
            // NOT CURRENTLY SUPPORTED
            break;
        case EMPH: case STRONG:
            print_attr_element_list(out, elt->children, attributes, merge(current, attributes[elt->key]));
            break;
        case LIST:
            print_attr_element_list(out, elt->children, attributes, merge(current, attributes[elt->key]));
            break;
        case RAW:
            /* Shouldn't occur - these are handled by process_raw_blocks() */
            assert(elt->key != RAW);
            break;
        case H1: case H2: case H3: case H4: case H5: case H6:
            print_attr_element_list(out, elt->children, attributes, merge(current, attributes[elt->key]));
            print_attr_string(out, @"\n",current);
            print_attr_string(out, @"\n",current);
            break;
        case PLAIN:
            print_attr_element_list(out, elt->children, attributes, merge(current, attributes[elt->key]));
            break;
        case PARA:
            //NSLog(@"%@",merge(current, attributes[elt->key]));
            print_attr_element_list(out, elt->children, attributes, merge(current, attributes[elt->key]));
            print_attr_string(out, @"\n",current);
            print_attr_string(out, @"\n",current);
            break;
        case HRULE:         print_attr_string(out, @"\n-----------------------------------------------------\n", merge(current, attributes[elt->key])); break;
        case HTMLBLOCK:     print_attr_string(out, elt->contents.str, merge(current, attributes[elt->key])); break;
        case VERBATIM:      print_attr_string(out, elt->contents.str, merge(current, attributes[elt->key])); break;
        case BULLETLIST:
            //pad(out, 2);
            padded = 0;
            print_attr_string(out, @"\n",current);
            indentation+=1;
            print_attr_element_list(out, elt->children, attributes, merge(current, attributes[elt->key]));
            //pad(out, 1);
            indentation-=1;
            print_attr_string(out, @"\n",current);
            padded = 0;
            break;
        case ORDEREDLIST:
            //pad(out, 2);
            padded = 0;
            print_attr_element_list(out, elt->children, attributes, merge(current, attributes[elt->key]));
            //pad(out, 1);
            padded = 0;
            break;
        case LISTITEM:
            //pad(out, 1);
            print_attr_string(out, @"\u2022  ",current);
            padded = 2;
            print_attr_element_list(out, elt->children, attributes, merge(current, attributes[elt->key]));
            print_attr_string(out, @"\n",current);
            padded = 0;
            break;
        case BLOCKQUOTE:
            //pad(out, 2);
            padded = 2;
            //NSLog(@"block");
            print_attr_element_list(out, elt->children, attributes, merge(current, attributes[elt->key]));
            //pad(out, 1);
            padded = 0;
            break;
        case REFERENCE:
            /* Nonprinting */
            break;
        case NOTE:
            /* if contents.str == 0, then print note; else ignore, since this
             * is a note block that has been incorporated into the notes list */
            /*if (elt->contents.str == 0) {
                add_endnote(elt);
                ++notenumber;
                [out appendFormat:@"<a class=\"noteref\" id=\"fnref%d\" href=\"#fn%d\" title=\"Jump to note %d\">[%d]</a>",
                 notenumber, notenumber, notenumber, notenumber];
            }*/
            break;
        default:
            fprintf(stderr, "print_html_element encountered unknown element key = %d\n", elt->key);
            exit(EXIT_FAILURE);
    }
}

/**********************************************************************

  Parameterized function for printing an Element.

 ***********************************************************************/

void print_element_list_attr(NSMutableAttributedString *out, element *elt, int exts,NSDictionary *attributes[], NSDictionary *current) {
    /* Initialize globals */
    endnotes = nil;
    notenumber = 0;
    
    extensions = exts;
    padded = 2;  /* set padding to 2, so no extra blank lines at beginning */
    print_attr_element_list(out, elt, attributes, current);
    if (endnotes != nil) {
       // pad(out, 2);
       // print_attr_endnotes(out);
    }
}



/* vim:set ts=4 sw=4: */
