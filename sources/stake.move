module harvest::stake {
    use std::signer;

    use aptos_std::event::{Self, EventHandle};
    use aptos_std::table;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;

    //
    // Errors
    //

    /// Pool does not exist.
    const ERR_NO_POOL: u64 = 100;

    /// Pool already exists.
    const ERR_POOL_ALREADY_EXISTS: u64 = 101;

    /// Pool reward can't be zero.
    const ERR_REWARD_CANNOT_BE_ZERO: u64 = 102;

    /// User has no stake.
    const ERR_NO_STAKE: u64 = 103;

    /// Not enough S balance to unstake
    const ERR_NOT_ENOUGH_S_BALANCE: u64 = 104;

    /// Not enough balance to pay reward.
    const ERR_NOT_ENOUGH_REWARDS: u64 = 105;

    /// Amount can't be zero.
    const ERR_AMOUNT_CANNOT_BE_ZERO: u64 = 106;

    /// Nothing to harvest yet.
    const ERR_NOTHING_TO_HARVEST: u64 = 107;

    /// CoinType is not a coin.
    const ERR_IS_NOT_COIN: u64 = 108;

    /// Cannot unstake before lockup period end.
    const ERR_TOO_EARLY_UNSTAKE: u64 = 109;

    //
    // Constants
    //

    // todo: now S and R coins could be with any decimals value. do something
    /// Multiplier to account six decimal places.
    const SIX_DECIMALS: u128 = 1000000;

    /// Week in seconds, lockup period.
    const WEEK_IN_SECONDS: u64 = 604800;

    //
    // Core data structures
    //

    /// Stake pool, stores stake, reward coins and related info.
    struct StakePool<phantom S, phantom R> has key {
        // pool reward coins per second
        reward_per_sec: u64,
        // pool reward ((reward_per_sec * time) / total_staked) + accum_reward (previous period)
        accum_reward: u128,
        // last accum_reward & reward_per_sec update time
        last_updated: u64,
        // pool staked coins
        stake_coins: Coin<S>,
        // pool reward coins
        reward_coins: Coin<R>,
        // stake events
        stake_events: EventHandle<StakeEvent>,
        // unstake events
        unstake_events: EventHandle<UnstakeEvent>,
        // deposit events
        deposit_events: EventHandle<DepositRewardEvent>,
        // harvest events
        harvest_events: EventHandle<HarvestEvent>,
    }

    struct UserStakeTable<phantom S, phantom R> has key {
        items: table::Table<address, UserStake>
    }

    /// Stores user stake info.
    struct UserStake has store {
        // staked amount
        amount: u64,
        // contains the value of rewards that cannot be harvested by the user
        unobtainable_reward: u128,
        // reward earned by current stake
        earned_reward: u64,
        // unlock time
        unlock_time: u64,
    }

    //
    // Pool config
    //

    /// Registering pool for specific coin.
    public fun register_pool<S, R>(owner: &signer, reward_per_sec: u64) {
        assert!(reward_per_sec > 0, ERR_REWARD_CANNOT_BE_ZERO);
        assert!(!exists<StakePool<S, R>>(signer::address_of(owner)), ERR_POOL_ALREADY_EXISTS);
        assert!(coin::is_coin_initialized<S>() && coin::is_coin_initialized<R>(), ERR_IS_NOT_COIN);

        let pool = StakePool<S, R> {
            reward_per_sec,
            accum_reward: 0,
            last_updated: timestamp::now_seconds(),
            stake_coins: coin::zero(),
            reward_coins: coin::zero(),
            stake_events: account::new_event_handle<StakeEvent>(owner),
            unstake_events: account::new_event_handle<UnstakeEvent>(owner),
            deposit_events: account::new_event_handle<DepositRewardEvent>(owner),
            harvest_events: account::new_event_handle<HarvestEvent>(owner),
        };
        move_to(owner, pool);

        let user_stake_table = UserStakeTable<S, R> { items: table::new() };
        move_to(owner, user_stake_table);
    }

    /// Depositing reward coins to specific pool.
    public fun deposit_reward_coins<S, R>(pool_addr: address, coins: Coin<R>) acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
        let amount = coin::value(&coins);

        coin::merge(&mut pool.reward_coins, coins);

        event::emit_event<DepositRewardEvent>(
            &mut pool.deposit_events,
            DepositRewardEvent { amount },
        );
    }

    //
    // Getter functions
    //

    /// Returns current staked amount in pool.
    public fun get_pool_total_stake<S, R>(pool_addr: address): u64 acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        coin::value(&borrow_global<StakePool<S, R>>(pool_addr).stake_coins)
    }

    /// Returns current amount staked by user in specific pool.
    public fun get_user_stake<S, R>(pool_addr: address, user_addr: address): u64 acquires UserStakeTable {
        assert!(exists<UserStakeTable<S, R>>(pool_addr), ERR_NO_POOL);

        let user_stake_table = borrow_global<UserStakeTable<S, R>>(pool_addr);
        if (table::contains(&user_stake_table.items, user_addr)) {
            table::borrow(&user_stake_table.items, user_addr).amount
        } else {
            0
        }
    }

    //
    // Public functions
    //

    /// Stakes user coins in pool.
    public fun stake<S, R>(
        user: &signer,
        pool_addr: address,
        coins: Coin<S>
    ) acquires StakePool, UserStakeTable {
        assert!(coin::value(&coins) > 0, ERR_AMOUNT_CANNOT_BE_ZERO);
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let current_time = timestamp::now_seconds();
        let user_addr = signer::address_of(user);
        let amount = coin::value(&coins);
        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);

        // update pool accum_reward and timestamp
        update_accum_reward(pool);

        let accum_reward = pool.accum_reward;

        let user_stake_table = borrow_global_mut<UserStakeTable<S, R>>(pool_addr);
        if (!table::contains(&user_stake_table.items, user_addr)) {
            let new_stake = UserStake {
                amount,
                unobtainable_reward: 0,
                earned_reward: 0,
                unlock_time: current_time + WEEK_IN_SECONDS,
            };
            // calculate unobtainable reward for new stake
            new_stake.unobtainable_reward = (accum_reward * to_u128(amount)) / SIX_DECIMALS;
            table::add(&mut user_stake_table.items, user_addr, new_stake);
        } else {
            let user_stake = table::borrow_mut(&mut user_stake_table.items, user_addr);

            // update earnings
            update_user_earnings(pool, user_stake);

            user_stake.amount = user_stake.amount + amount;

            // recalculate unobtainable reward after stake amount changed
            user_stake.unobtainable_reward = (accum_reward * to_u128(user_stake.amount)) / SIX_DECIMALS;

            user_stake.unlock_time =  current_time + WEEK_IN_SECONDS;
        };

        coin::merge(&mut pool.stake_coins, coins);

        event::emit_event<StakeEvent>(
            &mut pool.stake_events,
            StakeEvent { user_address: user_addr, amount },
        );
    }

    /// Unstakes user coins from pool.
    public fun unstake<S, R>(
        user: &signer,
        pool_addr: address,
        amount: u64
    ): Coin<S> acquires StakePool, UserStakeTable {
        assert!(amount > 0, ERR_AMOUNT_CANNOT_BE_ZERO);
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let user_addr = signer::address_of(user);
        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
        let user_stake_table = borrow_global_mut<UserStakeTable<S, R>>(pool_addr);

        assert!(table::contains(&user_stake_table.items, user_addr), ERR_NO_STAKE);

        let user_stake = table::borrow_mut(&mut user_stake_table.items, user_addr);
        let current_time = timestamp::now_seconds();

        // check unlock timestamp
        assert!(current_time >= user_stake.unlock_time, ERR_TOO_EARLY_UNSTAKE);

        // update pool accum_reward and timestamp
        update_accum_reward(pool);

        // update earnings
        update_user_earnings(pool, user_stake);

        assert!(amount <= user_stake.amount, ERR_NOT_ENOUGH_S_BALANCE);

        user_stake.amount = user_stake.amount - amount;

        // recalculate unobtainable reward after stake amount changed
        user_stake.unobtainable_reward = (pool.accum_reward * to_u128(user_stake.amount)) / SIX_DECIMALS;

        event::emit_event<UnstakeEvent>(
            &mut pool.unstake_events,
            UnstakeEvent { user_address: user_addr, amount },
        );

        coin::extract(&mut pool.stake_coins, amount)
    }

    /// Harvests user reward, returning R coins.
    public fun harvest<S, R>(user_addr: address, pool_addr: address): Coin<R> acquires StakePool, UserStakeTable {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);

        let user_stake_table = borrow_global_mut<UserStakeTable<S, R>>(pool_addr);
        assert!(table::contains(&user_stake_table.items, user_addr), ERR_NO_STAKE);

        // update pool accum_reward and timestamp
        update_accum_reward(pool);

        let user_stake = table::borrow_mut(&mut user_stake_table.items, user_addr);

        // update earnings
        update_user_earnings(pool, user_stake);

        let earned = user_stake.earned_reward;
        user_stake.earned_reward = 0;

        assert!(earned > 0, ERR_NOTHING_TO_HARVEST);
        assert!(coin::value(&pool.reward_coins) >= earned, ERR_NOT_ENOUGH_REWARDS);

        event::emit_event<HarvestEvent>(
            &mut pool.harvest_events,
            HarvestEvent { user_address: user_addr, amount: earned },
        );

        coin::extract(&mut pool.reward_coins, earned)
    }

    /// Recalculates pool accumulated reward.
    fun update_accum_reward<S, R>(pool: &mut StakePool<S, R>) {
        let current_time = timestamp::now_seconds();
        let seconds_passed = current_time - pool.last_updated;
        let total_stake = coin::value(&pool.stake_coins);

        pool.last_updated = current_time;

        if (total_stake != 0) {
            let total_reward = to_u128(pool.reward_per_sec) * to_u128(seconds_passed) * SIX_DECIMALS;

            pool.accum_reward =
                pool.accum_reward + total_reward / to_u128(total_stake);
        }
    }

    /// Calculates user earnings.
    fun update_user_earnings<S, R>(pool: &mut StakePool<S, R>, user_stake: &mut UserStake) {
        let earned =
            (pool.accum_reward * (to_u128(user_stake.amount)) / SIX_DECIMALS) - user_stake.unobtainable_reward;

        user_stake.earned_reward = user_stake.earned_reward + to_u64(earned);
        user_stake.unobtainable_reward = user_stake.unobtainable_reward + earned;
    }

    fun to_u64(num: u128): u64 {
        (num as u64)
    }

    fun to_u128(num: u64): u128 {
        (num as u128)
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

    struct DepositRewardEvent has drop, store {
        amount: u64,
    }

    struct HarvestEvent has drop, store {
        user_address: address,
        amount: u64,
    }

    #[test_only]
    /// Access user stake fields with no getters.
    public fun get_user_stake_info<S, R>(
        pool_addr: address,
        user_addr: address
    ): (u128, u64, u64) acquires UserStakeTable {
        let user_stake_table = borrow_global<UserStakeTable<S, R>>(pool_addr);
        let fields = table::borrow(&user_stake_table.items, user_addr);

        (fields.unobtainable_reward, fields.earned_reward, fields.unlock_time)
    }

    #[test_only]
    /// Access staking pool fields with no getters.
    public fun get_pool_info<S, R>(pool_addr: address): (u64, u128, u64, u64) acquires StakePool {
        let pool = borrow_global<StakePool<S, R>>(pool_addr);

        (pool.reward_per_sec, pool.accum_reward, pool.last_updated, coin::value<R>(&pool.reward_coins))
    }

    #[test_only]
    /// Force pool & user stake recalculations.
    public fun recalculate_user_stake<S, R>(pool_addr: address, user_addr: address) acquires StakePool, UserStakeTable {
        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);

        update_accum_reward(pool);

        let user_stake_table = borrow_global_mut<UserStakeTable<S, R>>(pool_addr);
        let user_stake = table::borrow_mut(&mut user_stake_table.items, user_addr);

        update_user_earnings(pool, user_stake);
    }
}
