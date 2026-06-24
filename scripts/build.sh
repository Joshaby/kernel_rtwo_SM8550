#!/usr/bin/env bash
# build.sh — moto SM8550 kernel build
# env: SOURCE_TYPE, KSU_TYPE, DEFCONFIG, VARIANT, KERNEL_SRC, WORK_DIR, CLANG_DIR
set -e

: "${SOURCE_TYPE:?}"
: "${KERNEL_SRC:?}"
: "${WORK_DIR:?}"
: "${DEFCONFIG:?}"
: "${CLANG_DIR:?}"

OUT_DIR="${WORK_DIR}/out"
START=$(date +%s)

export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-superuseryu}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github}"
export PATH="${CLANG_DIR}/bin:$PATH"

if command -v ccache &>/dev/null; then _CC="ccache clang"; else _CC="clang"; fi

MAKE_FLAGS=(
  -j$(nproc)
  O="${OUT_DIR}/dist"
  ARCH=arm64
  SUBARCH=arm64
  LLVM=1
  LLVM_IAS=1
  CC="$_CC"
  LD=ld.lld
  AR=llvm-ar
  NM=llvm-nm
  OBJCOPY=llvm-objcopy
  OBJDUMP=llvm-objdump
  STRIP=llvm-strip
  CROSS_COMPILE=aarch64-linux-gnu-
  CROSS_COMPILE_ARM32=arm-linux-gnueabi-
  KBUILD_BUILD_USER="$KBUILD_BUILD_USER"
  KBUILD_BUILD_HOST="$KBUILD_BUILD_HOST"
  KCFLAGS="-pipe -fno-strict-aliasing -Wno-error"
  LLVM_PARALLEL_LINK_JOBS=2
)

set -o pipefail
mkdir -p "${OUT_DIR}/dist"
cd "$KERNEL_SRC"

LOG="/tmp/build_${SOURCE_TYPE}.log"

make "${MAKE_FLAGS[@]}" gki_defconfig \
    vendor/kalama_GKI.config \
    vendor/ext_config/moto-kalama.config \
    vendor/ext_config/moto-kalama-gki.config

echo "[${SOURCE_TYPE^^}] Switching to ThinLTO..."
./scripts/config --file "${OUT_DIR}/dist/.config" \
  --disable LTO_CLANG_FULL \
  --enable  LTO_CLANG_THIN
make "${MAKE_FLAGS[@]}" olddefconfig

if [ -n "${CLO_FRAGMENT:-}" ] && [ -f "arch/arm64/configs/${CLO_FRAGMENT}" ]; then
  echo "[${SOURCE_TYPE^^}] Merging fragment: $CLO_FRAGMENT"
  KCONFIG_CONFIG="${OUT_DIR}/dist/.config" \
    scripts/kconfig/merge_config.sh -m \
    "${OUT_DIR}/dist/.config" \
    "arch/arm64/configs/${CLO_FRAGMENT}"
  make "${MAKE_FLAGS[@]}" olddefconfig
  ./scripts/config --file "${OUT_DIR}/dist/.config" \
    -d ZRAM_DEF_COMP_LZORLE -d ZRAM_DEF_COMP_ZSTD \
    -e ZRAM_DEF_COMP_LZ4    -d ZRAM_DEF_COMP_LZO \
    --set-str ZRAM_DEF_COMP "lz4"
  make "${MAKE_FLAGS[@]}" olddefconfig
fi

echo "[${SOURCE_TYPE^^}] Building Image..."
if ! make "${MAKE_FLAGS[@]}" Image 2>&1 | tee "$LOG"; then
  echo "[FAIL] ${SOURCE_TYPE^^} build failed:"
  tail -60 "$LOG"
  exit 1
fi

cp "${OUT_DIR}/dist/arch/arm64/boot/Image" "${OUT_DIR}/dist/Image"
echo "[${SOURCE_TYPE^^}] Image copied to ${OUT_DIR}/dist/Image"

DURATION=$(( $(date +%s) - START ))
echo "✅ Build done in $((DURATION/60))m $((DURATION%60))s"
echo "duration=$DURATION" >> "${GITHUB_OUTPUT:-/dev/null}"
