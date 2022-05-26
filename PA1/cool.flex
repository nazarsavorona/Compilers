/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

#define line_number curr_lineno

int comment_depth;
bool is_null_in_string;
char* current_string;

char* append_character(char* string, char c);
char* append_string(char* string, char* another_string);
char* handle_string_character(char* current_string, char c);

%}

TYPE_ID	        [[:upper:]][[:alnum:]_]*
OBJECT_ID       [[:lower:]][[:alnum:]_]*

IF              (?i:if)
FI              (?i:fi)
TRUE            t(?i:rue)
FALSE	        f(?i:alse)
CLASS           (?i:class)
ELSE            (?i:else)
IN              (?i:in)
INHERITS        (?i:inherits)
ISVOID          (?i:isvoid)
LET             (?i:let)
LOOP            (?i:loop)
POOL            (?i:pool)
THEN            (?i:then)
WHILE           (?i:while)
CASE            (?i:case)
ESAC            (?i:esac)
NEW             (?i:new)
OF              (?i:of)
NOT             (?i:not)

DARROW          =>
LE              <=
ASSIGN		    <-

%x SINGLE_LINE_COMMENT MULTILINE_COMMENT STRING

%%

{IF}     	return IF;
{FI}		return FI;
{CLASS}	    return CLASS;
{ELSE}    	return ELSE;
{IN}      	return IN;
{INHERITS}	return INHERITS;
{ISVOID}	return ISVOID;
{LET}     	return LET;
{LOOP}    	return LOOP;
{POOL}    	return POOL;
{THEN}    	return THEN;
{WHILE}	    return WHILE;
{CASE}	    return CASE;
{ESAC}  	return ESAC;
{NEW}   	return NEW;
{OF}    	return OF;
{NOT}   	return NOT;
{DARROW}	return DARROW;
{LE}		return LE;
{ASSIGN}	return ASSIGN;

{TRUE} {
    cool_yylval.boolean = 1;
    return BOOL_CONST;
}

{FALSE} {
    cool_yylval.boolean = 0;
    return BOOL_CONST;
}


{TYPE_ID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}

{OBJECT_ID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}

\n line_number++;

[[:space:]] ;


[:+\-*/=)(}{~.,;<@] {
    return int(yytext[0]);
}

[[:digit:]]+ {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}


-- BEGIN SINGLE_LINE_COMMENT;

\*\) {
    cool_yylval.error_msg = "Mismatched *)";
    return ERROR;
}

\(\* {
    comment_depth++;
    BEGIN MULTILINE_COMMENT;
}

\"	{
    BEGIN STRING;
    current_string = new char[1];
    current_string[0] = '\0';
    is_null_in_string = false;
}

. {
    cool_yylval.error_msg = yytext;
    return ERROR;
}

<SINGLE_LINE_COMMENT>\n {
    line_number++;
    BEGIN INITIAL;
}

<SINGLE_LINE_COMMENT><<EOF>> BEGIN INITIAL;

<SINGLE_LINE_COMMENT>. ;

<MULTILINE_COMMENT>"(*" comment_depth++;

<MULTILINE_COMMENT>"*)" {
    comment_depth--;

    if (comment_depth == 0) {
       BEGIN INITIAL;
    }
}

<MULTILINE_COMMENT>\n line_number++;

<MULTILINE_COMMENT><<EOF>> {
    BEGIN INITIAL;
    cool_yylval.error_msg = "EOF in comment";
    return ERROR;
}

<MULTILINE_COMMENT>. ;

<STRING>\"	{
    BEGIN INITIAL;

    if (strlen(current_string) >= MAX_STR_CONST) {
        cool_yylval.error_msg = "String constant too long";
	    return ERROR;
    }

    if (is_null_in_string) {
       cool_yylval.error_msg = "String contains null character";
       return ERROR;
    }

    cool_yylval.symbol = stringtable.add_string(current_string);

    return STR_CONST;
}

<STRING>\\\n current_string = append_character(current_string, '\n');

<STRING>\n {
    BEGIN INITIAL;
    line_number++;
    cool_yylval.error_msg = "Unterminated string constant";
    return ERROR;
}

<STRING>\0 is_null_in_string = true;

<STRING>\\. {
    current_string= handle_string_character(current_string, yytext[1]);
}

<STRING><<EOF>> {
    BEGIN INITIAL;
    cool_yylval.error_msg = "EOF in string";
    return ERROR;
}

<STRING>. current_string = append_string(current_string, yytext);

%%

char* append_character(char* string, char c) {
    size_t old_length = strlen(string);

    char* result = new char[old_length + 2];

    strcpy(result, string);    
    result[old_length] = c;
    result[old_length + 1] = '\0';

    delete[] string;
    
    return result;
}

char* append_string(char* string, char* another_string) {
    size_t string_length = strlen(string);
    size_t another_length = strlen(another_string);

    char* result = new char[string_length + another_length + 1];

    strcpy(result, string);
    strcpy(result + string_length, another_string); 
   
    result[string_length + another_length] = '\0';

    delete[] string;
    //delete[] another_string;

    return result;
}

char* handle_string_character(char* current_string, char c) {
    switch (c) {
        case 'f':
	    current_string = append_character(current_string, '\f');
	    break;
	case 'b':
	    current_string = append_character(current_string, '\b');
	    break;
	case 't':
	    current_string = append_character(current_string, '\t');
	    break;
	case 'n':
	    current_string = append_character(current_string, '\n');
	    break;
	case '\0':
	    is_null_in_string = true;
	    break;
	default:
	    current_string = append_character(current_string, c);
    }

    return current_string;
}
