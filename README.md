# Harvest

The current repository contains the first basic version of Liquidswap Harvest (Staking) contracts.
The main purpose of contracts is to allow the staking of LP coins and earn community/3rd party project reward coins.

Supported features:

* The contracts are permissionless: anyone can create new staking pool.
* Any coins can be used as stake or reward coins.
* NFT collection can be configured during pool creation and NFTs used to boost stake. 
* Rewards can be deposited to a pool at any time and duration would be extended.
* User can unstake own coins without loss of profit at any time after one week since the stake passed or once harvest period is finished.
* User can withdraw rewards at any time by doing harvesting.

**Important warnings:**
* As it's permissionless, we will allowlist only trusted pools on our end (UI).
* It may not work with exotic coins (large decimals amounts, too large supply), so use on your own risk and double check.

## Liquidswap Staking Tests

End to end tests for Liquidswap LP staking. 

Placed in [liquiswap_staking_tests/](liquidswap_staking_tests) module.

---

### Build

[Aptos CLI](https://github.com/aptos-labs/aptos-core/releases) required.

Core:

    aptos move compile

### Test

Core:

    aptos move test

Or LP staking module:

    cd liquidswap_staking_tests
    aptos move test

### License

See [LICENSE](LICENSE)
