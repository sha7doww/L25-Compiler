#include <algorithm>
#include <bit>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <unordered_map>
#include <vector>

constexpr int STACK_SIZE = (1 << 20);

struct Code {
    std::string op;
    long long val;
};

struct ExceptionFrame {
    int handlerPC;
    long long savedSP;
    long long savedFP;
};

std::vector<long long> stack_mem(STACK_SIZE, 0);
std::vector<ExceptionFrame> ex_stack;

int SP = 0;
int FP = 0;
int PC = 0;

std::vector<Code> code;

long long pop_stack() {
    if (SP <= 0) {
        std::cerr << "Runtime error: stack underflow" << std::endl;
        std::exit(1);
    }
    return stack_mem[--SP];
}

void push_stack(long long v) {
    if (SP >= STACK_SIZE) {
        std::cerr << "Runtime error: stack overflow" << std::endl;
        std::exit(1);
    }
    stack_mem[SP++] = v;
}

long long mem_load(int addr) {
    if (addr < 0) {
        std::cerr << "Runtime error: negative memory access" << std::endl;
        std::exit(1);
    }
    if (addr < STACK_SIZE) {
        return stack_mem[addr];
    } else {
        std::cerr << "Runtime error: invalid memory access" << std::endl;
        std::exit(1);
    }
}

void mem_store(int addr, long long val) {
    if (addr < 0) {
        std::cerr << "Runtime error: negative memory write" << std::endl;
        std::exit(1);
    }
    if (addr < STACK_SIZE) {
        stack_mem[addr] = val;
    } else {
        std::cerr << "Runtime error: invalid memory write" << std::endl;
        std::exit(1);
    }
}

void handle_divide_by_zero() {
    if (ex_stack.empty()) {
        std::cerr << "Runtime error: division by zero, no handler" << std::endl;
        std::exit(1);
    }
    std::cerr << "Exception caught: division by zero" << std::endl;
    ExceptionFrame frame = ex_stack.back();
    ex_stack.pop_back();
    SP = frame.savedSP;
    FP = frame.savedFP;
    PC = frame.handlerPC;
}

