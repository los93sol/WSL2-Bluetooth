cd ~
apt update
apt install -y git build-essential bc dwarves flex bison libssl-dev libelf-dev libncurses-dev autoconf libudev-dev libtool
branch_list=$(git ls-remote --refs https://github.com/microsoft/WSL2-Linux-Kernel.git)
kernel_version=$(uname -r | awk -F. '{print $1"."$2}')
branch_name=$(echo "$branch_list" | grep -Eo "refs/heads/linux-msft-wsl-$kernel_version[^[:space:]]*" | sed 's/refs\/heads\///')
if [[ -z "$branch_name" ]]; then
    echo "No matching branch found for kernel version $kernel_version"
    exit 1
fi
if [ -d "WSL2-Linux-Kernel" ]; then
    echo "Pulling WSL2-Linux-Kernel branch $branch_name"
    cd WSL2-Linux-Kernel
    git pull
else
    echo "Cloning WSL2-Linux-Kernel branch $brach_name"
    git clone --branch $branch_name --depth 1 --single-branch https://github.com/microsoft/WSL2-Linux-Kernel.git
    cd WSL2-Linux-Kernel
fi

cp /proc/config.gz config.gz
gunzip config.gz
mv config .config
echo -e "CONFIG_BT=y\nCONFIG_BT_HCIBTUSB=y\nCONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT=y\nCONFIG_DEBUG_INFO_DWARF4=n\nCONFIG_DEBUG_INFO_DWARF5=n\n" >> .config
echo "Compiling kernel, this will take a long time"
yes "n" | make -j$(getconf _NPROCESSORS_ONLN) && sudo make modules_install -j$(getconf _NPROCESSORS_ONLN) && sudo make install -j$(getconf _NPROCESSORS_ONLN)
echo "Copying arch/x86/boot/bzImage to $1/bluetooth-bzImage"
cp arch/x86/boot/bzImage $1/bluetooth-bzImage
