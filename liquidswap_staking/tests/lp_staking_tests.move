#[test_only]
module dgen_owner::lp_staking_tests {
    use std::string::utf8;

    use aptos_framework::genesis;

    use harvest::stake_test_helpers::{Self, new_account};
    use liquidswap::curves::Uncorrelated;
    use liquidswap::router;
    use test_helpers::test_pool;

    struct BTC {}

    struct USDT {}

    #[test]
    fun test_liquidswap_staking_e2e() {
        genesis::setup();
        test_pool::initialize_liquidity_pool();

        let dgen_owner = new_account(@dgen_owner);
        stake_test_helpers::initialize_coin<BTC>(
            &dgen_owner,
            utf8(b"BTC"),
            utf8(b"BTC"),
            6
        );
        stake_test_helpers::initialize_coin<USDT>(
            &dgen_owner,
            utf8(b"USDT"),
            utf8(b"USDT"),
            6
        );

        let harvest = new_account(@harvest);
        router::register_pool<BTC, USDT, Uncorrelated>(&harvest);
    }
}
