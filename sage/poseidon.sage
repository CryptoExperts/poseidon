#####################################################################################
# The following code has been reworked from
# https://starkware.co/hash-challenge/hash-challenge-implementation-reference-code/
#####################################################################################

# Prime field
F251 = GF(2**251 + 17*2**192 + 1)
    
def sponge(permutation_func, inputs, params):
    """
    Applies the sponge construction to permutation_func.
    inputs should be a vector of field elements whose size is divisible by
    params.r.
    permutation_func should be a function which gets (state, params) where state
    is a vector of params.m field elements, and returns a vector of params.m
    field elements.
    """
    assert parent(inputs) == VectorSpace(params.field, len(inputs)), \
        'inputs must be a vector of field elements. Found: %r' % parent(inputs)
    assert len(inputs) % params.r == 0, \
        'Number of field elements must be divisible by %s. Found: %s' % (
            params.r, len(inputs))
    state = vector([params.field(0)] * params.m)
    for i in range(0, len(inputs), params.r):
        state[:params.r] += inputs[i:i+params.r]
        state = permutation_func(state, params)
    # We do not support more than r output elements, since this requires
    # additional invocations of permutation_func.
    assert params.output_size <= params.r
    return state[:params.output_size]

def int2field(field, val):
    """
    Converts val to an element of the field.
    Assumes the input field is prime
    """
    assert field.characteristic() == field.order()
    return field(val)

def field_vector(field, values):
    """
    Converts a list of integers to field elements using int2field.
    """
    return vector(field, [int2field(field, val) for val in values])

def field_matrix(field, values):
    """
    Converts a list of lists of integers to field elements using int2field.
    """
    return matrix(field, [[int2field(field, val) for val in row]
                          for row in values])


class HadesParams(object):
    def __init__(self, field, r, c, Rf, Rp, ark, mds):
        self.field = field
        self.r = r
        self.c = c
        self.m = m = r + c
        assert Rf % 2 == 0
        self.Rf = Rf
        self.Rp = Rp
        self.n_rounds = n_rounds = Rf + Rp
        self.output_size = c
        assert self.output_size <= r
        # A list of Rf+Rp vectors for the Add-Round Key phase.
        self.ark = [field_vector(field, v) for v in ark]
        # The MDS matrix for the MixLayer phase.
        self.mds = field_matrix(field,mds)

