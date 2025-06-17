%option noyywrap
%option yylineno

%{

#include "parser.tab.hh"
extern YYLTYPE yylloc;
static int yycolumn = 1;
void yyerror(const char*);

#include <cstdlib>
#include <cstring>
#include <string>

%}

%%

[\r\n]+  {
    yycolumn = 1;
    yylloc.first_line   = yylineno + 1;
    yylloc.first_column = 1;
    yylloc.last_line    = yylineno + 1;
    yylloc.last_column  = 1;
}
[ \t]+  {
    yycolumn += yyleng;
}

"program"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return PROGRAM;
}
"struct"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return STRUCT;
}
"func"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return FUNC;
}
"main"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return MAIN;
}
"return"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return RETURN;
}
"let"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return LET;
}
"int"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return INT;
}
"bool"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return BOOL;
}
"char"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return CHAR;
}
"void"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return VOID;
}
"float"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return FLOAT;
}
"string"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return STRING;
}
"if"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return IF;
}
"else"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return ELSE;
}
"while"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return WHILE;
}
"=="  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return EQ;
}
"!="  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return NEQ;
}
"<="  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return LE;
}
">="  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return GE;
}
"&&"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return AND;
}
"||"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return OR;
}
"<<"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return LSH;
}
">>"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return RSH;
}
"try"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return TRY;
}
"catch"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return CATCH;
}
"input"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return INPUT;
}
"output"  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return OUTPUT;
}

[0-9]+ {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    yylval.ival = atoi(yytext);
    return INT_CONST;
}
(true|false|TRUE|FALSE) {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    yylval.ival = strcmp(yytext, "true") == 0 || strcmp(yytext, "TRUE") == 0;
    return BOOL_CONST;
}
\'([^\\\'\n]|\\.)\' {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    char c;
    if (yytext[1] == '\\')
    {
        switch (yytext[2])
        {
            case 'n':
                c = '\n';
                break;
            case 't':
                c = '\t';
                break;
            case 'r':
                c = '\r';
                break;
            case '\\':
                c = '\\';
                break;
            case '\'':
                c = '\'';
                break;
            case '\"':
                c = '\"';
                break;
            case '0':
                c = '\0';
                break;
            default:
                c = yytext[2];
                break;
        }
    } else {
        c = yytext[1];
    }
    yylval.cval = c;
    return CHAR_CONST;
}
(null|NULL)  {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    return VOID_CONST;
}
([0-9]+\.[0-9]+([eE][-+]?[0-9]+)?)|([0-9]+[eE][-+]?[0-9]+) {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    yylval.fval = atof(yytext);
    return FLOAT_CONST;
}
\"([^\\\"]|\\.)*\" {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    yylval.sval = strdup(yytext);
    return STRING_CONST;
}

[a-zA-Z_][a-zA-Z0-9_]* {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    yylval.sval = strdup(yytext);
    return IDENT;
}
[+\-*/%&|^!=<>()\[\]{}.,:;] {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn;
    ++yycolumn;
    return yytext[0];
}

"//".* {
    yycolumn += yyleng;
}
. {
    yylloc.first_line   = yylineno;
    yylloc.first_column = yycolumn;
    yylloc.last_line    = yylineno;
    yylloc.last_column  = yycolumn + yyleng - 1;
    yycolumn += yyleng;
    yyerror(("Syntax Error: invalid character '" +
                std::string(yytext) + "'").c_str());
    exit(1);
}

%%
