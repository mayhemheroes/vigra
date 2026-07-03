#!/usr/bin/env bash
#
# mayhem/build.sh — build vigra's fuzz harnesses + functional test suite.
# Runs inside the commit image (mayhem/Dockerfile) as `mayhem` in /mayhem.
#
# Targets built:
#   /mayhem/fuzz_vigra_impex         — libFuzzer harness: vigra image import API
#   /mayhem/fuzz_vigra_impex-standalone  — standalone reproducer (run-once on one file)
#   /mayhem/fuzz_trimString          — libFuzzer harness: vigra::detail::trimString
#   /mayhem/fuzz_trimString-standalone   — standalone reproducer
#   /mayhem/example_invert           — file-input binary: invert a vigra-readable image
# Test suite (normal flags, for mayhem/test.sh):
#   /mayhem/build-tests/test/impex/test_impex
set -euo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}"
: "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS DEBUG_FLAGS SANITIZER_FLAGS COVERAGE_FLAGS
cd "$SRC"

# ── 1) Build libvigraimpex with sanitizers ──────────────────────────────────────
cmake -S . -B build \
      -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
      -DCMAKE_C_FLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS" \
      -DCMAKE_CXX_FLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS" \
      -DVIGRA_STATIC_LIB=1 \
      -DBUILD_TESTS=OFF \
      -DWITH_VIGRANUMPY=OFF \
      -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$MAYHEM_JOBS" --target vigraimpex

# ── 2) Build example_invert (sanitized) ────────────────────────────────────────
# The examples target is EXCLUDE_FROM_ALL; build it explicitly.
cmake --build build -j"$MAYHEM_JOBS" --target example_invert
cp build/src/examples/example_invert /mayhem/example_invert

# ── 3) Build libFuzzer + standalone harnesses ───────────────────────────────────
IMPEX_INC="-I$SRC/include"
IMPEX_LIB="$SRC/build/src/impex/libvigraimpex.a"

# Compile the standalone driver as C so LLVMFuzzerTestOneInput keeps C linkage
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o

# fuzz_vigra_impex — image import API harness
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -std=c++11 $IMPEX_INC \
     "$SRC/mayhem/fuzz_vigra_impex.cpp" $LIB_FUZZING_ENGINE \
     "$IMPEX_LIB" -lpng -ljpeg -ltiff -lz \
     -o /mayhem/fuzz_vigra_impex

$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -std=c++11 $IMPEX_INC \
     "$SRC/mayhem/fuzz_vigra_impex.cpp" /tmp/standalone_main.o \
     "$IMPEX_LIB" -lpng -ljpeg -ltiff -lz \
     -o /mayhem/fuzz_vigra_impex-standalone

# fuzz_trimString — internal string utility harness (links same library)
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -std=c++11 $IMPEX_INC \
     "$SRC/mayhem/fuzz_trimString.cpp" $LIB_FUZZING_ENGINE \
     "$IMPEX_LIB" -lpng -ljpeg -ltiff -lz \
     -o /mayhem/fuzz_trimString

$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -std=c++11 $IMPEX_INC \
     "$SRC/mayhem/fuzz_trimString.cpp" /tmp/standalone_main.o \
     "$IMPEX_LIB" -lpng -ljpeg -ltiff -lz \
     -o /mayhem/fuzz_trimString-standalone

# ── 4) Build test suite (normal flags) for mayhem/test.sh ──────────────────────
cmake -S . -B build-tests \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_TESTS=ON \
      -DWITH_VIGRANUMPY=OFF \
      -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" \
      -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS"
cmake --build build-tests -j"$MAYHEM_JOBS" --target test_impex

echo "vigra mayhem/build.sh: done"
