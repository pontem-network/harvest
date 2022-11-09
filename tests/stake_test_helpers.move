#[test_only]
module harvest::stake_test_helpers {
    use std::string::{String, utf8};

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};

    // Coins.

    struct RewardCoin {}

    struct StakeCoin {}

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

    public fun initialize_reward_coin(account: &signer, decimals: u8) {
        initialize_coin<RewardCoin>(
            account,
            utf8(b"Reward Coin"),
            utf8(b"RC"),
            decimals
        );
    }

    public fun initialize_stake_coin(account: &signer, decimals: u8) {
        initialize_coin<StakeCoin>(
            account,
            utf8(b"Stake Coin"),
            utf8(b"SC"),
            decimals
        );
    }

    public fun initialize_coins(coin_admin: &signer) {
        initialize_stake_coin(coin_admin, 6);
        initialize_reward_coin(coin_admin, 6);
    }

    public fun mint_coins<CoinType>(amount: u64): Coin<CoinType> acquires Capabilities {
        let caps = borrow_global<Capabilities<CoinType>>(@harvest);
        coin::mint(amount, &caps.mint_cap)
    }

    // Accounts.

    public fun new_account(account_addr: address): signer {
        let account = account::create_account_for_test(account_addr);
        account
    }

    public fun new_account_with_stake_coins(account_addr: address, amount: u64): signer acquires Capabilities {
        let account = account::create_account_for_test(account_addr);
        let stake_coins = mint_coins<StakeCoin>(amount);
        coin::register<StakeCoin>(&account);
        coin::deposit(account_addr, stake_coins);
        account
    }

    // Math.

    public fun to_u128(num: u64): u128 {
        (num as u128)
    }
}
