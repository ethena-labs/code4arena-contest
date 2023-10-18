# Ethena smart contracts

## Install

```bash
pnpm install
```

### Foundry deployment

First copy the `.env.example` file to `.env`, and fill all the environment variables

```
# Move to protocols/USDe directory before running the copy command
cp .env.example .env
```

Run deploy in local network

```
forge script script/FullDeployment.sol
```

Run deploy in testnet network and verify the output

```
forge script script/FullDeployment.sol --slow --rpc-url sepolia --broadcast --verify --sender <YOUR_SEPOLIA_ADDRESS_WITH_ETH>
```

To check the deployed addresses, check the output of the command or have a look at `/broadcast/FullDeployment.sol/1115511/run-latest.json`

### Foundry unit tests

```bash
forge build
forge test
```

Enable tracing and logging to console via

```
forge test -vvvv
```

## Coverage

- To run the coverage you need to provide the `TEST_FORK_URL=YOUR_RPC_URL` variable in the `.env` file located in the main folder.
- In order to execute the lending market coverage using only one command run `pnpm run -w test:coverage:lending` from the `protocols/USDe` folder. This command will run forge coverage with a custom configuration, creating the report in the `coverage-lending` folder.
- To see the full coverage report go to `lending-coverage-full` and open the `index.html`
- Keep in mind that right now the `forge coverage` tool has many bugs, causing incomplete coverage reports, even when the tests are present. For example if a various contracts inherit from the same contract, only the first one will be reflected in the coverage, for this reason the script only checks for the USDe token contracts, the other contracts are tested to the 100% only that the won't be present in the coverage. [Error ref](https://github.com/foundry-rs/foundry/issues/4316)
- There is a full coverage in the `lending-coverage-full` folder.
