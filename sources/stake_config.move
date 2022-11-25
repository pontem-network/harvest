/// Module handles global stake pool configuration:
///   * allows to enable "global emergency state", which disables all the operations on the `StakePool` instances,
///     except for the `emergency_unstake()`.
///   * allows to specify custom `emergency_admin` account.
module harvest::stake_config {
    use std::signer;

    // Errors.

    /// Doesn't have enough permissions: not a current admin account.
    const ERR_NO_PERMISSIONS: u64 = 200;

    /// Global config is not initialized, call `initialize()` first.
    const ERR_NOT_INITIALIZED: u64 = 201;

    /// Operation is not accessible as "global emergency state" is enabled.
    const ERR_GLOBAL_EMERGENCY: u64 = 202;

    // Resources.

    /// Global config: contains emergency lock and admin address.
    struct GlobalConfig has key {
        emergency_admin_address: address,
        treasury_admin_address: address,
        global_emergency_locked: bool,
    }

    // Functions.

    /// Initializes global configuration.
    ///     * `emergency_admin` - initial emergency admin account.
    ///     * `treasury_admin` - initial treasury admin address.
    public entry fun initialize(emergency_admin: &signer, treasury_admin: address) {
        assert!(
            signer::address_of(emergency_admin) == @stake_emergency_admin,
            ERR_NO_PERMISSIONS
        );
        move_to(emergency_admin, GlobalConfig {
            emergency_admin_address: @stake_emergency_admin,
            treasury_admin_address: treasury_admin,
            global_emergency_locked: false,
        })
    }

    /// Sets `emergency_admin` account.
    /// Should be signed with current `emergency_admin` account.
    ///     * `emergency_admin` - current emergency admin account.
    ///     * `new_address` - new emergency admin address.
    public entry fun set_emergency_admin_address(emergency_admin: &signer, new_address: address) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global_mut<GlobalConfig>(@stake_emergency_admin);
        assert!(
            signer::address_of(emergency_admin) == global_config.emergency_admin_address,
            ERR_NO_PERMISSIONS
        );
        global_config.emergency_admin_address = new_address;
    }

    /// Gets current address of `emergency_admin` account.
    /// Returns address of emergency admin account.
    public fun get_emergency_admin_address(): address acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global<GlobalConfig>(@stake_emergency_admin);
        global_config.emergency_admin_address
    }

    /// Sets `treasury_admin` account.
    /// Should be signed with current `treasury_admin` account.
    ///     * `treasury_admin` - current treasury admin account.
    ///     * `new_address` - new treasury admin address.
    public entry fun set_treasury_admin_address(treasury_admin: &signer, new_address: address) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global_mut<GlobalConfig>(@stake_emergency_admin);
        assert!(
            signer::address_of(treasury_admin) == global_config.treasury_admin_address,
            ERR_NO_PERMISSIONS
        );
        global_config.treasury_admin_address = new_address;
    }

    /// Gets current address of `treasury admin` account.
    /// Returns address of treasury admin.
    public fun get_treasury_admin_address(): address acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global<GlobalConfig>(@stake_emergency_admin);
        global_config.treasury_admin_address
    }

    /// Enables "global emergency state". All the pools' operations are disabled except for `emergency_unstake()`.
    /// This state cannot be disabled, use with caution.
    ///     * `emergency_admin` - current emergency admin account.
    public entry fun enable_global_emergency(emergency_admin: &signer) acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global_mut<GlobalConfig>(@stake_emergency_admin);
        assert!(
            signer::address_of(emergency_admin) == global_config.emergency_admin_address,
            ERR_NO_PERMISSIONS
        );
        assert!(!global_config.global_emergency_locked, ERR_GLOBAL_EMERGENCY);
        global_config.global_emergency_locked = true;
    }

    /// Checks whether global "emergency state" is enabled.
    /// Returns true if emergency enabled.
    public fun is_global_emergency(): bool acquires GlobalConfig {
        assert!(exists<GlobalConfig>(@stake_emergency_admin), ERR_NOT_INITIALIZED);
        let global_config = borrow_global<GlobalConfig>(@stake_emergency_admin);
        global_config.global_emergency_locked
    }
}
