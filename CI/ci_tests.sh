#!/bin/sh

set -e

## x86_64 target using the local host compiler and cross compilers
for c in gcc clang x86_64-w64-mingw32-gcc; do
	for iso_c in 0 1; do
		echo "=========== Compiling with $c compiler ISO_C=$iso_c\n\n\n"
		make clean && ISO_C="$iso_c" CC=$c EXTRA_CFLAGS="-DPERF_MEASUREMENT=100" make
		echo "\n\n\n=========== Testing compilation with $c compiler and ISO_C=$iso_c\n\n\n"
		if echo "$c" | grep -q "mingw"; then
			# Emulate with wine
			echo "============== (emulating with wine)"
			wine ./test.exe
			wine ./test_asm.exe
		else
			./test
			./test_asm
		fi
	done
done

## x86 32 bits targets
for c in i686-linux-gnu-gcc clang i686-w64-mingw32-gcc; do
	for iso_c in 0 1; do
		echo "=========== Compiling with $c compiler for x86 32 bits ISO_C=$iso_c\n\n\n"
		make clean && ISO_C="$iso_c" CC=$c EXTRA_CFLAGS="-DPERF_MEASUREMENT=100 -m32" make
		echo "\n\n\n=========== Testing compilation with $c (x86 32 bits) compiler and ISO_C=$iso_c\n\n\n"
		if echo "$c" | grep -q "mingw"; then
			# Emulate with wine
			echo "============== (emulating with wine)"
			wine ./test.exe
		else
			make clean && ISO_C="$iso_c" CC=$c EXTRA_CFLAGS="-DPERF_MEASUREMENT=100 -m32 -static" make test
			qemu-i386-static ./test
		fi
	done
done
	

## Non-x86 targets
echo "\n\n\n=========== Switching to cross-compilation of C variants for non-x86 platforms\n\n\n"
for c in arm-linux-gnueabi-gcc aarch64-linux-gnu-gcc sparc64-linux-gnu-gcc mips64-linux-gnuabi64-gcc mips64el-linux-gnuabi64-gcc riscv64-linux-gnu-gcc; do
	arch=`echo -n $c | cut -d'-' -f1`
	for iso_c in 0 1; do
		echo "=========== Compiling with $c compiler for architecture $arch and ISO_C=$iso_c\n\n\n"
		make clean && ISO_C="$iso_c" CC=$c EXTRA_CFLAGS="-DPERF_MEASUREMENT=100" make
		echo "\n\n\n=========== Testing compilation with $c compiler, architecture $arch and ISO_C=$iso_c\n\n\n"
		make clean && ISO_C="$iso_c" CC=$c EXTRA_CFLAGS="-DPERF_MEASUREMENT=100 -static" make test
		qemu-$arch-static ./test
	done
done

## ARM Cortex M MCU targets
## NOTE: we use some trick to force Qemu in semi-hosting mode to exit
awk '/#include/ && !done { print "#include \"CI/qemu_semihosting_exit.h\""; done=1;}; 1;' test.c > /tmp/test.c
sed -i 's/return 0;/    _exit_qemu();return 0;/' /tmp/test.c
mv /tmp/test.c test.c
make clean && CC="arm-none-eabi-gcc" EXTRA_CFLAGS="-DPERF_MEASUREMENT=10 -march=armv6-m -mtune=cortex-m0 -specs=picolibc.specs --oslib=semihost -TCI/cortexm_layout.ld -static" make test
qemu-system-arm -semihosting-config enable=on -monitor none -serial none -nographic -machine mps2-an385,accel=tcg -no-reboot -kernel ./test
make clean && CC="arm-none-eabi-gcc" EXTRA_CFLAGS="-DPERF_MEASUREMENT=10 -march=armv7-m -mtune=cortex-m3 -specs=picolibc.specs --oslib=semihost -TCI/cortexm_layout.ld -static" make test
qemu-system-arm -semihosting-config enable=on -monitor none -serial none -nographic -machine mps2-an385,accel=tcg -no-reboot -kernel ./test
