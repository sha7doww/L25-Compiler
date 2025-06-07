#!/bin/bash
set -e

# Define source and build directories
SRC_DIR="source"
BUILD_DIR="build"

echo "Creating '${BUILD_DIR}' directory"
mkdir -p "${BUILD_DIR}"

echo "Running Bison (generate parser)"
bison -o "${BUILD_DIR}/l25.tab.cc" -d "${SRC_DIR}/l25.y"

echo "Running Flex (generate lexer)"
flex -o "${BUILD_DIR}/l25.lex.cc" "${SRC_DIR}/l25.l"

echo "Compiling compiler"
g++ -std=c++20 -Wno-free-nonheap-object \
    -o "${BUILD_DIR}/compiler" \
    "${BUILD_DIR}/l25.tab.cc" \
    "${BUILD_DIR}/l25.lex.cc"

echo "Compiling interpreter (release build)"
g++ -std=c++20 -DNDEBUG \
    -o "${BUILD_DIR}/interpreter" \
    "${SRC_DIR}/pcode.cc"

echo "Compiling interpreterd (debug build)"
g++ -std=c++20 \
    -o "${BUILD_DIR}/interpreterd" \
    "${SRC_DIR}/pcode.cc"

echo "Build complete"
