# poseidon

C and x86_64 implementation of Poseidon hash function.

## Building

- See the Makefile in `sources` folder.
- To build the x86_64 accelerated version, define the macro ASSEMBLY.
- The x86_64 accelerated version requires support of [Intel ADX instructions](https://en.wikipedia.org/wiki/Intel_ADX) (introduced since Broadwell architecture). Some safety nets are implemented during compilation and at runtime to detect if the current CPU (compiling or running the library) supports ADX, and a message should be emitted whenever this is not the case:
```
$ make clean && make
...
[-] Your CPU does not seem to support ADX ... The assembly version will not run here!
...

$ ./test_asm
[-] Sorry, but your CPU does not seem to support the necessary ADX extensions for the x86_64 ASSEMBLY backend!
```

- The non-assembly source comes in two flavours: a pure ISO C standard version and a version optimized for compilers with support of the `__int128` type (which should be the case for any recent `gcc` or `clang` version on 64-bit platforms (32-bit platforms do not define this type). The detection of the suitable version should be automatic (through preprocessing the the C files). In order to force the C stadard version even though `__int128` is present, it is possible to use the `ISO_C=1 make` compilation toggle. For squeezing out the best performance of the C versions, we **strongly recommend** to use `clang`.
- The standard C and `__int128` versions should be endian neutral, and should be compilable on non-x86 platforms. For instance, cross-compiling for ARM 64-bit `aarch64` on a Linux distro with the `aarch64-linux-gnu-gcc` cross-toolchain is as simple as:

```
$ make clean && CC=aarch64-linux-gnu-gcc make
```

The `Makefile` also takes `EXTRA_CFLAGS` and `EXTRA_ASMFLAGS` as environement variables to add user defined options. You can also fully override `CFLAGS` and `CFLAGS_ASM` with the environment variables.

The assembly version has been tested under Linux, Mac OS and Windows (using the `x86_64-w64-mingw32-gcc` for cross-compilation in this last case, but any `GNUC` compiler targetting Windows should do the trick). The standard C version should be portable across all decent C compilers on all OSes, and the C `__int128` version should be portable across `CGNUC` compilers supporting this type on all OSes as well.

## First report

- For the modular reduction, I've compared Barrett and Montgomery. The former was significantly slower in C and after some investigation I figured there was no way it would give better results in assembly, so I went with Montgomery. (I also considered sparse-modulus reduction such as Solinas, but it is not interesting for our prime).
- For the Montgomery multiplication, I reused the x86_64 code shared by Ilya with a tweak -namely an additional overflow reduction- to support two operands on [0,2^256) (while the original code requires one operand on [0,p)).
- For the MixLayer implementation, I've taken advantage of the particular form of the MDS matrix (only 1's except on the diagonal). The idea is to sum all the coordinates of the input vector, then each output coordinate equals this sum plus a small multiple of an input coordinate.
- For the AddRoundConstant, I’ve used a tweak which removes n-1 constant additions for each partial round (a constant addition is only necessary for the cell of the state entering the s-box).
- Here are some benchmarks for one Poseidon permutation on an AMD Ryzen 7 PRO 6850U (2.7GHz) compiled with `clang-18`:
    - Full standard C implementation:
        - n=3 : 0.021056 ms (56851 cc)
        - n=4 : 0.021060 ms (56862 cc)
        - n=5 : 0.026912 ms (72662 cc)
        - n=9 : 0.039712 ms (107222 cc)

   - Full C implementation with `__int128` support:
        - n=3 : 0.007172 ms (19364 cc)
        - n=4 : 0.007368 ms (19893 cc)
        - n=5 : 0.008894 ms (24013 cc)
        - n=9 : 0.013496 ms (36439 cc)
        
    - Assembly accelerated implementation (the chosen AMD CPU supports the `ADX` instructions set):
        - n=3 : 0.005538 ms (14952 cc)
        - n=4 : 0.005552 ms (14990 cc)
        - n=5 : 0.006554 ms (17695 cc)
        - n=9 : 0.009266 ms (25018 cc)
        
    This makes between 84 (for n=9) and 155 (for n=3) cycles per byte.

## Tests

Test scripts in Python/SageMath are provided in the folder `sage`. C functions are called using the [ctypes](https://docs.python.org/3/library/ctypes.html) library. See the Jupyter notebook `tests.ipynb` for how to run the tests.

For instance:

```python
load('poseidon.sage')
load('test_clib.sage')

print("=== TEST F251 C ===")
test_lib_f251('lib_pos.so')

print("\n=== TEST F251 ASM ===")
test_lib_f251('lib_pos_asm.so')

print("\n=== TEST POSEIDON C ===")
test_permutation('lib_pos.so')

print("\n=== TEST POSEIDON ASM ===")
test_permutation('lib_pos_asm.so')
```

should produce:

```
=== TEST F251 C ===
Test add, sub, x +/- {2,3,4}*y, ...
OK
Test Montgomery ...
OK
Test sum state ...
OK
youpi!

=== TEST F251 ASM ===
Test add, sub, x +/- {2,3,4}*y, ...
OK
Test Montgomery ...
OK
Test sum state ...
OK
youpi!

=== TEST POSEIDON C ===
Test permutation_3 ...
OK
Test permutation_4 ...
OK
Test permutation_5 ...
OK
Test permutation_9 ...
OK
youpi!

=== TEST POSEIDON ASM ===
Test permutation_3 ...
OK
Test permutation_4 ...
OK
Test permutation_5 ...
OK
Test permutation_9 ...
OK
youpi!
```

## Still to be done

* Document entry points in `f251.h` and `poseidon.h`
* optimize context saving/restoring

## Contact

[matthieu.rivain@cryptoexperts.com](mailto:matthieu.rivain@cryptoexperts.com)
