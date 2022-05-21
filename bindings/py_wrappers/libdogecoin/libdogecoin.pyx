cimport cython as cy
from cython.operator cimport dereference as deref

# FUNCTIONS FROM STATIC LIBRARY
#========================================================
cdef extern from "ecc.h":
    void dogecoin_ecc_start()
    void dogecoin_ecc_stop()

cdef extern from "address.h":
    int generatePrivPubKeypair(char* wif_privkey, char* p2pkh_pubkey, bint is_testnet)
    int generateHDMasterPubKeypair(char* wif_privkey_master, char* p2pkh_pubkey_master, bint is_testnet)
    int generateDerivedHDPubkey(const char* wif_privkey_master, char* p2pkh_pubkey)
    int verifyPrivPubKeypair(char* wif_privkey, char* p2pkh_pubkey, bint is_testnet)
    int verifyHDMasterPubKeypair(char* wif_privkey_master, char* p2pkh_pubkey_master, bint is_testnet)
    int verifyP2pkhAddress(char* p2pkh_pubkey, cy.uchar len)

cdef extern from "transaction.h":
    int start_transaction()
    int save_raw_transaction(int txindex, const char* hexadecimal_transaction)
    int add_utxo(int txindex, char* hex_utxo_txid, int vout)
    int add_output(int txindex, char* destinationaddress,  cy.ulong amount)
    char* finalize_transaction(int txindex, char* destinationaddress, double subtractedfee, cy.ulong out_dogeamount_for_verification, char* public_key)
    char* get_raw_transaction(int txindex) 
    void clear_transaction(int txindex) 
    char* sign_raw_transaction(int inputindex, char* incomingrawtx, char* scripthex, int sighashtype, int amount, char* privkey)
    char* sign_indexed_raw_transaction(int txindex, int inputindex, char* incomingrawtx, char* scripthex, int sighashtype, int amount, char* privkey)


# PYTHON INTERFACE
#========================================================

# ADDRESS FUNCTIONS
def context_start():
    dogecoin_ecc_start()

def context_stop():
    dogecoin_ecc_stop()

def generate_priv_pub_key_pair(chain_code=0):
    """Generate a valid private key paired with the corresponding
    p2pkh address
    Keyword arguments:
    chain_code -- 0 for mainnet pair, 1 for testnet pair
    as_bytes -- flag to return key pair as bytes object
    """
    # verify arguments are valid
    assert isinstance(chain_code, int) and chain_code in [0,1]
    
    # prepare arguments
    cdef char privkey[53]
    cdef char p2pkh_pubkey[35]
    cdef bint is_testnet = chain_code

    # call c function
    generatePrivPubKeypair(privkey, p2pkh_pubkey, chain_code)

    # return keys as bytes object
    return privkey, p2pkh_pubkey


def generate_hd_master_pub_key_pair(chain_code=0):
    """Generate a master private and public key pair for use in
    heirarchical deterministic wallets. Public key can be used for
    child key derivation using generate_derived_hd_pub_key().
    Keyword arguments:
    chain_code -- 0 for mainnet pair, 1 for testnet pair
    as_bytes -- flag to return key pair as bytes object
    """
    # verify arguments are valid
    assert isinstance(chain_code, int) and chain_code in [0,1]
    
    # prepare arguments
    cdef char master_privkey[128]
    cdef char master_p2pkh_pubkey[35]

    # call c function
    generateHDMasterPubKeypair(master_privkey, master_p2pkh_pubkey, chain_code)

    # return keys
    # TODO: extra bytes added to end of testnet keys?? truncate after 34 as a temp patch 
    return master_privkey, master_p2pkh_pubkey[:34]


def generate_derived_hd_pub_key(wif_privkey_master):
    """Given a HD master public key, derive a child key from it.
    Keyword arguments:
    wif_privkey_master -- HD master public key as wif-encoded string
    as_bytes -- flag to return key pair as bytes object
    """
    # verify arguments are valid
    assert isinstance(wif_privkey_master, (str, bytes))

    # prepare arguments
    if not isinstance(wif_privkey_master, bytes):
        wif_privkey_master = wif_privkey_master.encode('utf-8')
    cdef char child_p2pkh_pubkey[128]

    # call c function
    generateDerivedHDPubkey(wif_privkey_master, child_p2pkh_pubkey)

    # return results in bytes
    return child_p2pkh_pubkey


