#ifndef SYMBOL_HPP
#define SYMBOL_HPP

#include "type.hpp"

enum ScopeKind { SCOPE_LOCAL, SCOPE_MEMBER, SCOPE_GLOBAL };
struct Sym {
    int type, addr;
    ScopeKind kind;
};

int curLocal;
int entType, entAddr;
std::vector<int> paramStk;
std::vector<std::vector<int>> typeStk;
std::vector<std::map<std::string, StructDef::Field>> fieldStk;
std::vector<Sym*> calleeStk;

std::vector<std::map<std::string, Sym>> scopes(1);

Sym& find(const std::string& id) {
    for (int i = scopes.size(); i--;)
        if (scopes[i].count(id))
            return scopes[i][id];
    yyerror(("Syntax Error: " + id + " is undeclared").c_str());
    exit(1);
}
void declare(const std::string& id, int type, int addr, ScopeKind kind) {
    if (scopes.back().count(id)) {
        yyerror(("Syntax Error: " + id + " is redeclared").c_str());
        exit(1);
    }
    scopes.back()[id] = {type, addr, kind};
}

void unify(Sym& s, int realType) {
    if (s.type == TYPE_AUTO_ID) {
        s.type = realType;
        for (auto& vec : typeStk)
            for (int& t : vec)
                if (t == TYPE_AUTO_ID)
                    t = realType;
    }
}

std::string unescapeLiteral(const char* raw) {
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

#endif