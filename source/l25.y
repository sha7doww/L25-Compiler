%locations
%define parse.error verbose

%{

#include <bit>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <map>
#include <string>
#include <vector>
#include "types.hpp"

extern std::vector<TypeInfo> typeTable;
extern std::map<int, int> ptrTypeMap;
extern std::map<int, std::map<int, int>> arrTypeMap;
extern std::map<int, std::map<std::vector<int>, int>> funcTypeMap;
extern int TYPE_AUTO_ID;

extern std::vector<PtrDef> ptrDef;
extern std::vector<ArrDef> arrDef;
extern std::vector<FuncDef> funcDef;
extern std::vector<StructDef> structDef;

extern int curLocal;
extern int entType, entAddr;
extern std::vector<int> paramStk;
extern std::vector<std::vector<int>> typeStk;
extern std::vector<std::map<std::string, StructDef::Field>> fieldStk;
extern std::vector<Sym*> calleeStk;   // 每遇到一次 func_call 入栈

extern std::vector<std::map<std::string, Sym>> scopes;
extern int preStk;
extern std::vector<int> codeStk;
extern std::vector<Code> code, codePre;

%}

%union
{
    long long ival;
    double fval;
    char* sval;
    char cval;
}

%token PROGRAM STRUCT FUNC MAIN RETURN
%token LET INT BOOL CHAR VOID FLOAT STRING
%token IF ELSE WHILE EQ NEQ LE GE AND OR LSH RSH
%token TRY CATCH INPUT OUTPUT ALLOC FREE ARROW THIS SIZEOF

%token <sval> IDENT
%token <ival> INT_CONST
%token <ival> BOOL_CONST
%token <cval> CHAR_CONST
%token VOID_CONST
%token <fval> FLOAT_CONST
%token <sval> STRING_CONST
%type <ival> type_spec func_call alloc_call
%type <ival> const_expr left_expr right_expr compare_expr
%type <ival> bitwise_expr bitwise_term arith_expr arith_term factor
%type <ival> return_type_opt

%nonassoc '='
%left AND OR
%nonassoc '<' '>' LE GE EQ NEQ
%left '&' '|' '^'
%left LSH RSH
%left '+' '-' 
%left '*' '/' 
%right UNARY
%left '[' '.' ARROW

%%

program
:   PROGRAM IDENT '{'
    {
        initBasicTypes();

        int jmp = emit("JMP");
        codeStk.push_back(jmp);
    }
    global_list_opt MAIN '{'
    {
        int jmp = codeStk.back();
        codeStk.pop_back();
        code[jmp].val = code.size();
        
        scopes.push_back({});

        curLocal = 0;
        
        emit("PUSHFP");
        emit("MOVFP");
        int addsp = emit("ADDSP");
        codeStk.push_back(addsp);
    }
    stmt_list '}' '}'
    {
        scopes.pop_back();

        int addsp = codeStk.back();
        codeStk.pop_back();
        code[addsp].val = curLocal;

        emit("ADDSP", -curLocal);
        emit("POPFP");

        generateCode();
        exit(0);
    }
;

global_list_opt
:   /* epsilon */ {}
|   global_list_opt declare_def
|   global_list_opt struct_def
|   global_list_opt func_def
;

declare_def
:   LET IDENT
    {
        declare($2, TYPE_AUTO_ID,
            emitPre("ADDSP", 1), SCOPE_GLOBAL);
    }
|   LET IDENT ':' type_spec
    {
        declare($2, $4,
            emitPre("ADDSP", typeTable[$4].size), SCOPE_GLOBAL);
    }
;

struct_def
:   STRUCT IDENT '{'
    {
        entType = structType($2);
        declare($2, entType, 0, SCOPE_GLOBAL);

        scopes.push_back({});

        fieldStk.push_back({});
    }
    field_list_opt '}'
    {
        fixStructType(entType, fieldStk.back());
        entType = TYPE_VOID;

        scopes.pop_back();

        fieldStk.pop_back();
    }
;

field_list_opt
:   /* epsilon */ {}
|   field_list
;

field_list
:   field_def
|   field_list field_def
;

field_def
:   IDENT ':' type_spec ';'
    {
        if ($3 == entType)
        {
            yyerror(("syntax error, expected complete type, "
                     "found \"" + typeTable[$3].name + "\"").c_str());
            exit(1);
        }
        declare($1, $3, 0, SCOPE_LOCAL);
        fieldStk.back()[$1] = {int($3), -1};
    }
;

