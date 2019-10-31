#include <stdio.h>
#include <stdlib.h>
#include "markdown.h"
#include "discount-support.h"


char* markdownToHTML(const char *markdownStr) {

    // C bridge to the Discount HTML conversion engine
    
    char *html = NULL;
    Document *page = mkd_string((char *)markdownStr, (int)strlen(markdownStr), 0);
    mkd_compile(page, MKD_EXTRA_FOOTNOTE);
    return mkd_document(page, &html) == 0 ? NULL : html;
}
