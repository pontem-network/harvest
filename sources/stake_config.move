module harvest::stake_config {
    use std::signer;

    const ERR_NOT_AN_EMERGENCY_ADMIN: u64 = 201;

    const ERR_NOT_INITIALIZED: u64 = 202;

    const ERR_NOT_GLOBAL_LOCKED: u64 = 203;

    const ERR_NOT_GLOBAL_UNLOCKED: u64 = 204;

    struct GlobalConfig has key {
        emergency_admin_address: address,
        global_emergency_locked: bool
    }

    public entry fun initialize(emergency_admin: &signer) {
        assert!(
            signer::address_of(emergency_admin) == @stake_emergency_admin,
            ERR_NOT_AN_EMERGENCY_ADMIN
        );
        move_to(emergency_admin, GlobalConfig {
            emergency_admin_address: @stake_emergency_admin,
            global_emergency_locked: false,
        })
    }

    public fun set_emergency_admin_address(emergency_admin: &signer, new_address: address) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global_mut<GlobalConfig>(@stake_emergency_admin);
        assert!(
            signer::address_of(emergency_admin) == global_config.emergency_admin_address,
            ERR_NOT_AN_EMERGENCY_ADMIN
        );
        global_config.emergency_admin_address = new_address;
    }

    public fun get_emergency_admin_address(): address acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global<GlobalConfig>(@stake_emergency_admin);
        global_config.emergency_admin_address
    }

    public fun enable_global_emergency_lock(emergency_admin: &signer) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global_mut<GlobalConfig>(@stake_emergency_admin);
        assert!(
            signer::address_of(emergency_admin) == global_config.emergency_admin_address,
            ERR_NOT_AN_EMERGENCY_ADMIN
        );
        assert!(!global_config.global_emergency_locked, ERR_NOT_GLOBAL_UNLOCKED);
        global_config.global_emergency_locked = true;
    }

    public fun disable_global_emergency_lock(emergency_admin: &signer) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global_mut<GlobalConfig>(@stake_emergency_admin);
        assert!(
            signer::address_of(emergency_admin) == global_config.emergency_admin_address,
            ERR_NOT_AN_EMERGENCY_ADMIN
        );
        assert!(global_config.global_emergency_locked, ERR_NOT_INITIALIZED);
        assert!(global_config.global_emergency_locked, ERR_NOT_GLOBAL_LOCKED);
        global_config.global_emergency_locked = false;
    }

    public fun is_global_emergency_locked(): bool acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global<GlobalConfig>(@stake_emergency_admin);
        global_config.global_emergency_locked
    }
}
