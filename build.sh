#!/bin/bash
#
# Compile script for kernel
# Copyright (C) 2025 RyuDev (romiyusnandar)
# All rights reserved.
#

#######################################
# Variabel dasar build
#######################################
DEVICE="sweet"
BUILD_TYPE="Development"
KERNEL="Kryptonite"

#
# Jika CONFIG_LOCALVERSION_AUTO aktif, kernel build system akan menambahkan suffix
# berdasarkan status Git. Kita bisa mendapatkan nilai yang sama menggunakan:
#   git describe --dirty --always
#
# Misalnya, kita ingin memasukkan string tersebut ke dalam nama kernel.
#
# Perhatikan bahwa ZIPNAME di-generate sebelum kita melakukan modifikasi pada KERNEL.
# Perbarui zipname di main
ZIPNAME=""

#######################################
# Konfigurasi Telegram
#######################################
CHATIDQ="-1001597724605"
CHATID="-1001597724605"
TELEGRAM_TOKEN="7249254292:AAH3367b3c_QmHyDsgQByaSh1qTSqw8Ngt0"

#######################################
# Clone Telegram.sh jika belum ada
#######################################
TELEGRAM_FOLDER="${HOME}/telegram"
if ! [ -d "${TELEGRAM_FOLDER}" ]; then
    git clone https://github.com/romiyusnandar/telegram.sh/ "${TELEGRAM_FOLDER}"
fi
TELEGRAM="${TELEGRAM_FOLDER}/telegram"

#######################################
# Fungsi untuk mengirim pesan ke Telegram menggunakan telegram.sh
#######################################
tg_cast() {
    "${TELEGRAM}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -H \
    "$(
        for POST in "${@}"; do
            echo "${POST}"
        done
    )"
}

#######################################
# Set environment untuk build
#######################################
export ARCH=arm64
export KBUILD_BUILD_USER="RyuDev"
export KBUILD_BUILD_HOST="RyuServer"
export PATH="/home/romiz/ryu/clang/bin/:$PATH"

#######################################
# Fungsi: Kirim pesan awal build via Telegram
#######################################
send_start_telegram() {
    local commit_hash repo_url commit_url

    commit_hash=$(git rev-parse --short HEAD 2>/dev/null)
    repo_url="https://github.com/romiyusnandar/android_kernel_xiaomi_sm6150"
    commit_url="${repo_url}/commit/${commit_hash}"
    random_str=$(git describe --dirty --always)

    tg_cast "<b>STARTING KERNEL BUILD</b>" \
        "Device: <code>${DEVICE}</code>" \
        "Build Type: <code>${BUILD_TYPE}</code>" \
        "Kernel Name: <code>${KERNEL}</code>" \
        "Release Version: <code>${random_str}</code>" \
        "Linux Version: <code>$(make kernelversion)</code>" \
        "Latest Commit: <a href='${commit_url}'>${commit_hash}</a>"
}

#######################################
# Fungsi: Membersihkan folder output
#######################################
clean_output() {
    if [[ "$1" == "-c" || "$1" == "--clean" ]]; then
        rm -rf out
        echo "Cleaned output folder"
    fi
}

#######################################
# Fungsi: Konfigurasi dan kompilasi kernel
#######################################
compile_kernel() {
    echo -e "\nStarting compilation for $DEVICE...\n"
    make O=out ARCH=arm64 "${DEVICE}_defconfig"
    make -j$(nproc --all) \
         O=out \
         ARCH=arm64 \
         LLVM=1 \
         LLVM_IAS=1 \
         CROSS_COMPILE=aarch64-linux-gnu- \
         CROSS_COMPILE_ARM32=arm-linux-gnueabi-
}

#######################################
# Fungsi: Verifikasi hasil kompilasi
#######################################
verify_build_outputs() {
    local kernel="out/arch/arm64/boot/Image.gz"
    local dtbo="out/arch/arm64/boot/dtbo.img"
    local dtb="out/arch/arm64/boot/dtb.img"
    END=$(TZ=Asia/Jakarta date +"%s")
    DIFF=$(( END - START ))

    if [ ! -f "$kernel" ] || [ ! -f "$dtbo" ] || [ ! -f "$dtb" ]; then
        echo -e "\nCompilation failed!"
        tg_cast "Build for ${DEVICE} <b>failed</b> in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! Check Instance for errors @RyuDevpr"
        exit 1
    fi

    # Simpan path hasil kompilasi ke variabel global
    BUILD_KERNEL="$kernel"
    BUILD_DTBO="$dtbo"
    BUILD_DTB="$dtb"

    tg_cast "Build for ${DEVICE} <b>succeed</b> took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! by @RyuDevpr \
              Uploading zip..."
}

#######################################
# Fungsi: Persiapkan AnyKernel3 untuk packaging
#######################################
prepare_anykernel() {
    if [ -d "$AK3_DIR" ]; then
        cp -r "$AK3_DIR" AnyKernel3
    else
        if ! git clone -q https://github.com/romiyusnandar/Anykernel3.git -b sweet AnyKernel3; then
            echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
            tg_cast "AnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting... @RyuDevpr"
            exit 1
        fi
    fi
}

#######################################
# Fungsi: Mengemas kernel ke file zip
#######################################
package_kernel() {
    echo -e "\nKernel compiled successfully! Zipping up...\n"

    prepare_anykernel

    cp "$BUILD_KERNEL" AnyKernel3
    cp "$BUILD_DTBO" AnyKernel3
    cp "$BUILD_DTB" AnyKernel3

    pushd AnyKernel3 > /dev/null
    zip -r9 "../$ZIPNAME" * -x .git
    popd > /dev/null

    rm -rf AnyKernel3

    echo "Zip: $ZIPNAME"
    "${TELEGRAM}" -f "$ZIPNAME" -t "${TELEGRAM_TOKEN}" -c "${CHATIDQ}"
    rm -rf "$ZIPNAME"
}

#######################################
# Fungsi utama: Mengkoordinasikan proses build
#######################################
main() {
    clean_output "$1"
    send_start_telegram

    ZIPNAME="${KERNEL}-${random_str}-${DEVICE}-$(date '+%Y%m%d-%H%M').zip"
    # Catat waktu mulai build (zona waktu Asia/Jakarta)
    START=$(TZ=Asia/Jakarta date +"%s")

    compile_kernel
    verify_build_outputs
    package_kernel
}

#######################################
# Eksekusi fungsi utama
#######################################
main "$@"