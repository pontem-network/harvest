/// Liquidswap DGEN coin module.
module dgen_owner::dgen {
    use std::signer;
    use std::string;

    use aptos_framework::coin::{Self, BurnCapability, Coin};

    /// Only creator can execute.
    const ERR_NO_PERMISSIONS: u64 = 100;

    /// Coin does not exist.
    const ERR_NO_COIN: u64 = 101;

    /// 100m total DGEN supply.
    const TOTAL_SUPPLY: u64 = 100000000000000;

    /// DGEN coin.
    struct DGEN {}

    /// Burn capabilities for DGEN coin.
    struct DGENCapabilities has key { burn_cap: BurnCapability<DGEN> }

    /// Initializes DGEN coin, making total supply premint for creator.
    public entry fun initialize(creator: &signer) {
        let creator_addr = signer::address_of(creator);
        assert!(creator_addr == @dgen_owner, ERR_NO_PERMISSIONS);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<DGEN>(
            creator,
            string::utf8(b"Liquidswap DGEN"),
            string::utf8(b"DGEN"),
            6,
            true
        );

        let pre_mint_coins = coin::mint(TOTAL_SUPPLY, &mint_cap);
        coin::register<DGEN>(creator);
        coin::deposit(creator_addr, pre_mint_coins);

        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);

        move_to(creator, DGENCapabilities { burn_cap });
    }

    /// Burns provided DGEN coins.
    public fun burn(coins: Coin<DGEN>): u64 acquires DGENCapabilities {
        assert!(exists<DGENCapabilities>(@dgen_owner), ERR_NO_COIN);

        let amount = coin::value(&coins);
        let cap = borrow_global<DGENCapabilities>(@dgen_owner);

        coin::burn<DGEN>(coins, &cap.burn_cap);
        amount
    }
}
