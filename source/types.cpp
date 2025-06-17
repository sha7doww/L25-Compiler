

#include <bit>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <map>
#include <string>
#include <vector>
#include "types.hpp"



std::vector<TypeInfo> typeTable;
std::map<int, int> ptrTypeMap;
std::map<int, std::map<int, int>> arrTypeMap;
std::map<int, std::map<std::vector<int>, int>> funcTypeMap;
int TYPE_AUTO_ID = -1;

std::vector<PtrDef> ptrDef;
std::vector<ArrDef> arrDef;
std::vector<FuncDef> funcDef;
std::vector<StructDef> structDef;

int curLocal;
int entType, entAddr;
std::vector<int> paramStk;
std::vector<std::vector<int>> typeStk;
std::vector<std::map<std::string, StructDef::Field>> fieldStk;
std::vector<Sym*> calleeStk;   // 每遇到一次 func_call 入栈

std::vector<std::map<std::string, Sym>> scopes(1);
int preStk;
std::vector<int> codeStk;
std::vector<Code> code, codePre;


int emit(const std::string& op, long long val)
{
    int idx = code.size();
    code.push_back({op, val});
    return idx;
}
int emitPre(const std::string& op, long long val)
{
    int idx = preStk;
    codePre.push_back({op, val});
    if (op == "ADDSP")
        preStk += val;
    else
        preStk++;
    return idx;
}



void initBasicTypes()
{
    typeTable.push_back({"int", TYPE_INT, 1, -1});
    typeTable.push_back({"bool", TYPE_BOOL, 1, -1});
    typeTable.push_back({"char", TYPE_CHAR, 1, -1});
    typeTable.push_back({"void", TYPE_VOID, 0, -1});
    typeTable.push_back({"float", TYPE_FLOAT, 1, -1});
    typeTable.push_back({"string", TYPE_STRING, 256, -1});
    typeTable.push_back({"auto", TYPE_AUTO, 1, -1});
    TYPE_AUTO_ID = typeTable.size() - 1;   // 以后直接用
}


int ptrType(int baseType)
{
    if (ptrTypeMap.count(baseType))
        return ptrTypeMap[baseType];
    PtrDef def = {baseType};
    int ptrIdx = ptrDef.size();
    ptrDef.push_back(def);

    TypeInfo info =
    {
        typeTable[baseType].name + "*",
        TYPE_PTR,
        1,
        ptrIdx
    };
    int type = typeTable.size();
    typeTable.push_back(info);
    return ptrTypeMap[baseType] = type;
}
int arrType(int baseType, int length)
{
    if (arrTypeMap.count(baseType) && arrTypeMap[baseType].count(length))
        return arrTypeMap[baseType][length];
    ArrDef def = {baseType, length};
    int arrIdx = arrDef.size();
    arrDef.push_back(def);

    TypeInfo info =
    {
        typeTable[baseType].name + "[" + std::to_string(length) + "]",
        TYPE_ARR,
        typeTable[baseType].size * length,
        arrIdx
    };
    int type = typeTable.size();
    typeTable.push_back(info);
    return arrTypeMap[baseType][length] = type;
}
int funcType(int retType, const std::vector<int>& argType)
{
    if (funcTypeMap.count(retType) && funcTypeMap[retType].count(argType))
        return funcTypeMap[retType][argType];
    FuncDef def = {retType, argType, 0};
    for (int type: argType)
        def.argSize += typeTable[type].size;
    int funcIdx = funcDef.size();
    funcDef.push_back(def);

    std::string name = typeTable[retType].name + "(";
    for (int type: argType)
        name += typeTable[type].name + ", ";
    if (!argType.empty())
        name.pop_back(), name.pop_back();
    name += ")";

    TypeInfo info = {name, TYPE_FUNC, 1, funcIdx};
    int type = typeTable.size();
    typeTable.push_back(info);
    return funcTypeMap[retType][argType] = type;
}
int structType(const std::string& name)
{
    TypeInfo info = {"struct " + name, TYPE_STRUCT, 0, 0};
    int type = typeTable.size();
    typeTable.push_back(info);
    return type;
}
void fixStructType(int type,
    const std::map<std::string, StructDef::Field>& field)
{
    StructDef def = {field};
    int structIdx = structDef.size();
    structDef.push_back(def);

    int size = 0;
    for (auto& [_, f]: structDef.back().field)
        f.offset = size, size += typeTable[f.type].size;

    typeTable[type].size = size;
    typeTable[type].index = structIdx;
}

Sym& find(const std::string& id)
{
    for (int i = scopes.size(); i--;)
        if (scopes[i].count(id))
            return scopes[i][id];
    yyerror(("syntax error, " + id + " is undeclared").c_str());
    exit(1);
}
void declare(const std::string& id, int type, int addr, ScopeKind kind)
{
    if (scopes.back().count(id))
    {
        yyerror(("syntax error, " + id + " is redeclared").c_str());
        exit(1);
    }
    scopes.back()[id] = {type, addr, kind};
}

void unify(Sym &s, int realType)
{
    if (s.type == TYPE_AUTO_ID) {
        s.type = realType;
        for (auto &vec : typeStk)
            for (int &t : vec)
                if (t == TYPE_AUTO_ID) t = realType;
    }
}

std::string unescapeLiteral(const char *raw)
{
    int len = strlen(raw);
    std::string out;
    out.reserve(len > 2 ? len - 2 : 0);
    for (int i = 1; i + 1 < len; ++i) {
        if (raw[i] == '\\' && i + 1 + 1 < len) {
            switch (raw[i + 1]) {
                case 'n':
                    out.push_back('\n');
                    break;
                case 't':
                    out.push_back('\t');
                    break;
                case '\\':
                    out.push_back('\\');
                    break;
                case '"':
                    out.push_back('"');
                    break;
                default:
                    out.push_back(raw[i + 1]);
            }
            i++;
        } else {
            out.push_back(raw[i]);
        }
    }
    return out;
}

void generateCode()
{
    for (const auto& [op, val] : codePre)
        if (op == "PUSH")
            std::cout << op << " " << val + codePre.size() << std::endl;
        else
            std::cout << op << " " << val << std::endl;
    for (const auto& [op, val] : code)
        if (op == "JMP" || op == "JPC" || op == "PUSHE")
            std::cout << op << " " << val + codePre.size() << std::endl;
        else
            std::cout << op << " " << val << std::endl;
    return;
}