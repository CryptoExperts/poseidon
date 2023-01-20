load('low_level.sage')
import ctypes
from ctypes import *
import pathlib
import sys


###############################################################################
### C-Sage interface

def load_lib(libname='lib_pos.so'):
    # Load the shared library into ctypes
    libpath = pathlib.Path().absolute() / ('../sources/'+libname)
    c_lib = ctypes.CDLL(libpath)
    return c_lib

def int_to_c_buffer(x, n_words):
    X = int_to_words(x, n_words)
    c_x = (c_uint64 * len(X))(*X)
    return c_x

def c_buffer_to_int(c_x,n_words):
    X = [Integer(c_x[i]) for i in range(n_words)]
    x = words_to_int(X)
    return x

def null_c_buffer(n_words):
    c_x = int_to_c_buffer(0,n_words)
    return c_x

def random_c_buffer(n_words):
    x = randint(0,(2^WLEN)^n_words-1)
    c_x = int_to_c_buffer(x,n_words)
    return (x,c_x)

def random_c_state(size):
    p = 2^251 + 17 * 2^192 + 1
    #state = [randint(0,2^256-1) for i in range(size)]
    state = [randint(0,p) for i in range(size)]
    state_words = flatten([int_to_words(s,n=4) for s in state])
    c_state = (c_uint64 * len(state_words))(*state_words)
    return (state, c_state)

def int_state_to_c_state(state):
    state_words = flatten([int_to_words(s,n=4) for s in state])
    c_state = (c_uint64 * len(state_words))(*state_words)
    return c_state

def c_state_to_int_state(c_state,size):
    state_words = [Integer(c_state[i]) for i in range(size*4)]
    state_words_reshaped = [state_words[i*4: (i+1)*4] for i in range(size)]
    state = [words_to_int(s) for s in state_words_reshaped]
    return state

###############################################################################
### Tests for field functions

def test_f251_overflow_reduce(c_lib):
    
    for i in range(1000):

        x = randint(0,2^257-1)
        X = int_to_words(x,5)
        c_x = (c_uint64 * int(5))(*X)
        c_z = null_c_buffer(4)

        c_lib.f251_overflow_reduce(c_z,c_x)

        z = c_buffer_to_int(c_z,4)

        assert z %p == x %p
    
def test_f251_reduce(c_lib):
    
    for i in range(10000):
    
        (x,c_x) = random_c_buffer(8)
        c_z     = null_c_buffer(4)

        c_lib.f251_reduce(c_z,c_x)

        z = c_buffer_to_int(c_z,4)

        assert z %p == x %p
        
def test_f251_x_plus_minus_const_y(c_lib):
            
    for i in range(1000):
        
        (x,c_x) = random_c_buffer(4)
        (y,c_y) = random_c_buffer(4)
        c_xp1y  = null_c_buffer(4)
        c_xp2y  = null_c_buffer(4)
        c_xp3y  = null_c_buffer(4)
        c_xp4y  = null_c_buffer(4)
        c_xm1y  = null_c_buffer(4)
        c_xm2y  = null_c_buffer(4)
        c_xm3y  = null_c_buffer(4)
        c_xm4y  = null_c_buffer(4)
        
        try:

            # C version
            c_lib.f251_add(c_xp1y,c_x,c_y)
            c_lib.f251_x_plus_2y(c_xp2y,c_x,c_y)
            c_lib.f251_x_plus_3y(c_xp3y,c_x,c_y)
            c_lib.f251_x_plus_4y(c_xp4y,c_x,c_y)
            c_lib.f251_sub(c_xm1y,c_x,c_y)
            c_lib.f251_x_minus_2y(c_xm2y,c_x,c_y)
            c_lib.f251_x_minus_3y(c_xm3y,c_x,c_y)
            c_lib.f251_x_minus_4y(c_xm4y,c_x,c_y)
        
        except AttributeError:

            # ASM version
            c_lib.f251_add(c_xp1y,c_x,c_y)
            c_lib.f251_x_plus_c_times_y(c_xp2y,c_x,c_uint32(2),c_y)
            c_lib.f251_x_plus_c_times_y(c_xp3y,c_x,c_uint32(3),c_y)
            c_lib.f251_x_plus_c_times_y(c_xp4y,c_x,c_uint32(4),c_y)
            c_lib.f251_sub(c_xm1y,c_x,c_y)
            c_lib.f251_x_minus_c_times_y(c_xm2y,c_x,c_uint32(2),c_y)
            c_lib.f251_x_minus_c_times_y(c_xm3y,c_x,c_uint32(3),c_y)
            c_lib.f251_x_minus_c_times_y(c_xm4y,c_x,c_uint32(4),c_y)


        xp1y = c_buffer_to_int(c_xp1y,4) 
        xp2y = c_buffer_to_int(c_xp2y,4) 
        xp3y = c_buffer_to_int(c_xp3y,4)
        xp4y = c_buffer_to_int(c_xp4y,4)
        xm1y = c_buffer_to_int(c_xm1y,4)
        xm2y = c_buffer_to_int(c_xm2y,4)
        xm3y = c_buffer_to_int(c_xm3y,4)
        xm4y = c_buffer_to_int(c_xm4y,4)

        assert xp1y % p == (x + 1 * y) % p
        assert xp2y % p == (x + 2 * y) % p
        assert xp3y % p == (x + 3 * y) % p
        assert xp4y % p == (x + 4 * y) % p
        assert xm1y % p == (x - 1 * y) % p
        assert xm2y % p == (x - 2 * y) % p
        assert xm3y % p == (x - 3 * y) % p
        assert xm4y % p == (x - 4 * y) % p
    
