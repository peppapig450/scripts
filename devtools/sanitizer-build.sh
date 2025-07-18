#!/usr/bin/env bash
# This script wraps around generic Makefile-based projects to enable building
# with common sanitizers (asan, msan, tsan, ubsan) or valgrind-friendly builds.
# Originally written for fastp but reusable for other C++ projects.
set -Eeuo pipefail


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
cd "${PROJECT_ROOT}"

BUILD_TYPE="$1"
TARGET="${2:-fastp}"

SANITIZER_FLAGS=""
LDFLAGS=""

case "$BUILD_TYPE" in
    asan)
        SANITIZER_FLAGS="-fsanitize=address -O1"
        LDFLAGS="-fsanitize=address"
        ;;
    msan)
        SANITIZER_FLAGS="-fsanitize=memory -O1"
        LDFLAGS="-fsanitize=memory"
        ;;
    tsan)
        SANITIZER_FLAGS="-fsanitize=thread -O1"
        LDFLAGS="-fsanitize=thread"
        ;;
    ubsan)
        SANITIZER_FLAGS="-fsanitize=undefined,float-divide-by-zero -O1"
        LDFLAGS="-fsanitize=undefined"
        ;;
    valgrind)
        SANITIZER_FLAGS="-O0"
        ;;
    *)
        echo "Usage: $0 {asan|msan|tsan|ubsan|valgrind}"
        exit 1
        ;;
esac

echo ">>> Cleaning previous builds..."
make clean

echo ">>> Building with $BUILD_TYPE sanitizer..."

cores="$(( $(getconf _NPROCESSORS_ONLN) / 2 ))"
# NOTE: LD_FLAGS is NOT standard this is a fastp quirk.
make -j${cores} CXX="clang++" \
     CXXFLAGS="$SANITIZER_FLAGS -std=c++11 -pthread -fno-omit-frame-pointer -D_GLIBCXX_DEBUG -g -I./inc" \
     LD_FLAGS="$LDFLAGS -lisal -ldeflate -lpthread" \
     ${TARGET}