def verify_priv_pub_keypair(wif_privkey, p2pkh_pubkey, chain_code=0):
    """Given a keypair from generate_priv_pub_key_pair, verify that the keys
    are valid and are associated with each other.
    Keyword arguments:
    wif_privkey -- string containing wif-encoded private key
    p2pkh_pubkey -- string containing address derived from wif_privkey
    chain_code -- 0 for mainnet, 1 for testnet
    """
    # verify arguments are valid
    assert isinstance(wif_privkey, (str, bytes))
    assert isinstance(p2pkh_pubkey, (str, bytes))
    assert isinstance(chain_code, int) and chain_code in [0,1]

    # prepare arguments
    if not isinstance(wif_privkey, bytes):
        wif_privkey = wif_privkey.encode('utf-8')
    if not isinstance(p2pkh_pubkey, bytes):
        p2pkh_pubkey = p2pkh_pubkey.encode('utf-8')

    # call c function
    res = verifyPrivPubKeypair(wif_privkey, p2pkh_pubkey, chain_code)

    # return boolean result
    return res


def verify_master_priv_pub_keypair(wif_privkey_master, p2pkh_pubkey_master, chain_code=0):
    """Given a keypair from generate_hd_master_pub_key_pair, verify that the
    keys are valid and are associated with each other.
    Keyword arguments:
    wif_privkey_master -- string containing wif-encoded private master key
    p2pkh_pubkey_master -- string containing address derived from wif_privkey
    chain_code -- 0 for mainnet, 1 for testnet
    """
    # verify arguments are valid
    assert isinstance(wif_privkey_master, (str, bytes))
    assert isinstance(p2pkh_pubkey_master, (str, bytes))
    assert isinstance(chain_code, int) and chain_code in [0,1]

    # prepare arguments
    if not isinstance(wif_privkey_master, bytes):
        wif_privkey_master = wif_privkey_master.encode('utf-8')
    if not isinstance(p2pkh_pubkey_master, bytes):
        p2pkh_pubkey_master = p2pkh_pubkey_master.encode('utf-8')

    # call c function
    res = verifyHDMasterPubKeypair(wif_privkey_master, p2pkh_pubkey_master, chain_code)

    # return boolean result
    return res


def verify_p2pkh_address(p2pkh_pubkey):
    """Given a p2pkh address, confirm address is in correct Dogecoin
    format
    Keyword arguments:
    p2pkh_pubkey -- string containing basic p2pkh address
    """
    # verify arguments are valid
    assert isinstance(p2pkh_pubkey, (str, bytes))

    # prepare arguments
    if not isinstance(p2pkh_pubkey, bytes):
        p2pkh_pubkey = p2pkh_pubkey.encode('utf-8')

    # call c function
    res = verifyP2pkhAddress(p2pkh_pubkey, len(p2pkh_pubkey))

    # return boolean result
    return res



# TRANSACTION FUNCTIONS

def w_start_transaction():
    """Create a new, empty dogecoin transaction."""
    # call c function
    res = start_transaction()

    # return boolean result
    return res

def w_save_raw_transaction(tx_index, hex_transaction):
    """Given a serialized transaction string, saves the transaction
    as a working transaction with the specified index.
    Keyword arguments:
    tx_index -- the index where the new working transaction will be saved
    hex_transaction -- the serialized string of the transaction to save
    """
    # verify arguments are valid
    assert isinstance(tx_index, int)
    assert isinstance(hex_transaction, (str, bytes))

    # prepare arguments
    if not isinstance(hex_transaction, bytes):
        hex_transaction = hex_transaction.encode('utf-8')

    # call c function
    res = save_raw_transaction(tx_index, hex_transaction)

    # return boolean result
    return res


def w_add_utxo(tx_index, hex_utxo_txid, vout):
    """Given the index of a working transaction, add another
    input to it.
    Keyword arguments:
    tx_index -- the index of the working transaction to update
    hex_utxo_txid -- the transaction id of the utxo to be spent
    vout -- the number of outputs associated with the specified utxo
    """
    # verify arguments are valid
    assert isinstance(tx_index, int)
    assert isinstance(hex_utxo_txid, (str, bytes))
    assert isinstance(vout, int)

    # prepare arguments
    if not isinstance(hex_utxo_txid, bytes):
        hex_utxo_txid = hex_utxo_txid.encode('utf-8')

    # call c function
    res = add_utxo(tx_index, hex_utxo_txid, vout)

    # return boolean result
    return res