def one_test_f251_montgomery(c_lib,x,y):

    c_x = int_to_c_buffer(x,4)
    c_y = int_to_c_buffer(y,4)

    c_mx  = null_c_buffer(4)
    c_my  = null_c_buffer(4)
    c_mxy = null_c_buffer(4)
    c_mz = null_c_buffer(4)

    c_xy  = null_c_buffer(4)
    c_z = null_c_buffer(4)

    c_lib.f251_to_montgomery(c_mx,c_x)
    c_lib.f251_to_montgomery(c_my,c_y)

    c_lib.f251_montgomery_mult(c_mxy,c_mx,c_my)
    
    # z = (x * y)^(3^6)
    c_lib.f251_montgomery_cube(c_mz,c_mxy)
    for i in range(5): 
        c_lib.f251_montgomery_cube(c_mz,c_mz)

    c_lib.f251_from_montgomery(c_xy,c_mxy)
    c_lib.f251_from_montgomery(c_z,c_mz)

    mx  = c_buffer_to_int(c_mx,  4)
    my  = c_buffer_to_int(c_my,  4)
    mxy = c_buffer_to_int(c_mxy, 4)
    mz  = c_buffer_to_int(c_mz,  4)
    xy  = c_buffer_to_int(c_xy,  4)
    z   = c_buffer_to_int(c_z,   4)

    expected_z = (x * y)^(3^6) % p

    assert mx % p == 2^256 * x % p
    assert my % p == 2^256 * y % p
    assert mxy % p == 2^256 * x * y % p
    assert mz % p ==  2^256 * expected_z % p
    assert xy % p == x*y % p
    assert z % p  == expected_z

def test_f251_montgomery(c_lib):

    # random tests
    for t in range(500):
        x = randint(0,2^256-1)
        y = randint(0,2^256-1)
        one_test_f251_montgomery(c_lib,x,y)
    
    # edge cases
    T = [0, 2^64, 2^128, 2^192, 2^256-1, p, p-1, p+1, 2*p, 4*p, 8*p, 16*p]
    for x in T:
        for y in T:
            mx  = x * 2^256 % p
            my  = y * 2^256 % p
            imx = x * 2^-256 % p
            imy = y * 2^-256 % p
            one_test_f251_montgomery(c_lib,x,y)
            one_test_f251_montgomery(c_lib,mx,my)
            one_test_f251_montgomery(c_lib,imx,imy)

def test_f251_sum_state(c_lib):

    # n = 3
    for t in range(10000):

        (state, c_state) = random_c_state(3)
        c_z  = null_c_buffer(4)
        c_lib.f251_sum_state_3(c_z,c_state)
        z = c_buffer_to_int(c_z, 4)
        assert z % p == sum(state) % p 

    # n = 4
    for t in range(10000):

        (state, c_state) = random_c_state(4)
        c_z1  = null_c_buffer(4)
        c_z2  = null_c_buffer(4)
        c_lib.f251_sum_state_4(c_z1,c_z2,c_state)
        z1 = c_buffer_to_int(c_z1, 4)
        z2 = c_buffer_to_int(c_z2, 4)
        assert z1 % p == sum(state) % p 
        assert z2 % p == (sum(state) - state[2]) % p

    # n = 5
    for t in range(10000):

        (state, c_state) = random_c_state(3)
        c_z  = null_c_buffer(4)
        c_lib.f251_sum_state_3(c_z,c_state)
        z = c_buffer_to_int(c_z, 4)
        assert z % p == sum(state) % p 
    
    # n = 9
    for t in range(10000):

        (state, c_state) = random_c_state(9)
        c_z1  = null_c_buffer(4)
        c_z2  = null_c_buffer(4)
        c_lib.f251_sum_state_9(c_z1,c_z2,c_state)
        z1 = c_buffer_to_int(c_z1, 4)
        z2 = c_buffer_to_int(c_z2, 4)
        assert z1 % p == sum(state) % p 
        assert z2 % p == (sum(state) - state[8]) % p    

