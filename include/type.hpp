#ifndef TYPE_HPP
#define TYPE_HPP

#include "pcode.hpp"

enum TypeKind {
    TYPE_INT,
    TYPE_BOOL,
    TYPE_CHAR,
    TYPE_VOID,
    TYPE_FLOAT,
    TYPE_STRING,
    TYPE_AUTO,
    TYPE_ARR,
    TYPE_FUNC,
    TYPE_STRUCT
};
struct TypeInfo {
    std::string name;
    TypeKind kind;
    int size, index;
};

std::vector<TypeInfo> typeTable;
std::map<int, std::map<int, int>> arrTypeMap;
std::map<int, std::map<std::vector<int>, int>> funcTypeMap;
int TYPE_AUTO_ID = -1;

void initBasicTypes() {
    typeTable.push_back({"int", TYPE_INT, 1, -1});
    typeTable.push_back({"bool", TYPE_BOOL, 1, -1});
    typeTable.push_back({"char", TYPE_CHAR, 1, -1});
    typeTable.push_back({"void", TYPE_VOID, 0, -1});
    typeTable.push_back({"float", TYPE_FLOAT, 1, -1});
    typeTable.push_back({"string", TYPE_STRING, 256, -1});
    typeTable.push_back({"auto", TYPE_AUTO, 1, -1});
    TYPE_AUTO_ID = typeTable.size() - 1; // 以后直接用
}

struct StructDef {
    struct Field {
        int type;
        int offset;
    };
    std::map<std::string, Field> field;
};
struct ArrDef {
    int baseType;
    int length;
};
struct FuncDef {
    int retType;
    std::vector<int> argType;
    int argSize;
};

std::vector<ArrDef> arrDef;
std::vector<FuncDef> funcDef;
std::vector<StructDef> structDef;

int arrType(int baseType, int length) {
    if (arrTypeMap.count(baseType) && arrTypeMap[baseType].count(length))
        return arrTypeMap[baseType][length];
    ArrDef def = {baseType, length};
    int arrIdx = arrDef.size();
    arrDef.push_back(def);

    TypeInfo info = {typeTable[baseType].name + "[" + std::to_string(length) + "]",
                     TYPE_ARR, typeTable[baseType].size * length, arrIdx};
    int type = typeTable.size();
    typeTable.push_back(info);
    return arrTypeMap[baseType][length] = type;
}
int funcType(int retType, const std::vector<int>& argType) {
    if (funcTypeMap.count(retType) && funcTypeMap[retType].count(argType))
        return funcTypeMap[retType][argType];
    FuncDef def = {retType, argType, 0};
    for (int type : argType)
        def.argSize += typeTable[type].size;
    int funcIdx = funcDef.size();
    funcDef.push_back(def);

    std::string name = typeTable[retType].name + "(";
    for (int type : argType)
        name += typeTable[type].name + ", ";
    if (!argType.empty())
        name.pop_back(), name.pop_back();
    name += ")";

    TypeInfo info = {name, TYPE_FUNC, 1, funcIdx};
    int type = typeTable.size();
    typeTable.push_back(info);
    return funcTypeMap[retType][argType] = type;
}
int structType(const std::string& name) {
    TypeInfo info = {"struct " + name, TYPE_STRUCT, 0, 0};
    int type = typeTable.size();
    typeTable.push_back(info);
    return type;
}
void fixStructType(int type, const std::map<std::string, StructDef::Field>& field) {
    StructDef def = {field};
    int structIdx = structDef.size();
    structDef.push_back(def);

    int size = 0;
    for (auto& [_, f] : structDef.back().field)
        f.offset = size, size += typeTable[f.type].size;

    typeTable[type].size = size;
    typeTable[type].index = structIdx;
}

#endif