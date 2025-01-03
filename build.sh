#!/bin/bash

set -o errexit
export GIT_SSL_NO_VERIFY=1

###########################################################
# Step 1. Prepare the buildroot, apply MbedTEE's patch to it
###########################################################
br_patch=`ls *.patch --sort=time | head -n 1`
if [ -z "$br_patch" ]; then
	echo "Error: buildroot patch do not exist"
	exit 1
fi
br_version=$(basename $br_patch .patch)
rm -rf buildroot buildroot-${br_version}
git clone https://git.busybox.net/buildroot buildroot-${br_version}
git -C buildroot-${br_version} checkout ${br_version}
patch --no-backup-if-mismatch -d buildroot-${br_version} -N -r /dev/null -p1 < ${br_patch}
mv buildroot-${br_version} buildroot

###########################################################
# Step 2. Config and Make the buildroot with $1 parameter
###########################################################
br_defconfig=mbedtee_qemu_virt_aarch64_defconfig
if [ "$1" == "aarch64" ]; then
	br_defconfig=mbedtee_qemu_virt_aarch64_defconfig
elif [ "$1" == "aarch32" ]; then
	br_defconfig=mbedtee_qemu_virt_arm_defconfig
elif [ "$1" == "riscv64" ]; then
	br_defconfig=mbedtee_qemu_virt_riscv64_linux_defconfig
elif [ "$1" == "riscv32" ]; then
	br_defconfig=mbedtee_qemu_virt_riscv32_linux_defconfig
elif [ "$1" == "mips32" ]; then
	br_defconfig=mbedtee_qemu_malta_mips32r2_defconfig
fi
cd buildroot && make ${br_defconfig} && make
cd -

###########################################################
# Step 3. Config and Make the QEMU
###########################################################
rm -rf qemu
git clone https://gitlab.com/qemu-project/qemu.git && \
cd qemu && git checkout stable-9.0 && ./configure --prefix=$(pwd)/output --enable-slirp \
	--target-list=mips64el-softmmu,mipsel-softmmu,aarch64-softmmu,arm-softmmu,riscv32-softmmu,riscv64-softmmu && \
make -j8 && make install
cd -

###########################################################
# Step 4. Run with QEMU - only if the $2 is "run"
###########################################################
if [ "$2" == "run" ]; then
	if [ "$1" == "aarch64" ]; then
		gnome-terminal -e "telnet 127.0.0.1 5555" --tab -t "LinuxREE"& gnome-terminal -e "telnet 127.0.0.1 5556" --tab -t "MbedTEE"& qemu/build/qemu-system-aarch64 -M virt -M secure=on,gic-version=3,virtualization=on -cpu cortex-a710 -smp 4 -m 2048 -device loader,file=buildroot/output/images/mbedtee.bin,addr=0x80000000,force-raw=on -device loader,file=buildroot/output/images/linux.dtb,addr=0x85F00000,force-raw=on -device loader,file=buildroot/output/images/Image,addr=0x86000000,force-raw=on -device loader,addr=0x80000000,cpu-num=0 -device loader,addr=0x80000000,cpu-num=1 -device loader,addr=0x80000000,cpu-num=2 -device loader,addr=0x80000000,cpu-num=3 -serial telnet::5555,server,nowait -serial telnet::5556,server,nowait
	elif [ "$1" == "aarch32" ]; then
		gnome-terminal -e "telnet 127.0.0.1 5555" --tab -t "LinuxREE"& gnome-terminal -e "telnet 127.0.0.1 5556" --tab -t "MbedTEE"& qemu/build/qemu-system-arm -M virt -M secure=on -cpu cortex-a15 -smp 4 -m 2048 -device loader,file=buildroot/output/images/mbedtee.bin,addr=0x80000000,force-raw=on -device loader,file=buildroot/output/images/linux.dtb,addr=0x85F00000,force-raw=on -device loader,file=buildroot/output/images/Image,addr=0x86008000,force-raw=on -device loader,addr=0x80000000,cpu-num=0 -device loader,addr=0x80000000,cpu-num=1 -device loader,addr=0x80000000,cpu-num=2 -device loader,addr=0x80000000,cpu-num=3 -serial telnet::5555,server,nowait -serial telnet::5556,server,nowait
	elif [ "$1" == "riscv64" ]; then
		gnome-terminal -e "telnet 127.0.0.1 6666" --tab -t "LinuxREE + MbedTEE"& qemu/build/qemu-system-riscv64 -M virt -smp 8 -m 4G -device loader,file=buildroot/output/images/fw_jump.bin,addr=0x86000000,force-raw=on -device loader,file=buildroot/output/images/Image,addr=0x86200000,force-raw=on -device loader,file=buildroot/output/images/mbedtee.bin,addr=0x80000000,force-raw=on -device loader,addr=0x80000000,cpu-num=0 -device loader,addr=0x80000000,cpu-num=1 -device loader,addr=0x80000000,cpu-num=2 -device loader,addr=0x80000000,cpu-num=3 -device loader,addr=0x86000000,cpu-num=4 -device loader,addr=0x86000000,cpu-num=5 -device loader,addr=0x86000000,cpu-num=6 -device loader,addr=0x86000000,cpu-num=7 -M aclint=on -nographic -serial telnet::6666,server,nowait
	elif [ "$1" == "riscv32" ]; then
		gnome-terminal -e "telnet 127.0.0.1 7777" --tab -t "LinuxREE + MbedTEE"& qemu/build/qemu-system-riscv32 -M virt -smp 8 -m 2G -device loader,file=buildroot/output/images/fw_jump.bin,addr=0x86000000,force-raw=on -device loader,file=buildroot/output/images/Image,addr=0x86400000,force-raw=on -device loader,file=buildroot/output/images/mbedtee.bin,addr=0x80000000,force-raw=on -device loader,addr=0x80000000,cpu-num=0 -device loader,addr=0x80000000,cpu-num=1 -device loader,addr=0x80000000,cpu-num=2 -device loader,addr=0x80000000,cpu-num=3 -M aclint=on -nographic -device loader,addr=0x86000000,cpu-num=4 -device loader,addr=0x86000000,cpu-num=5 -device loader,addr=0x86000000,cpu-num=6 -device loader,addr=0x86000000,cpu-num=7 -serial telnet::7777,server,nowait
	elif [ "$1" == "mips32" ]; then
		qemu/build/qemu-system-mipsel -M malta -m 1G -cpu 74Kf -kernel buildroot/output/images/mbedtee.elf -serial stdio
	fi
fi