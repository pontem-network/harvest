# Harvest

The current repository contains the first basic version of Liquidswap Harvest (Staking) contracts.
The main purpose of contracts is to allow the staking of LP coins and earn community/3rd party project reward coins.

Supported features:

* The contracts are permissionless and can be used for any Stake/Reward coins pair.
* Each staking pool has a reward rate per second set by the pool creator.
* Rewards can be deposited to a pool at any time.
* User can unstake own coins without loss of profit at any time after one week since the stake passed.
* User can withdraw rewards at any time.
* Pool can be emergency stopped, and stakers can withdraw their stake.
* **Important:** as it's permissionless, we will allowlist only trusted pools on our end (UI).

## DGEN coin

The `DGEN` coin is currently placed in [DGEN](./DGEN) module.

It's our community genesis generation coin which we are going to airdrop and reward
early adopters, also it will be used in our staking pools as a reward.

## Liquidswap Staking Tests

End to end tests for Liquidswap LP staking. 

Placed in [liquiswap_staking_tests/](liquidswap_staking_tests) module.

---

### Build

[Aptos CLI](https://github.com/aptos-labs/aptos-core/releases) required:

    aptos move compile

Or LP staking module:

    cd liquidswap_staking
    aptos move compile
    
Or DGEN:

    cd DGEN
    aptos move compile

### Test

    aptos move test

Or LP staking module:

    cd liquidswap_staking
    aptos move test

Or DGEN:

    cd DGEN
    aptos move test


### License

See [LICENSE](LICENSE)
