#ifndef PCODE_HPP
#define PCODE_HPP

#ifndef YYLTYPE_IS_DECLARED
#define YYLTYPE_IS_DECLARED 1
typedef struct YYLTYPE {
    int first_line;
    int first_column;
    int last_line;
    int last_column;
} YYLTYPE;
#endif

extern YYLTYPE yylloc;
int yylex();
void yyerror(const char*);
void yyerror(YYLTYPE* yylloc, const char*);

#include <bit>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <map>
#include <string>
#include <vector>

struct Code {
    std::string op;
    long long val;
};

int preStk;
std::vector<int> codeStk;
std::vector<Code> code, codePre;

int emit(const std::string& op, long long val = 0) {
    int idx = code.size();
    code.push_back({op, val});
    return idx;
}
int emitPre(const std::string& op, long long val = 0) {
    int idx = preStk;
    codePre.push_back({op, val});
    if (op == "ADDSP")
        preStk += val;
    else
        preStk++;
    return idx;
}

#endif