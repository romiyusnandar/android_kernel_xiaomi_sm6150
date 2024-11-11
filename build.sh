#!/bin/bash
#
# Script For Building Android arm64 Kernel

# Setup warna untuk skrip
yellow='\033[0;33m'
white='\033[0m'
red='\033[0;31m'
green='\e[0;32m'

echo -e "$green << cleanup >> \n $white"

rm -rf out
rm -rf zip
rm -rf error.log

# Edit area
DEVICE="Redmi Note 10 Pro"
KERNEL_NAME="Evergreen-OSS"
CODENAME="sweet"

DEFCONFIG_COMMON="vendor/sdmsteppe-perf_defconfig"
DEFCONFIG_DEVICE="vendor/sweet.config"

# CLANG_PATH berada satu level di atas direktori skrip
CLANG_PATH="$(dirname "$(pwd)")/clang"
AnyKernel="https://github.com/romiyusnandar/AnyKernel3-sweet.git"
AnyKernelbranch="master"

KRNL_REL_TAG="STABLE"
API_BOT="7249254292:AAHXrkRg5n--RTFQGzqxNxP-QOQokou_7AM"
CHATID="-1001930168269"
HOSST="romi.yusna"
USEER="orion-server"
# end of edit area

# Setup Telegram env
export BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
  -d "parse_mode=html" \
  -d text="$1"
}

tg_post_build() {
  MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

  curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
  -F chat_id="$2" \
  -F "disable_web_page_preview=true" \
  -F "parse_mode=html" \
  -F caption="$3 build finished in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

tg_error() {
  curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
  -F chat_id="$2" \
  -F "disable_web_page_preview=true" \
  -F "parse_mode=html" \
  -F caption="$3Failed to build, check <code>error.log</code>"
}

# clang setup
if [ ! -d "$CLANG_PATH" ] || [ -z "$(ls -A "$CLANG_PATH")" ]; then
  echo -e "$green << getting clang >> \n $white"
  mkdir -p "$CLANG_PATH"
  pushd "$CLANG_PATH" > /dev/null
  wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r536225.tar.gz
  tar -xf clang-r536225.tar.gz
  rm clang-r536225.tar.gz
  popd > /dev/null
else
  echo -e "$yellow << clang already exists >> \n $white"
fi

export PATH="$CLANG_PATH/bin:$PATH"
export KBUILD_COMPILER_STRING=$("$CLANG_PATH"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')

# Setup proses build
build_kernel() {
  Start=$(date +"%s")
  make -j$(nproc --all) O=out \
                        ARCH=arm64 \
                        LLVM=1 \
                        LLVM_IAS=1 \
                        AR=llvm-ar \
                        NM=llvm-nm \
                        LD=ld.lld \
                        OBJCOPY=llvm-objcopy \
                        OBJDUMP=llvm-objdump \
                        STRIP=llvm-strip \
                        CC=clang \
                        CLANG_TRIPLE=aarch64-linux-gnu- \
                        CROSS_COMPILE=aarch64-linux-android- \
                        CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1 | tee error.log

  End=$(date +"%s")
  Diff=$(($End - $Start))
}

# Let's start
echo -e "$green << doing pre-compilation process >> \n $white"
export ARCH=arm64
export SUBARCH=arm64
export HEADER_ARCH=arm64

export KBUILD_BUILD_HOST="$HOSST"
export KBUILD_BUILD_USER="$USEER"

mkdir -p out

make clean && make mrproper
make "$DEFCONFIG_COMMON" O=out
make "$DEFCONFIG_DEVICE" O=out

echo -e "$yellow << compiling the kernel >> \n $white"
tg_post_msg "Triggered compiling kernel for $DEVICE ($CODENAME)" "$CHATID"

build_kernel || error=true

DATE=$(date +"%Y%m%d-%H%M%S")
KERVER=$(make kernelversion)

export IMG="$PWD"/out/arch/arm64/boot/Image.gz
export dtbo="$PWD"/out/arch/arm64/boot/dtbo.img
export dtb="$PWD"/out/arch/arm64/boot/dtb.img

# Cek apakah kernel berhasil dibuild
if [ -f "$IMG" ]; then
  echo -e "$green << Build completed in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds >> \n $white"

  # Clone AnyKernel
  echo -e "$green << Cloning AnyKernel from your repo >> \n $white"
  git clone --depth=1 "$AnyKernel" --single-branch -b "$AnyKernelbranch" zip

  echo -e "$yellow << Making kernel zip >> \n $white"
  cp -r "$IMG" "$dtbo" "$dtb" zip/

  pushd zip
  export ZIP="${KERNEL_NAME}-${KRNL_REL_TAG}-${CODENAME}"
  zip -r9 "$ZIP" * -x .git README.md LICENSE *placeholder

  # Sign kernel
  curl -sLo zipsigner-3.0.jar https://gitlab.com/itsshashanksp/zipsigner/-/raw/master/bin/zipsigner-3.0-dexed.jar
  java -jar zipsigner-3.0.jar "$ZIP".zip "$ZIP"-signed.zip

  # Upload kernel
  tg_post_msg "Kernel successfully compiled, uploading ZIP" "$CHATID"
  tg_post_build "$ZIP"-signed.zip "$CHATID"
  tg_post_msg "done" "$CHATID"

  popd
else
  # Send error n log to Telegram
  echo -e "$red << Failed to compile the kernel, check error log >>$white"
  tg_post_msg "Kernel failed to compile, uploading error log" "$CHATID"
  tg_error "error.log" "$CHATID"
  tg_post_msg "done" "$CHATID"
fi

# Bersihkan file sementara
rm -rf error.log out zip zipsigner-3.0.jar
exit
