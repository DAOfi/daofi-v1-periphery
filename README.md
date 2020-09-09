# Uniswap V2

[![Actions Status](https://github.com/Uniswap/uniswap-v2-periphery/workflows/CI/badge.svg)](https://github.com/Uniswap/uniswap-v2-periphery/actions)
[![npm](https://img.shields.io/npm/v/@defiinvest.tech/uniswap-v2-periphery?style=flat-square)](https://npmjs.com/package/@defiinvest.tech/uniswap-v2-periphery)

In-depth documentation on Uniswap V2 is available at [uniswap.org](https://uniswap.org/docs).

The built contract artifacts can be browsed via [unpkg.com](https://unpkg.com/browse/@defiinvest.tech/uniswap-v2-periphery@latest/).

# Local Development

The following assumes the use of `node@>=10`.

## Install Dependencies

`yarn`

## Compile Contracts

`yarn compile`

## Run Tests (TODO)

`yarn test`

Currently tests are failing with the updated uniswap-v2-core dependency (@defiinvest.tech/uniswap-v2-xdai)

Once tests are restored, the `prepulishOnly` npm script should be restored to `yarn test`
