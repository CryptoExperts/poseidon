p = 2^251 + 17 * 2^192 + 1

########################################################
# Word definitions

CARRY = 0
OVERFLOW = 0
WLEN = 64

def assert_word(X):
    global WLEN
    assert 0 <= X < 2^WLEN

def assert_double(X):
    global WLEN
    assert 0 <= X < 2^(2*WLEN)

def int_to_words(x, n=None):
    global WLEN
    X = Integer(x).digits(base=2^WLEN)
    if n == None:
        return X
    else:
        assert n >= len(X)
        return X + [0]*(n-len(X))
    
def words_to_int(X):
    global WLEN
    return sum([2^(WLEN*i)*X[i] for i in range(len(X))])

def i2w(x):
    return int_to_words(x)

def w2i(X):
    return words_to_int(X)

########################################################
# Low-level instructions

def ADD(X,Y):
    global WLEN, CARRY, OVERFLOW
    assert_word(X)
    assert_word(Y)
    T = X+Y
    CARRY = T >> WLEN
    OVERFLOW = CARRY
    Z = T % 2^WLEN
    assert_word(Z)
    return Z
    
def ADDC(X,Y):
    global WLEN, CARRY
    assert_word(X)
    assert_word(Y)
    T = X+Y+CARRY
    CARRY = T >> WLEN
    Z = T % 2^WLEN
    assert_word(Z)
    return Z
        
def ADDO(X,Y):
    global WLEN, OVERFLOW
    assert_word(X)
    assert_word(Y)
    T = X+Y+OVERFLOW
    OVERFLOW = T >> WLEN
    Z = T % 2^WLEN
    assert_word(Z)
    return Z

def SUB(X,Y):
    global WLEN, CARRY
    assert_word(X)
    assert_word(Y)
    T = X-Y+2^WLEN
    CARRY = (T >> WLEN) ^^ 1
    Z = T % 2^WLEN
    assert_word(Z)
    return Z

def SUBB(X,Y):
    global WLEN, CARRY
    assert_word(X)
    assert_word(Y)
    T = X-(Y+CARRY)+2^WLEN
    CARRY = (T >> WLEN) ^^ 1
    Z = T % 2^WLEN
    assert_word(Z)
    return Z

def MUL(X,Y):
    global WLEN, CARRY
    assert_word(X)
    assert_word(Y)
    T = X*Y
    ZH = T >> WLEN
    ZL = T % 2^WLEN
    assert_word(ZH)
    assert_word(ZL)
    return [ZL,ZH]

########################################################
# Multi-precision functions

def assert_words(X):
    assert type(X) == list
    for w in X:
        assert_word(w)

# addition
# l words + l words -> l+1 words
# the ms word of the result is the carry

def add(X,Y):
    global CARRY
    assert_words(X)
    assert_words(Y)
    assert len(X) == len(Y)
    lenZ = len(X)+1
    Z = [None]*(lenZ)
    Z[0] = ADD(X[0],Y[0])
    for i in range(1,lenZ-1):
        Z[i] = ADDC(X[i],Y[i])
    Z[lenZ-1] = CARRY
    return Z

# subtraction
# l words + l words -> l words
# the final borrow remains in the CARRY flag

def sub(X,Y):
    global CARRY
    assert_words(X)
    assert_words(Y)
    assert len(X) == len(Y)
    lenZ = len(X)
    Z = [None]*(lenZ)
    Z[0] = SUB(X[0],Y[0])
    for i in range(1,lenZ):
        Z[i] = SUBB(X[i],Y[i])
    return Z
    

########################################################
# Montgomery multiplication

# perform one round of Montgomery multiplication mod p
# 1. Z += xi * Y
# 2. u = - Z[0] * p^-1 mod 2^64 = - Z[0] mod 2^64
# 3. Z += u * p

