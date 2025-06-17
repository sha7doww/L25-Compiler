#!/bin/bash
set -e

# Define source and build directories
SRC_DIR="source"
BUILD_DIR="build"

echo "Creating '${BUILD_DIR}' directory"
mkdir -p "${BUILD_DIR}"

echo "Running Bison (generate parser)"
bison -o "${BUILD_DIR}/parser.tab.cc" -d "${SRC_DIR}/parser.y"

echo "Running Flex (generate lexer)"
flex -o "${BUILD_DIR}/lexer.lex.cc" "${SRC_DIR}/lexer.l"

echo "Compiling compiler"
g++ -std=c++20 -Wno-free-nonheap-object \
    -o "${BUILD_DIR}/compiler" \
    "${BUILD_DIR}/parser.tab.cc" \
    "${BUILD_DIR}/lexer.lex.cc"

echo "Compiling interpreter (release build)"
g++ -std=c++20 -DNDEBUG \
    -o "${BUILD_DIR}/interpreter" \
    "${SRC_DIR}/interpreter.cc"

echo "Compiling interpreterd (debug build)"
g++ -std=c++20 \
    -o "${BUILD_DIR}/interpreterd" \
    "${SRC_DIR}/interpreter.cc"

echo "Build complete"
