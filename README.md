# poseidon

C and x86_64 implementation of [Poseidon](https://www.poseidon-hash.info/) hash permutation. 

## Parameters

Four instances of the Poseidon permutation are implemented with parameters provided by [StarkWare](https://starkware.co/):

- The base field is GF(p) with `p = 2^251 + 17 * 2^192 + 1`.
- The state size is of either 3, 4, 5 or 9 field elements.
- The round constants and MDS matrices are provided in the `parameters` folder.

## Building

- See the Makefile in `sources` folder.
- To build the x86_64 accelerated version, define the macro `ASSEMBLY`.
- The x86_64 accelerated version requires support of [Intel ADX instructions](https://en.wikipedia.org/wiki/Intel_ADX) (introduced since Broadwell architecture). Some safety nets are implemented during compilation and at runtime to detect if the current CPU (compiling or running the library) supports ADX, and a message should be emitted whenever this is not the case:
    
    ```
    $ make clean && make
    ...
    [-] Your CPU does not seem to support ADX ... The assembly version will not run here!
    ...
    
    $ ./test_asm
    [-] Sorry, but your CPU does not seem to support the necessary ADX extensions for the x86_64 ASSEMBLY backend!
    ```
    
- The non-assembly source comes in two flavours: a pure ISO C standard version and a version optimized for compilers with support of the `__int128` type (which should be the case for any recent `gcc` or `clang` version on 64-bit platforms (32-bit platforms do not define this type). The detection of the suitable version should be automatic (through preprocessing the the C files). In order to force the C standard version even though `__int128` is present, it is possible to use the `ISO_C=1 make` compilation toggle. For squeezing out the best performance of the C versions, we **strongly recommend** to use `clang`.
- The standard C and `__int128` versions aim to be endian neutral and compilable on non-x86 platforms. For instance, cross-compiling for ARM 64-bit `aarch64` on a Linux distro with the `aarch64-linux-gnu-gcc` cross-toolchain can be done with:
    
    ```
    $ make clean && CC=aarch64-linux-gnu-gcc make
    ```
    
- The Makefile also takes `EXTRA_CFLAGS` and `EXTRA_ASMFLAGS` as environment variables to add user defined options. You can also fully override `CFLAGS` and `CFLAGS_ASM` with the environment variables.

## Benchmark

Here are some benchmark for one Poseidon permutation with the different parameters on different platforms.

- On **Intel Core i5 (3,7 GHz)**, compiled with `clang-11`:
    - Assembly accelerated (`x86_64`) implementation:
        - n=3 : 0.005200 ms
        - n=4 : 0.005514 ms
        - n=5 : 0.006294 ms
        - n=9 : 0.009712 ms
    - Full C implementation with `__int128` support:
        - n=3 : 0.007688 ms
        - n=4 : 0.007980 ms
        - n=5 : 0.009948 ms
        - n=9 : 0.015312 ms
    - Full standard C implementation:
        - n=3 : 0.027122 ms
        - n=4 : 0.027054 ms
        - n=5 : 0.033934 ms
        - n=9 : 0.053316 ms
        
- On **AMD Ryzen 7 PRO 6850U (2.7GHz)**, compiled with `clang-18`:
    - Assembly accelerated (`x86_64`) implementation:
        - n=3 : 0.005538 ms (14952 cc)
        - n=4 : 0.005552 ms (14990 cc)
        - n=5 : 0.006554 ms (17695 cc)
        - n=9 : 0.009266 ms (25018 cc)
    - Full C implementation with `__int128` support:
        - n=3 : 0.007172 ms (19364 cc)
        - n=4 : 0.007368 ms (19893 cc)
        - n=5 : 0.008894 ms (24013 cc)
        - n=9 : 0.013496 ms (36439 cc)
    - Full standard C implementation:
        - n=3 : 0.021056 ms (56851 cc)
        - n=4 : 0.021060 ms (56862 cc)
        - n=5 : 0.026912 ms (72662 cc)
        - n=9 : 0.039712 ms (107222 cc)
        
- On **Apple M1 Pro**, compiled  with `clang-13`:
    - Full C implementation with `__int128` support:
        - n=3 : 0.009532 ms
        - n=4 :  0.009620 ms
        - n=5 : 0.011992 ms
        - n=9 : 0.018218 ms
    - Full standard C implementation:
        - n=3 : 0.025284 ms
        - n=4 : 0.026768 ms
        - n=5 : 0.033294 ms
        - n=9 : 0.049628 ms

## Implementation notes

- Integer values mod p are represented in Montgomery form and lie in the range [0,2^256) across the computation. They are put back to standard form and reduced to lie in [0,p) at the end of the computation.
- The MixLayer implementation takes advantage of the particular form of the MDS matrix (only 1's except on the diagonal).
- The AddRoundConstant implementation uses a tweak to remove n-1 constant additions for each partial round (a constant addition is only necessary for the cell of the state entering the s-box).

## Tests

Test scripts in Python/SageMath are provided in the folder `sage`. C functions are called using the [ctypes](https://docs.python.org/3/library/ctypes.html) library. See the Jupyter notebook `tests.ipynb` for how to run the tests.

For instance:

```python
load('poseidon.sage')
load('test_clib.sage')

print("=== TEST F251 C ===")
test_lib_f251('lib_pos.so')

print("\\n=== TEST F251 ASM ===")
test_lib_f251('lib_pos_asm.so')

print("\\n=== TEST POSEIDON C ===")
test_permutation('lib_pos.so')

print("\\n=== TEST POSEIDON ASM ===")
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

The assembly version has been tested under Linux, Mac OS and Windows (using the `x86_64-w64-mingw32-gcc` for cross-compilation in this last case, but any `GNUC` compiler targeting Windows should work). The standard C version should be portable across C compilers on any OS, and the C `__int128` version should be portable across `CGNUC` compilers supporting this type on any OS.

## Contact

Developed and maintained by [Matthieu Rivain](https://www.matthieurivain.com/)

## Acknowledgements

- Ilya Lesokhin (StarkWare): initial version of the Montgomery multiplication in assembly.
- Ryad Benadjila (CryptoExperts):  `__int128` version of the C code, cross-compilation & sanity checks.

## License 

This project is licensed under the terms of Apache License, Version 2.0
