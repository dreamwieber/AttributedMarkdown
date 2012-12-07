/* markdown_peg.h */
#import "markdown_lib.h"
#import <Foundation/Foundation.h>

extern char *strdup(const char *string);

/* Information (label, URL and title) for a link. */
struct Link {
    struct Element                          *label;
    NSString         __unsafe_unretained    *url;
    NSString         __unsafe_unretained    *title;
};

typedef struct Link Link;

/* Union for contents of an Element (string, list, or link). */
union Contents {
    NSMutableString  __unsafe_unretained    *str;
    struct Link                             *link;
};

/* Types of semantic values returned by parsers. */
enum keys { LIST,   /* A generic list of values.  For ordered and bullet lists, see below. */
            RAW,    /* Raw markdown to be processed further */
            SPACE,
            LINEBREAK,
            ELLIPSIS,
            EMDASH,
            ENDASH,
            APOSTROPHE,
            SINGLEQUOTED,
            DOUBLEQUOTED,
            STRING,
            LINK,
            IMAGE,
            CODE,
            HTML,
            EMPH,
            STRONG,
            PLAIN,
            PARA,
            LISTITEM,
            BULLETLIST,
            ORDEREDLIST,
            H1, H2, H3, H4, H5, H6,  /* Code assumes that these are in order. */
            BLOCKQUOTE,
            VERBATIM,
            HTMLBLOCK,
            HRULE,
            REFERENCE,
            NOTE
          };

/* Semantic value of a parsing action. */
struct Element {
    int               key;
    union Contents    contents;
    struct Element    *children;
    struct Element    *next;
};

typedef struct Element element;

element * parse_references(NSString *string, int extensions);
element * parse_notes(NSString *string, int extensions, element *reference_list);
element * parse_markdown(NSString *string, int extensions, element *reference_list, element *note_list);
void free_element_list(element * elt);
void free_element(element *elt);
void print_element_list(NSMutableString *out, element *elt, int format, int exts, NSDictionary* current);
void print_element_list_attr(NSMutableAttributedString *out, element *elt, int exts, NSDictionary __unsafe_unretained *attributes[], NSDictionary *current);


/* vim:set ts=4 sw=4: */
