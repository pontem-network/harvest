#[test_only]
module harvest::staking_test_helpers {
    use std::string::{String, utf8};

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};
    use liquidswap::curves::Uncorrelated;
    use liquidswap::liquidity_pool;
    use liquidswap_lp::lp_coin::LP;
    use test_helpers::test_pool;

    use harvest::dgen::{Self, DGEN};

    // Coins.

    struct BTC {}

    struct USDT {}

    struct Capabilities<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
        burn_cap: BurnCapability<CoinType>,
    }

    fun initialize_coin<CoinType>(
        account: &signer,
        name: String,
        symbol: String,
        decimals: u8,
    ) {
        let (b, f, m) = coin::initialize<CoinType>(
            account,
            name,
            symbol,
            decimals,
            true
        );

        coin::destroy_freeze_cap(f);

        move_to(account, Capabilities<CoinType> {
            mint_cap: m,
            burn_cap: b,
        });
    }

    public fun initialize_btc(account: &signer) {
        initialize_coin<BTC>(
            account,
            utf8(b"Bitcoin"),
            utf8(b"BTC"),
            8
        );
    }

    public fun initialize_usdt(account: &signer) {
        initialize_coin<USDT>(
            account,
            utf8(b"Tether"),
            utf8(b"USDT"),
            6
        );
    }

    public fun initialize_btc_usdt_coins(account: &signer) {
        initialize_btc(account);
        initialize_usdt(account);
    }

    public fun mint_coins<CoinType>(amount: u64): Coin<CoinType> acquires Capabilities {
        let caps = borrow_global<Capabilities<CoinType>>(@harvest);
        coin::mint(amount, &caps.mint_cap)
    }

    public fun burn_coins<CoinType>(to_burn: Coin<CoinType>): u64 acquires Capabilities {
        let caps = borrow_global<Capabilities<CoinType>>(@harvest);
        let val = coin::value(&to_burn);
        coin::burn(to_burn, &caps.burn_cap);

        val
    }

    public fun mint_dgen_coins(coin_creator_acc: &signer, amount: u64): Coin<DGEN> {
        dgen::initialize(coin_creator_acc);
        coin::withdraw<DGEN>(coin_creator_acc, amount)
    }

    // Accounts.
    public fun create_account(account_address: address): signer {
        let signer = account::create_account_for_test(account_address);
        signer
    }

    // Pools.

    public fun create_pool_with_liquidity<X, Y>(account: &signer, coins_x: Coin<X>, coin_y: Coin<Y>): Coin<LP<X, Y, Uncorrelated>> {
        test_pool::initialize_liquidity_pool();
        liquidity_pool::register<X, Y, Uncorrelated>(account);

        let lp_coins = liquidity_pool::mint<X, Y, Uncorrelated>(
            coins_x,
            coin_y
        );

        lp_coins
    }

    // Math.
    public fun to_u128(num: u64): u128 {
        (num as u128)
    }
}
