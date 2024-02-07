module harvest::wrap_token {
    use std::signer;
    use std::string;
    use std::string::String;

    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};

    use aptos_token::token::{Self, Token, TokenDataId, TokenId};

    /// When token with zero amount passed as LB token (shouldn't be reached, yet just in case).
    const ERR_LB_TOKEN_ZERO_AMOUNT: u64 = 1;
    /// When provided LB tokens has a wrong creator.
    const ERR_WRONG_TOKEN_CREATOR: u64 = 2;
    /// When provided LB tokens are from wrong token collection.
    const ERR_WRONG_TOKEN_COLLECTION: u64 = 3;
    const ERR_STORE_DOES_NOT_EXIST: u64 = 4;

    struct WStakeCoin<phantom T> has store {}

    struct WSCStore<phantom T> has key {
        token_data_id: TokenDataId,
        token_id: TokenId,
        burn_cap: BurnCapability<WStakeCoin<T>>,
        mint_cap: MintCapability<WStakeCoin<T>>,
    }

    public fun wrap_token<T>(
        user: &signer,
        asset: Token
    ) acquires WSCStore {
        // take token
        let token_amount = token::get_token_amount(&asset);
        assert!(token_amount > 0, ERR_LB_TOKEN_ZERO_AMOUNT);

        let token_id = token::get_token_id(&asset);
        let token_data_id = token::get_tokendata_id(token_id);
        let (token_creator, token_collection, token_name) =
            token::get_token_data_id_fields(&token_data_id);

        assert!(token_creator == @liquidswap_v1_resource_account, ERR_WRONG_TOKEN_CREATOR);

        // token::transfer(user, token_id, @harvest, token_amount);
                            //@harvest
        token::deposit_token(user, asset);

        let is_store = exists<WSCStore<T>>(@harvest);

        if (is_store) {
            check_collection<T>(token_collection);
        } else {
            create_wrap_coin<T>(user, token_data_id, token_id, token_name);
        };

        let mint_cap = &borrow_global<WSCStore<T>>(@harvest).mint_cap;
        let coins = coin::mint<WStakeCoin<T>>(token_amount, mint_cap);

        if (coin::is_account_registered<WStakeCoin<T>>(signer::address_of(user))) {
            coin::register<WStakeCoin<T>>(user);
        };

        coin::deposit(signer::address_of(user), coins)
    }

    fun check_collection<T>(token_collection: String) acquires WSCStore {
        let current_token_id = borrow_global<WSCStore<T>>(@harvest).token_id;
        let current_token_data_id = token::get_tokendata_id(current_token_id);

        let (_, current_token_collection, _) =
            token::get_token_data_id_fields(&current_token_data_id);

        assert!(current_token_collection == token_collection, ERR_WRONG_TOKEN_COLLECTION);
    }

    fun create_wrap_coin<T>(owner: &signer, token_data_id: TokenDataId, token_id: TokenId, token_name: String) {
        let (burn_cap, freeze_cap, mint_cap) =
                coin::initialize<WStakeCoin<T>>(
                    owner, //@harvest
                    token_name,
                    string::utf8(b"WST"),
                    6,
                    true
                );
            move_to(owner, WSCStore<T> {
                //@harvest
                token_data_id,
                token_id,
                burn_cap,
                mint_cap
            });
            coin::destroy_freeze_cap(freeze_cap);
    }

    public fun unwrap_coin<T>(owner: &signer, coins: Coin<WStakeCoin<T>>, to: address) acquires WSCStore {
        assert!(exists<WSCStore<T>>(@harvest), ERR_STORE_DOES_NOT_EXIST);

        let amount = coin::value(&coins);
        let token_id = borrow_global<WSCStore<T>>(@harvest).token_id;
        let burn_cap = &borrow_global<WSCStore<T>>(@harvest).burn_cap;

        coin::burn<WStakeCoin<T>>(coins, burn_cap);
        token::transfer(owner, token_id, to, amount);
    }
}