def w_add_output(tx_index, destination_address, amount):
    """Given the index of a working transaction, add another
    output to it.
    Keyword arguments:
    tx_index -- the index of the working transaction to update
    destination_address -- the address of the output being added
    amount -- the amount of dogecoin to send to the specified address
    """
    # verify arguments are valid
    assert isinstance(tx_index, int)
    assert isinstance(destination_address, (str, bytes))
    assert isinstance(amount, int) # TEMPORARY PATCH TO AGREE WITH C CODE, SHOULD BE FLOAT

    # prepare arguments
    if not isinstance(destination_address, bytes):
        destination_address = destination_address.encode('utf-8')

    # call c function
    res = add_output(tx_index, destination_address, amount)

    # return boolean result
    return res


def w_finalize_transaction(tx_index, destination_address, subtracted_fee, out_dogeamount_for_verification, sender_p2pkh):
    """Given the index of a working transaction, prepares it
    for signing by specifying the recipient and fee to subtract,
    directing extra change back to the sender.
    Keyword arguments:
    tx_index -- the index of the working transaction
    destination address -- the address to send coins to
    subtracted_fee -- the amount of dogecoin to assign as a fee
    out_dogeamount_for_verification -- the total amount of dogecoin being sent (fee included)
    sender_p2pkh -- the address of the sender to receive their change
    """
    # verify arguments are valid
    assert isinstance(tx_index, int)
    assert isinstance(destination_address, (str, bytes))
    assert isinstance(subtracted_fee, float)
    assert isinstance(out_dogeamount_for_verification, int) # ALSO TEMPORARY INT, CHANGE TO FLOAT LATER
    assert isinstance(sender_p2pkh, (str, bytes))

    # prepare arguments
    if not isinstance(destination_address, bytes):
        destination_address = destination_address.encode('utf-8')
    if not isinstance(sender_p2pkh, bytes):
        sender_p2pkh = sender_p2pkh.encode('utf-8')

    # call c function
    cdef void* res
    cdef char* finalized_transaction_hex
    res = finalize_transaction(tx_index, destination_address, subtracted_fee, out_dogeamount_for_verification, sender_p2pkh)

    # return hex result
    try:
        if (res==<void*>0):
            raise TypeError
        finalized_transaction_hex = <char*>res
        return finalized_transaction_hex.decode('utf-8')
    except:
        return 0


def w_get_raw_transaction(tx_index):
    """Given the index of a working transaction, returns
    the serialized object in hex format.
    Keyword arguments:
    tx_index -- the index of the working transaction
    """
    # verify arguments are valid
    assert isinstance(tx_index, int)

    # call c function
    cdef void* res
    cdef char* raw_transaction_hex
    res = get_raw_transaction(tx_index)

    # return hex result
    try:
        if (res==<void*>0):
            raise TypeError
        raw_transaction_hex = <char*>res
        return raw_transaction_hex.decode('utf-8') 
    except:
        return 0
        


def w_clear_transaction(tx_index):
    """Discard a working transaction.
    Keyword arguments:
    tx_index -- the index of the working transaction
    """
    # verify arguments are valid
    assert isinstance(tx_index, int)

    # call c function
    clear_transaction(tx_index)


def w_sign_raw_transaction(tx_index, incoming_raw_tx, script_hex, sig_hash_type, amount, privkey):
    """Sign a finalized raw transaction using the specified
    private key.
    Keyword arguments:
    tx_index -- the index of the working transaction to sign
    incoming_raw_tx -- the serialized string of the transaction to sign
    script_hex -- the hex of the script to be signed
    sig_hash_type -- the type of signature hash to be used
    amount -- the amount of dogecoin in the transaction being signed
    privkey -- the private key to sign with
    """
    # verify arguments are valid
    assert isinstance(tx_index, int)
    assert isinstance(incoming_raw_tx, (str, bytes))
    assert isinstance(script_hex, (str, bytes))
    assert isinstance(sig_hash_type, int)
    assert isinstance(amount, int) # TEMPORARY
    assert isinstance(privkey, (str, bytes))

    # prepare arguments
    if not isinstance(incoming_raw_tx, bytes):
        incoming_raw_tx = incoming_raw_tx.encode('utf-8')
    if not isinstance(script_hex, bytes):
        script_hex = script_hex.encode('utf-8')
    if not isinstance(privkey, bytes):
        privkey = privkey.encode('utf-8')

    # call c function
    return sign_raw_transaction(tx_index, incoming_raw_tx, script_hex, sig_hash_type, amount, privkey).decode('utf-8')
