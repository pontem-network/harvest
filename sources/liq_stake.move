module staking_admin::staking {
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_std::event::{Self, EventHandle};
    use aptos_std::table::{Self, Table};

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
    struct StakePool<phantom CoinType> has key {
        // total staked
        total: u128,
        // stake ledger
        ledger: Table<address, Coin<CoinType>>,
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

    public entry fun initialize<CoinType>(pool_admin: &signer) {
        assert!(signer::address_of(pool_admin) == @staking_admin, ERR_NO_PERMISSIONS);
        assert!(!exists<StakePool<CoinType>>(@staking_admin), ERR_POOL_ALREADY_EXISTS);

        move_to(
            pool_admin,
            StakePool<CoinType> {
                total: 0,
                ledger: table::new(),
                stake_events: account::new_event_handle<StakeEvent>(pool_admin),
                unstake_events: account::new_event_handle<UnstakeEvent>(pool_admin),
            }
        );
    }

    //
    // Getter functions
    //

    public fun get_total_stake<CoinType>(): u128 acquires StakePool {
        assert!(exists<StakePool<CoinType>>(@staking_admin), ERR_NO_POOL);

        borrow_global<StakePool<CoinType>>(@staking_admin).total
    }

    public fun get_user_stake<CoinType>(user_address: address): u64 acquires StakePool {
        assert!(exists<StakePool<CoinType>>(@staking_admin), ERR_NO_POOL);

        let pool = borrow_global<StakePool<CoinType>>(@staking_admin);
        if (table::contains(&pool.ledger, user_address)) {
            coin::value(table::borrow(&pool.ledger, user_address))
        } else {
            0
        }
    }

    //
    // Public functions
    //

    public fun stake<CoinType>(user: &signer, coins: Coin<CoinType>) acquires StakePool {
        assert!(exists<StakePool<CoinType>>(@staking_admin), ERR_NO_POOL);

        let user_address = signer::address_of(user);
        let pool = borrow_global_mut<StakePool<CoinType>>(@staking_admin);
        let amount = coin::value(&coins);

        if (table::contains(&pool.ledger, user_address)) {
            let staked_coins = table::borrow_mut(&mut pool.ledger, user_address);

            coin::merge(staked_coins, coins);
        } else {
            table::add(&mut pool.ledger, user_address, coins);
        };

        pool.total = pool.total + (amount as u128);

        event::emit_event<StakeEvent>(
            &mut pool.stake_events,
            StakeEvent { user_address, amount },
        );
    }

    public fun unstake<CoinType>(user: &signer, amount: u64): Coin<CoinType> acquires StakePool {
        assert!(exists<StakePool<CoinType>>(@staking_admin), ERR_NO_POOL);

        let user_address = signer::address_of(user);
        let pool = borrow_global_mut<StakePool<CoinType>>(@staking_admin);

        assert!(table::contains(&pool.ledger, user_address), ERR_NO_STAKE);

        let staked_coins = table::borrow_mut(&mut pool.ledger, user_address);

        assert!(amount <= coin::value(staked_coins), ERR_NOT_ENOUGH_BALANCE);

        pool.total = pool.total - (amount as u128);

        event::emit_event<UnstakeEvent>(
            &mut pool.unstake_events,
            UnstakeEvent { user_address, amount },
        );

        coin::extract(staked_coins, amount)
    }
}