def hades_permutation(values, params):
    assert len(values) == params.m
    round_idx = 0
    # Apply Rf/2 full rounds.
    for i in range(params.Rf // 2):
        values = hades_round(values, params, True, round_idx)
        round_idx += 1
    # Apply Rp partial rounds.
    for i in range(params.Rp):
        values = hades_round(values, params, False, round_idx)
        round_idx += 1
    # Apply Rf/2 full rounds.
    for i in range(params.Rf // 2):
        values = hades_round(values, params, True, round_idx)
        round_idx += 1
    assert round_idx == params.n_rounds
    return values

def hades_round(values, params, is_full_round, round_idx):
    # Add-Round Key
    values += params.ark[round_idx]
    # SubWords
    if is_full_round:
        for i in range(len(values)):
            values[i] = values[i] ** 3
    else:
        values[-1] = values[-1] ** 3
    # MixLayer
    values = params.mds * values
    return values

def hades_hash(inputs, params):
    return sponge(hades_permutation, inputs, params)


        
# Instances
load('poseidon3_data.sage')
load('poseidon4_data.sage')
load('poseidon5_data.sage')
load('poseidon9_data.sage')
P3_PARAMS = HadesParams(field=F251, r=2, c=1, Rf=8, Rp=83, ark=RoundKeys3, mds=Matrix3)
P4_PARAMS = HadesParams(field=F251, r=3, c=1, Rf=8, Rp=84, ark=RoundKeys4, mds=Matrix4)
P5_PARAMS = HadesParams(field=F251, r=4, c=1, Rf=8, Rp=84, ark=RoundKeys5, mds=Matrix5)
P9_PARAMS = HadesParams(field=F251, r=8, c=1, Rf=8, Rp=84, ark=RoundKeys9, mds=Matrix9)
def P3(v):
    return hades_permutation(field_vector(F251,v),P3_PARAMS)
def P4(v):
    return hades_permutation(field_vector(F251,v),P4_PARAMS)
def P5(v):
    return hades_permutation(field_vector(F251,v),P5_PARAMS)
def P9(v):
    return hades_permutation(field_vector(F251,v),P9_PARAMS)

# Test vectors
assert P3([0,0,0]) == field_vector(F251,[
    3446325744004048536138401612021367625846492093718951375866996507163446763827,
    1590252087433376791875644726012779423683501236913937337746052470473806035332,
    867921192302518434283879514999422690776342565400001269945778456016268852423])
assert P4([0,0,0,0]) == field_vector(F251,[
    535071095200566880914603862188010633478042591441142518549720701573192347548,
    3567335813488551850156302853280844225974867890860330236555401145692518003968,
    229995103310401763929738317978722680640995513996113588430855556460153357543,
    3513983790849716360905369754287999509206472929684378838050290392634812839312])
assert P5([0,0,0,0,0]) == field_vector(F251,[
    2337689130971531876049206831496963607805116499042700598724344149414565980684,
    3230969295497815870174763682436655274044379544854667759151474216427142025631,
    3297330512217530111610698859408044542971696143761201570393504997742535648562,
    2585480844700786541432072704002477919020588246983274666988914431019064343941,
    3595308260654382824623573767385493361624474708214823462901432822513585995028])
assert P9([0,0,0,0,0,0,0,0,0]) == field_vector(F251,[
    1534116856660032929112709488204491699743182428465681149262739677337223235050,
    1710856073207389764546990138116985223517553616229641666885337928044617114700,
    3165864635055638516987240200217592641540231237468651257819894959934472989427,
    1003007637710164252047715558598366312649052908276423203724288341354608811559,
    68117303579957054409211824649914588822081700129416361923518488718489651489,
    1123395637839379807713801282868237406546107732595903195840754789810160564711,
    478590974834311070537087181212389392308746075734019180430422247431982932503,
    835322726024358888065061514739954009068852229059154336727219387089732433787,
    3129703030204995742174502162918848446737407262178341733578946634564864233056])


# Debbuging purpose

def get_params(n):
    if   n == 3:
        return P3_PARAMS
    elif n == 4:
        return P4_PARAMS
    elif n == 5:
        return P5_PARAMS
    elif n == 9:
        return P9_PARAMS

def round(state, ind, is_full_round=True):
    n = len(state)
    assert n in [3,4,5,9]
    PARAMS = get_params(n)
    f251_state = field_vector(F251,state)
    f251_state = hades_round(f251_state, PARAMS, is_full_round, ind)
    out_state = [Integer(s) for s in f251_state]
    return out_state

def AddRoundConst(state, ind):
    n = len(state)
    assert n in [3,4,5,9]
    PARAMS = get_params(n)
    f251_state = field_vector(F251,state)
    f251_state += PARAMS.ark[ind]
    out_state = [Integer(s) for s in f251_state]
    return out_state

def SubWords(state,is_full_round=True):
    n = len(state)
    assert n in [3,4,5,9]
    PARAMS = get_params(n)
    f251_state = field_vector(F251,state)
    if is_full_round:
        for i in range(len(f251_state)):
            f251_state[i] = f251_state[i] ** 3
    else:
        f251_state[-1] = f251_state[-1] ** 3
    out_state = [Integer(s) for s in f251_state]
    return out_state

def MixLayer(state):
    n = len(state)
    assert n in [3,4,5,9]
    PARAMS = get_params(n)
    f251_state = field_vector(F251,state)
    f251_state = PARAMS.mds * f251_state
    out_state = [Integer(s) for s in f251_state]
    return out_state



