module coin_creator::liq {
    use std::signer;
    use std::string;

    use aptos_framework::coin::{Self, BurnCapability, MintCapability, Coin};

    // coin does not exist
    const ERR_NO_COIN: u64 = 200;

    struct LIQ {}

    struct LIQCapabilities has key {
        burn_cap: BurnCapability<LIQ>,
        mint_cap: MintCapability<LIQ>,
    }

    public fun initialize(sender: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<LIQ>(
            sender,
            string::utf8(b"LIQ Coin"),
            string::utf8(b"LIQ"),
            6,
            true
        );
        coin::destroy_freeze_cap(freeze_cap);

        move_to(sender, LIQCapabilities {
            burn_cap,
            mint_cap,
        });
    }

    public fun mint(owner: &signer, amount: u64): Coin<LIQ> acquires LIQCapabilities {
        let owner_address = signer::address_of(owner);
        assert!(exists<LIQCapabilities>(owner_address), ERR_NO_COIN);

        let cap = borrow_global<LIQCapabilities>(owner_address);

        coin::mint<LIQ>(amount, &cap.mint_cap)
    }

    public fun burn(owner: &signer, coins: Coin<LIQ>): u64 acquires LIQCapabilities {
        let owner_address = signer::address_of(owner);
        assert!(exists<LIQCapabilities>(owner_address), ERR_NO_COIN);

        let amount = coin::value(&coins);
        let cap = borrow_global<LIQCapabilities>(owner_address);

        coin::burn<LIQ>(coins, &cap.burn_cap);
        amount
    }
}
