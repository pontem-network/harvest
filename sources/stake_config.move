/// Module handles global stake pool configuration:
///   * allows to enable "global emergency state", which disables all the operations on the `StakePool` instances,
///     except for the `emergency_unstake()`
///   * allows to specify custom `emergency_admin` account
module harvest::stake_config {
    use std::signer;

    /// Doesn't have enough permissions: not a current `emergency_admin` account.
    const ERR_NOT_AN_EMERGENCY_ADMIN: u64 = 201;

    /// Global config is not initialized, call `initialize()` first.
    const ERR_NOT_INITIALIZED: u64 = 202;

    /// Operation is not accessible as "global emergency state" is enabled.
    const ERR_GLOBAL_EMERGENCY: u64 = 204;

    struct GlobalConfig has key {
        emergency_admin_address: address,
        global_emergency_locked: bool
    }

    /// Initializes global pool configuration.
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

    /// Sets `emergency_admin` account. Should be signed with current `emergency_admin` account.
    public fun set_emergency_admin_address(emergency_admin: &signer, new_address: address) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global_mut<GlobalConfig>(@stake_emergency_admin);
        assert!(
            signer::address_of(emergency_admin) == global_config.emergency_admin_address,
            ERR_NOT_AN_EMERGENCY_ADMIN
        );
        global_config.emergency_admin_address = new_address;
    }

    /// Gets current address of `emergency_admin` account.
    public fun get_emergency_admin_address(): address acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global<GlobalConfig>(@stake_emergency_admin);
        global_config.emergency_admin_address
    }

    /// Enables "global emergency state". All the pools' operations are disabled except for `emergency_unstake()`.
    /// This state cannot be disabled, use with caution.
    public fun enable_global_emergency(emergency_admin: &signer) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global_mut<GlobalConfig>(@stake_emergency_admin);
        assert!(
            signer::address_of(emergency_admin) == global_config.emergency_admin_address,
            ERR_NOT_AN_EMERGENCY_ADMIN
        );
        assert!(!global_config.global_emergency_locked, ERR_GLOBAL_EMERGENCY);
        global_config.global_emergency_locked = true;
    }

    /// Checks whether global "emergency state" is enabled.
    public fun is_global_emergency(): bool acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global<GlobalConfig>(@stake_emergency_admin);
        global_config.global_emergency_locked
    }
}