def mong_round(Z, Y, xi):
    
    global WLEN, CARRY, OVERFLOW
    
    assert WLEN == 64
    assert_words(Z)
    assert_words(Y)
    assert_word(xi)
    assert len(Z) == 5
    assert len(Y) == 4
    
    # - Step 1 -
    # Z += xi * Y
    
    CARRY = 0
    OVERFLOW = 0
    
    T = MUL(xi, Y[0])
    Z[0] = ADDC (Z[0],T[0])
    Z[1] = ADDO (Z[1],T[1])
    
    T = MUL(xi, Y[1])
    Z[1] = ADDC (Z[1],T[0])
    Z[2] = ADDO (Z[2],T[1])
    
    T = MUL(xi, Y[2])
    Z[2] = ADDC (Z[2],T[0])
    Z[3] = ADDO (Z[3],T[1])
    
    T = MUL(xi, Y[3])
    Z[3] = ADDC (Z[3],T[0])
    Z[4] = ADDO (Z[4],T[1])
    
    Z[4] = ADDC (Z[4],0)
    
    assert CARRY == 0
    assert OVERFLOW == 0
    
    # - Step 2 - 
    # u = - Z[0] mod 2^64
    
    u = - Z[0] % 2^WLEN
    
    # - Step 3 - 
    # Z += u * p
    
    T = MUL(u,2^59+17)
    
    Z[0] = ADD (Z[0], u)
    Z[1] = ADDC(Z[1], 0)
    Z[2] = ADDC(Z[2], 0)
    Z[3] = ADDC(Z[3], T[0])
    Z[4] = ADDC(Z[4], T[1])
    
    assert CARRY == 0
    
    return Z
    
    
# Montgomery multiplication mod p
# takes X and Y, 4-word integers
# returns a 4-word integer Z = X * Y * 2^-256 mod p

def f251_mong_mult(X,Y):

    assert WLEN == 64
    assert_words(X)
    assert_words(Y)
    assert len(X) == 4
    assert len(Y) == 4
    
    Z = [0]*8
    
    Z[0:5] = mong_round(Z[0:5],Y,X[0])
    Z[1:6] = mong_round(Z[1:6],Y,X[1])
    Z[2:7] = mong_round(Z[2:7],Y,X[2])
    Z[3:8] = mong_round(Z[3:8],Y,X[3])
    
    return Z[4:]


# Turns X to Montgomery form
# takes a 4-word intger X 
# returns the 4-word integer Mon(X) = X * 2^256 mod p
# simply Montgomery-mulmtiplies X by Mon(2^256) = ((2^256)^2 mod p)

def f251_to_mong(X):
    
    MONG_2256 = [0xfffffd737e000401, 0x1330fffff, 0xffffffffff6f8000, 0x7ffd4ab5e008810]
    
    MX = f251_mong_mult(X, MONG_2256)

    return MX
   
# Turns Mon(X) to standard form
# takes a 4-word intger Mon(X)
# returns the 4-word integer X
# simply Montgomery-mulmtiplies X by Mon(2^-256) = 1

def f251_from_mong(MX):
    
    X = f251_mong_mult(MX, [1,0,0,0])
    
    return X

########################################################
# Test functions
    
def one_test_montgomery(x,y):

    X = int_to_words(x,n=4)
    Y = int_to_words(y,n=4)

    MX  = f251_to_mong(X)
    MY  = f251_to_mong(Y)
    MXY = f251_mong_mult(MX,MY)
    XY  = f251_from_mong(MXY)

    assert w2i(MX) % p == 2^256 * x % p
    assert w2i(MY) % p == 2^256 * y % p
    assert w2i(MXY)% p == 2^256 * x * y % p
    assert w2i(XY) % p == x*y % p
    
def test_montgomery():
    
    assert WLEN == 64
    
    # random tests
    for t in range(1000):
        x = randint(0,2^256-1)
        y = randint(0,2^256-1)
        one_test_montgomery(x,y)
    
    # edge cases
    T = [0, 2^64, 2^128, 2^192, 2^256-1, p, p-1, p+1, 2*p, 4*p, 8*p, 16*p]
    for x in T:
        for y in T:
            mx  = x * 2^256 % p
            my  = y * 2^256 % p
            imx = x * 2^-256 % p
            imy = y * 2^-256 % p
            one_test_montgomery(x,y)
            one_test_montgomery(mx,my)
            one_test_montgomery(imx,imy)