module staking_admin::liq_stake {
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, Coin};
    use aptos_std::event::{Self, EventHandle};
    use liquidswap_lp::lp_coin::LP;

    //
    // Errors
    //

    // pool does not exist
    const ERR_NO_POOL: u64 = 100;

    // pool already exists
    const ERR_POOL_ALREADY_EXISTS: u64 = 101;

    // pool reward can't be zero
    const ERR_REWARD_CANNOT_BE_ZERO: u64 = 102;

    // user has no stake
    const ERR_NO_STAKE: u64 = 103;

    // not enough balance
    const ERR_NOT_ENOUGH_BALANCE: u64 = 104;

    // only admin can execute
    const ERR_NO_PERMISSIONS: u64 = 105;

    //
    // Constants
    //

    // multiplier to account six decimal places for LP and LIQ coins
    const SIX_DECIMALS: u64 = 1000000;

    //
    // Core data structures
    //

    struct StakePool<phantom X, phantom Y, phantom Curve> has key {
        // pool reward LIQ per second
        reward_per_sec: u64,
        // pool reward ((reward_per_sec * time) / total_staked) + acc_reward (previous period)
        acc_reward: u64,
        // last acc_reward & reward_per_sec update time
        last_updated: u64,

        // total LP staked
        total_staked: u64,
        // total LIQ earned
        total_earned: u64,
        // total LIQ paid
        total_paid: u64,

        // pool coins
        coins: Coin<LP<X, Y, Curve>>,
        // stake events
        stake_events: EventHandle<StakeEvent>,
        // unstake events
        unstake_events: EventHandle<UnstakeEvent>,
    }

    struct Stake<phantom X, phantom Y, phantom Curve> has key {
        // staked amount
        amount: u64,
        // stores pool acc_reward * amount which is already paid or does not belong to user
        unobtainable_reward: u64,
        // reward earned by current stake
        earned_reward: u64,
        // reward ever harvested by current stake
        harvested_reward: u64,
    }

    //
    // Events
    //

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

    public entry fun initialize<X, Y, Curve>(pool_admin: &signer, reward_per_sec: u64) {
        assert!(signer::address_of(pool_admin) == @staking_admin, ERR_NO_PERMISSIONS);
        assert!(!exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_POOL_ALREADY_EXISTS);
        assert!(reward_per_sec > 0, ERR_REWARD_CANNOT_BE_ZERO);

        move_to(
            pool_admin,
            StakePool<X, Y, Curve> {
                reward_per_sec,
                acc_reward: 0,
                last_updated: timestamp::now_seconds(),
                total_staked: 0,
                total_earned: 0,
                total_paid: 0,
                coins: coin::zero(),
                stake_events: account::new_event_handle<StakeEvent>(pool_admin),
                unstake_events: account::new_event_handle<UnstakeEvent>(pool_admin),
            }
        );
    }

    //
    // Getter functions
    //

    public fun get_pool_total_staked<X, Y, Curve>(): u64 acquires StakePool {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_NO_POOL);

        borrow_global<StakePool<X, Y, Curve>>(@staking_admin).total_staked
    }

    public fun get_pool_total_earned<X, Y, Curve>(): u64 acquires StakePool {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_NO_POOL);

        borrow_global<StakePool<X, Y, Curve>>(@staking_admin).total_earned
    }

    public fun get_pool_total_paid<X, Y, Curve>(): u64 acquires StakePool {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_NO_POOL);

        borrow_global<StakePool<X, Y, Curve>>(@staking_admin).total_paid
    }

    public fun get_user_stake<X, Y, Curve>(user_address: address): u64 acquires Stake {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_NO_POOL);

        if (exists<Stake<X, Y, Curve>>(user_address)) {
            borrow_global<Stake<X, Y, Curve>>(user_address).amount
        } else {
            0
        }
    }

    //
    // Public functions
    //

    public fun stake<X, Y, Curve>(user: &signer, coins: Coin<LP<X, Y, Curve>>) acquires StakePool, Stake {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_NO_POOL);

        let user_address = signer::address_of(user);
        let amount = coin::value(&coins);
        let pool = borrow_global_mut<StakePool<X, Y, Curve>>(@staking_admin);

        // update pool acc_reward and timestamp
        update_acc_reward(pool);

        let acc_reward = pool.acc_reward;
        if (!exists<Stake<X, Y, Curve>>(user_address)) {
            move_to(user,
                Stake<X, Y, Curve> {
                    amount,
                    unobtainable_reward: (acc_reward * amount) / SIX_DECIMALS,
                    earned_reward: 0,
                    harvested_reward: 0
                }
            );
        } else {
            let user_stake = borrow_global_mut<Stake<X, Y, Curve>>(user_address);

            // update earnings
            update_user_earnings<X, Y, Curve>(pool, user_stake);

            user_stake.unobtainable_reward = (acc_reward * (user_stake.amount + amount)) / SIX_DECIMALS;
            user_stake.amount = user_stake.amount + amount;
        };

        coin::merge(&mut pool.coins, coins);

        pool.total_staked = pool.total_staked + amount;

        event::emit_event<StakeEvent>(
            &mut pool.stake_events,
            StakeEvent { user_address, amount },
        );
    }

    public fun unstake<X, Y, Curve>(user: &signer, amount: u64): Coin<LP<X, Y, Curve>> acquires StakePool, Stake {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_admin), ERR_NO_POOL);

        let user_address = signer::address_of(user);
        let pool = borrow_global_mut<StakePool<X, Y, Curve>>(@staking_admin);

        // update pool acc_reward and timestamp
        update_acc_reward(pool);

        assert!(exists<Stake<X, Y, Curve>>(user_address), ERR_NO_STAKE);

        let user_stake =
            borrow_global_mut<Stake<X, Y, Curve>>(user_address);

        // update earnings
        update_user_earnings(pool, user_stake);

        assert!(amount <= user_stake.amount, ERR_NOT_ENOUGH_BALANCE);

        pool.total_staked = pool.total_staked - amount;
        user_stake.amount = user_stake.amount - amount;
        user_stake.unobtainable_reward = (pool.acc_reward * user_stake.amount) / SIX_DECIMALS;

        event::emit_event<UnstakeEvent>(
            &mut pool.unstake_events,
            UnstakeEvent { user_address, amount },
        );

        coin::extract(&mut pool.coins, amount)
    }

    fun update_acc_reward<X, Y, Curve>(pool: &mut StakePool<X, Y, Curve>) {
        let curr_time = timestamp::now_seconds();
        let time_passed = curr_time - pool.last_updated;
        let total_staked = pool.total_staked;

        pool.last_updated = curr_time;

        if (total_staked != 0) {
            pool.acc_reward = pool.acc_reward + ((pool.reward_per_sec * time_passed * SIX_DECIMALS) / total_staked);
        }
    }

    fun update_user_earnings<X, Y, Curve>(pool: &mut StakePool<X, Y, Curve>, user_stake: &mut Stake<X, Y, Curve>) {
        let earned = ((user_stake.amount * pool.acc_reward) / SIX_DECIMALS) - user_stake.unobtainable_reward;

        user_stake.earned_reward = user_stake.earned_reward + earned;
        user_stake.unobtainable_reward = user_stake.unobtainable_reward + earned;
        pool.total_earned = pool.total_earned + earned;
    }

    #[test_only]
    // access user stake fields with no getters
    public fun get_user_stake_info<X, Y, Curve>(user_address: address): (u64, u64, u64) acquires Stake {
        let fields = borrow_global<Stake<X, Y, Curve>>(user_address);

        (fields.unobtainable_reward, fields.earned_reward, fields.harvested_reward)
    }

    #[test_only]
    // access staking pool fields with no getters
    public fun get_pool_info<X, Y, Curve>(): (u64, u64, u64) acquires StakePool {
        let pool = borrow_global<StakePool<X, Y, Curve>>(@staking_admin);

        (pool.reward_per_sec, pool.acc_reward, pool.last_updated)
    }

    #[test_only]
    // force pool & user stake recalculations
    public fun recalculate_user_stake<X, Y, Curve>(user_address: address) acquires StakePool, Stake {
        let pool = borrow_global_mut<StakePool<X, Y, Curve>>(@staking_admin);

        update_acc_reward(pool);

        let user_stake = borrow_global_mut<Stake<X, Y, Curve>>(user_address);

        update_user_earnings(pool, user_stake);
    }
}
