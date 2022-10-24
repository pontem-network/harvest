module coin_creator::liq {
    use std::signer;
    use std::string;

    use aptos_framework::coin::{Self, BurnCapability, Coin};

    // only creator can execute
    const ERR_NO_PERMISSIONS: u64 = 100;

    // coin does not exist
    const ERR_NO_COIN: u64 = 101;

    // 100 millions total LIQ supply
    const TOTAL_SUPPLY: u64 = 100000000000000;

    struct LIQ {}

    struct LIQCapabilities has key { burn_cap: BurnCapability<LIQ> }

    public entry fun initialize(creator: &signer) {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @coin_creator, ERR_NO_PERMISSIONS);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<LIQ>(
            creator,
            string::utf8(b"LIQ Coin"),
            string::utf8(b"LIQ"),
            6,
            true
        );

        let pre_mint_coins = coin::mint(TOTAL_SUPPLY, &mint_cap);
        coin::register<LIQ>(creator);
        coin::deposit(creator_addr, pre_mint_coins);

        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);

        move_to(creator, LIQCapabilities { burn_cap });
    }

    public fun burn(coins: Coin<LIQ>): u64 acquires LIQCapabilities {
        assert!(exists<LIQCapabilities>(@coin_creator), ERR_NO_COIN);

        let amount = coin::value(&coins);
        let cap = borrow_global<LIQCapabilities>(@coin_creator);

        coin::burn<LIQ>(coins, &cap.burn_cap);
        amount
    }
}
