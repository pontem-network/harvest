module harvest::v2_stake {
    use std::signer;
    use std::string::String;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::event::{Self, EventHandle};
    use liquidswap_lp::lp_coin::LP;

    use aptos_std::type_info;

    //
    // Errors
    //

    /// pool does not exist
    const ERR_NO_POOL: u64 = 100;

    /// pool already exists
    const ERR_POOL_ALREADY_EXISTS: u64 = 101;

    /// pool reward can't be zero
    const ERR_REWARD_CANNOT_BE_ZERO: u64 = 102;

    /// user has no stake
    const ERR_NO_STAKE: u64 = 103;

    /// not enough LP balance to unstake
    const ERR_NOT_ENOUGH_LP_BALANCE: u64 = 104;

    /// only admin can execute
    const ERR_NO_PERMISSIONS: u64 = 105;

    /// not enough pool DGEN balance to pay reward
    const ERR_NOT_ENOUGH_DGEN_BALANCE: u64 = 106;

    /// amount can't be zero
    const ERR_AMOUNT_CANNOT_BE_ZERO: u64 = 107;

    /// nothing to harvest yet
    const ERR_NOTHING_TO_HARVEST: u64 = 108;

    /// module not initialized
    const ERR_MODULE_NOT_INITIALIZED: u64 = 109;

    /// CoinType is not a coin
    const ERR_IS_NOT_COIN: u64 = 110;

    //
    // Constants
    //

    /// multiplier to account six decimal places for LP and DGEN coins
    const SIX_DECIMALS: u128 = 1000000;

    /// minimum stake period duration (week)
    const MIN_STAKE_DURATION: u64 = 604800;

    /// maximum stake period duration (~year)
    const MAX_STAKE_DURATION: u64 = 31536000;

    /// minimum amount to stake 0.01 LP
    const MIN_STAKE_AMOUNT: u64 = 10000;

    /// 100%
    const BOOST_WEIGHT: u64 = 1000000000000;

    /// 365 days in seconds
    const DURATION_FACTOR: u64 = 31536000;

    /// precision factor
    const PRECISION_FACTOR: u64 = 1000000000000;

    /// boost precision
    const BOOST_PRECISION: u64 = 1000000000000;

    ///
    /// uint256 public constant PRECISION_FACTOR_SHARE = 1e28; // precision factor for share.
    // todo: I'M a wrong value, not 1e28, change me
    const PRECISION_FACTOR_SHARE: u64 = 1000000000000000000;

    //
    // Core data structures
    //

    struct UserInfo<phantom X, phantom Y, phantom Curve, phantom Reward> has key {
        shares: u64,
        last_deposit_time: u64,
        tokens_at_last_user_action: u64,
        last_user_action_time: u64,
        lock_start_time: u64,
        lock_end_time: u64,
        user_boosted_share: u64,

        locked: bool,
        locked_amount: u64,
    }

    /// LP stake pool, stores LP, DGEN (reward) coins and related info
    struct StakePool<phantom X, phantom Y, phantom Curve, phantom Reward> has key {
        // DGEN reward per second
        reward_per_second: u64,
        // total boosted share
        total_boosted_share: u64,
        // last reward time
        last_reward_time: u64,
        // total shares
        total_shares: u64,
        // total boost debt
        total_boost_debt: u64,
        // locked amount
        total_locked_amount: u64,
        // pool staked LP coins
        lp_coins: Coin<LP<X, Y, Curve>>,
        // pool reward DGEN coins
        dgen_coins: Coin<Reward>,
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
    public entry fun initialize(dgen_stake_admin: &signer) {
        assert!(signer::address_of(dgen_stake_admin) == @harvest, ERR_NO_PERMISSIONS);

        move_to(dgen_stake_admin,
            RegisterEventsStorage { register_events: account::new_event_handle<RegisterEvent>(dgen_stake_admin) });
    }

    //
    // Pool config
    //

    /// Registering staking pool on resource account with provided LP coins and `Reward` coin as rewards.
    /// * `pool_creator` - creator of the pool.
    /// * `reward_per_sec` - reward per second that shared between stackers.
    /// * `seed` - seed for creating new resource account.
    public fun register<X, Y, Curve, Reward>(
        pool_creator: &signer,
        reward_per_sec: u64,
        seed: vector<u8>
    ): address acquires RegisterEventsStorage {
        assert!(reward_per_sec > 0, ERR_REWARD_CANNOT_BE_ZERO);
        assert!(coin::is_coin_initialized<LP<X, Y, Curve>>(), ERR_IS_NOT_COIN);
        assert!(coin::is_coin_initialized<Reward>(), ERR_IS_NOT_COIN);

        let (rs_signer, _) =
            account::create_resource_account(pool_creator, seed);

        let rs_address = signer::address_of(&rs_signer);

        assert!(!exists<StakePool<X, Y, Curve, Reward>>(rs_address), ERR_POOL_ALREADY_EXISTS);

        let pool = StakePool<X, Y, Curve, Reward> {
            reward_per_second: 0,
            // acc_reward_per_share: 0,
            total_boosted_share: 0,
            last_reward_time: timestamp::now_seconds(),
            total_shares: 0,
            total_boost_debt: 0,
            total_locked_amount: 0,
            lp_coins: coin::zero(),
            dgen_coins: coin::zero(),
            stake_events: account::new_event_handle<StakeEvent>(&rs_signer),
            unstake_events: account::new_event_handle<UnstakeEvent>(&rs_signer),
            deposit_events: account::new_event_handle<DepositRewardEvent>(&rs_signer),
            harvest_events: account::new_event_handle<HarvestEvent>(&rs_signer),
        };

        move_to(&rs_signer, pool);

        let lp_type_name = type_info::type_name<LP<X, Y, Curve>>();
        let event_storage = borrow_global_mut<RegisterEventsStorage>(@harvest);
        event::emit_event<RegisterEvent>(
            &mut event_storage.register_events,
            RegisterEvent { creator_address: signer::address_of(pool_creator), reward_per_sec, lp_type_name },
        );

        rs_address
    }

    //
    // Getter functions
    //

    /// returns current LP amount staked in pool
    public fun get_pool_total_stake<X, Y, Curve, Reward>(pool_addr: address): u64 acquires StakePool {
        assert!(exists<StakePool<X, Y, Curve, Reward>>(pool_addr), ERR_NO_POOL);
        coin::value(&borrow_global<StakePool<X, Y, Curve, Reward>>(pool_addr).lp_coins)
    }

    /// returns current LP amount staked by user in specific pool
    public fun get_user_stake<X, Y, Curve, Reward>(user_address: address): u64 acquires UserInfo {
        assert!(exists<StakePool<X, Y, Curve, Reward>>(@staking_storage), ERR_NO_POOL);

        if (exists<UserInfo<X, Y, Curve, Reward>>(user_address)) {
            borrow_global<UserInfo<X, Y, Curve, Reward>>(user_address).locked_amount
        } else {
            // todo: doesn't exists!
            0
        }
    }

    //
    // Public functions
    //

    public fun stake<X, Y, Curve, Reward>(user: &signer, coins: Coin<LP<X, Y, Curve>>, lock_duration: u64) acquires StakePool, UserInfo {
        assert!(exists<StakePool<X, Y, Curve, Reward>>(@staking_storage), ERR_NO_POOL);
        // todo: add assert and error
        // require(_amount > 0 || _lockDuration > 0, "Nothing to deposit");

        let user_address = signer::address_of(user);
        let amount = coin::value(&coins);
        let pool = borrow_global_mut<StakePool<X, Y, Curve, Reward>>(@staking_storage);

        // create if not exists
        if (!exists<UserInfo<X, Y, Curve, Reward>>(user_address)) {
            let empty_stake = UserInfo<X, Y, Curve, Reward> {
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
            move_to(user, empty_stake);
        };

        let user_stake = borrow_global_mut<UserInfo<X, Y, Curve, Reward>>(user_address);

        // if stakes first time user_stake.shares == 0
        // if stakes more amount > 0
        if (user_stake.shares == 0 || amount > 0) {
            // todo: add according error and test
            assert!(amount >= MIN_STAKE_AMOUNT, 1);
        };

        // calculate the total lock duration and check whether the lock duration meets the conditions
        let current_time = timestamp::now_seconds();
        let total_lock_duration = lock_duration;

        // if something already staked?
        if (user_stake.lock_end_time >= current_time) {
            // adding funds during the lock duration is equivalent to re-locking the position, needs to update some variables
            if (amount > 0) {
                user_stake.lock_start_time = current_time;
                pool.total_locked_amount = pool.total_locked_amount - user_stake.locked_amount;
                user_stake.locked_amount = 0;
            };
            // todo: check it later
            // prolong stake duration
            total_lock_duration = total_lock_duration + (user_stake.lock_end_time - user_stake.lock_start_time);
        };

        // todo: test when amount zero but longer duration etc
        // todo: create according errors and tests
        // min lock period check
        assert!(lock_duration == 0 || total_lock_duration >= MIN_STAKE_DURATION, 1);
        // max lock period check
        assert!(total_lock_duration <= MAX_STAKE_DURATION, 1);

        coin::merge(&mut pool.lp_coins, coins);

        // harvest(pool, user_stake);

        // update user share
        update_stake(pool, user_stake);

        // update lock duration
        // only on first stake or duration prolongation
        if (lock_duration > 0) {
            if (user_stake.lock_end_time < current_time) {
                // first stake
                user_stake.lock_start_time = current_time;
                user_stake.lock_end_time = current_time + lock_duration;
            } else {
                // duration + stake
                user_stake.lock_end_time = user_stake.lock_end_time + lock_duration;
            };
            user_stake.locked = true;
        };

        let current_shares;
        let current_amount = amount;
        let user_current_locked_balance = 0;
        let pool_balance = balance_of<X, Y, Curve, Reward>(pool);

        // calculate lock funds
        if (user_stake.shares > 0 && user_stake.locked) {
            user_current_locked_balance = (pool_balance * user_stake.shares) / pool.total_shares;
            current_amount = current_amount + user_current_locked_balance;
            pool.total_shares = pool.total_shares - user_stake.shares;
            user_stake.shares = 0;

            // update lock amount
            if (user_stake.lock_start_time == current_time) {
                user_stake.locked_amount = user_current_locked_balance;
                pool.total_locked_amount = pool.total_locked_amount + user_stake.locked_amount;
            }
        };

        if (pool.total_shares != 0) {
            current_shares = (current_amount * pool.total_shares) / (pool_balance - user_current_locked_balance);
        } else {
            current_shares = current_amount;
        };

        if (user_stake.lock_end_time > user_stake.lock_start_time) {
            let boost_weight =
                ((user_stake.lock_end_time - user_stake.lock_start_time) * BOOST_WEIGHT) / DURATION_FACTOR;
            let boost_shares = (boost_weight * current_shares) / PRECISION_FACTOR;

            current_shares = current_shares + boost_shares;
            user_stake.shares = user_stake.shares + current_shares;

            let user_boosted_share = (boost_weight * current_amount) / PRECISION_FACTOR;
            user_stake.user_boosted_share = user_stake.user_boosted_share + user_boosted_share;
            pool.total_boost_debt = pool.total_boost_debt + user_boosted_share;

            user_stake.locked_amount = user_stake.locked_amount + amount;
            pool.total_locked_amount = pool.total_locked_amount + amount;
            // todo: emit lock??
        } else {
            user_stake.shares = user_stake.shares + current_shares;
        };

        if (amount > 0 || lock_duration > 0) {
            user_stake.last_deposit_time = current_time;
        };
        pool.total_shares = pool.total_shares + current_shares;

        user_stake.tokens_at_last_user_action =
            (user_stake.shares * balance_of(pool)) / pool.total_shares - user_stake.user_boosted_share;
        user_stake.last_user_action_time = current_time;

        std::debug::print(&user_stake.shares);
        std::debug::print(&user_stake.locked_amount);

        event::emit_event<StakeEvent>(
            &mut pool.stake_events,
            StakeEvent { user_address, amount, lock_duration /* todo: check duration */ },
        );
    }

    fun balance_of<X, Y, Curve, Reward>(pool: &StakePool<X, Y, Curve, Reward>): u64 {
        // todo: remove this function or add asserts like: exists<pool>

        // pool.total_locked_amount + pool.total_boost_debt
        coin::value(&pool.lp_coins) + pool.total_boost_debt
    }

    fun update_stake<X, Y, Curve, Reward>(
        pool: &mut StakePool<X, Y, Curve, Reward>,
        user_stake: &mut UserInfo<X, Y, Curve, Reward>
    ) {
        if (user_stake.shares > 0) {
            if (user_stake.locked) {
                // calculate the user's current token amount and update related parameters
                let pool_balance = balance_of(pool);
                let current_amount = (pool_balance * user_stake.shares) / pool.total_shares - user_stake.user_boosted_share;
                pool.total_boost_debt = pool.total_boost_debt - user_stake.user_boosted_share;
                user_stake.user_boosted_share = 0;
                pool.total_shares = pool.total_shares - user_stake.shares;

                // todo: overdue fee was here

                // recalculate the user share
                let current_shares;
                if (pool.total_shares != 0) {
                    current_shares = (current_amount * pool.total_shares) / (pool_balance - current_amount);
                } else {
                    current_shares = current_amount;
                };

                user_stake.shares = current_shares;
                pool.total_shares = pool.total_shares + current_shares;

                // after the lock duration, update related parameters
                let current_time = timestamp::now_seconds();
                if (user_stake.lock_end_time < current_time) {
                    pool.total_locked_amount = pool.total_locked_amount - user_stake.locked_amount;
                    user_stake.locked = false;
                    user_stake.lock_start_time = 0;
                    user_stake.lock_end_time = 0;
                    user_stake.locked_amount = 0;
                    // todo: emit unlock?
                }
            // todo: !free performance fee use case
            }
        }
    }

    //     function withdrawOperation(uint256 _shares, uint256 _amount) internal {
    public fun unstake<X, Y, Curve, Reward>(user: &signer, shares: u64, amount: u64): Coin<LP<X, Y, Curve>> acquires StakePool, UserInfo {
        let user_address = signer::address_of(user);

        // todo: test
        assert!(exists<RegisterEventsStorage>(@harvest), ERR_MODULE_NOT_INITIALIZED);
        // todo: test
        assert!(exists<StakePool<X, Y, Curve, Reward>>(@staking_storage), ERR_NO_POOL);
        // todo: test
        assert!(exists<UserInfo<X, Y, Curve, Reward>>(user_address), ERR_NO_STAKE);

        let pool = borrow_global_mut<StakePool<X, Y, Curve, Reward>>(@staking_storage);
        let user_stake = borrow_global_mut<UserInfo<X, Y, Curve, Reward>>(user_address);
        let current_time = timestamp::now_seconds();

        // todo: use existing amount error, use existing test
        assert!(shares <= user_stake.shares, 1);
        // todo: create error and test
        assert!(user_stake.lock_end_time < current_time, 1);

        let current_share;
        let shares_percent = (shares * PRECISION_FACTOR_SHARE) / user_stake.shares;

        //     harvest();

        update_stake(pool, user_stake);

        if (shares == 0 && amount > 0) {
            let pool_balance = balance_of(pool);
            // calculate equivalent shares
            current_share = (amount * pool.total_shares) / pool_balance;
            if (current_share > user_stake.shares) {
              current_share = user_stake.shares;
            };
        } else {
            current_share = (shares_percent * user_stake.shares) / PRECISION_FACTOR_SHARE;
        };

        let current_amount = (balance_of(pool) * current_share) / pool.total_shares;

        // todo: do we need withdraw fee? It was here btw

        let coins = coin::extract(&mut pool.lp_coins, current_amount);

        if (user_stake.shares > 0) {
            user_stake.tokens_at_last_user_action = (user_stake.shares * balance_of(pool)) / pool.total_shares;
        } else {
            user_stake.tokens_at_last_user_action = 0;
        };

        user_stake.last_user_action_time = current_time;

        event::emit_event<UnstakeEvent>(
            &mut pool.unstake_events,
            UnstakeEvent { user_address, amount },
        );

        coins
    }

    //
    // Events
    //

    struct RegisterEvent has drop, store {
        creator_address: address,
        reward_per_sec: u64,
        lp_type_name: String,
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
