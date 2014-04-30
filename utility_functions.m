/* utility_functions.c - List manipulation functions, element
 * constructors, and macro definitions for leg markdown parser. */

/**********************************************************************

  List manipulation functions

 ***********************************************************************/

/* cons - cons an element onto a list, returning pointer to new head */
static element * cons(element *elt, element *list) {
    assert(elt != NULL);
    elt->next = list;
    return elt;
}

/* reverse - reverse a list, returning pointer to new list list */
static element *reverse(element *list) {
    element *newlist = NULL;
    element *next = NULL;
    while (list != NULL) {
        next = list->next;
        newlist = cons(list, newlist);
        list = next;
    }
    return newlist;
}

/* concat_string_list - concatenates string contents of list of STRING elements.
 * Frees STRING elements as they are added to the concatenation. */
static NSMutableString *concat_string_list(element *list) {
    NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
    element *next;
    while (list != NULL) {
        assert(list->key == STRING);
        assert(list->contents.str != NULL);
        [result appendString:list->contents.str];
        next = list->next;
        free_element(list);
        list = next;
    }
    return result;
}

/**********************************************************************

  Global variables used in parsing

 ***********************************************************************/

struct Input {
    char *charbuf;         /* Buffer of characters to be parsed. */
    NSUInteger position;   /* Curent index into charbuf. */
};

struct Markdown {
    struct Input input;    /* Input buffer with position. */
    element *references;   /* List of link references found. */
    element *notes;        /* List of footnotes found. */
    element *parse_result; /* Results of parse. */
    int syntax_extensions; /* Syntax extensions selected. */
};

static struct Markdown md = { { nil, 0 }, NULL, NULL, NULL, 0 };

/**********************************************************************

  Auxiliary functions for parsing actions.
  These make it easier to build up data structures (including lists)
  in the parsing actions.

 ***********************************************************************/

/* mk_element - generic constructor for element */
static element * mk_element(int key) {
    element *result = malloc(sizeof(element));
    result->key = key;
    result->children = NULL;
    result->next = NULL;
    result->contents.str = nil;
    return result;
}

/* mk_str - constructor for STRING element */
static element * mk_str(const char *string) {
    element *result;
    assert(string != NULL);
    result = mk_element(STRING);
    result->contents.str = [[NSMutableString alloc] initWithCString:string encoding:NSUTF8StringEncoding];
    return result;
}

/* mk_str_from_list - makes STRING element by concatenating a
 * reversed list of strings, adding optional extra newline */
static element * mk_str_from_list(element *list, bool extra_newline) {
    element *result;
    NSMutableString *c = concat_string_list(reverse(list));
    if (extra_newline)
        [c appendString:@"\n"];
    result = mk_element(STRING);
    result->contents.str = [c retain];
    return result;
}

/* mk_list - makes new list with key 'key' and children the reverse of 'lst'.
 * This is designed to be used with cons to build lists in a parser action.
 * The reversing is necessary because cons adds to the head of a list. */
static element * mk_list(int key, element *lst) {
    element *result;
    result = mk_element(key);
    result->children = reverse(lst);
    return result;
}

/* mk_link - constructor for LINK element */
static element * mk_link(element *label, NSString *url, NSString *title) {
    element *result;
    result = mk_element(LINK);
    result->contents.link = malloc(sizeof(Link));
    result->contents.link->label = label;
    result->contents.link->url = [url retain];
    result->contents.link->title = [title retain];
    return result;
}
/* extension = returns true if extension is selected */
static bool extension(int ext) {
    return (md.syntax_extensions & ext);
}

/* match_inlines - returns true if inline lists match (case-insensitive...) */
static bool match_inlines(element *l1, element *l2) {
    while (l1 != NULL && l2 != NULL) {
        if (l1->key != l2->key)
            return false;
        switch (l1->key) {
        case SPACE:
        case LINEBREAK:
        case ELLIPSIS:
        case EMDASH:
        case ENDASH:
        case APOSTROPHE:
            break;
        case CODE:
        case STRING:
        case HTML:
            if ([l1->contents.str caseInsensitiveCompare:l2->contents.str] == NSOrderedSame)
                break;
            else
                return false;
        case EMPH:
        case STRONG:
        case LIST:
        case SINGLEQUOTED:
        case DOUBLEQUOTED:
            if (match_inlines(l1->children, l2->children))
                break;
            else
                return false;
        case LINK:
        case IMAGE:
            return false;  /* No links or images within links */
        default:
            fprintf(stderr, "match_inlines encountered unknown key = %d\n", l1->key);
            exit(EXIT_FAILURE);
            break;
        }
        l1 = l1->next;
        l2 = l2->next;
    }
    return (l1 == NULL && l2 == NULL);  /* return true if both lists exhausted */
}

/* find_reference - return true if link found in references matching label.
 * 'link' is modified with the matching url and title. */
static bool find_reference(Link *result, element *label) {
    element *cur = md.references;  /* pointer to walk up list of references */
    Link *curitem;
    while (cur != NULL) {
        curitem = cur->contents.link;
        if (match_inlines(label, curitem->label)) {
            *result = *curitem;
            return true;
        }
        else
            cur = cur->next;
    }
    return false;
}

/* find_note - return true if note found in notes matching label.
   if found, 'result' is set to point to matched note. */

static bool find_note(element **result, NSString *label) {
   element *cur = md.notes;  /* pointer to walk up list of notes */
   while (cur != NULL) {
       if ([label isEqualToString:cur->contents.str] == NSOrderedSame) {
           *result = cur;
           return true;
       }
       else
           cur = cur->next;
   }
   return false;
}

/**********************************************************************

  Definitions for leg parser generator.
  YY_INPUT is the function the parser calls to get new input.
  We take all new input from charbuf.

 ***********************************************************************/

#define YYSTYPE element *
#ifdef __DEBUG__
#define YY_DEBUG 1
#endif

#define YY_INPUT(buf, result, max_size, data)             \
{                                                         \
    int yyc;                                              \
    if (md.input.charbuf && *md.input.charbuf != '\0') {  \
        yyc= *md.input.charbuf++;                         \
    } else {                                              \
        yyc= EOF;                                         \
    }                                                     \
    result= (EOF == yyc) ? 0 : (*(buf)= yyc, 1);          \
}


/* vim:set ts=4 sw=4: */
