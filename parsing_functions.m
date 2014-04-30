/* parsing_functions.c - Functions for parsing markdown and
 * freeing element lists. */

void parse_from(yyrule yystart)
{
    GREG g;
    memset(&g, 0, sizeof(g));
    yyparse_from(&g, yystart);    /* first pass, just to collect references */
    yydeinit(&g);
}

static void free_element_contents(element elt);

/* free_element_list - free list of elements recursively */
void free_element_list(element * elt) {
    element * next = NULL;
    while (elt != NULL) {
        next = elt->next;
        free_element_contents(*elt);
        if (elt->children != NULL) {
            free_element_list(elt->children);
            elt->children = NULL;
        }
        free(elt);
        elt = next;
    }
}

/* free_element_contents - free element contents depending on type */
static void free_element_contents(element elt) {
    switch (elt.key) {
      case STRING:
      case SPACE:
      case RAW:
      case HTMLBLOCK:
      case HTML:
      case VERBATIM:
      case CODE:
      case NOTE:
        [elt.contents.str release];
        elt.contents.str = nil;
        break;
      case LINK:
      case IMAGE:
      case REFERENCE:
        [elt.contents.link->url release];
        elt.contents.link->url = nil;
        [elt.contents.link->title release];
        elt.contents.link->title = nil;
        free_element_list(elt.contents.link->label);
        free(elt.contents.link);
        elt.contents.link = NULL;
        break;
      default:
        ;
    }
}

/* free_element - free element and contents */
void free_element(element *elt) {
    free_element_contents(*elt);
    free(elt);
}

element * parse_references(NSString *string, int extensions) {
    md.syntax_extensions = extensions;

    struct Input saved = md.input;
    md.input.charbuf  = (char *)[string UTF8String];
    md.input.position = 0;
  
    parse_from(yy_References);           /* first pass, just to collect references */

    md.input = saved;

    return md.references;
}

element * parse_notes(NSString *string, int extensions, element *reference_list) {
    md.notes = NULL;
    md.syntax_extensions = extensions;

    if (extension(EXT_NOTES)) {
        md.references = reference_list;

        struct Input saved = md.input;
        md.input.charbuf  = (char *)[string UTF8String];
        md.input.position = 0;

        parse_from(yy_Notes);           /* second pass for notes */

        md.input = saved;
    }

    return md.notes;
}

element * parse_markdown(NSString *string, int extensions, element *reference_list, element *note_list) {
    md.syntax_extensions = extensions;
    md.references = reference_list;
    md.notes = note_list;

    struct Input saved = md.input;
    md.input.charbuf  = (char *)[string UTF8String];
    md.input.position = 0;
  
    parse_from(yy_Doc);

    md.input = saved;

    return md.parse_result;
}

/* vim:set ts=4 sw=4: */
