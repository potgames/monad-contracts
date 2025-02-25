# PotGame Contracts

# Local Development

The following assumes the use of `node@>=14` and `npm@>=6`.

## Install Dependencies

`npm install --save-dev hardhat`

`npm install ganache-cli`

## Compile Contracts

`npx hardhat compile`

## Run Ganache-cli

`npx hardhat node`

## Run Tests

### Localhost

`npx hardhat --network localhost test` or `yarn test`

## Network

### Deploy Monad

`npx hardhat run --network monadDevnet deploy/monad/deploy.js`

### Verify + public source code
1. Create new constructor params file in arguments folder
2.

```bash
npx hardhat --network monadDevnet verify --constructor-args ./args/monad/args.js 0x1dD872A2956670882E1C8bEDc444244bfeC04F78
```

### Get verify network hardhat support

`npx hardhat verify --list-networks`


### Resource
npx hardhat --network monadDevnet verify --constructor-args ./args/monad/pyth-adapter.js 0x754BAEED583a13E9521F5F7d0d7146Ba1DF1262c
npx hardhat --network monadDevnet verify --constructor-args ./args/monad/moon-or-doom-operator.js 0x138A0e1304C25B3e272099A2491890e5eADA3Eb3
npx hardhat --network monadDevnet verify --constructor-args ./args/monad/moon-or-doom-native-token.js 0x8D3274D8B06d0cb91E1070FeE28feE6b3CCD071a
