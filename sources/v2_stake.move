module harvest::v2_stake {
    use std::signer;
    use std::string::String;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::event::{Self, EventHandle};

    use aptos_std::type_info;
    use aptos_std::table::Table;
    use aptos_std::table;

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

    /// Not enough coins to stake, less than minimum.
    const ERR_MIN_STAKE: u64 = 104;

    /// Only admin can execute.
    const ERR_NO_PERMISSIONS: u64 = 105;

    /// `CoinType` is not a coin
    const ERR_IS_NOT_COIN: u64 = 106;

    /// When lock duration is less than minimum.
    const ERR_MIN_DURATION: u64 = 107;

    /// When lock duration is greater than maximum.
    const ERR_MAX_DURATION: u64 = 108;

    /// When stake exists for user already.
    const ERR_STAKE_EXISTS: u64 = 109;

    //
    // Constants
    //

    /// multiplier to account six decimal places for staked and reward coins
    const SIX_DECIMALS: u128 = 1000000;

    /// minimum stake period duration (week)
    const MIN_STAKE_DURATION: u64 = 604800;

    /// maximum stake period duration (~year)
    const MAX_STAKE_DURATION: u64 = 31536000;

    /// minimum amount to stake 0.01 LP
    const MIN_STAKE_AMOUNT: u64 = 10000;

    // Constants.

    /// 100%
    const BOOST_WEIGHT: u128 = 100000000;

    /// 365 days in seconds
    const DURATION_FACTOR: u128 = 31536000;

    /// precision factor
    const PRECISION_FACTOR: u128 = 100000000;

    /// boost precision
    const BOOST_PRECISION: u64 = 1000000000000;

    ///
    /// uint256 public constant PRECISION_FACTOR_SHARE = 1e28; // precision factor for share.
    // todo: I'M a wrong value, not 1e28, change me
    const PRECISION_FACTOR_SHARE: u64 = 1000000000000000000;

    //
    // Core data structures
    //

    /// User information.
    struct UserInfo<phantom StakeCoin, phantom RewardCoinn> has store {
        // shares
        shares: u128,
        tokens_at_last_user_action: u128,
        user_boosted_share: u128,
        // time
        last_user_action_time: u64,
        last_deposit_time: u64,
        lock_start_time: u64,
        lock_end_time: u64,
        // amount & locked
        locked_amount: u64,
        locked: bool,
    }

    /// Stakinng pool.
    struct StakePool<phantom StakeCoin,phantom RewardCoin> has key {
        // DGEN reward per second
        reward_per_second: u64,
        // total boosted share
        total_boosted_share: u128,
        // last reward time
        last_reward_time: u64,
        // total shares
        total_shares: u128,
        // total boost debt
        total_boost_debt: u128,
        // locked amount
        total_locked_amount: u64,
        // pool staked coins
        staked_coins: Coin<StakeCoin>,
        // pool reward coins
        reward_coins: Coin<RewardCoin>,
        // Users who stake for pool.
        users: Table<address, UserInfo<StakeCoin, RewardCoin>>,
        // stake events
        stake_events: EventHandle<StakeEvent>,
        // unstake events
        unstake_events: EventHandle<UnstakeEvent>,
        // deposit events
        deposit_events: EventHandle<DepositRewardEvent>,
        // harvest events
        harvest_events: EventHandle<HarvestEvent>,
    }

    /// Stores events emitted on pool registration under Harvest account
    struct RegisterEventsStorage has key { register_events: EventHandle<RegisterEvent> }

    /// initializes module, creating resource account to store pools
    public entry fun initialize(harvest: &signer) {
        assert!(signer::address_of(harvest) == @harvest, ERR_NO_PERMISSIONS);

        move_to(harvest,
            RegisterEventsStorage { register_events: account::new_event_handle<RegisterEvent>(harvest) });
    }

    //
    // Pool config
    //

    /// Registering staking pool on resource account with provided LP coins and `Reward` coin as rewards.
    /// * `pool_creator` - creator of the pool.
    /// * `reward_per_sec` - reward per second that shared between stackers.
    /// * `seed` - seed for creating new resource account.
    /// Returns address stores pool.
    public fun register<S, R>(
        pool_creator: &signer,
        reward_per_sec: u64,
        seed: vector<u8>
    ): address acquires RegisterEventsStorage {
        assert!(reward_per_sec > 0, ERR_REWARD_CANNOT_BE_ZERO);
        assert!(coin::is_coin_initialized<S>(), ERR_IS_NOT_COIN);
        assert!(coin::is_coin_initialized<R>(), ERR_IS_NOT_COIN);

        let (rs_signer, _) =
            account::create_resource_account(pool_creator, seed);

        let rs_address = signer::address_of(&rs_signer);

        assert!(!exists<StakePool<S, R>>(rs_address), ERR_POOL_ALREADY_EXISTS);

        let pool = StakePool<S, R> {
            reward_per_second: 0,
            // acc_reward_per_share: 0,
            total_boosted_share: 0,
            last_reward_time: timestamp::now_seconds(),
            total_shares: 0,
            total_boost_debt: 0,
            total_locked_amount: 0,
            staked_coins: coin::zero(),
            reward_coins: coin::zero(),
            users: table::new(),
            stake_events: account::new_event_handle<StakeEvent>(&rs_signer),
            unstake_events: account::new_event_handle<UnstakeEvent>(&rs_signer),
            deposit_events: account::new_event_handle<DepositRewardEvent>(&rs_signer),
            harvest_events: account::new_event_handle<HarvestEvent>(&rs_signer),
        };

        move_to(&rs_signer, pool);

        let stake_coin_type = type_info::type_name<S>();
        let reward_coin_type = type_info::type_name<R>();

        let event_storage = borrow_global_mut<RegisterEventsStorage>(@harvest);
        event::emit_event<RegisterEvent>(
            &mut event_storage.register_events,
            RegisterEvent {
                resource_address: rs_address,
                reward_per_sec,
                stake_coin_type,
                reward_coin_type
            },
        );

        rs_address
    }

    //
    // Getter functions
    //

    /// Aborts if pool doesn't exists.
    fun assert_pool_exists<S, R>(pool_addr: address) {
        assert!(pool_exists<S, R>(pool_addr), ERR_NO_POOL);
    }

    /// Determines if pool exists.
    public fun pool_exists<S, R>(pool_addr: address): bool {
        exists<StakePool<S, R>>(pool_addr)
    }

    /// Aborts if user stake doesn't exists.
    fun assert_user_stake_exists<S, R>(pool_addr: address, user_addr: address) acquires StakePool {
        assert!(user_stake_exists<S, R>(pool_addr, user_addr), ERR_NO_STAKE);
    }

    /// Determines if user has/had stakes.
    public fun user_stake_exists<S, R>(pool_addr: address, user_addr: address): bool acquires StakePool {
        assert_pool_exists<S, R>(pool_addr);
        let pool = borrow_global<StakePool<S, R>>(pool_addr);

        table::contains(&pool.users, user_addr)
    }

    /// Returns current amount staked in pool.
    public fun get_pool_total_stake<S, R>(pool_addr: address): u64 acquires StakePool {
        assert_pool_exists<S, R>(pool_addr);
        coin::value(&borrow_global<StakePool<S, R>>(pool_addr).staked_coins)
    }

    /// Returns current amount staked by user in specific pool.
    public fun get_user_stake<S, R>(pool_addr: address, user_address: address): u64 acquires StakePool {
        assert_pool_exists<S, R>(pool_addr);
        let pool = borrow_global<StakePool<S, R>>(pool_addr);

        assert!(table::contains(&pool.users, user_address), ERR_NO_STAKE);

        let user_stake = table::borrow(&pool.users, user_address);
        user_stake.locked_amount
    }

    //
    // Public functions
    //

    /// When user stakes first time.
    public fun stake<S, R>(user: &signer, pool_addr: address, to_stake: Coin<S>, lock_duration: u64) acquires StakePool {
        assert_pool_exists<S, R>(pool_addr);

        let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);

        let user_address = signer::address_of(user);
        assert!(!table::contains(&pool.users, user_address), ERR_STAKE_EXISTS);

        let to_stake_val = coin::value(&to_stake);
        assert!(to_stake_val >= MIN_STAKE_AMOUNT, ERR_MIN_STAKE);

        assert!(lock_duration >= MIN_STAKE_DURATION, ERR_MIN_DURATION);
        assert!(lock_duration <= MAX_STAKE_DURATION, ERR_MAX_DURATION);

        let current_time = timestamp::now_seconds();

        let user_stake = UserInfo<S, R> {
            shares: 0,
            last_deposit_time: 0,
            tokens_at_last_user_action: 0,
            last_user_action_time: 0,
            lock_start_time: 0,
            lock_end_time: 0,
            user_boosted_share: 0,
            locked: false,
            locked_amount: 0,
        };

        user_stake.lock_start_time = current_time;
        user_stake.lock_end_time = current_time + lock_duration;

        coin::merge(&mut pool.staked_coins, to_stake);

        let staked_coins_val = (coin::value(&pool.staked_coins) as u128);

        let pool_balance = staked_coins_val + pool.total_boost_debt;
        let current_shares = if (pool.total_shares != 0) {
            ((to_stake_val as u128) * pool.total_shares) / pool_balance
        } else {
            (to_stake_val as u128)
        };

        aptos_std::debug::print(&current_shares);

        let boost_weight = ((lock_duration as u128) * BOOST_WEIGHT) / DURATION_FACTOR;
        aptos_std::debug::print(&boost_weight);
        let boost_shares = (boost_weight * current_shares) / PRECISION_FACTOR;

        current_shares = current_shares + boost_shares;
        user_stake.shares = user_stake.shares + current_shares;

        let user_boosted_share = (boost_weight * (to_stake_val as u128)) / PRECISION_FACTOR;
        user_stake.user_boosted_share = user_stake.user_boosted_share + user_boosted_share;
        pool.total_boost_debt = pool.total_boost_debt + user_boosted_share;

        user_stake.locked_amount = user_stake.locked_amount + to_stake_val;
        pool.total_locked_amount = pool.total_locked_amount + to_stake_val;

        user_stake.last_deposit_time = current_time;
        pool.total_shares = pool.total_shares + current_shares;

        pool_balance = staked_coins_val + pool.total_boost_debt;

        user_stake.tokens_at_last_user_action =
            (user_stake.shares * pool_balance) / pool.total_shares - user_stake.user_boosted_share;

        user_stake.last_user_action_time = current_time;
        user_stake.locked = true;

        aptos_std::debug::print(&user_stake);
        //aptos_std::debug::print(pool);

        table::add(&mut pool.users, user_address, user_stake);
    }

    // Stake `S` coins in the pool.
    // public fun update_stake_1<S, R>(user: &signer, pool_addr: address, coins: Coin<S>, lock_duration: u64) acquires StakePool {
    //     assert_pool_exists<S, R>(pool_addr);
    //
    //     // todo: add assert and error.
    //     // require(_amount > 0 || _lockDuration > 0, "Nothing to deposit");
    //
    //     let user_address = signer::address_of(user);
    //     let amount = coin::value(&coins);
    //
    //     let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
    //
    //     // create if not exists
    //     if (!table::contains(&pool.users, user_address)) {
    //         let empty_stake = UserInfo<S, R> {
    //             shares: 0,
    //             last_deposit_time: 0,
    //             tokens_at_last_user_action: 0,
    //             last_user_action_time: 0,
    //             lock_start_time: 0,
    //             lock_end_time: 0,
    //             user_boosted_share: 0,
    //             locked: false,
    //             locked_amount: 0,
    //         };
    //         table::add(&mut pool.users, user_address, empty_stake);
    //     };
    //
    //     let user_stake = table::borrow_mut(&mut pool.users, user_address);
    //
    //     // if stakes first time user_stake.shares == 0
    //     // if stakes more amount > 0
    //     if (user_stake.shares == 0 || amount > 0) {
    //         assert!(amount >= MIN_STAKE_AMOUNT, ERR_MIN_STAKE);
    //     };
    //
    //     // calculate the total lock duration and check whether the lock duration meets the conditions
    //     let current_time = timestamp::now_seconds();
    //     let total_lock_duration = lock_duration;
    //
    //     // if something already staked and not expired?
    //     if (user_stake.lock_end_time >= current_time) {
    //         // adding funds during the lock duration is equivalent to re-locking the position, needs to update some variables.
    //         if (amount > 0) {
    //             user_stake.lock_start_time = current_time;
    //             pool.total_locked_amount = pool.total_locked_amount - user_stake.locked_amount;
    //             user_stake.locked_amount = 0;
    //         };
    //         // todo: check it later
    //         // prolong stake duration
    //         total_lock_duration = total_lock_duration + (user_stake.lock_end_time - user_stake.lock_start_time);
    //     };
    //
    //     // todo: test when amount zero but longer duration etc
    //     // todo: create according errors and tests
    //     // min lock period check
    //     assert!(lock_duration == 0 || total_lock_duration >= MIN_STAKE_DURATION, ERR_MIN_DURATION);
    //     // max lock period check
    //     assert!(total_lock_duration <= MAX_STAKE_DURATION, ERR_MAX_DURATION);
    //
    //     coin::merge(&mut pool.staked_coins, coins);
    //
    //     // harvest(pool, user_stake);
    //
    //     // update user share
    //     update_stake(pool, user_stake);
    //
    //     // update lock duration
    //     // only on first stake or duration prolongation
    //     if (lock_duration > 0) {
    //         if (user_stake.lock_end_time < current_time) {
    //             // first stake
    //             user_stake.lock_start_time = current_time;
    //             user_stake.lock_end_time = current_time + lock_duration;
    //         } else {
    //             // duration + stake
    //             user_stake.lock_end_time = user_stake.lock_end_time + lock_duration;
    //         };
    //         user_stake.locked = true;
    //     };
    //
    //     let current_shares;
    //     let current_amount = amount;
    //     let user_current_locked_balance = 0;
    //     let pool_balance = coin::value(&pool.staked_coins) + pool.total_boost_debt;
    //
    //     // calculate lock funds
    //     if (user_stake.shares > 0 && user_stake.locked) {
    //         user_current_locked_balance = (pool_balance * user_stake.shares) / pool.total_shares;
    //         current_amount = current_amount + user_current_locked_balance;
    //         pool.total_shares = pool.total_shares - user_stake.shares;
    //         user_stake.shares = 0;
    //
    //         // update lock amount
    //         if (user_stake.lock_start_time == current_time) {
    //             user_stake.locked_amount = user_current_locked_balance;
    //             pool.total_locked_amount = pool.total_locked_amount + user_stake.locked_amount;
    //         }
    //     };
    //
    //     if (pool.total_shares != 0) {
    //         current_shares = (current_amount * pool.total_shares) / (pool_balance - user_current_locked_balance);
    //     } else {
    //         current_shares = current_amount;
    //     };
    //
    //     if (user_stake.lock_end_time > user_stake.lock_start_time) {
    //         let boost_weight =
    //             ((user_stake.lock_end_time - user_stake.lock_start_time) * BOOST_WEIGHT) / DURATION_FACTOR;
    //         let boost_shares = (boost_weight * current_shares) / PRECISION_FACTOR;
    //
    //         current_shares = current_shares + boost_shares;
    //         user_stake.shares = user_stake.shares + current_shares;
    //
    //         let user_boosted_share = (boost_weight * current_amount) / PRECISION_FACTOR;
    //         user_stake.user_boosted_share = user_stake.user_boosted_share + user_boosted_share;
    //         pool.total_boost_debt = pool.total_boost_debt + user_boosted_share;
    //
    //         user_stake.locked_amount = user_stake.locked_amount + amount;
    //         pool.total_locked_amount = pool.total_locked_amount + amount;
    //         // todo: emit lock??
    //     } else {
    //         user_stake.shares = user_stake.shares + current_shares;
    //     };
    //
    //     if (amount > 0 || lock_duration > 0) {
    //         user_stake.last_deposit_time = current_time;
    //     };
    //     pool.total_shares = pool.total_shares + current_shares;
    //
    //     user_stake.tokens_at_last_user_action =
    //         (user_stake.shares * balance_of(pool)) / pool.total_shares - user_stake.user_boosted_share;
    //     user_stake.last_user_action_time = current_time;
    //
    //     std::debug::print(&user_stake.shares);
    //     std::debug::print(&user_stake.locked_amount);
    //
    //     event::emit_event<StakeEvent>(
    //         &mut pool.stake_events,
    //         StakeEvent { user_address, amount, lock_duration /* todo: check duration */ },
    //     );
    // }

    // fun balance_of<S, R>(pool: &StakePool<S, R>): u64 {
    //     // todo: remove this function or add asserts like: exists<pool>
    //
    //     // pool.total_locked_amount + pool.total_boost_debt
    //     coin::value(&pool.staked_coins) + pool.total_boost_debt
    // }

    // fun update_stake<S, R>(
    //     pool: &mut StakePool<S, R>,
    //     user_stake: &mut UserInfo<S, R>
    // ) {
    //     if (user_stake.shares > 0) {
    //         if (user_stake.locked) {
    //             // calculate the user's current token amount and update related parameters
    //             let pool_balance = balance_of(pool);
    //             let current_amount = (pool_balance * user_stake.shares) / pool.total_shares - user_stake.user_boosted_share;
    //             pool.total_boost_debt = pool.total_boost_debt - user_stake.user_boosted_share;
    //             user_stake.user_boosted_share = 0;
    //             pool.total_shares = pool.total_shares - user_stake.shares;
    //
    //             // todo: overdue fee was here
    //
    //             // recalculate the user share
    //             let current_shares;
    //             if (pool.total_shares != 0) {
    //                 current_shares = (current_amount * pool.total_shares) / (pool_balance - current_amount);
    //             } else {
    //                 current_shares = current_amount;
    //             };
    //
    //             user_stake.shares = current_shares;
    //             pool.total_shares = pool.total_shares + current_shares;
    //
    //             // after the lock duration, update related parameters
    //             let current_time = timestamp::now_seconds();
    //             if (user_stake.lock_end_time < current_time) {
    //                 pool.total_locked_amount = pool.total_locked_amount - user_stake.locked_amount;
    //                 user_stake.locked = false;
    //                 user_stake.lock_start_time = 0;
    //                 user_stake.lock_end_time = 0;
    //                 user_stake.locked_amount = 0;
    //                 // todo: emit unlock?
    //             }
    //         // todo: !free performance fee use case
    //         }
    //     }
    // }

    //     function withdrawOperation(uint256 _shares, uint256 _amount) internal {
    // public fun unstake<S, R>(user: &signer, pool_addr: address, shares: u64, amount: u64): Coin<S> acquires StakePool {
    //     assert_pool_exists<S, R>(pool_addr);
    //
    //     let pool = borrow_global_mut<StakePool<S, R>>(pool_addr);
    //     let user_address = signer::address_of(user);
    //
    //     assert!(table::contains(&pool.users, user_address), ERR_NO_STAKE);
    //
    //     let user_stake = table::borrow_mut(&mut pool.users, user_address);
    //     let current_time = timestamp::now_seconds();
    //
    //     // todo: use existing amount error, use existing test
    //     assert!(shares <= user_stake.shares, 1);
    //     // todo: create error and test
    //     assert!(user_stake.lock_end_time < current_time, 1);
    //
    //     let current_share;
    //     let shares_percent = (shares * PRECISION_FACTOR_SHARE) / user_stake.shares;
    //
    //     //     harvest();
    //     update_stake(pool, user_stake);
    //
    //     if (shares == 0 && amount > 0) {
    //         let pool_balance = balance_of(pool);
    //         // calculate equivalent shares
    //         current_share = (amount * pool.total_shares) / pool_balance;
    //         if (current_share > user_stake.shares) {
    //           current_share = user_stake.shares;
    //         };
    //     } else {
    //         current_share = (shares_percent * user_stake.shares) / PRECISION_FACTOR_SHARE;
    //     };
    //
    //     let current_amount = (balance_of(pool) * current_share) / pool.total_shares;
    //
    //     // todo: do we need withdraw fee? It was here btw
    //
    //     let coins = coin::extract(&mut pool.staked_coins, current_amount);
    //
    //     if (user_stake.shares > 0) {
    //         user_stake.tokens_at_last_user_action = (user_stake.shares * balance_of(pool)) / pool.total_shares;
    //     } else {
    //         user_stake.tokens_at_last_user_action = 0;
    //     };
    //
    //     user_stake.last_user_action_time = current_time;
    //
    //     event::emit_event<UnstakeEvent>(
    //         &mut pool.unstake_events,
    //         UnstakeEvent { user_address, amount },
    //     );
    //
    //     coins
    // }

    //
    // Events
    //

    struct RegisterEvent has drop, store {
        resource_address: address,
        reward_per_sec: u64,
        stake_coin_type: String,
        reward_coin_type: String,
    }

    struct StakeEvent has drop, store {
        user_address: address,
        amount: u64,
        lock_duration: u64,
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
}
