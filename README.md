# Harvest

The current repository contains the first basic version of Liquidswap Harvest (Staking) contracts.
The main purpose of contracts is to allow the staking of LP coins and earn community/3rd party project reward coins.

## Docs

Documentation is available at [official docs portal](https://docs.liquidswap.com/staking-harvest).

### Build

[Aptos CLI](https://github.com/aptos-labs/aptos-core/releases) required.

Core:

    aptos move compile

### Test

Core:

    aptos move test

**Liquidswap Staking Tests**

Placed in [liquiswap_staking_tests/](liquidswap_staking_tests) module.

    cd liquidswap_staking_tests
    aptos move test

### License

See [LICENSE](LICENSE)
