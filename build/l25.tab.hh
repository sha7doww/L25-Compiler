/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

#ifndef YY_YY_BUILD_L25_TAB_HH_INCLUDED
# define YY_YY_BUILD_L25_TAB_HH_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    PROGRAM = 258,                 /* PROGRAM  */
    STRUCT = 259,                  /* STRUCT  */
    FUNC = 260,                    /* FUNC  */
    MAIN = 261,                    /* MAIN  */
    RETURN = 262,                  /* RETURN  */
    LET = 263,                     /* LET  */
    INT = 264,                     /* INT  */
    BOOL = 265,                    /* BOOL  */
    CHAR = 266,                    /* CHAR  */
    VOID = 267,                    /* VOID  */
    FLOAT = 268,                   /* FLOAT  */
    STRING = 269,                  /* STRING  */
    IF = 270,                      /* IF  */
    ELSE = 271,                    /* ELSE  */
    WHILE = 272,                   /* WHILE  */
    EQ = 273,                      /* EQ  */
    NEQ = 274,                     /* NEQ  */
    LE = 275,                      /* LE  */
    GE = 276,                      /* GE  */
    AND = 277,                     /* AND  */
    OR = 278,                      /* OR  */
    LSH = 279,                     /* LSH  */
    RSH = 280,                     /* RSH  */
    TRY = 281,                     /* TRY  */
    CATCH = 282,                   /* CATCH  */
    INPUT = 283,                   /* INPUT  */
    OUTPUT = 284,                  /* OUTPUT  */
    ALLOC = 285,                   /* ALLOC  */
    FREE = 286,                    /* FREE  */
    ARROW = 287,                   /* ARROW  */
    THIS = 288,                    /* THIS  */
    SIZEOF = 289,                  /* SIZEOF  */
    IDENT = 290,                   /* IDENT  */
    INT_CONST = 291,               /* INT_CONST  */
    BOOL_CONST = 292,              /* BOOL_CONST  */
    CHAR_CONST = 293,              /* CHAR_CONST  */
    VOID_CONST = 294,              /* VOID_CONST  */
    FLOAT_CONST = 295,             /* FLOAT_CONST  */
    STRING_CONST = 296,            /* STRING_CONST  */
    UNARY = 297                    /* UNARY  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{
#line 284 "source/l25.y"

    long long ival;
    double fval;
    char* sval;
    char cval;

#line 113 "build/l25.tab.hh"

};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif

/* Location type.  */
#if ! defined YYLTYPE && ! defined YYLTYPE_IS_DECLARED
typedef struct YYLTYPE YYLTYPE;
struct YYLTYPE
{
  int first_line;
  int first_column;
  int last_line;
  int last_column;
};
# define YYLTYPE_IS_DECLARED 1
# define YYLTYPE_IS_TRIVIAL 1
#endif


extern YYSTYPE yylval;
extern YYLTYPE yylloc;

int yyparse (void);


#endif /* !YY_YY_BUILD_L25_TAB_HH_INCLUDED  */
