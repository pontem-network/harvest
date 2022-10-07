module staking_admin::staking {
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_std::event::{Self, EventHandle};
    use aptos_std::table::{Self, Table};
    use liquidswap_lp::lp_coin::LP;

    //
    // Errors.
    //

    // pool does not exist
    const ERR_NO_POOL: u64 = 100;

    // pool already exists
    const ERR_POOL_ALREADY_EXISTS: u64 = 101;

    // user has no stake
    const ERR_NO_STAKE: u64 = 102;

    // not enough balance
    const ERR_NOT_ENOUGH_BALANCE: u64 = 103;

    // only admin can execute
    const ERR_NO_PERMISSIONS: u64 = 104;

    /// Core data structures
    struct StakePool<phantom X, phantom Y, phantom Curve> has key {
        // total staked
        total: u128,
        // pool coins
        coins: Coin<LP<X, Y, Curve>>,
        // stake ledger
        ledger: Table<address, u64>,
        // stake events
        stake_events: EventHandle<StakeEvent>,
        // unstake events
        unstake_events: EventHandle<UnstakeEvent>,
    }

    struct StakeEvent has drop, store {
        user_address: address,
        amount: u64,
    }

    struct UnstakeEvent has drop, store {
        user_address: address,
        amount: u64,
    }

    //
    // Pool config
    //

    public entry fun initialize<X, Y, Curve>(pool_admin: &signer) {
        assert!(signer::address_of(pool_admin) == @staking_admin, ERR_NO_PERMISSIONS);
        assert!(!exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_POOL_ALREADY_EXISTS);

        move_to(
            pool_admin,
            StakePool<X, Y, Curve> {
                total: 0,
                coins: coin::zero(),
                ledger: table::new(),
                stake_events: account::new_event_handle<StakeEvent>(pool_admin),
                unstake_events: account::new_event_handle<UnstakeEvent>(pool_admin),
            }
        );
    }

    //
    // Getter functions
    //

    public fun get_total_stake<X, Y, Curve>(): u128 acquires StakePool {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_NO_POOL);

        borrow_global<StakePool<X, Y, Curve>>(@staking_admin).total
    }

    public fun get_user_stake<X, Y, Curve>(user_address: address): u64 acquires StakePool {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_NO_POOL);

        let pool = borrow_global<StakePool<X, Y, Curve>>(@staking_admin);
        if (table::contains(&pool.ledger, user_address)) {
            *table::borrow(&pool.ledger, user_address)
        } else {
            0
        }
    }

    //
    // Public functions
    //

    public fun stake<X, Y, Curve>(user: &signer, coins: Coin<LP<X, Y, Curve>>) acquires StakePool {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_NO_POOL);

        let user_address = signer::address_of(user);
        let amount = coin::value(&coins);
        let pool = borrow_global_mut<StakePool<X, Y, Curve>>(@staking_admin);
        let user_staked_amount =
            table::borrow_mut_with_default(&mut pool.ledger, user_address, 0);

        coin::merge(&mut pool.coins, coins);

        *user_staked_amount = *user_staked_amount + amount;
        pool.total = pool.total + (amount as u128);

        event::emit_event<StakeEvent>(
            &mut pool.stake_events,
            StakeEvent { user_address, amount },
        );
    }

    public fun unstake<X, Y, Curve>(user: &signer, amount: u64): Coin<LP<X, Y, Curve>> acquires StakePool {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_NO_POOL);

        let user_address = signer::address_of(user);
        let pool = borrow_global_mut<StakePool<X, Y, Curve>>(@staking_admin);

        assert!(table::contains(&pool.ledger, user_address), ERR_NO_STAKE);

        let user_staked_amount =
            table::borrow_mut(&mut pool.ledger, user_address);

        assert!(amount <= *user_staked_amount, ERR_NOT_ENOUGH_BALANCE);

        pool.total = pool.total - (amount as u128);
        *user_staked_amount = *user_staked_amount - amount;

        event::emit_event<UnstakeEvent>(
            &mut pool.unstake_events,
            UnstakeEvent { user_address, amount },
        );

        coin::extract(&mut pool.coins, amount)
    }
}
