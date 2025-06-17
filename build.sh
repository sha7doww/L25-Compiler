#!/bin/bash
set -e

# Define source and build directories
SRC_DIR="source"
BUILD_DIR="build"

echo "Creating '${BUILD_DIR}' directory"
mkdir -p "${BUILD_DIR}"

echo "Running Bison (generate parser)"
bison -o "${SRC_DIR}/l25.tab.c" -d "${SRC_DIR}/l25.y"

echo "Running Flex (generate lexer)"
flex -o "${SRC_DIR}/l25.lex.c" "${SRC_DIR}/l25.l"

echo "Compiling compiler"
g++ -std=c++20 -Wno-free-nonheap-object \
    -o "${BUILD_DIR}/compiler" \
    "${SRC_DIR}/l25.tab.c" \
    "${SRC_DIR}/l25.lex.c" \
    "${SRC_DIR}/types.cpp"

echo "Compiling interpreter"
g++ -std=c++20 -DNDEBUG \
    -o "${BUILD_DIR}/interpreter" \
    "${SRC_DIR}/pcode.cc"

echo "Build complete"