#!/usr/bin/env bash
# clone-source.sh — clone moto SM8550 kernel source
# env: SOURCE_TYPE, KSU_TYPE, KERNEL_SRC (output dir)
set -e

: "${SOURCE_TYPE:?}"
: "${KERNEL_SRC:=$WORK_DIR/kernel_src}"

mkdir -p "$KERNEL_SRC"

case "$SOURCE_TYPE" in

  moto)
    MOTO_REPO="https://github.com/LineageOS/android_kernel_motorola_sm8550"
    MOTO_DT_REPO="https://github.com/LineageOS/android_kernel_motorola_sm8550-devicetrees"
    MOTO_MOD_REPO="https://github.com/LineageOS/android_kernel_motorola_sm8550-modules"
    MOTO_BRANCH="lineage-23.2"
    if [ "${MOTO_CACHE_HIT}" = "true" ] && [ -d "$KERNEL_SRC/.git" ]; then
      echo "[Moto] Cache hit — fetching delta only..."
      for attempt in 1 2 3; do
        git -C "$KERNEL_SRC" fetch origin --depth=1 "$MOTO_BRANCH" && \
          git -C "$KERNEL_SRC" reset --hard FETCH_HEAD && break
        echo "⚠️ Fetch attempt $attempt failed, retrying in 30s..."
        sleep 30
      done
    else
      echo "[Moto] Cloning $MOTO_BRANCH ..."
      for attempt in 1 2 3; do
        git clone --recursive --branch "$MOTO_BRANCH" "$MOTO_REPO" "$KERNEL_SRC" --depth=1 && break
        echo "⚠️ Attempt $attempt failed, retrying in 30s..."
        rm -rf "$KERNEL_SRC" && mkdir -p "$KERNEL_SRC"
        sleep 30
      done
    fi

    echo "[Moto] Cloning Devicetrees..."
    for attempt in 1 2 3; do
      git clone --recursive --branch "$MOTO_BRANCH" "$MOTO_DT_REPO" "$KERNEL_SRC/devicetrees" --depth=1 && break
      echo "⚠️ Devicetrees attempt $attempt failed, retrying in 30s..."
      rm -rf "$KERNEL_SRC/devicetrees"
      sleep 30
    done

    echo "[Moto] Cloning Modules..."
    for attempt in 1 2 3; do
      git clone --recursive --branch "$MOTO_BRANCH" "$MOTO_MOD_REPO" "$KERNEL_SRC/modules" --depth=1 && break
      echo "⚠️ Modules attempt $attempt failed, retrying in 30s..."
      rm -rf "$KERNEL_SRC/modules"
      sleep 30
    done
    ;;

  *)
    echo "[ERROR] Unknown source type: $SOURCE_TYPE"
    exit 1
    ;;
esac

echo "[OK] Source cloned → $KERNEL_SRC"
echo "KERNEL_SRC=$KERNEL_SRC" >> "${GITHUB_ENV:-/dev/null}"