func_def
:   FUNC IDENT '('
    {
        scopes.push_back({});

        curLocal = 0;

        typeStk.push_back({});

        entAddr = emitPre("PUSH", code.size());

    }
    arg_list_opt ')' return_type_opt          
    {
        
        entType = $7;   

        int protoRet = (entType == -1 ? TYPE_AUTO_ID : entType);
        int protoType = funcType(protoRet, typeStk.back());
        declare($2, protoType, entAddr, SCOPE_GLOBAL);             

        
        emit("PUSHFP"); emit("MOVFP");
        int addsp = emit("ADDSP");
        codeStk.push_back(addsp);

        
        int argSize = 0;
        for (int t : typeStk.back()) argSize += typeTable[t].size;
        for (auto& [name, s] : scopes.back())
            if (name != $2) s.addr -= 2 + argSize;
    }
    '{'
    stmt_list RETURN right_expr ';'
    {
        
        int retType = (entType == -1 ? $12 : entType);   
        if (entType != -1 && entType != $12 && !(entType == TYPE_AUTO || $12 == TYPE_AUTO)) {
            yyerror(("syntax error, expected \"" +
                    typeTable[entType].name + "\", found \"" +
                    typeTable[$12].name + "\"").c_str());
            exit(1);
        }

        
        scopes.pop_back();
        int addsp = codeStk.back(); codeStk.pop_back();
        code[addsp].val = curLocal;

        /* new: 所有形参必须已推断完成 */
        // for (int t : typeStk.back())
        //     if (t == TYPE_AUTO_ID) {
        //         yyerror("cannot infer parameter type");
        //         exit(1);
        //     }
        int fType = funcType(retType, typeStk.back());
        declare($2, fType, entAddr, SCOPE_GLOBAL);

        
        for (int i = 0; i < typeTable[retType].size; i++) {
            emit("PADDRL", -3 - funcDef[typeTable[fType].index].argSize - i);
            emit("SWAP", 1); emit("STR");
        }

        emit("ADDSP", -curLocal);
        emit("POPFP"); emit("RET");

        typeStk.pop_back();
    }
    '}'
;

arg_list_opt
:   /* epsilon */ {}
|   arg_list
;

return_type_opt
    : ':' type_spec   { $$ = $2; }
    |                 { $$ = -1;   }
;

arg_list
:   arg_def
|   arg_list ',' arg_def
;

arg_def
:   IDENT ':' type_spec
    {
        declare($1, $3, curLocal, SCOPE_LOCAL);
        curLocal += typeTable[$3].size;
        typeStk.back().push_back($3);
    }
| IDENT                /* 省略类型，待推断 */
    {
        declare($1, TYPE_AUTO_ID, curLocal, SCOPE_LOCAL);
        curLocal += 1;                      // 先占 1 word
        typeStk.back().push_back(TYPE_AUTO_ID);
    }
;

type_spec
:   INT
    {
        $$ = TYPE_INT;
    }
|   BOOL
    {
        $$ = TYPE_BOOL;
    }
|   CHAR
    {
        $$ = TYPE_CHAR;
    }
|   VOID
    {
        $$ = TYPE_VOID;
    }
|   FLOAT
    {
        $$ = TYPE_FLOAT;
    }
|   STRING
    {
        $$ = TYPE_STRING;
    }
|   STRUCT IDENT
    {
        Sym& s = find($2);
        if (typeTable[s.type].kind != TYPE_STRUCT)
        {
            yyerror(("syntax error, expected struct type, "
                     "found \"" + typeTable[s.type].name + "\"").c_str());
            exit(1);
        }
        $$ = s.type;
    }
|   type_spec '*'
    {
        $$ = ptrType($1);
    }
|   type_spec '[' INT_CONST ']'
    {
        $$ = arrType($1, $3);
    }
|   FUNC type_spec '('
    {
        typeStk.push_back({});
    }
    type_spec_list_opt ')'
    {
        $$ = funcType($2, typeStk.back());
        typeStk.pop_back();
    }
;

type_spec_list_opt
:   /* epsilon */ {}
|   type_spec_list
;

type_spec_list
:   type_spec
    {
        typeStk.back().push_back($1);
    }
|   type_spec_list ',' type_spec
    {
        typeStk.back().push_back($3);
    }
|   THIS
    {
        typeStk.back().push_back(ptrType(entType));
    }
;

stmt_list
:   stmt ';'
|   stmt_list stmt ';'
|   '{'
    {
        scopes.push_back({});
    }
    stmt_list '}' ';'
    {
        scopes.pop_back();
    }
|   stmt_list '{'
    {
        scopes.push_back({});
    }
    stmt_list '}' ';'
    {
        scopes.pop_back();
    }
;

stmt
:   declare_stmt
|   assign_stmt
|   if_stmt
|   while_stmt
|   try_catch_stmt
|   func_call
    {
        emit("ADDSP", -typeTable[$1].size);
    }
|   input_call
|   output_call
|   alloc_call
    {
        emit("ADDSP", -typeTable[$1].size);
    }
|   free_call
;

declare_stmt
:   LET IDENT
    {
        declare($2, TYPE_AUTO_ID, curLocal, SCOPE_LOCAL);
        curLocal += 1;  // 先占 1 word
    }

|   LET IDENT ':' type_spec
    {
        declare($2, $4, curLocal, SCOPE_LOCAL);
        curLocal += typeTable[$4].size;
    }
|   LET IDENT ':' type_spec '=' right_expr
    {
        
        if (!($6 == TYPE_AUTO || $4 == TYPE_AUTO) && $4 != $6)
        {
            yyerror(("syntax error, type dismatch, expected \"" +
                     typeTable[$4].name + "\", found \"" +
                     typeTable[$6].name + "\"").c_str());
            exit(1);
        }
        declare($2, $4, curLocal, SCOPE_LOCAL);
        for (int i = typeTable[$4].size; i--;)
        {
            emit("PADDRL", curLocal + i);
            emit("SWAP", 1);
            emit("STR");
        }
        curLocal += typeTable[$4].size;
    }