def test_lib_f251(libname):

    c_lib = load_lib(libname)
    
    print("Test add, sub, x +/- {2,3,4}*y, ...")
    test_f251_x_plus_minus_const_y(c_lib)
    print("OK")
    print("Test Montgomery ...")
    test_f251_montgomery(c_lib)
    print("OK")
    print("Test sum state ...")
    test_f251_sum_state(c_lib)
    print("OK")
    print("youpi!")


###############################################################################
### Tests for Poseidon functions    

def reduce_state(state):
    return [s % p for s in state]
    
def mix_layer(state):
    assert len(state) in [3,4,5,9]
    f251_in_state = field_vector(F251,state)
    if len(state) == 3:
        mat = Poseidon3.mds
    elif len(state) == 4:
        mat = Poseidon4.mds
    elif len(state) == 5:
        mat = Poseidon5.mds
    elif len(state) == 9:
        mat = Poseidon9.mds
    f251_out_state = mat * f251_in_state
    out_state = [Integer(e) for e in f251_out_state]
    return out_state

def test_mix_layer(libname):

    c_lib = load_lib(libname)

    # mix_layer_3
    
    for i in range(10000):

        (in_state, c_state) = random_c_state(3)
        c_lib.mix_layer_3(c_state)
        out_state = c_state_to_int_state(c_state,3)

        assert reduce_state(out_state) == reduce_state(mix_layer(in_state))

    # mix_layer_4
    
    for i in range(5000):

        (in_state, c_state) = random_c_state(4)
        c_lib.mix_layer_4(c_state)
        out_state = c_state_to_int_state(c_state,4)

        assert reduce_state(out_state) == reduce_state(mix_layer(in_state))

    # mix_layer_5
    
    for i in range(2000):

        (in_state, c_state) = random_c_state(5)
        c_lib.mix_layer_5(c_state)
        out_state = c_state_to_int_state(c_state,5)

        assert reduce_state(out_state) == reduce_state(mix_layer(in_state))

    # mix_layer_9
    
    for i in range(1000):

        (in_state, c_state) = random_c_state(9)
        c_lib.mix_layer_9(c_state)
        out_state = c_state_to_int_state(c_state,9)

        assert reduce_state(out_state) == reduce_state(mix_layer(in_state))
   
def test_permutation(libname):

    c_lib = load_lib(libname)

    # permutation_3

    print("Test permutation_3 ...")
    
    for i in range(1000):

        (in_state, c_state) = random_c_state(3)
        c_lib.permutation_3(c_state)
        out_state = c_state_to_int_state(c_state,3)

        assert [s for s in out_state] == [s for s in P3(in_state)]

    print("OK")

    # permutation_4

    print("Test permutation_4 ...")
    
    for i in range(1000):

        (in_state, c_state) = random_c_state(4)
        c_lib.permutation_4(c_state)
        out_state = c_state_to_int_state(c_state,4)

        assert [s for s in out_state] == [s for s in P4(in_state)]

    print("OK")

    # permutation_5

    print("Test permutation_5 ...")
    
    for i in range(1000):

        (in_state, c_state) = random_c_state(5)
        c_lib.permutation_5(c_state)
        out_state = c_state_to_int_state(c_state,5)

        assert [s for s in out_state] == [s for s in P5(in_state)]

    print("OK")

    # permutation_9

    print("Test permutation_9 ...")
    
    for i in range(1000):

        (in_state, c_state) = random_c_state(9)
        c_lib.permutation_9(c_state)
        out_state = c_state_to_int_state(c_state,9)

        assert [s for s in out_state] == [s for s in P9(in_state)]

    print("OK")
    print("youpi!")


###############################################################################
### Debug rountines
    
def check_reduced_state(c_state,f251_state,label):
    
    n = len(f251_state)
    
    montgomery_state = c_state_to_int_state(c_state,n)
    reduced_state = [(s * 2^-256) % p for s in montgomery_state]
    expected_state = [Integer(s) for s in f251_state]
    
    if (reduced_state != expected_state):
        
        print('Error after '+label)
        print('State (C, Montgomery form): ', montgomery_state)
        print('State (reduced): ', reduced_state)
        print('State (expected): ', expected_state)
        
    assert reduced_state == expected_state


