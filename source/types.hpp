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

struct Code
{
    std::string op;
    long long val;
};


int emit(const std::string& op, long long val = 0);
int emitPre(const std::string& op, long long val = 0);

enum TypeKind
{
    TYPE_INT,
    TYPE_BOOL,
    TYPE_CHAR,
    TYPE_VOID,
    TYPE_FLOAT,
    TYPE_STRING,
    TYPE_AUTO, 
    TYPE_PTR,
    TYPE_ARR,
    TYPE_FUNC,
    TYPE_STRUCT
};
struct TypeInfo
{
    std::string name;
    TypeKind kind;
    int size, index;
};

void initBasicTypes();
struct StructDef
{
    struct Field
    {
        int type;
        int offset;
    };
    std::map<std::string, Field> field;
};
struct PtrDef
{
    int baseType;
};
struct ArrDef 
{
    int baseType;
    int length;
};
struct FuncDef
{
    int retType;
    std::vector<int> argType;
    int argSize;
};

int ptrType(int baseType);
int arrType(int baseType, int length);
int funcType(int retType, const std::vector<int>& argType);
int structType(const std::string& name);
void fixStructType(int type,
    const std::map<std::string, StructDef::Field>& field);
enum ScopeKind
{
    SCOPE_LOCAL,
    SCOPE_MEMBER,
    SCOPE_GLOBAL
};
struct Sym
{
    int type, addr;
    ScopeKind kind;
};


Sym& find(const std::string& id);
void declare(const std::string& id, int type, int addr, ScopeKind kind);

void unify(Sym &s, int realType);
std::string unescapeLiteral(const char *raw);

void generateCode();