|   LET IDENT '=' right_expr
    {
        declare($2, $4, curLocal, SCOPE_LOCAL);
        for (int i = typeTable[$4].size; i--;)
        {
            emit("PADDRL", curLocal + i);
            emit("SWAP", 1);
            emit("STR");
        }
        curLocal += typeTable[$4].size;
    }
;

assign_stmt
:   left_expr '=' right_expr
    {
        if (!($1 == TYPE_AUTO || $3 == TYPE_AUTO) && $1 != $3)
        {
            yyerror(("syntax error, type dismatch, expected \"" +
                     typeTable[$1].name + "\", found \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
        if (typeTable[$3].size == 1)
            emit("STR");
        else
        {
            emit("PUSH");
            emit("SWAP", typeTable[$3].size + 1);
            for (int i = typeTable[$3].size; i--;)
            {
                emit("DUP");
                emit("SWAP", 2);
                emit("SWAP", 1);
                emit("PUSH", i);
                emit("ADD");
                emit("SWAP", 1);
                emit("STR");
            }
            emit("POP");
            emit("POP");
        }
    }
;

const_expr
:   INT_CONST
    {
        emit("PUSH", $1);
        $$ = TYPE_INT;
    }
|   BOOL_CONST
    {
        emit("PUSH", $1);
        $$ = TYPE_BOOL;
    }
|   CHAR_CONST
    {
        emit("PUSH", $1);
        $$ = TYPE_CHAR;
    }
|   VOID_CONST
    {
        $$ = TYPE_VOID;
    }
|   FLOAT_CONST
    {
        double f = $1;
        emit("PUSH", std::bit_cast<long long>(f));
        $$ = TYPE_FLOAT;
    }
|   STRING_CONST
    {
        std::string str = unescapeLiteral($1);
        for (int i = 0; i < 256; i++)
        {
            if (i < str.size())
                emit("PUSH", str[i]);
            else
                emit("PUSH", 0);
        }
        $$ = TYPE_STRING;
    }
|   SIZEOF '(' type_spec ')'
    {
        emit("PUSH", typeTable[$3].size);
        $$ = TYPE_INT;
    }
;

left_expr
:   IDENT
    {
        Sym& s = find($1);
        // unify(s, s.type); /* 如果后面再推断会再次调用 */
        $$ = s.type;
        if (s.kind == SCOPE_LOCAL)
            emit("PADDRL", s.addr);
        else
            emit("PUSH", s.addr);
    }
|   '*' factor %prec UNARY
    {
        if (typeTable[$2].kind != TYPE_PTR)
        {
            yyerror(("syntax error, indirection expected pointer type, "
                     "found \"" + typeTable[$2].name + "\"").c_str());
            exit(1);
        }
        int ptrIdx = typeTable[$2].index;
        $$ = ptrDef[ptrIdx].baseType;

    }
|   left_expr '[' right_expr ']'
    {
        if (typeTable[$3].kind != TYPE_INT)
        {
            yyerror(("syntax error, expected subscriptable type, "
                     "found \"" + typeTable[$3].name + "\"").c_str());
            exit(1);
        }
        if (typeTable[$1].kind == TYPE_PTR)
        {
            int ptrIdx = typeTable[$1].index;
            $$ = ptrDef[ptrIdx].baseType;
            emit("SWAP", 1);
            emit("LOD");
            emit("SWAP", 1);
            emit("PADDRA", typeTable[ptrDef[ptrIdx].baseType].size);
        }
        else if (typeTable[$1].kind == TYPE_ARR)
        {
            int arrIdx = typeTable[$1].index;
            $$ = arrDef[arrIdx].baseType;
            emit("PADDRA", typeTable[arrDef[arrIdx].baseType].size);
        }
        else if (typeTable[$1].kind == TYPE_STRING)
        {
            $$ = TYPE_CHAR;
            emit("PADDRA", 1);
        }
        else
        {
            yyerror(("syntax error, index access expected array-like type, "
                     "found \"" + typeTable[$1].name + "\"").c_str());
            exit(1);
        }
    }
|   left_expr '.' IDENT
    {
        if (typeTable[$1].kind != TYPE_STRUCT)
        {
            yyerror(("syntax error, field access expected struct type, "
                     "found \"" + typeTable[$1].name + "\"").c_str());
            exit(1);
        }
        int structIdx = typeTable[$1].index;
        auto it = structDef[structIdx].field.find($3);
        if (it == structDef[structIdx].field.end())
        {
            yyerror(("syntax error, struct \"" + typeTable[$1].name +
                     "\" has no field \"" + $3 + "\"").c_str());
            exit(1);
        }
        $$ = it->second.type;
        emit("PADDRF", it->second.offset);
    }
|   factor ARROW IDENT
    {
        if (typeTable[$1].kind != TYPE_PTR)
        {
            yyerror(("syntax error, indirection expected pointer type, "
                     "found \"" + typeTable[$1].name + "\"").c_str());
            exit(1);
        }
        int ptrIdx = typeTable[$1].index;
        int type = ptrDef[ptrIdx].baseType;
        if (typeTable[type].kind != TYPE_STRUCT)
        {
            yyerror(("syntax error, field access expected struct type, "
                     "found \"" + typeTable[type].name + "\"").c_str());
            exit(1);
        }
        int structIdx = typeTable[type].index;
        auto it = structDef[structIdx].field.find($3);
        if (it == structDef[structIdx].field.end())
        {
            yyerror(("syntax error, struct \"" + typeTable[$1].name +
                     "\" has no field \"" + $3 + "\"").c_str());
            exit(1);
        }
        $$ = it->second.type;
        emit("PADDRF", it->second.offset);
    }
;

right_expr
:   right_expr AND compare_expr
    {
        if ((typeTable[$1].kind == TYPE_BOOL
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_BOOL
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("ANDB");
            $$ = TYPE_BOOL;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" && \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   right_expr OR compare_expr
    {
        if ((typeTable[$1].kind == TYPE_BOOL
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_BOOL
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("ORB");
            $$ = TYPE_BOOL;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" || \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   compare_expr
    {
        $$ = $1;
    }
;

compare_expr
:   bitwise_expr '<' bitwise_expr
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("LT");
            $$ = TYPE_BOOL;
        }
        else if (typeTable[$1].kind == TYPE_FLOAT &&
                 typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("LTF");
            $$ = TYPE_BOOL;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" < \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   bitwise_expr '>' bitwise_expr
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("GT");
            $$ = TYPE_BOOL;
        }
        else if (typeTable[$1].kind == TYPE_FLOAT &&
                 typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("GTF");
            $$ = TYPE_BOOL;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" > \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   bitwise_expr LE bitwise_expr
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("LE");
            $$ = TYPE_BOOL;
        }
        else if (typeTable[$1].kind == TYPE_FLOAT &&
                 typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("LEF");
            $$ = TYPE_BOOL;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" <= \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   bitwise_expr GE bitwise_expr
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("GE");
            $$ = TYPE_BOOL;
        }
        else if (typeTable[$1].kind == TYPE_FLOAT &&
                 typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("GEF");
            $$ = TYPE_BOOL;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" >= \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   bitwise_expr EQ bitwise_expr
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("EQ");
            $$ = TYPE_BOOL;
        }
        else if (typeTable[$1].kind == TYPE_FLOAT &&
                 typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("EQF");
            $$ = TYPE_BOOL;
        }
        else if (typeTable[$1].kind == TYPE_PTR &&
                 typeTable[$3].kind == TYPE_PTR && $1 == $3)
        {
            emit("EQ");
            $$ = TYPE_BOOL;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" == \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   bitwise_expr NEQ bitwise_expr
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("NEQ");
            $$ = TYPE_BOOL;
        }
        else if (typeTable[$1].kind == TYPE_FLOAT &&
                 typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("NEQF");
            $$ = TYPE_BOOL;
        }
        else if (typeTable[$1].kind == TYPE_PTR &&
                 typeTable[$3].kind == TYPE_PTR && $1 == $3)
        {
            emit("NEQ");
            $$ = TYPE_BOOL;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" != \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   bitwise_expr
    {
        $$ = $1;
    }
;

bitwise_expr
:   bitwise_expr '&' bitwise_term
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("AND");
            $$ = TYPE_INT;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" & \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   bitwise_expr '|' bitwise_term
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("OR");
            $$ = TYPE_INT;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" | \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   bitwise_expr '^' bitwise_term
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("XOR");
            $$ = TYPE_INT;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" ^ \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   bitwise_term
    {
        $$ = $1;
    }
;

bitwise_term
:   bitwise_term LSH arith_expr
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("LSH");
            $$ = TYPE_INT;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" << \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   bitwise_term RSH arith_expr
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("RSH");
            $$ = TYPE_INT;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" >> \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   arith_expr
    {
        $$ = $1;
    }
;

arith_expr
:   arith_expr '+' arith_term
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("ADD");
            $$ = TYPE_INT;
        }
        else if (typeTable[$1].kind == TYPE_FLOAT &&
                 typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("ADDF");
            $$ = TYPE_FLOAT;
        }
        else if (typeTable[$1].kind == TYPE_PTR &&
                 typeTable[$3].kind == TYPE_INT)
        {
            emit("PUSH",
                 typeTable[ptrDef[typeTable[$1].index].baseType].size);
            emit("MUL");
            emit("ADD");
            $$ = $1;
        }
        else if (typeTable[$3].kind == TYPE_PTR &&
                 typeTable[$1].kind == TYPE_INT)
        {
            emit("SWAP", 1);
            emit("PUSH",
                 typeTable[ptrDef[typeTable[$3].index].baseType].size);
            emit("MUL");
            emit("ADD");
            $$ = $3;
        }
        else if (typeTable[$1].kind == TYPE_STRING &&
                 typeTable[$3].kind == TYPE_STRING)
        {
            emit("ADDS");
            $$ = TYPE_STRING;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" + \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   arith_expr '-' arith_term
    {

        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("SUB");
            $$ = TYPE_INT;
        }
        else if (typeTable[$1].kind == TYPE_FLOAT &&
                 typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("SUBF");
            $$ = TYPE_FLOAT;
        }
        else if (typeTable[$1].kind == TYPE_PTR &&
                 typeTable[$3].kind == TYPE_INT)
        {
            emit("PUSH",
                 typeTable[ptrDef[typeTable[$1].index].baseType].size);
            emit("MUL");
            emit("SUB");
            $$ = $1;
        }
        else if (typeTable[$3].kind == TYPE_PTR &&
                 typeTable[$1].kind == TYPE_INT)
        {
            emit("PUSH",
                 typeTable[ptrDef[typeTable[$3].index].baseType].size);
            emit("MUL");
            emit("SUB");
            $$ = $3;
        }
        else if (typeTable[$1].kind == TYPE_PTR &&
                 typeTable[$3].kind == TYPE_PTR)
        {
            emit("SUB");
            $$ = TYPE_INT;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" - \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   arith_term
    {
        $$ = $1;
    }
;

arith_term
:   arith_term '*' factor
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("MUL");
            $$ = TYPE_INT;
        }
        else if (typeTable[$1].kind == TYPE_FLOAT &&
                 typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("MULF");
            $$ = TYPE_FLOAT;
        }
        else if (typeTable[$1].kind == TYPE_STRING &&
                 typeTable[$3].kind == TYPE_INT)
        {
            emit("MULS");
            $$ = TYPE_STRING;
        }
        else if (typeTable[$1].kind == TYPE_INT &&
                 typeTable[$3].kind == TYPE_STRING)
        {
            emit("SWAP", 1);
            emit("MULS");
            $$ = TYPE_STRING;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" * \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   arith_term '/' factor
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("DIV");
            $$ = TYPE_INT;
        }
        else if (typeTable[$1].kind == TYPE_FLOAT &&
                 typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("DIVF");
            $$ = TYPE_FLOAT;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" / \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   arith_term '%' factor
    {
        if ((typeTable[$1].kind == TYPE_INT
            || typeTable[$1].kind == TYPE_AUTO) &&
           (typeTable[$3].kind == TYPE_INT
            || typeTable[$3].kind == TYPE_AUTO))
        {
            emit("MOD");
            $$ = TYPE_INT;
        }
        else
        {
            yyerror(("syntax error, type dismatch, \"" +
                     typeTable[$1].name + "\" % \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
|   factor
    {
        $$ = $1;
    }
;

factor
:   left_expr
    {
        if (typeTable[$1].size == 1)
            emit("LOD", 0);
        else
        {
            emit("ADDSP", typeTable[$1].size);
            emit("PUSH");
            emit("SWAP", typeTable[$1].size + 1);
            for (int i = 0; i < typeTable[$1].size; i++)
            {
                emit("DUP");
                emit("PUSH", i);
                emit("ADD");
                emit("LOD");
                emit("SWAP", typeTable[$1].size - i + 2);
                emit("POP");
            }
            emit("POP");
            emit("POP");
        }
        $$ = $1;
    }
|   const_expr
    {
        $$ = $1;
    }
|   '(' right_expr ')'
    {
        $$ = $2;
    }
|   type_spec '(' right_expr ')'
    {
        if ($3 == $1)
            ;
        else if (typeTable[$3].kind == TYPE_INT &&
                 typeTable[$1].kind == TYPE_FLOAT)
        {
            emit("I2F");
        }
        else if (typeTable[$3].kind == TYPE_FLOAT &&
                 typeTable[$1].kind == TYPE_INT)
        {
            emit("F2I");
        }
        else if (typeTable[$3].kind == TYPE_INT &&
                 typeTable[$1].kind == TYPE_BOOL)
        {
            emit("I2B");
        }
        else if (typeTable[$3].kind == TYPE_BOOL &&
                 typeTable[$1].kind == TYPE_INT)
        {
            emit("B2I");
        }
        else if (typeTable[$3].kind == TYPE_INT &&
                 typeTable[$1].kind == TYPE_CHAR)
        {
            emit("I2C");
        }
        else if (typeTable[$3].kind == TYPE_CHAR &&
                 typeTable[$1].kind == TYPE_INT)
        {
            emit("C2I");
        }
        else if (typeTable[$3].kind == TYPE_FLOAT &&
                 typeTable[$1].kind == TYPE_BOOL)
        {
            emit("F2B");
        }
        else if (typeTable[$3].kind == TYPE_BOOL &&
                 typeTable[$1].kind == TYPE_FLOAT)
        {
            emit("B2F");
        }
        else if (typeTable[$3].kind == TYPE_FLOAT &&
                 typeTable[$1].kind == TYPE_CHAR)
        {
            emit("F2I");
            emit("I2C");
        }
        else if (typeTable[$3].kind == TYPE_CHAR &&
                 typeTable[$1].kind == TYPE_FLOAT)
        {
            emit("C2I");
            emit("I2F");
        }
        else if (typeTable[$3].kind == TYPE_CHAR &&
                 typeTable[$1].kind == TYPE_BOOL)
        {
            emit("C2I");
            emit("I2B");
        }
        else if (typeTable[$3].kind == TYPE_BOOL &&
                 typeTable[$1].kind == TYPE_CHAR)
        {
            emit("B2I");
            emit("I2C");
        }
        else if (typeTable[$3].kind == TYPE_PTR &&
                 typeTable[$1].kind == TYPE_PTR)
            ;
        else if (typeTable[$3].kind == TYPE_VOID &&
                 typeTable[$1].kind == TYPE_PTR)
        {
            emit("PUSH");
        }
        else
        {
            yyerror(("syntax error, unsupported cast from \"" +
                     typeTable[$3].name + "\" to \"" +
                     typeTable[$1].name + "\"").c_str());
            exit(1);
        }
    }
|   func_call
    {
        $$ = $1;
    }
|   alloc_call
    {
        $$ = $1;
    }
|   '&' left_expr %prec UNARY
    {
        $$ = ptrType($2);
    }
|   '-' factor %prec UNARY
    {
        if (typeTable[$2].kind == TYPE_INT)
            emit("NEG");
        else if (typeTable[$2].kind == TYPE_FLOAT)
            emit("NEGF");
        else
        {
            yyerror(("syntax error, type dismatch, -\"" +
                     typeTable[$2].name + "\"").c_str());
            exit(1);
        }
        $$ = $2;
    }
|   '+' factor %prec UNARY
    {
        if (typeTable[$2].kind == TYPE_INT)
            ;
        else if (typeTable[$2].kind == TYPE_FLOAT)
            ;
        else
        {
            yyerror(("syntax error, type dismatch, +\"" +
                     typeTable[$2].name + "\"").c_str());
            exit(1);
        }
        $$ = $2;
    }
|   '~' factor %prec UNARY
    {
        if (typeTable[$2].kind == TYPE_INT)
            emit("COMPL");
        else
        {
            yyerror(("syntax error, type dismatch, ~\"" +
                     typeTable[$2].name + "\"").c_str());
            exit(1);
        }
        $$ = $2;
    }
|   '!' factor %prec UNARY
    {
        if (typeTable[$2].kind == TYPE_BOOL)
        {
            emit("PUSH", 1);
            emit("SUB");
            $$ = TYPE_BOOL;
        }
        else
        {
            yyerror(("syntax error, type dismatch, !\"" +
                     typeTable[$2].name + "\"").c_str());
            exit(1);
        }
        $$ = $2;
    }
;

if_stmt
:   IF '(' right_expr ')' '{'
    {
        int jpc = emit("JPC");
        codeStk.push_back(jpc);

        scopes.push_back({});
    }
    stmt_list '}'
    {
        scopes.pop_back();
    }
    else_opt
;

else_opt
:   /* epsilon */
    {
        int jpc = codeStk.back();
        codeStk.pop_back();
        code[jpc].val = code.size();
    }
|   ELSE '{'
    {   
        int jpc = codeStk.back();
        codeStk.pop_back();

        int jmp = emit("JMP");

        code[jpc].val = code.size();

        codeStk.push_back(jmp);

        scopes.push_back({});
    }
    stmt_list '}'
    {
        scopes.pop_back();

        int jmp = codeStk.back();
        codeStk.pop_back();
        code[jmp].val = code.size();
    }
;

while_stmt
:   WHILE '('
    {
        int top = code.size();
        codeStk.push_back(top);
    }
    right_expr ')' '{'
    {
        int jpc = emit("JPC");
        codeStk.push_back(jpc);

        scopes.push_back({});
    }
    stmt_list '}'
    {
        scopes.pop_back();

        int jpc = codeStk.back();
        codeStk.pop_back();

        int top = codeStk.back();
        codeStk.pop_back();

        emit("JMP", top);
        code[jpc].val = code.size();
    }
;

try_catch_stmt
:   TRY '{'
    {
        int pushe = emit("PUSHE");
        codeStk.push_back(pushe);

        scopes.push_back({});
    }
    stmt_list '}'
    {
        scopes.pop_back();
    }
    CATCH '{'
    {
        emit("POPE");
        
        int jmp = emit("JMP");

        int pushe = codeStk.back();
        codeStk.pop_back();
        code[pushe].val = code.size();

        codeStk.push_back(jmp);

        scopes.push_back({});
    }
    stmt_list '}'
    {   
        scopes.pop_back();

        int jmp = codeStk.back();
        codeStk.pop_back();
        code[jmp].val = code.size();
    }
;

func_call
:   IDENT '('
    {
        Sym* f = &find($1);
        calleeStk.push_back(f);
        Sym& s = find($1);
        if (typeTable[s.type].kind != TYPE_FUNC)
        {
            yyerror(("syntax error, expected function type, "
                     "found \"" + typeTable[s.type].name + "\"").c_str());
            exit(1);
        }

        paramStk.push_back(0);
        typeStk.push_back(funcDef[typeTable[s.type].index].argType);

        emit("ADDSP",
             typeTable[funcDef[typeTable[s.type].index].retType].size);
    }
    param_list_opt ')'
    {
        Sym& s = find($1);
        if (paramStk.back() < typeStk.back().size())
        {
            yyerror("syntax error, too few parameters");
            exit(1);
        }
        paramStk.pop_back();
        typeStk.pop_back();

        if (s.kind == SCOPE_LOCAL)
            emit("PADDRL", s.addr);
        else
            emit("PUSH", s.addr);
        emit("LOD");
        emit("CALL");
        emit("ADDSP", -funcDef[typeTable[s.type].index].argSize);
        $$ = funcDef[typeTable[s.type].index].retType;
    }
|   left_expr '.' IDENT '('
    {
        if (typeTable[$1].kind != TYPE_STRUCT)
        {
            yyerror(("syntax error, field access expected struct type, "
                     "found \"" + typeTable[$1].name + "\"").c_str());
            exit(1);
        }
        int structIdx = typeTable[$1].index;
        auto it = structDef[structIdx].field.find($3);
        if (it == structDef[structIdx].field.end())
        {
            yyerror(("syntax error, struct \"" + typeTable[$1].name +
                     "\" has no field \"" + $3 + "\"").c_str());
            exit(1);
        }
        emit("DUP");
        emit("PADDRF", it->second.offset);

        int retType = funcDef[typeTable[it->second.type].index].retType;

        paramStk.push_back(1);
        typeStk.push_back(funcDef[typeTable[it->second.type].index].argType);

        emit("ADDSP", typeTable[retType].size);
        emit("PUSH");
        emit("SWAP", typeTable[retType].size + 2);
    }
    param_list_opt ')'
    {
        int structIdx = typeTable[$1].index;
        auto it = structDef[structIdx].field.find($3);

        if (paramStk.back() < typeStk.back().size())
        {
            yyerror("syntax error, too few parameters");
            exit(1);
        }
        paramStk.pop_back();
        typeStk.pop_back();

        int retType = funcDef[typeTable[it->second.type].index].retType;

        emit("PUSH");
        emit("SWAP", typeTable[retType].size +
            funcDef[typeTable[it->second.type].index].argSize + 1);
        emit("LOD");
        emit("CALL");
        emit("ADDSP", -funcDef[typeTable[it->second.type].index].argSize);

        emit("PUSH");
        for (int i = 0; i < typeTable[retType].size; i++)
        {
            emit("SWAP", typeTable[retType].size - i);
            emit("SWAP", typeTable[retType].size - i + 2);
        }
        emit("POP");
        emit("POP");
        emit("POP");
        $$ = retType;
    }
|   factor ARROW IDENT '('
    {
        if (typeTable[$1].kind != TYPE_PTR)
        {
            yyerror(("syntax error, indirection expected pointer type, "
                     "found \"" + typeTable[$1].name + "\"").c_str());
            exit(1);
        }
        int ptrIdx = typeTable[$1].index;
        int type = ptrDef[ptrIdx].baseType;
        if (typeTable[type].kind != TYPE_STRUCT)
        {
            yyerror(("syntax error, field access expected struct type, "
                     "found \"" + typeTable[type].name + "\"").c_str());
            exit(1);
        }
        int structIdx = typeTable[type].index;
        auto it = structDef[structIdx].field.find($3);
        if (it == structDef[structIdx].field.end())
        {
            yyerror(("syntax error, struct \"" + typeTable[$1].name +
                     "\" has no field \"" + $3 + "\"").c_str());
            exit(1);
        }
        emit("DUP");
        emit("PADDRF", it->second.offset);

        int retType = funcDef[typeTable[it->second.type].index].retType;

        paramStk.push_back(1);
        typeStk.push_back(funcDef[typeTable[it->second.type].index].argType);

        emit("ADDSP", typeTable[retType].size);
        emit("PUSH");
        emit("SWAP", typeTable[retType].size + 2);
    }
    param_list_opt ')'
    {
        int ptrIdx = typeTable[$1].index;
        int type = ptrDef[ptrIdx].baseType;
        int structIdx = typeTable[type].index;
        auto it = structDef[structIdx].field.find($3);

        if (paramStk.back() < typeStk.back().size())
        {
            yyerror("syntax error, too few parameters");
            exit(1);
        }
        paramStk.pop_back();
        typeStk.pop_back();

        int retType = funcDef[typeTable[it->second.type].index].retType;

        emit("PUSH");
        emit("SWAP", typeTable[retType].size +
            funcDef[typeTable[it->second.type].index].argSize + 1);
        emit("LOD");
        emit("CALL");
        emit("ADDSP", -funcDef[typeTable[it->second.type].index].argSize);

        emit("PUSH");
        for (int i = 0; i < typeTable[retType].size; i++)
        {
            emit("SWAP", typeTable[retType].size - i);
            emit("SWAP", typeTable[retType].size - i + 2);
        }
        emit("POP");
        emit("POP");
        emit("POP");
        $$ = retType;
    }
;

param_list_opt
:   /* epsilon */ {}
|   param_list
;

param_list
:   right_expr
    {
        if (paramStk.back() >= typeStk.back().size())
        {
            yyerror("syntax error, too many parameters");
            exit(1);
        }
        int &formal = typeStk.back()[paramStk.back()];
        if (formal == TYPE_AUTO_ID) formal = $1;   /* 首次使用即锁定 */
        if ($1 != formal)
        {
            yyerror(("syntax error, expected \"" +
                     typeTable[typeStk.back()[paramStk.back()]].name +
                     "\", found \"" + typeTable[$1].name + "\"").c_str());
            exit(1);
        }
        paramStk.back()++;
        if (paramStk.back() == typeStk.back().size()) {
            // 所有实参已处理完 —— 更新函数原型
            Sym* f = calleeStk.back();
            int newProto = funcType(funcDef[typeTable[f->type].index].retType,
                                    typeStk.back());
            f->type = newProto;

            // 弹栈收尾
            calleeStk.pop_back();
            // paramStk.pop_back();
        }        
    }
|   param_list ',' right_expr
    {
        if (paramStk.back() >= typeStk.back().size())
        {
            yyerror("syntax error, too many parameters");
            exit(1);
        }
        int &formal = typeStk.back()[paramStk.back()];
        if (formal == TYPE_AUTO_ID) formal = $3;
        if ($3 != formal)
        {
            yyerror(("syntax error, expected \"" +
                     typeTable[typeStk.back()[paramStk.back()]].name +
                     "\", found \"" + typeTable[$3].name + "\"").c_str());
            exit(1);
        }
        paramStk.back()++;
        if (paramStk.back() == typeStk.back().size()) {
            // 所有实参已处理完 —— 更新函数原型
            Sym* f = calleeStk.back();
            int newProto = funcType(funcDef[typeTable[f->type].index].retType,
                                    typeStk.back());
            f->type = newProto;

            // 弹栈收尾
            calleeStk.pop_back();
            // paramStk.pop_back();
        }
    }
;

input_call
:   INPUT '(' in_arg_list ')'
;

in_arg_list
:   left_expr
    {
        if (typeTable[$1].kind == TYPE_INT || typeTable[$1].kind == TYPE_AUTO)
        {
            emit("SCAN");
            emit("STR");
        }
        else if (typeTable[$1].kind == TYPE_FLOAT)
        {
            emit("SCANF");
            emit("STR");
        }
        else if (typeTable[$1].kind == TYPE_CHAR)
        {
            emit("GET");
            emit("STR");
        }
        else if (typeTable[$1].kind == TYPE_STRING)
        {
            emit("GETS");
            emit("PUSH");
            emit("SWAP", 257);
            for (int i = 256; i--;)
            {
                emit("DUP");
                emit("SWAP", 2);
                emit("SWAP", 1);
                emit("PUSH", i);
                emit("ADD");
                emit("SWAP", 1);
                emit("STR");
            }
            emit("POP");
            emit("POP");
        }
        else {
            yyerror(("syntax error, unsupported input type \"" +
                     typeTable[$1].name + "\"").c_str());
            exit(1);
        }
    }
|   in_arg_list ',' left_expr
    {
        if (typeTable[$3].kind == TYPE_INT)
        {
            emit("SCAN");
            emit("STR");
        }
        else if (typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("SCANF");
            emit("STR");
        }
        else if (typeTable[$3].kind == TYPE_CHAR)
        {
            emit("GET");
            emit("STR");
        }
        else if (typeTable[$3].kind == TYPE_STRING)
        {
            emit("GETS");
            emit("PUSH");
            emit("SWAP", 257);
            for (int i = 256; i--;)
            {
                emit("DUP");
                emit("SWAP", 2);
                emit("SWAP", 1);
                emit("PUSH", i);
                emit("ADD");
                emit("SWAP", 1);
                emit("STR");
            }
            emit("POP");
            emit("POP");
        }
        else {
            yyerror(("syntax error, unsupported input type \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
;

output_call
:   OUTPUT '(' out_arg_list ')'
;

out_arg_list
:   right_expr
    {
        if (typeTable[$1].kind == TYPE_AUTO)
        {
            emit("PRINT");
        }
        else if (typeTable[$1].kind == TYPE_INT)
        {
            emit("PRINT");
        }
        else if (typeTable[$1].kind == TYPE_FLOAT)
        {
            emit("PRINTF");
        }
        else if (typeTable[$1].kind == TYPE_CHAR)
        {
            emit("PUT");
        }
        else if (typeTable[$1].kind == TYPE_STRING)
        {
            emit("PUTS");
        }
        else if (typeTable[$1].kind == TYPE_PTR &&
                 ptrDef[typeTable[$1].index].baseType == TYPE_VOID)
        {
            emit("PRINT");
        }
        else {
            yyerror(("syntax error, unsupported output type \"" +
                     typeTable[$1].name + "\"").c_str());
            exit(1);
        }
    }
|   out_arg_list ',' right_expr
    {
        if (typeTable[$3].kind == TYPE_AUTO)
        {
            emit("PRINT");
        }
        else if (typeTable[$3].kind == TYPE_INT)
        {
            emit("PRINT");
        }
        else if (typeTable[$3].kind == TYPE_FLOAT)
        {
            emit("PRINTF");
        }
        else if (typeTable[$3].kind == TYPE_CHAR)
        {
            emit("PUT");
        }
        else if (typeTable[$3].kind == TYPE_STRING)
        {
            emit("PUTS");
        }
        else if (typeTable[$3].kind == TYPE_PTR &&
                 ptrDef[typeTable[$3].index].baseType == TYPE_VOID)
        {
            emit("PRINT");
        }
        else {
            yyerror(("syntax error, unsupported output type \"" +
                     typeTable[$3].name + "\"").c_str());
            exit(1);
        }
    }
;

alloc_call
:   ALLOC '(' right_expr ')'
    {
        emit("ALLOC");
        $$ = ptrType(TYPE_VOID);
    }
;

free_call
:   FREE '(' right_expr ')'
    {
        emit("FREE");
    }
;

%%

void yyerror(const char* msg)
{
    return yyerror(&yylloc, msg);
}
void yyerror(YYLTYPE* yylloc, const char* msg)
{
    std::cerr << "Compile error at line " << yylloc->first_line
              << ", column " << yylloc->first_column << ": "
              <<  msg << std::endl;
}

int main()
{
    yyparse();
    return 0;
}