def c_ulong_pointer_add(c_pointer, i):
    void_p = ctypes.cast(c_pointer, ctypes.c_voidp).value
    c_pointer_i = ctypes.cast(void_p+int(i), ctypes.POINTER(ctypes.c_ulong))
    return c_pointer_i


# debug_round (and debug_poseidon) calls the C functions called in each round
# while debug_round_macro (and debug_poseidon_macro) calls the C function computing a round 
    
def debug_round(PARAMS,r,rc_idx,VARIANT_RC,is_full,f251_state,c_lib,c_state):
    
    n = PARAMS.m
  
    # AddRoundConstant + SubWords
    
    if is_full:

        for i in range(n-1):
            
            f251_state[i] += F251(VARIANT_RC[rc_idx])
            c_rc = int_to_c_buffer((2^256 * VARIANT_RC[rc_idx])%p,4)
            c_state_i = c_ulong_pointer_add(c_state,i*4*8)
            c_lib.f251_add(c_state_i, c_state_i, c_rc)
            rc_idx += 1
            
            check_reduced_state(c_state,f251_state,'Round '+str(r)+' > AddRoundConstant state['+str(i)+']')

        
        for i in range(n-1):
            f251_state[i] = f251_state[i]^3
            c_state_i = c_ulong_pointer_add(c_state,i*4*8)
            c_lib.f251_montgomery_cube(c_state_i, c_state_i)
            
            check_reduced_state(c_state,f251_state,'Round '+str(r)+' > SubWords state['+str(i)+']')
            
    f251_state[n-1] += F251(VARIANT_RC[rc_idx])
    c_rc = int_to_c_buffer((2^256 * VARIANT_RC[rc_idx])%p,4)
    c_state_i = c_ulong_pointer_add(c_state,(n-1)*4*8)
    c_lib.f251_add(c_state_i, c_state_i, c_rc)
    rc_idx += 1

    check_reduced_state(c_state,f251_state,'Round '+str(r)+' > AddRoundConstant state['+str(n-1)+']')

    
    f251_state[-1] = f251_state[-1]^3
    c_lib.f251_montgomery_cube(c_state_i, c_state_i)
    
    check_reduced_state(c_state,f251_state,'Round '+str(r)+' > SubWords state['+str(n-1)+']')

    
    # MixLayer   
    if   n == 3:
        c_lib.mix_layer_3(c_state)
    elif n == 4:
        c_lib.mix_layer_4(c_state)
    elif n == 5:
        c_lib.mix_layer_5(c_state)
    elif n == 9:
        c_lib.mix_layer_9(c_state)

    f251_state = PARAMS.mds * f251_state

    check_reduced_state(c_state,f251_state,'Round '+str(r)+' > MixLayer')

    return (r,rc_idx,f251_state)
    
     
def debug_poseidon(libname='lib_pos.so', n=3, state=None):
    
    p = 2^251 + 17 * 2^192 + 1    
    assert n in [3,4,5,9]
    
    PARAMS = get_params(n)
    VARIANT_RC = get_variant_round_cst(n)

    c_lib = load_lib(libname)

    # pick a random state if not specified
    if state == None:
        state = [randint(0,p) for i in range(n)]
    
    # init c state (for C) and f251 state (for Sage)
    c_state = int_state_to_c_state(state)
    f251_state = field_vector(F251,state)

    # expected final state
    if   n == 3:
        final_state = [s for s in P3(state)]
    elif n == 4:
        final_state = [s for s in P4(state)]
    elif n == 5:
        final_state = [s for s in P5(state)]
    elif n == 9:
        final_state = [s for s in P9(state)]
    
    # initial convertion to Montgomery form
    c_lib.state_to_montgomery(c_state, int(n))
    check_reduced_state(c_state,f251_state,'state_to_montgomery')
    
    r = 0
    rc_idx = 0
    
    # first full rounds
    is_full = True
    for i in range(PARAMS.Rf/2):
        (r,rc_idx,f251_state) = debug_round(PARAMS,r,rc_idx,VARIANT_RC,is_full,f251_state,c_lib,c_state)
        
    # partial rounds
    is_full = False
    for i in range(PARAMS.Rp):
        (r,rc_idx,f251_state) = debug_round(PARAMS,r,rc_idx,VARIANT_RC,is_full,f251_state,c_lib,c_state)

    # last full rounds
    is_full = True
    for i in range(PARAMS.Rf/2):
        (r,rc_idx,f251_state) = debug_round(PARAMS,r,rc_idx,VARIANT_RC,is_full,f251_state,c_lib,c_state)
        
    # back from Montgomery
    c_lib.state_from_montgomery(c_state, int(n))

    state = c_state_to_int_state(c_state,n)
    expected_state = [Integer(s) for s in f251_state]
    
    if (state != expected_state):
        
        print('Error after state_from_montgomery')
        print('State: ', state)
        print('State (expected): ', expected_state)
        
    assert state == expected_state
    assert state == final_state
     
