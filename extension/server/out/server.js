"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_1 = require("vscode-languageserver/node");
const vscode_languageserver_textdocument_1 = require("vscode-languageserver-textdocument");
const child_process_1 = require("child_process");
const path = require("path");
const connection = (0, node_1.createConnection)(node_1.ProposedFeatures.all);
const documents = new node_1.TextDocuments(vscode_languageserver_textdocument_1.TextDocument);
let hasConfigurationCapability = false;
const builtInKeywords = new Set([
    "program", "struct", "func", "main", "return", "let",
    "int", "bool", "char", "void", "float", "string",
    "if", "else", "while", "try", "catch", "input", "output",
    "alloc", "free", "this", "sizeof", "true", "false", "default"
]);
let definitions = [];
let pendingParamDefs = [];
let structNames = new Set();
function buildSymbolTable(doc) {
    definitions = [];
    pendingParamDefs = [];
    structNames.clear();
    const lines = doc.getText().split(/\r?\n/);
    const total = lines.length;
    const funcSig = /\bfunc\s+([A-Za-z_]\w*)\s*\(\s*([^)]*)\s*\)/;
    const structDefRe = /\bstruct\s+([A-Za-z_]\w*)/;
    const letStruct = /\blet\s+([A-Za-z_]\w*)\s*:\s*struct\s+([A-Za-z_]\w*)/;
    const letInitStruct = /\blet\s+([A-Za-z_]\w*)\s*=\s*struct\s+([A-Za-z_]\w*)\s*\*/;
    const letType = /\blet\s+([A-Za-z_]\w*)\s*:\s*([A-Za-z_]\w*)/;
    const letSimple = /\blet\s+([A-Za-z_]\w*)/;
    const fieldDef = /^\s*([A-Za-z_]\w*)\s*:\s*([^;]+);/;
    const blockStack = [];
    for (let i = 0; i < total; i++) {
        const line = lines[i];
        for (const ch of line) {
            if (ch === "}" && blockStack.length) {
                const { start } = blockStack.pop();
                definitions.forEach(d => {
                    if (d.scopeStart === start && d.scopeEnd === Infinity) {
                        d.scopeEnd = i;
                    }
                });
            }
        }
        let m = funcSig.exec(line);
        if (m) {
            const fn = m[1], params = m[2].trim();
            const idx = line.indexOf(fn);
            definitions.push({
                name: fn,
                loc: {
                    uri: doc.uri,
                    range: {
                        start: { line: i, character: idx },
                        end: { line: i, character: idx + fn.length }
                    }
                },
                scopeStart: 0,
                scopeEnd: total
            });
            if (params) {
                params.split(",").map(s => s.trim()).forEach(p => {
                    const [pn, pt] = p.split(":").map(x => x.trim());
                    const pidx = line.indexOf(pn);
                    const ploc = {
                        uri: doc.uri,
                        range: {
                            start: { line: i, character: pidx },
                            end: { line: i, character: pidx + pn.length }
                        }
                    };
                    const sm = /^struct\s+([A-Za-z_]\w*)/.exec(pt);
                    pendingParamDefs.push({ name: pn, loc: ploc, typeName: sm ? sm[1] : undefined });
                });
            }
        }
        m = structDefRe.exec(line);
        let nextStruct;
        if (m) {
            const st = m[1];
            structNames.add(st);
            const idx = line.indexOf(st);
            definitions.push({
                name: st,
                loc: {
                    uri: doc.uri,
                    range: {
                        start: { line: i, character: idx },
                        end: { line: i, character: idx + st.length }
                    }
                },
                scopeStart: 0,
                scopeEnd: total
            });
            nextStruct = st;
        }
        m = letStruct.exec(line);
        if (m) {
            const varName = m[1], st = m[2];
            const idx = line.indexOf(varName);
            const ps = blockStack.length ? blockStack[blockStack.length - 1].start : 0;
            definitions.push({
                name: varName,
                loc: {
                    uri: doc.uri,
                    range: {
                        start: { line: i, character: idx },
                        end: { line: i, character: idx + varName.length }
                    }
                },
                scopeStart: ps,
                scopeEnd: Infinity,
                typeName: st
            });
        }
        else if ((m = letInitStruct.exec(line))) {
            const varName = m[1], st = m[2];
            const idx = line.indexOf(varName);
            const ps = blockStack.length ? blockStack[blockStack.length - 1].start : 0;
            definitions.push({
                name: varName,
                loc: {
                    uri: doc.uri,
                    range: {
                        start: { line: i, character: idx },
                        end: { line: i, character: idx + varName.length }
                    }
                },
                scopeStart: ps,
                scopeEnd: Infinity,
                typeName: st
            });
        }
        else if ((m = letType.exec(line))) {
            const varName = m[1], tp = m[2];
            const idx = line.indexOf(varName);
            const ps = blockStack.length ? blockStack[blockStack.length - 1].start : 0;
            definitions.push({
                name: varName,
                loc: {
                    uri: doc.uri,
                    range: {
                        start: { line: i, character: idx },
                        end: { line: i, character: idx + varName.length }
                    }
                },
                scopeStart: ps,
                scopeEnd: Infinity,
                typeName: structNames.has(tp) ? tp : undefined
            });
        }
        else if ((m = letSimple.exec(line))) {
            const varName = m[1];
            const idx = line.indexOf(varName);
            const ps = blockStack.length ? blockStack[blockStack.length - 1].start : 0;
            definitions.push({
                name: varName,
                loc: {
                    uri: doc.uri,
                    range: {
                        start: { line: i, character: idx },
                        end: { line: i, character: idx + varName.length }
                    }
                },
                scopeStart: ps,
                scopeEnd: Infinity
            });
        }
        m = fieldDef.exec(line);
        if (m && blockStack.length) {
            const top = blockStack[blockStack.length - 1];
            if (top.structName) {
                const fld = m[1];
                const idx = line.indexOf(fld);
                definitions.push({
                    name: fld,
                    loc: {
                        uri: doc.uri,
                        range: {
                            start: { line: i, character: idx },
                            end: { line: i, character: idx + fld.length }
                        }
                    },
                    scopeStart: 0,
                    scopeEnd: total,
                    typeName: top.structName
                });
            }
        }
        for (const ch of line) {
            if (ch === "{") {
                blockStack.push({ start: i, structName: nextStruct });
                if (pendingParamDefs.length) {
                    pendingParamDefs.forEach(p => {
                        definitions.push({
                            name: p.name,
                            loc: p.loc,
                            scopeStart: i,
                            scopeEnd: Infinity,
                            typeName: p.typeName
                        });
                    });
                    pendingParamDefs = [];
                }
                nextStruct = undefined;
            }
        }
    }
    definitions.forEach(d => {
        if (d.scopeEnd === Infinity)
            d.scopeEnd = total;
    });
}
function getWordAtPosition(doc, pos) {
    const lines = doc.getText().split(/\r?\n/);
    if (pos.line < 0 || pos.line >= lines.length)
        return null;
    const line = lines[pos.line];
    let s = pos.character, e = pos.character;
    while (s > 0 && /\w/.test(line[s - 1]))
        s--;
    while (e < line.length && /\w/.test(line[e]))
        e++;
    return s < e ? line.slice(s, e) : null;
}
function getMemberAccess(doc, pos) {
    const line = doc.getText({
        start: { line: pos.line, character: 0 },
        end: { line: pos.line, character: Number.MAX_SAFE_INTEGER }
    });
    const re = /([A-Za-z_]\w*)\s*(?:\.|->)\s*([A-Za-z_]\w*)/g;
    let m;
    while ((m = re.exec(line))) {
        const obj = m[1], fld = m[2];
        const full = m[0];
        const offset = line.indexOf(full, re.lastIndex - full.length);
        const fldStart = offset + full.indexOf(fld);
        const fldEnd = fldStart + fld.length;
        if (pos.character >= fldStart && pos.character <= fldEnd) {
            return { object: obj, field: fld };
        }
    }
    return null;
}
function findDefinition(name, ln, structName) {
    if (structName) {
        const fd = definitions.find(d => d.name === name &&
            d.typeName === structName &&
            d.scopeStart <= ln && ln < d.scopeEnd);
        if (fd)
            return fd;
    }
    let best = null;
    for (const d of definitions) {
        if (d.name === name && d.scopeStart <= ln && ln < d.scopeEnd) {
            if (!best || d.scopeStart > best.scopeStart)
                best = d;
        }
    }
    return best;
}
connection.onInitialize((params) => {
    hasConfigurationCapability =
        !!(params.capabilities.workspace && params.capabilities.workspace.configuration);
    return {
        capabilities: {
            textDocumentSync: node_1.TextDocumentSyncKind.Full,
            completionProvider: { resolveProvider: false },
            definitionProvider: true,
            referencesProvider: true,
            hoverProvider: true
        }
    };
});
connection.onInitialized(() => {
    if (hasConfigurationCapability) {
        connection.client.register(node_1.DidChangeConfigurationNotification.type, undefined);
    }
});
documents.onDidChangeContent((change) => __awaiter(void 0, void 0, void 0, function* () {
    buildSymbolTable(change.document);
    yield validateTextDocument(change.document);
}));
function validateTextDocument(doc) {
    return __awaiter(this, void 0, void 0, function* () {
        const text = doc.getText();
        const diagnostics = [];
        return new Promise(resolve => {
            const compilerPath = path.join(__dirname, "..", "bin", "l25-compiler");
            const cp = (0, child_process_1.spawn)(compilerPath, [], { stdio: ["pipe", "ignore", "pipe"] });
            let buf = "";
            cp.stderr.setEncoding("utf8");
            cp.stderr.on("data", c => (buf += c));
            cp.on("error", err => {
                diagnostics.push({
                    severity: node_1.DiagnosticSeverity.Warning,
                    range: { start: { line: 0, character: 0 }, end: { line: 0, character: 1 } },
                    message: `Cannot start compiler: ${err.message}`,
                    source: "l25-compiler"
                });
                connection.sendDiagnostics({ uri: doc.uri, diagnostics });
                resolve();
            });
            cp.on("close", () => {
                const ls = buf.split(/\r?\n/);
                const re = /Compile error at line\s+(\d+),\s*column\s+(\d+):\s*(.*)/i;
                for (const l of ls) {
                    if (!l.trim())
                        continue;
                    const m = re.exec(l);
                    if (m) {
                        const ln = parseInt(m[1], 10) - 1, cn = parseInt(m[2], 10) - 1;
                        diagnostics.push({
                            severity: node_1.DiagnosticSeverity.Error,
                            range: { start: { line: ln, character: cn }, end: { line: ln, character: cn + 1 } },
                            message: m[3],
                            source: "l25-compiler"
                        });
                    }
                    else {
                        diagnostics.push({
                            severity: node_1.DiagnosticSeverity.Error,
                            range: { start: { line: 0, character: 0 }, end: { line: 0, character: 1 } },
                            message: l,
                            source: "l25-compiler"
                        });
                    }
                }
                connection.sendDiagnostics({ uri: doc.uri, diagnostics });
                resolve();
            });
            cp.stdin.write(text);
            cp.stdin.end();
        });
    });
}
connection.onDefinition((params) => {
    const doc = documents.get(params.textDocument.uri);
    if (!doc)
        return null;
    const w = getWordAtPosition(doc, params.position);
    if (!w || builtInKeywords.has(w))
        return null;
    const member = getMemberAccess(doc, params.position);
    const ln = params.position.line;
    if (member) {
        const od = findDefinition(member.object, ln);
        if (od && od.typeName) {
            const fd = findDefinition(member.field, ln, od.typeName);
            if (fd)
                return [fd.loc];
        }
    }
    const def = findDefinition(w, ln);
    return def ? [def.loc] : null;
});
connection.onHover((params) => {
    const doc = documents.get(params.textDocument.uri);
    if (!doc)
        return null;
    const w = getWordAtPosition(doc, params.position);
    if (!w || builtInKeywords.has(w))
        return null;
    const member = getMemberAccess(doc, params.position);
    const ln = params.position.line;
    let def = null;
    if (member) {
        const od = findDefinition(member.object, ln);
        if (od && od.typeName) {
            def = findDefinition(member.field, ln, od.typeName);
        }
    }
    else {
        def = findDefinition(w, ln);
    }
    if (!def)
        return null;
    const decl = doc.getText({
        start: { line: def.loc.range.start.line, character: 0 },
        end: { line: def.loc.range.start.line, character: Number.MAX_SAFE_INTEGER }
    }).trim();
    return {
        contents: { kind: node_1.MarkupKind.Markdown, value: "```l25\n" + decl + "\n```" },
        range: def.loc.range
    };
});
connection.onReferences((params) => {
    const { textDocument: { uri }, position, context } = params;
    const doc = documents.get(uri);
    if (!doc)
        return [];
    const w = getWordAtPosition(doc, position);
    if (!w || builtInKeywords.has(w))
        return [];
    const ln = position.line;
    let structName;
    const member = getMemberAccess(doc, position);
    let defEntry = null;
    if (member) {
        const od = findDefinition(member.object, ln);
        if (od)
            structName = od.typeName;
        defEntry = structName
            ? findDefinition(member.field, ln, structName)
            : null;
    }
    else {
        defEntry = findDefinition(w, ln);
    }
    if (!defEntry)
        return [];
    const entry = defEntry;
    const results = [];
    for (const d of documents.all()) {
        const text = d.getText();
        const lines = text.split(/\r?\n/);
        for (let lineNum = 0; lineNum < lines.length; lineNum++) {
            const lineText = lines[lineNum];
            const memberRe = new RegExp(`\\b\\w+\\s*(?:\\.|->)\\s*${entry.name}\\b`, "g");
            let m;
            while ((m = memberRe.exec(lineText))) {
                const startChar = m.index + m[0].lastIndexOf(entry.name);
                const endChar = startChar + entry.name.length;
                if (lineNum >= entry.scopeStart && lineNum < entry.scopeEnd) {
                    results.push({
                        uri: d.uri,
                        range: {
                            start: { line: lineNum, character: startChar },
                            end: { line: lineNum, character: endChar }
                        }
                    });
                }
            }
            const wordRe = new RegExp(`\\b${entry.name}\\b`, "g");
            while ((m = wordRe.exec(lineText))) {
                const startChar = m.index;
                const endChar = startChar + entry.name.length;
                if (lineNum >= entry.scopeStart && lineNum < entry.scopeEnd) {
                    results.push({
                        uri: d.uri,
                        range: {
                            start: { line: lineNum, character: startChar },
                            end: { line: lineNum, character: endChar }
                        }
                    });
                }
            }
        }
    }
    if (!context.includeDeclaration) {
        return results.filter(loc => !(loc.uri === entry.loc.uri
            && loc.range.start.line === entry.loc.range.start.line
            && loc.range.start.character === entry.loc.range.start.character));
    }
    return results;
});
connection.onCompletion(() => {
    const kws = Array.from(builtInKeywords);
    return kws.map(kw => ({ label: kw, kind: node_1.CompletionItemKind.Keyword }));
});
connection.onCompletionResolve(item => item);
documents.listen(connection);
connection.listen();
//# sourceMappingURL=server.js.map