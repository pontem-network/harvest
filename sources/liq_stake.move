module staking_admin::liq_stake {
    use std::signer;
    use std::string::String;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::event::{Self, EventHandle};
    use liquidswap_lp::lp_coin::LP;

    use coin_creator::liq::LIQ;

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

    // not enough LP balance to unstake
    const ERR_NOT_ENOUGH_LP_BALANCE: u64 = 104;

    // only admin can execute
    const ERR_NO_PERMISSIONS: u64 = 105;

    // not enough pool LIQ balance to pay reward
    const ERR_NOT_ENOUGH_LIQ_BALANCE: u64 = 106;

    // amount can't be zero
    const ERR_AMOUNT_CANNOT_BE_ZERO: u64 = 107;

    // nothing to harvest yet
    const ERR_NOTHING_TO_HARVEST: u64 = 108;

    // module not initialized
    const ERR_MODULE_NOT_INITIALIZED: u64 = 109;

    // CoinType is not a coin
    const ERR_IS_NOT_COIN: u64 = 110;

    //
    // Constants
    //

    // multiplier to account six decimal places for LP and LIQ coins
    const SIX_DECIMALS: u128 = 1000000;

    //
    // Core data structures
    //

    struct StakePool<phantom X, phantom Y, phantom Curve> has key {
        // pool reward LIQ per second
        reward_per_sec: u64,
        // pool reward ((reward_per_sec * time) / total_staked) + accum_reward (previous period)
        accum_reward: u128,
        // last accum_reward & reward_per_sec update time
        last_updated: u64,
        // pool staked LP coins
        lp_coins: Coin<LP<X, Y, Curve>>,
        // pool reward LIQ coins
        liq_coins: Coin<LIQ>,
        // stake events
        stake_events: EventHandle<StakeEvent>,
        // unstake events
        unstake_events: EventHandle<UnstakeEvent>,
        // deposit events
        deposit_events: EventHandle<DepositEvent>,
        // harvest events
        harvest_events: EventHandle<HarvestEvent>,
    }

    struct Stake<phantom X, phantom Y, phantom Curve> has key {
        // staked amount
        amount: u64,
        // contains the value of rewards that cannot be harvested by the user
        unobtainable_reward: u128,
        // reward earned by current stake
        earned_reward: u64,
    }

    struct RegisterEventsStorage has key { register_events: EventHandle<RegisterEvent> }

    struct CapabilityStorage has key { signer_cap: SignerCapability }

    public entry fun initialize(liq_stake_admin: &signer) {
        assert!(signer::address_of(liq_stake_admin) == @staking_admin, ERR_NO_PERMISSIONS);

        let (_, signer_cap) =
            account::create_resource_account(liq_stake_admin, b"staking_admin_account_seed");

        move_to(liq_stake_admin, CapabilityStorage { signer_cap });
        move_to(liq_stake_admin,
            RegisterEventsStorage { register_events: account::new_event_handle<RegisterEvent>(liq_stake_admin) });
    }

    //
    // Pool config
    //

    public fun register<X, Y, Curve>(
        pool_creator: &signer,
        reward_per_sec: u64
    ) acquires RegisterEventsStorage, CapabilityStorage {
        assert!(reward_per_sec > 0, ERR_REWARD_CANNOT_BE_ZERO);
        assert!(exists<RegisterEventsStorage>(@staking_admin), ERR_MODULE_NOT_INITIALIZED);
        assert!(coin::is_coin_initialized<LP<X, Y, Curve>>(), ERR_IS_NOT_COIN);
        assert!(!exists<StakePool<X, Y, Curve>>(@staking_storage), ERR_POOL_ALREADY_EXISTS);

        // create account to store pool resource
        let cap = borrow_global<CapabilityStorage>(@staking_admin);
        let storage_acc = &account::create_signer_with_capability(&cap.signer_cap);

        let pool = StakePool<X, Y, Curve> {
            reward_per_sec,
            accum_reward: 0,
            last_updated: timestamp::now_seconds(),
            lp_coins: coin::zero(),
            liq_coins: coin::zero(),
            stake_events: account::new_event_handle<StakeEvent>(storage_acc),
            unstake_events: account::new_event_handle<UnstakeEvent>(storage_acc),
            deposit_events: account::new_event_handle<DepositEvent>(storage_acc),
            harvest_events: account::new_event_handle<HarvestEvent>(storage_acc),
        };

        let lp_symbol = coin::symbol<LP<X, Y, Curve>>();
        let event_storage = borrow_global_mut<RegisterEventsStorage>(@staking_admin);
        event::emit_event<RegisterEvent>(
            &mut event_storage.register_events,
            RegisterEvent { creator_address: signer::address_of(pool_creator), reward_per_sec, lp_symbol },
        );

        move_to(storage_acc, pool);
    }

    public fun deposit_reward_coins<X, Y, Curve>(pool_admin: &signer, coins: Coin<LIQ>) acquires StakePool {
        assert!(signer::address_of(pool_admin) == @staking_admin, ERR_NO_PERMISSIONS);
        assert!(exists<StakePool<X, Y, Curve>>(@staking_storage), ERR_NO_POOL);

        let pool = borrow_global_mut<StakePool<X, Y, Curve>>(@staking_storage);

        event::emit_event<DepositEvent>(
            &mut pool.deposit_events,
            DepositEvent { amount: coin::value(&coins) },
        );

        coin::merge(&mut pool.liq_coins, coins);
    }

    //
    // Getter functions
    //

    public fun get_pool_total_stake<X, Y, Curve>(): u64 acquires StakePool {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_storage), ERR_NO_POOL);

        coin::value(&borrow_global<StakePool<X, Y, Curve>>(@staking_storage).lp_coins)
    }

    public fun get_user_stake<X, Y, Curve>(user_address: address): u64 acquires Stake {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_storage), ERR_NO_POOL);

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
        assert!(coin::value(&coins) > 0, ERR_AMOUNT_CANNOT_BE_ZERO);
        assert!(exists<StakePool<X, Y, Curve>>(@staking_storage), ERR_NO_POOL);

        let user_address = signer::address_of(user);
        let amount = coin::value(&coins);
        let pool = borrow_global_mut<StakePool<X, Y, Curve>>(@staking_storage);

        // update pool accum_reward and timestamp
        update_accum_reward(pool);

        let accum_reward = pool.accum_reward;

        if (!exists<Stake<X, Y, Curve>>(user_address)) {
            let new_stake = Stake<X, Y, Curve> {
                amount,
                unobtainable_reward: 0,
                earned_reward: 0
            };
            // calculate unobtainable reward for new stake
            new_stake.unobtainable_reward = (accum_reward * to_u128(amount)) / SIX_DECIMALS;

            move_to(user, new_stake);
        } else {
            let user_stake = borrow_global_mut<Stake<X, Y, Curve>>(user_address);

            // update earnings
            update_user_earnings(pool, user_stake);

            user_stake.amount = user_stake.amount + amount;

            // recalculate unobtainable reward after stake amount changed
            user_stake.unobtainable_reward = (accum_reward * to_u128(user_stake.amount)) / SIX_DECIMALS;
        };

        event::emit_event<StakeEvent>(
            &mut pool.stake_events,
            StakeEvent { user_address, amount },
        );

        coin::merge(&mut pool.lp_coins, coins);
    }

    public fun unstake<X, Y, Curve>(user: &signer, amount: u64): Coin<LP<X, Y, Curve>> acquires StakePool, Stake {
        assert!(amount > 0, ERR_AMOUNT_CANNOT_BE_ZERO);
        assert!(exists<StakePool<X, Y, Curve>>(@staking_storage), ERR_NO_POOL);

        let user_address = signer::address_of(user);
        let pool = borrow_global_mut<StakePool<X, Y, Curve>>(@staking_storage);

        // update pool accum_reward and timestamp
        update_accum_reward(pool);

        assert!(exists<Stake<X, Y, Curve>>(user_address), ERR_NO_STAKE);

        let user_stake = borrow_global_mut<Stake<X, Y, Curve>>(user_address);

        // update earnings
        update_user_earnings(pool, user_stake);

        assert!(amount <= user_stake.amount, ERR_NOT_ENOUGH_LP_BALANCE);

        user_stake.amount = user_stake.amount - amount;

        // recalculate unobtainable reward after stake amount changed
        user_stake.unobtainable_reward = (pool.accum_reward * to_u128(user_stake.amount)) / SIX_DECIMALS;

        event::emit_event<UnstakeEvent>(
            &mut pool.unstake_events,
            UnstakeEvent { user_address, amount },
        );

        coin::extract(&mut pool.lp_coins, amount)
    }

    public fun harvest<X, Y, Curve>(user: &signer): Coin<LIQ> acquires StakePool, Stake {
        assert!(exists<StakePool<X, Y, Curve>>(@staking_storage), ERR_NO_POOL);

        let user_address = signer::address_of(user);
        let pool = borrow_global_mut<StakePool<X, Y, Curve>>(@staking_storage);

        assert!(exists<Stake<X, Y, Curve>>(user_address), ERR_NO_STAKE);

        // update pool accum_reward and timestamp
        update_accum_reward(pool);

        let user_stake = borrow_global_mut<Stake<X, Y, Curve>>(user_address);

        // update earnings
        update_user_earnings(pool, user_stake);

        let earned = user_stake.earned_reward;
        user_stake.earned_reward = 0;

        assert!(earned > 0, ERR_NOTHING_TO_HARVEST);
        assert!(coin::value(&pool.liq_coins) >= earned, ERR_NOT_ENOUGH_LIQ_BALANCE);

        event::emit_event<HarvestEvent>(
            &mut pool.harvest_events,
            HarvestEvent { user_address, amount: earned },
        );

        coin::extract(&mut pool.liq_coins, earned)
    }

    fun update_accum_reward<X, Y, Curve>(pool: &mut StakePool<X, Y, Curve>) {
        let current_time = timestamp::now_seconds();
        let seconds_passed = current_time - pool.last_updated;
        let total_stake = coin::value(&pool.lp_coins);

        pool.last_updated = current_time;

        if (total_stake != 0) {
            let total_reward = to_u128(pool.reward_per_sec) * to_u128(seconds_passed) * SIX_DECIMALS;

            pool.accum_reward =
                pool.accum_reward + total_reward / to_u128(total_stake);
        }
    }

    fun update_user_earnings<X, Y, Curve>(pool: &mut StakePool<X, Y, Curve>, user_stake: &mut Stake<X, Y, Curve>) {
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

    struct RegisterEvent has drop, store {
        creator_address: address,
        reward_per_sec: u64,
        lp_symbol: String,
    }

    struct StakeEvent has drop, store {
        user_address: address,
        amount: u64,
    }

    struct UnstakeEvent has drop, store {
        user_address: address,
        amount: u64,
    }

    struct DepositEvent has drop, store {
        amount: u64,
    }

    struct HarvestEvent has drop, store {
        user_address: address,
        amount: u64,
    }

    #[test_only]
    // access user stake fields with no getters
    public fun get_user_stake_info<X, Y, Curve>(user_address: address): (u128, u64) acquires Stake {
        let fields = borrow_global<Stake<X, Y, Curve>>(user_address);

        (fields.unobtainable_reward, fields.earned_reward)
    }

    #[test_only]
    // access staking pool fields with no getters
    public fun get_pool_info<X, Y, Curve>(): (u64, u128, u64) acquires StakePool {
        let pool = borrow_global<StakePool<X, Y, Curve>>(@staking_storage);

        (pool.reward_per_sec, pool.accum_reward, pool.last_updated)
    }

    #[test_only]
    // force pool & user stake recalculations
    public fun recalculate_user_stake<X, Y, Curve>(user_address: address) acquires StakePool, Stake {
        let pool = borrow_global_mut<StakePool<X, Y, Curve>>(@staking_storage);

        update_accum_reward(pool);

        let user_stake = borrow_global_mut<Stake<X, Y, Curve>>(user_address);

        update_user_earnings(pool, user_stake);
    }
}