def debug_round_macro(PARAMS,r,rc_idx,VARIANT_RC,is_full,f251_state,c_lib,c_state):
    
    n = PARAMS.m
    
    if is_full:
        
        f251_state += vector(VARIANT_RC[rc_idx:rc_idx+n])
        f251_state = vector([s^3 for s in f251_state])
        f251_state = PARAMS.mds * f251_state

        if   n == 3:
            c_lib.round_3(c_state,int(rc_idx),c_ubyte(0xF))
        elif n == 4:
            c_lib.round_4(c_state,int(rc_idx),c_ubyte(0xF))
        elif n == 5:
            c_lib.round_5(c_state,int(rc_idx),c_ubyte(0xF))
        elif n == 9:
            c_lib.round_9(c_state,int(rc_idx),c_ubyte(0xF))

        rc_idx += n
        r += 1
        
    else:

        f251_state[-1] += VARIANT_RC[rc_idx]
        f251_state[-1] = f251_state[-1]^3
        f251_state = PARAMS.mds * f251_state
        
        if   n == 3:
            c_lib.round_3(c_state,int(rc_idx),c_ubyte(0x1))
        elif n == 4:
            c_lib.round_4(c_state,int(rc_idx),c_ubyte(0x1))
        elif n == 5:
            c_lib.round_5(c_state,int(rc_idx),c_ubyte(0x1))
        elif n == 9:
            c_lib.round_9(c_state,int(rc_idx),c_ubyte(0x1))

        rc_idx += 1
        r += 1
    
    check_reduced_state(c_state,f251_state,'Round '+str(r))

    return (r,rc_idx,f251_state)

        
def debug_poseidon_macro(libname='lib_pos.so', n=3, state=None):
    
    p = 2^251 + 17 * 2^192 + 1    
    assert n in [3,4,5,9]
    
    PARAMS = get_params(n)
    VARIANT_RC = get_variant_round_cst(n)

    c_lib = load_lib(libname)   

    # pick a random state if not specified
    if state == None:
        state = [randint(0,p) for i in range(n)]
    
    # init c state (for C) and f251 state (for Sage)
    c_state = int_state_to_c_state(state)
    f251_state = field_vector(F251,state)

    # expected final state
    if   n == 3:
        final_state = [s for s in P3(state)]
    elif n == 4:
        final_state = [s for s in P4(state)]
    elif n == 5:
        final_state = [s for s in P5(state)]
    elif n == 9:
        final_state = [s for s in P9(state)]
    
    # initial convertion to Montgomery form
    c_lib.state_to_montgomery(c_state, int(n))
    check_reduced_state(c_state,f251_state,'state_to_montgomery')
    
    r = 0
    rc_idx = 0
    
    # first full rounds
    is_full = True
    for i in range(PARAMS.Rf/2):
        (r,rc_idx,f251_state) = debug_round_macro(PARAMS,r,rc_idx,VARIANT_RC,is_full,f251_state,c_lib,c_state)

    # partial rounds
    is_full = False
    for i in range(PARAMS.Rp):
        (r,rc_idx,f251_state) = debug_round_macro(PARAMS,r,rc_idx,VARIANT_RC,is_full,f251_state,c_lib,c_state)

    # last full rounds
    is_full = True
    for i in range(PARAMS.Rf/2):
        (r,rc_idx,f251_state) = debug_round_macro(PARAMS,r,rc_idx,VARIANT_RC,is_full,f251_state,c_lib,c_state)

    # back from Montgomery
    c_lib.state_from_montgomery(c_state, int(n))

    state = c_state_to_int_state(c_state,n)
    expected_state = [Integer(s) for s in f251_state]
    
    if (state != expected_state):
        
        print('Error after state_from_montgomery')
        print('State: ', state)
        print('State (expected): ', expected_state)
        
    assert state == expected_state
    assert state == final_state
    

    