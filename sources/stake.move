module harvest::stake {
    use std::signer;
    use std::option;

    use aptos_std::event::{Self, EventHandle};
    use aptos_std::math64;
    use aptos_std::table;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_token::token::{Self, Token};

    use harvest::stake_config;
    use std::string::{Self, String};
    use std::option::Option;

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

    /// Pool has no rewards on balance.
    const ERR_EMPTY_POOL_REWARD_BALANCE: u64 = 105;

    /// Amount can't be zero.
    const ERR_AMOUNT_CANNOT_BE_ZERO: u64 = 106;

    /// Nothing to harvest yet.
    const ERR_NOTHING_TO_HARVEST: u64 = 107;

    /// CoinType is not a coin.
    const ERR_IS_NOT_COIN: u64 = 108;

    /// Cannot unstake before lockup period end.
    const ERR_TOO_EARLY_UNSTAKE: u64 = 109;

    /// The pool is in the "emergency state", all operations except for the `emergency_unstake()` are disabled.
    const ERR_EMERGENCY: u64 = 110;

    /// The pool is not in "emergency state".
    const ERR_NO_EMERGENCY: u64 = 111;

    /// Only one hardcoded account can enable "emergency state" for the pool, it's not the one.
    const ERR_NOT_ENOUGH_PERMISSIONS_FOR_EMERGENCY: u64 = 112;

    //
    // Constants
    //

    /// Week in seconds, lockup period.
    const WEEK_IN_SECONDS: u64 = 604800;

    // todo: comment it
    const MIN_NFT_BOOST_PRECENT: u64 = 1;

    const MAX_NFT_BOOST_PERCENT: u64 = 100;

    //
    // Core data structures
    //

    /// Stake pool, stores stake, reward coins and related info.
    struct StakePool<phantom S, phantom R> has key {
        reward_per_sec: u64,
        // pool reward ((reward_per_sec * time) / total_staked) + accum_reward (previous period)
        accum_reward: u128,
        // last accum_reward update time
        last_updated: u64,

        stakes: table::Table<address, UserStake>,
        stake_coins: Coin<S>,
        reward_coins: Coin<R>,
        stake_scale: u64,

        total_boosted: u64,
        // nft collection info
        collection_owner: address,
        collection_name: String,
        boost_percent: u64,

        /// This field set to `true` only in case of emergency:
        /// * only `emergency_unstake()` operation is available in the state of emergency
        emergency_locked: bool,

        stake_events: EventHandle<StakeEvent>,
        unstake_events: EventHandle<UnstakeEvent>,
        deposit_events: EventHandle<DepositRewardEvent>,
        harvest_events: EventHandle<HarvestEvent>,
    }

    // struct NFTBoost has store {
    //
    // }

    /// Stores user stake info.
    struct UserStake has store {
        amount: u64,
        // contains the value of rewards that cannot be harvested by the user
        unobtainable_reward: u128,
        earned_reward: u64,
        unlock_time: u64,
        // todo: comments?
        nft: Option<Token>,
        boosted_amount: u64,
    }

    //
    // Pool config
    //

    /// Registering pool for specific coin.
    /// * `owner` - pool creator account, under which the pool will be stored.
    /// * `reward_per_sec` - amount of R coins that the pool allocates each second for shared reward.
    // todo: complete comment
    public fun register_pool<S, R>(
        owner: &signer,
        reward_per_sec: u64,
        collection_owner: address,
        collection_name: String,
        boost_percent: u64,
    ) {
        assert!(reward_per_sec > 0, ERR_REWARD_CANNOT_BE_ZERO);
        assert!(!exists<StakePool<S, R>>(signer::address_of(owner)), ERR_POOL_ALREADY_EXISTS);
        assert!(coin::is_coin_initialized<S>() && coin::is_coin_initialized<R>(), ERR_IS_NOT_COIN);
        assert!(!stake_config::is_global_emergency(), ERR_EMERGENCY);


        // check collection exists
        if (collection_owner != @0x0 || !string::is_empty(&collection_name) || boost_percent != 0) {
            // todo: add exeption and test
            // todo: test with strange collection_name (very long, 0 len)
            std::debug::print(&b"123");
            assert!(token::check_collection_exists(collection_owner, collection_name), 1);
            assert!(boost_percent >= MIN_NFT_BOOST_PRECENT, 1);
            assert!(boost_percent <= MAX_NFT_BOOST_PERCENT, 1);
        };

        let pool = StakePool<S, R> {
            reward_per_sec,
            accum_reward: 0,
            last_updated: timestamp::now_seconds(),
            stakes: table::new(),
            stake_coins: coin::zero(),
            reward_coins: coin::zero(),
            stake_scale: math64::pow(10, (coin::decimals<S>() as u64)),

            total_boosted: 0,
            collection_owner,
            collection_name,
            boost_percent,

            emergency_locked: false,
            stake_events: account::new_event_handle<StakeEvent>(owner),
            unstake_events: account::new_event_handle<UnstakeEvent>(owner),
            deposit_events: account::new_event_handle<DepositRewardEvent>(owner),
            harvest_events: account::new_event_handle<HarvestEvent>(owner),
        };
        move_to(owner, pool);
    }

    /// Depositing reward coins to specific pool.
    /// * `pool_addr` - address under which pool are stored.
    /// * `coins` - R coins which are used in distribution as reward.
    public fun deposit_reward_coins<S, R>(pool_addr: address, coins: Coin<R>) acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
        assert!(!is_emergency_inner(pool), ERR_EMERGENCY);

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

    /// Checks if pool exists.
    /// * `pool_addr` - address under which pool are stored.
    /// Returns true if pool exists.
    public fun pool_exists<S, R>(pool_addr: address): bool {
        exists<StakePool<S, R>>(pool_addr)
    }

    /// Checks if stake exists.
    /// * `pool_addr` - address under which pool are stored.
    /// * `user_addr` - stake owner address.
    /// Returns true if stake exists.
    public fun stake_exists<S, R>(pool_addr: address, user_addr: address): bool acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let pool = borrow_global<StakePool<S, R>>(pool_addr);

        table::contains(&pool.stakes, user_addr)
    }

    /// Checks current total staked amount in pool.
    /// * `pool_addr` - address under which pool are stored.
    /// Returns total staked amount.
    public fun get_pool_total_stake<S, R>(pool_addr: address): u64 acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        coin::value(&borrow_global<StakePool<S, R>>(pool_addr).stake_coins)
    }

    /// Checks current amount staked by user in specific pool.
    /// * `pool_addr` - address under which pool are stored.
    /// * `user_addr` - stake owner address.
    /// Returns staked amount.
    public fun get_user_stake<S, R>(pool_addr: address, user_addr: address): u64 acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let pool = borrow_global<StakePool<S, R>>(pool_addr);

        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);

        table::borrow(&pool.stakes, user_addr).amount
    }

    /// Checks current pending user reward in specific pool.
    /// * `pool_addr` - address under which pool are stored.
    /// * `user_addr` - stake owner address.
    /// Returns reward amount that can be harvested by stake owner.
    public fun get_pending_user_rewards<S, R>(pool_addr: address, user_addr: address): u64 acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let pool = borrow_global<StakePool<S, R>>(pool_addr);

        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);
        let user_stake = table::borrow(&pool.stakes, user_addr);

        let current_time = timestamp::now_seconds();
        let new_accum_rewards = accum_rewards_since_last_updated(pool, current_time);

        let earned_since_last_update = user_earned_since_last_update(
            pool.accum_reward + new_accum_rewards,
            pool.stake_scale,
            user_stake,
        );

        user_stake.earned_reward + to_u64(earned_since_last_update)
    }

    //
    // Public functions
    //

    /// Stakes user coins in pool.
    /// * `user` - account that making a stake.
    /// * `pool_addr` - address under which pool are stored.
    /// * `coins` - S coins that will be staked in pool.
    public fun stake<S, R>(
        user: &signer,
        pool_addr: address,
        coins: Coin<S>
    ) acquires StakePool {
        assert!(coin::value(&coins) > 0, ERR_AMOUNT_CANNOT_BE_ZERO);
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let current_time = timestamp::now_seconds();
        let user_addr = signer::address_of(user);
        let amount = coin::value(&coins);

        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
        assert!(!is_emergency_inner(pool), ERR_EMERGENCY);

        // update pool accum_reward and timestamp
        update_accum_reward(pool);

        let accum_reward = pool.accum_reward;

        if (!table::contains(&pool.stakes, user_addr)) {
            let new_stake = UserStake {
                amount,
                unobtainable_reward: 0,
                earned_reward: 0,
                unlock_time: current_time + WEEK_IN_SECONDS,
                nft: option::none(),
                boosted_amount: 0,
            };

            // calculate unobtainable reward for new stake
            new_stake.unobtainable_reward = (accum_reward * to_u128(amount)) / to_u128(pool.stake_scale);
            table::add(&mut pool.stakes, user_addr, new_stake);
        } else {
            let user_stake = table::borrow_mut(&mut pool.stakes, user_addr);

            // update earnings
            update_user_earnings<S, R>(accum_reward, pool.stake_scale, user_stake);

            user_stake.amount = user_stake.amount + amount;

            if (option::is_some(&user_stake.nft)) {
                pool.total_boosted = pool.total_boosted - user_stake.boosted_amount;
                user_stake.boosted_amount = (user_stake.amount / 100) * pool.boost_percent;
                pool.total_boosted = pool.total_boosted + user_stake.boosted_amount;
            };

            // recalculate unobtainable reward after stake amount changed
            user_stake.unobtainable_reward =
                (accum_reward * to_u128(user_stake_amount_with_boosted(user_stake))) / to_u128(pool.stake_scale);

            user_stake.unlock_time =  current_time + WEEK_IN_SECONDS;
        };

        coin::merge(&mut pool.stake_coins, coins);

        event::emit_event<StakeEvent>(
            &mut pool.stake_events,
            StakeEvent { user_address: user_addr, amount },
        );
    }

    /// Unstakes user coins from pool.
    /// * `user` - account that owns stake.
    /// * `pool_addr` - address under which pool are stored.
    /// * `amount` - a number of S coins to unstake.
    /// Returns S coins: `Coin<S>`.
    public fun unstake<S, R>(
        user: &signer,
        pool_addr: address,
        amount: u64
    ): Coin<S> acquires StakePool {
        assert!(amount > 0, ERR_AMOUNT_CANNOT_BE_ZERO);
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let user_addr = signer::address_of(user);
        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
        assert!(!is_emergency_inner(pool), ERR_EMERGENCY);

        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);

        // update pool accum_reward and timestamp
        update_accum_reward(pool);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_addr);

        let current_time = timestamp::now_seconds();
        // check unlock timestamp
        assert!(current_time >= user_stake.unlock_time, ERR_TOO_EARLY_UNSTAKE);

        // update earnings
        update_user_earnings<S, R>(pool.accum_reward, pool.stake_scale, user_stake);

        assert!(amount <= user_stake.amount, ERR_NOT_ENOUGH_S_BALANCE);

        user_stake.amount = user_stake.amount - amount;

        if (option::is_some(&user_stake.nft)) {
            pool.total_boosted = pool.total_boosted - user_stake.boosted_amount;
            user_stake.boosted_amount = (user_stake.amount / 100) * pool.boost_percent;
            pool.total_boosted = pool.total_boosted + user_stake.boosted_amount;
        };
        // todo: add nft withdraw on full unstake

        // recalculate unobtainable reward after stake amount changed
        user_stake.unobtainable_reward =
            (pool.accum_reward * to_u128(user_stake_amount_with_boosted(user_stake))) / to_u128(pool.stake_scale);

        event::emit_event<UnstakeEvent>(
            &mut pool.unstake_events,
            UnstakeEvent { user_address: user_addr, amount },
        );

        coin::extract(&mut pool.stake_coins, amount)
    }

    /// Harvests user reward.
    /// * `user` - stake owner account.
    /// * `pool_addr` - address under which pool are stored.
    /// Returns R coins: `Coin<R>`.
    public fun harvest<S, R>(user: &signer, pool_addr: address): Coin<R> acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
        assert!(!is_emergency_inner(pool), ERR_EMERGENCY);

        let user_addr = signer::address_of(user);
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);

        // update pool accum_reward and timestamp
        update_accum_reward(pool);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_addr);

        // update earnings
        update_user_earnings<S, R>(pool.accum_reward, pool.stake_scale, user_stake);

        let earned_to_withdraw = user_stake.earned_reward;
        assert!(earned_to_withdraw > 0, ERR_NOTHING_TO_HARVEST);

        let pool_rewards_balance = coin::value(&pool.reward_coins);
        assert!(pool_rewards_balance > 0, ERR_EMPTY_POOL_REWARD_BALANCE);

        if (earned_to_withdraw > pool_rewards_balance) {
            earned_to_withdraw = pool_rewards_balance;
        };
        user_stake.earned_reward = user_stake.earned_reward - earned_to_withdraw;

        event::emit_event<HarvestEvent>(
            &mut pool.harvest_events,
            HarvestEvent { user_address: user_addr, amount: earned_to_withdraw },
        );

        coin::extract(&mut pool.reward_coins, earned_to_withdraw)
    }

    // todo: add comments
    public fun boost<S, R>(user: &signer, pool_addr: address, nft: Token) acquires StakePool {
        // todo: test
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);

        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
        assert!(!is_emergency_inner(pool), ERR_EMERGENCY);

        // todo: test
        let user_addr = signer::address_of(user);
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);

        let token_id = token::get_token_id(&nft);
        let (collection_owner, collection_name, _, _) = token::get_token_id_fields(&token_id);

        // todo: create according errors and tests
        // check collection id
        assert!(token::check_collection_exists(collection_owner, collection_name), 1);
        assert!(collection_owner == pool.collection_owner, 1);
        assert!(collection_name == pool.collection_name, 1);

        // recalculate pool
        update_accum_reward(pool);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_addr);

        // recalculate stake
        update_user_earnings<S, R>(pool.accum_reward, pool.stake_scale, user_stake);

        // check if not staked before
        // todo: add `already boosted error` test it
        assert!(option::is_none(&user_stake.nft), 1);


        option::fill(&mut user_stake.nft, nft);

        // update user stake and pool after stake boost
        user_stake.boosted_amount = (user_stake.amount / 100) * pool.boost_percent;
        pool.total_boosted = pool.total_boosted + user_stake.boosted_amount;
    }

    /// Enables local "emergency state" for the specific `<S, R>` pool at `pool_addr`. Cannot be disabled.
    public fun enable_emergency<S, R>(admin: &signer, pool_addr: address) acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);
        assert!(
            signer::address_of(admin) == stake_config::get_emergency_admin_address(),
            ERR_NOT_ENOUGH_PERMISSIONS_FOR_EMERGENCY
        );

        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
        assert!(!is_emergency_inner(pool), ERR_EMERGENCY);

        pool.emergency_locked = true;
    }

    // /// Withdraws all the user stake from the pool. Only accessible in the "emergency state".
    // public fun emergency_unstake<S, R>(user: &signer, pool_addr: address): Coin<S> acquires StakePool {
    //     assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);
    //
    //     let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
    //     assert!(is_emergency_inner(pool), ERR_NO_EMERGENCY);
    //
    //     let user_addr = signer::address_of(user);
    //     assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);
    //
    //     let user_stake = table::remove(&mut pool.stakes, user_addr);
    //     // todo: handle nft emergency withdraw
    //     let UserStake { amount, unobtainable_reward: _, earned_reward: _, unlock_time: _, nft: _ } = user_stake;
    //
    //     coin::extract(&mut pool.stake_coins, amount)
    // }

    /// Checks whether "emergency state" is enabled. In that state, only `emergency_unstake()` function is enabled.
    public fun is_emergency<S, R>(pool_addr: address): bool acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);
        let pool = borrow_global<StakePool<S, R>>(pool_addr);
        is_emergency_inner(pool)
    }

    /// Checks whether a specific `<S, R>` pool at the `pool_addr` has an "emergency state" enabled.
    public fun is_local_emergency<S, R>(pool_addr: address): bool acquires StakePool {
        assert!(exists<StakePool<S, R>>(pool_addr), ERR_NO_POOL);
        let pool = borrow_global<StakePool<S, R>>(pool_addr);
        pool.emergency_locked
    }

    fun is_emergency_inner<S, R>(pool: &StakePool<S, R>): bool {
        pool.emergency_locked || stake_config::is_global_emergency()
    }

    /// Calculates pool accumulated reward, updating pool.
    /// * `pool` - pool to update rewards.
    fun update_accum_reward<S, R>(pool: &mut StakePool<S, R>) {
        let current_time = timestamp::now_seconds();
        let new_accum_rewards = accum_rewards_since_last_updated(pool, current_time);

        pool.last_updated = current_time;

        if (new_accum_rewards != 0) {
            pool.accum_reward = pool.accum_reward + new_accum_rewards;
        };
    }

    /// Calculates accumulated reward without pool update.
    /// * `pool` - pool to calculate rewards.
    /// * `current_time` - execution timestamp.
    /// Returns new accumulated reward.
    fun accum_rewards_since_last_updated<S, R>(pool: &StakePool<S, R>, current_time: u64): u128 {
        let seconds_passed = current_time - pool.last_updated;
        if (seconds_passed == 0) return 0;

        // let total_stake = coin::value(&pool.stake_coins);
        let total_stake = pool_total_staked_with_boosted(pool);
        if (total_stake == 0) return 0;

        let total_rewards = to_u128(pool.reward_per_sec) * to_u128(seconds_passed) * to_u128(pool.stake_scale);
        total_rewards / to_u128(total_stake)
    }

    /// Calculates user earnings, updating stake.
    /// * `accum_reward` - reward accumulated by pool.
    /// * `stake_scale` - multiplier to count S coin decimals.
    /// * `user_stake` - stake to update earnings.
    fun update_user_earnings<S, R>(accum_reward: u128, stake_scale: u64, user_stake: &mut UserStake) {
        let earned =
            user_earned_since_last_update(accum_reward, stake_scale, user_stake);
        user_stake.earned_reward = user_stake.earned_reward + to_u64(earned);
        user_stake.unobtainable_reward = user_stake.unobtainable_reward + earned;
    }

    /// Calculates user earnings without stake update.
    /// * `accum_reward` - reward accumulated by pool.
    /// * `stake_scale` - multiplier to count S coin decimals.
    /// * `user_stake` - stake to update earnings.
    /// Returns new stake earnings.
    fun user_earned_since_last_update(accum_reward: u128, stake_scale: u64, user_stake: &UserStake): u128 {
        (accum_reward * (to_u128(user_stake_amount_with_boosted(user_stake))) / to_u128(stake_scale))
            - user_stake.unobtainable_reward
    }

    fun pool_total_staked_with_boosted<S, R>(pool: &StakePool<S, R>): u64 {
        coin::value(&pool.stake_coins) + pool.total_boosted
    }

    fun user_stake_amount_with_boosted(user_stake: &UserStake): u64 {
        user_stake.amount + user_stake.boosted_amount
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
    ): (u128, u64) acquires StakePool {
        let pool = borrow_global<StakePool<S, R>>(pool_addr);
        let fields = table::borrow(&pool.stakes, user_addr);

        (fields.unobtainable_reward, fields.unlock_time)
    }

    #[test_only]
    /// Access staking pool fields with no getters.
    public fun get_pool_info<S, R>(pool_addr: address): (u64, u128, u64, u64, u64) acquires StakePool {
        let pool = borrow_global<StakePool<S, R>>(pool_addr);

        (pool.reward_per_sec, pool.accum_reward, pool.last_updated,
            coin::value<R>(&pool.reward_coins), pool.stake_scale)
    }

    #[test_only]
    /// Force pool & user stake recalculations.
    public fun recalculate_user_stake<S, R>(pool_addr: address, user_addr: address) acquires StakePool {
        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
        update_accum_reward(pool);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_addr);
        update_user_earnings<S, R>(pool.accum_reward, pool.stake_scale, user_stake);
    }
}
