script {
    use aptos_token::token;
    use std::string::utf8;
    use std::vector;
    use std::signer;

    /// Just mint test collection so we can test it on testnet.
    fun mint_test_collection(account: &signer) {
        let collection_name = utf8(b"LS Staking");

        token::create_collection_script(
            account,
            collection_name,
            utf8(b"Liquidswap Staking Test Collection"),
            utf8(b"https://liquidswap.com"),
            100,
            vector[false, false, false],
        );

        token::create_token_script(
            account,
            collection_name,
            utf8(b"Test #1"),
            utf8(b"Test #1 Desc"),
            1,
            1,
            utf8(b"https://www.topaz.so/cdn-cgi/image/width=512,quality=90,fit=scale-down/https://bafybeic7kh6ah65l7ekydksjvwrf2p2o3xesnagbkgu4j4fbc2red7y4km.ipfs.w3s.link/97.png"),
            signer::address_of(account),
            1,
            1,
            vector[false, false, false, false, false],
            vector::empty(),
            vector::empty(),
            vector::empty(),
        );
    }
}