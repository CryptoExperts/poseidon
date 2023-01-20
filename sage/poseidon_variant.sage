load('poseidon.sage')

def get_partial_round_cst(n):
    
    # this function evaluate the symbolic expressions of s-box inputs in partial rounds
    # for now we only use it to get the "partial round constants"
    
    if n == 3:
        PARAMS = P3_PARAMS
    elif n == 4:
        PARAMS = P4_PARAMS
    elif n == 5:
        PARAMS = P5_PARAMS
    elif n == 9:
        PARAMS = P9_PARAMS

    # will be filled with symbolic expressions of s-box inputs in partial rounds
    SBOX_IN = []
    
    # the first n variables are the outputs of the s-box from the last full round
    # the next Rp varaibles are the outputs of the s-box from the partial rounds
    NBVAR = n + PARAMS.Rp
 
    # symbolic variables (s-box putputs)
    s = PolynomialRing(F251, NBVAR, ['s'+str(i) for i in range(NBVAR)]).gens()

    # index of the next symbolic variable to be used as s-box output
    sbox_out_idx = n

    # state for check evaluation
    state_check = field_vector(F251,[0]*n)

    # === initial full rounds but last ==
    r = 0
    for i in range(PARAMS.Rf/2-1):
        state_check += PARAMS.ark[r]
        state_check = vector([s^3 for s in state_check])
        state_check = PARAMS.mds * state_check
        r += 1

    # === last initial full round ===
    assert r == PARAMS.Rf/2-1
    # check evaluation
    state_check += PARAMS.ark[r]
    state_check = vector([s^3 for s in state_check])
    state_check = PARAMS.mds * state_check
    # symbolic state
    state = vector(s[:n])
    state = PARAMS.mds * state
    r += 1

    # === partial rounds ===
    for i in range(PARAMS.Rp):
        # check evaluation
        state_check += PARAMS.ark[r]
        state_check[-1] = state_check[-1]^3
        state_check = PARAMS.mds * state_check
        # symbolic state
        state += PARAMS.ark[r]
        SBOX_IN += [state[-1]]
        state[-1] = s[sbox_out_idx]
        sbox_out_idx += 1
        state = PARAMS.mds * state
        r += 1

    # === final full rounds
    # symbolic state
    state += PARAMS.ark[r]
    SBOX_IN += [s for s in state]
    # check evaluation
    for i in range(PARAMS.Rf/2):
        state_check += PARAMS.ark[r]
        state_check = vector([s^3 for s in state_check])
        state_check = PARAMS.mds * state_check
        r += 1
    
    # verify correctness of check evaluation 
    if n == 3:
        assert state_check == P3([0,0,0])
    elif n == 4:
        assert state_check == P4([0,0,0,0])
    elif n == 5:
        assert state_check == P5([0,0,0,0,0])
    elif n == 9:
        assert state_check == P9([0,0,0,0,0,0,0,0,0])
    
    # extract "partial round constants" from symbolic expressions
    PARTIAL_ROUND_CST = [sbi.coefficients()[-1] for sbi in SBOX_IN]
    
    return PARTIAL_ROUND_CST

def get_variant_round_cst(n):
    
    if n == 3:
        PARAMS = P3_PARAMS
    elif n == 4:
        PARAMS = P4_PARAMS
    elif n == 5:
        PARAMS = P5_PARAMS
    elif n == 9:
        PARAMS = P9_PARAMS
        
    PARTIAL_RC = get_partial_round_cst(n)
    INIT_FULL_RC = flatten([[cst for cst in csts] for csts in PARAMS.ark[:PARAMS.Rf/2]])
    FINAL_FULL_RC = flatten([[cst for cst in csts] for csts in PARAMS.ark[-(PARAMS.Rf/2-1):]])
    
    VARIANT_RC = INIT_FULL_RC + PARTIAL_RC + FINAL_FULL_RC
    
    return VARIANT_RC
    

def poseidon_variant(PARAMS,VARIANT_RC,state):
    
    state = field_vector(F251,state)
    n = PARAMS.m
    r = 0
    rc_idx = 0

    for i in range(PARAMS.Rf/2):

        state += vector(VARIANT_RC[rc_idx:rc_idx+n])
        rc_idx += n
        state = vector([s^3 for s in state])
        state = PARAMS.mds * state
        r += 1

    for i in range(PARAMS.Rp):

        state[-1] += VARIANT_RC[rc_idx]
        rc_idx += 1
        state[-1] = state[-1]^3
        state = PARAMS.mds * state
        r += 1
        
    for i in range(PARAMS.Rf/2):

        state += vector(VARIANT_RC[rc_idx:rc_idx+n])
        rc_idx += n
        state = vector([s^3 for s in state])
        state = PARAMS.mds * state
        r += 1
    
    return state

# check the correctness of the variant with "partial round constants"

for n in [3,4,5,9]:
        
    if n == 3:
        PARAMS = P3_PARAMS
    elif n == 4:
        PARAMS = P4_PARAMS
    elif n == 5:
        PARAMS = P5_PARAMS
    elif n == 9:
        PARAMS = P9_PARAMS
    
    VARIANT_RC = get_variant_round_cst(n)
    state_check = poseidon_variant(PARAMS,VARIANT_RC,[0]*n)
        
    if n == 3:
        assert state_check == P3([0,0,0])
    elif n == 4:
        assert state_check == P4([0,0,0,0])
    elif n == 5:
        assert state_check == P5([0,0,0,0,0])
    elif n == 9:
        assert state_check == P9([0,0,0,0,0,0,0,0,0])
    