load('low_level.sage')
load('poseidon.sage')
load('poseidon_variant.sage')

def print_c_rc(size, mode='STANDARD'):
    assert mode in ['STANDARD','MONTGOMERY']
    assert size in [3,4,5,9]
    if   size == 3:
        f251_rcst = P3_PARAMS.ark
    elif size == 4:
        f251_rcst = P4_PARAMS.ark
    elif size == 5:
        f251_rcst = P5_PARAMS.ark
    elif size == 9:
        f251_rcst = P9_PARAMS.ark
    if mode == 'MONTGOMERY':
        f251_rcst =  [[(rc * 2^256 % p) for rc in rcs] for rcs in f251_rcst]
        s = 'const felt_t ROUND_CONST_MONT_P'
    else:
        s = 'const felt_t ROUND_CONST_P'
    rcst = [[int_to_words(rc) for rc in rcs] for rcs in f251_rcst] 
    s += str(size)+'['+str(len(rcst))+']['+str(size)+']'
    s += ' = \n{{\n'
    for r in range(len(rcst)):
        for j in range(len(rcst[r])):
            s+= '    {'
            for i in range(4):
                w = str(rcst[r][j][i])
                if i<3: w = (20-len(w))*' ' + w
                else: w = (18-len(w))*' ' + w
                s +=  w + 'ull'
                if i < 3: s += ', '
            if j<len(rcst[r])-1: s += '},\n'
            else: s += '}\n'
        if r<len(rcst)-1: s+='    },{\n'
        else: s+='}};\n'
    print(s)


def print_c_rc_variant(size, mode='STANDARD'):
    assert mode in ['STANDARD','MONTGOMERY']
    assert size in [3,4,5,9]
    if   size == 3:
        PARAMS = P3_PARAMS
    elif size == 4:
        PARAMS = P4_PARAMS
    elif size == 5:
        PARAMS = P5_PARAMS
    elif size == 9:
        PARAMS = P9_PARAMS
    Rf = PARAMS.Rf
    Rp = PARAMS.Rp 
    f251_variant_rcst = get_variant_round_cst(size)
    if mode == 'MONTGOMERY':
        f251_variant_rcst = [(rc * 2^256 % p) for rc in f251_variant_rcst]
        s_variant = 'const felt_t CONST_RC_MONTGOMERY_P'
    else:
        s_variant = 'const felt_t CONST_RC_P'
    # variant round constants
    variant_rcst = [int_to_words(rc) for rc in f251_variant_rcst]
    s_variant += str(size)+'['+str(len(variant_rcst))+']'
    s_variant += ' = \n{\n'
    for j in range(len(variant_rcst)):
        s_variant+= '    {'
        for i in range(4):
            w = str(variant_rcst[j][i])
            if i<3: w = (20-len(w))*' ' + w
            else: w = (18-len(w))*' ' + w
            s_variant +=  w + 'ull'
            if i < 3: s_variant += ', '
        s_variant += '},\n'
    s_variant += '};\n'
    print(s_variant)