void run() {
#ifndef UNDEBUG
    int cnt = 0;
#endif

    while (PC < code.size()) {
        const Code& inst = code[PC];
        const std::string& op = inst.op;
        long long val = inst.val;

#ifndef UNDEBUG
        std::cout << "CNT=" << std::left << std::setw(8) << cnt++ << "SP=" << std::left
                  << std::setw(8) << SP << "FP=" << std::left << std::setw(8) << FP
                  << "PC=" << std::left << std::setw(8) << PC << "OP=" << std::left
                  << std::setw(8) << op << "VAL=" << std::left << std::setw(8) << val
                  << std::endl;
#endif

        if (op == "PUSH") {
            push_stack(val);
            PC++;
        } else if (op == "POP") {
            pop_stack();
            PC++;
        } else if (op == "DUP") {
            long long v = pop_stack();
            push_stack(v);
            push_stack(v);
            PC++;
        } else if (op == "SWAP") {
            if (SP < val + 1) {
                std::cerr << "Runtime error: stack underflow on SWAP" << std::endl;
                std::exit(1);
            }
            std::swap(stack_mem[SP - 1], stack_mem[SP - val - 1]);
            PC++;
        } else if (op == "ADD") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a + b);
            PC++;
        } else if (op == "ADDF") {
            double b = std::bit_cast<double>(pop_stack());
            double a = std::bit_cast<double>(pop_stack());
            push_stack(std::bit_cast<long long>(a + b));
            PC++;
        } else if (op == "SUB") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a - b);
            PC++;
        } else if (op == "SUBF") {
            double b = std::bit_cast<double>(pop_stack());
            double a = std::bit_cast<double>(pop_stack());
            push_stack(std::bit_cast<long long>(a - b));
            PC++;
        } else if (op == "MUL") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a * b);
            PC++;
        } else if (op == "MULF") {
            double b = std::bit_cast<double>(pop_stack());
            double a = std::bit_cast<double>(pop_stack());
            push_stack(std::bit_cast<long long>(a * b));
            PC++;
        } else if (op == "DIV") {
            long long b = pop_stack();
            long long a = pop_stack();
            if (b == 0) {
                handle_divide_by_zero();
                continue;
            }
            push_stack(a / b);
            PC++;
        } else if (op == "DIVF") {
            double b = std::bit_cast<double>(pop_stack());
            double a = std::bit_cast<double>(pop_stack());
            if (b == 0.0) {
                handle_divide_by_zero();
                continue;
            }
            push_stack(std::bit_cast<long long>(a / b));
            PC++;
        } else if (op == "MOD") {
            long long b = pop_stack();
            long long a = pop_stack();
            if (b == 0) {
                handle_divide_by_zero();
                continue;
            }
            push_stack(a % b);
            PC++;
        } else if (op == "NEG") {
            long long a = pop_stack();
            push_stack(-a);
            PC++;
        } else if (op == "NEGF") {
            double a = std::bit_cast<double>(pop_stack());
            push_stack(std::bit_cast<long long>(-a));
            PC++;
        } else if (op == "COMPL") {
            long long a = pop_stack();
            push_stack(~a);
            PC++;
        } else if (op == "AND") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a & b);
            PC++;
        } else if (op == "OR") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a | b);
            PC++;
        } else if (op == "XOR") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a ^ b);
            PC++;
        } else if (op == "LSH") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a << b);
            PC++;
        } else if (op == "RSH") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a >> b);
            PC++;
        } else if (op == "LT") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a < b);
            PC++;
        } else if (op == "LTF") {
            double b = std::bit_cast<double>(pop_stack());
            double a = std::bit_cast<double>(pop_stack());
            push_stack(a < b);
            PC++;
        } else if (op == "GT") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a > b);
            PC++;
        } else if (op == "GTF") {
            double b = std::bit_cast<double>(pop_stack());
            double a = std::bit_cast<double>(pop_stack());
            push_stack(a > b);
            PC++;
        } else if (op == "LE") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a <= b);
            PC++;
        } else if (op == "LEF") {
            double b = std::bit_cast<double>(pop_stack());
            double a = std::bit_cast<double>(pop_stack());
            push_stack(a <= b);
            PC++;
        } else if (op == "GE") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a >= b);
            PC++;
        } else if (op == "GEF") {
            long long bbits = pop_stack();
            long long abits = pop_stack();
            double b = std::bit_cast<double>(bbits);
            double a = std::bit_cast<double>(abits);
            push_stack(a >= b);
            PC++;
        } else if (op == "EQ") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a == b);
            PC++;
        } else if (op == "EQF") {
            double b = std::bit_cast<double>(pop_stack());
            double a = std::bit_cast<double>(pop_stack());
            push_stack(a == b);
            PC++;
        } else if (op == "NEQ") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a != b);
            PC++;
        } else if (op == "NEQF") {
            double b = std::bit_cast<double>(pop_stack());
            double a = std::bit_cast<double>(pop_stack());
            push_stack(a != b);
            PC++;
        } else if (op == "ANDB") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a && b);
            PC++;
        } else if (op == "ORB") {
            long long b = pop_stack();
            long long a = pop_stack();
            push_stack(a || b);
            PC++;
        } else if (op == "ADDS") {
            std::vector<long long> b(256);
            std::vector<long long> a(256);
            for (int i = 256; i--;)
                b[i] = pop_stack();
            for (int i = 256; i--;)
                a[i] = pop_stack();
            int c = 0;
            for (int i = 0; a[i] && c < 255;)
                push_stack(a[i++]), c++;
            for (int i = 0; b[i] && c < 255;)
                push_stack(b[i++]), c++;
            while (c < 256)
                push_stack(0), c++;
            PC++;
        } else if (op == "MULS") {
            long long b = pop_stack();
            std::vector<long long> a(256);
            for (int i = 256; i--;)
                a[i] = pop_stack();
            int c = 0;
            while (b--)
                for (int i = 0; a[i] && c < 255;)
                    push_stack(a[i++]), c++;
            while (c < 256)
                push_stack(0), c++;
            PC++;
        } else if (op == "I2F") {
            long long a = pop_stack();
            push_stack(std::bit_cast<long long>(static_cast<double>(a)));
            PC++;
        } else if (op == "F2I") {
            double a = std::bit_cast<double>(pop_stack());
            push_stack(static_cast<long long>(a));
            PC++;
        } else if (op == "I2B") {
            long long a = pop_stack();
            push_stack(a != 0);
            PC++;
        } else if (op == "B2I") {
            long long a = pop_stack();
            push_stack(a != 0);
            PC++;
        } else if (op == "I2C") {
            long long a = pop_stack();
            push_stack(a & 0xFF);
            PC++;
        } else if (op == "C2I") {
            long long a = pop_stack();
            push_stack(a & 0xFF);
            PC++;
        } else if (op == "F2B") {
            double a = std::bit_cast<double>(pop_stack());
            push_stack(a != 0.0);
            PC++;
        } else if (op == "B2F") {
            long long a = pop_stack();
            push_stack(std::bit_cast<long long>(static_cast<double>(a != 0)));
            PC++;
        } else if (op == "PUSHFP") {
            push_stack(FP);
            PC++;
        } else if (op == "MOVFP") {
            FP = SP;
            PC++;
        } else if (op == "POPFP") {
            long long oldfp = pop_stack();
            FP = oldfp;
            PC++;
        } else if (op == "ADDSP") {
            SP += val;
            if (SP < 0 || SP > STACK_SIZE) {
                std::cerr << "Runtime error: invalid ADDSP result" << std::endl;
                std::exit(1);
            }
            PC++;
        } else if (op == "PADDRL") {
            long long addr = FP + val;
            push_stack(addr);
            PC++;
        } else if (op == "PADDRA") {
            long long idx = pop_stack();
            long long base = pop_stack();
            long long addr = base + idx * val;
            push_stack(addr);
            PC++;
        } else if (op == "PADDRF") {
            long long base = pop_stack();
            long long addr = base + val;
            push_stack(addr);
            PC++;
        } else if (op == "LOD") {
            long long addr = pop_stack();
            long long v = mem_load(addr);
            push_stack(v);
            PC++;
        } else if (op == "STR") {
            long long v = pop_stack();
            long long addr = pop_stack();
            mem_store(addr, v);
            PC++;
        } else if (op == "JMP") {
            PC = val;
        } else if (op == "JPC") {
            long long cond = pop_stack();
            if (cond == 0)
                PC = val;
            else
                PC++;
        } else if (op == "CALL") {
            long long addr = pop_stack();
            push_stack(PC + 1);
            PC = addr;
        } else if (op == "RET") {
            long long addr = pop_stack();
            PC = addr;
        } else if (op == "SCAN") {
            long long x;
            if (!(std::cin >> x)) {
                std::cerr << "Runtime error: failed to read integer "
                             "from stdin"
                          << std::endl;
                std::exit(1);
            }
            push_stack(x);
            PC++;
        } else if (op == "SCANF") {
            double x;
            if (!(std::cin >> x)) {
                std::cerr << "Runtime error: failed to read double "
                             "from stdin"
                          << std::endl;
                std::exit(1);
            }
            push_stack(std::bit_cast<long long>(x));
            PC++;
        } else if (op == "GET") {
            char c;
            std::cin >> c;
            long long v = static_cast<long long>(static_cast<unsigned char>(c));
            push_stack(v);
            PC++;
        } else if (op == "GETS") {
            std::string s;
            std::cin >> s;
            int c = 0;
            for (int i = 0; i < s.size() && c < 255;)
                push_stack(s[i++]), c++;
            while (c < 256)
                push_stack(0), c++;
            PC++;
        } else if (op == "PRINT") {
            long long x = pop_stack();
            std::cout << x;
#ifndef UNDEBUG
            std::cout << std::endl;
#endif
            PC++;
        } else if (op == "PRINTF") {
            double x = std::bit_cast<double>(pop_stack());
            std::cout << x;
#ifndef UNDEBUG
            std::cout << std::endl;
#endif
            PC++;
        } else if (op == "PUT") {
            char c = static_cast<char>(pop_stack() & 0xFF);
            std::cout << c;
#ifndef UNDEBUG
            std::cout << std::endl;
#endif
            PC++;
        } else if (op == "PUTS") {
            std::string s(256, 0);
            for (int i = 256; i--;)
                s[i] = pop_stack();
            std::cout << s.c_str();
#ifndef UNDEBUG
            std::cout << std::endl;
#endif
            PC++;
        } else if (op == "PUSHE") {
            ExceptionFrame frame;
            frame.handlerPC = val;
            frame.savedSP = SP;
            frame.savedFP = FP;
            ex_stack.push_back(frame);
            PC++;
        } else if (op == "POPE") {
            if (!ex_stack.empty())
                ex_stack.pop_back();
            PC++;
        } else {
            std::cerr << "Runtime error: unknown opcode \"" << op << "\" at PC=" << PC
                      << "" << std::endl;
            std::exit(1);
        }
    }
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <bytecode.txt>" << std::endl;
        return 1;
    }

    std::ifstream cin(argv[1]);
    if (!cin) {
        std::cerr << "Failed to open bytecode file" << std::endl;
        return 1;
    }

    std::string op;
    long long val;
    while (cin >> op >> val)
        code.push_back({op, val});

    run();
    return 0;
}
