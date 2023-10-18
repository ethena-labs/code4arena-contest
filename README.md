# Ethena Monorepo

Ethena 1.0

## Getting Started

Repo requires the following modules to be installed

PNPM: https://pnpm.io/installation

Anvil: https://book.getfoundry.sh/getting-started/installation

### Bash profile

Set up the bash profile copy .bashrc.example to root of repo and rename to .bashrc and add the `ANVIL_FORK_URL`
then run `source .bashrc` this will need to be done every time you open a new terminal.

## Environment Variables

Copy the .env.example file to .env

### Install

`pnpm install`

### Dev

`pnpm run dev`

the UI should be available at http://localhost:3009

## Clean

`pnpm run clean` removes all node_modules and packages

## Generate

`pnpm run generate` generates the typescript types for the graphql schema

## e2e Testing

##### Full execution

- In order to test using only one command run `pnpm run test:e2eExecute` from the main folder or `pnpm -w run test:e2eExecute` from any folder. This command will setup a local anvil node, deploy the smart contracts and export the deployed addresses to finally test against this setup.

##### Setup the anvil local network / fork

- To setup the local network from anvil run from the main folder `pnpm run deploy:anvil:localNetwork` or `pnpm -w run deploy:anvil:localNetwork` from any folder.
- To setup a fork from the desired network use `deploy:anvil:publicNetworkFork`, the rpc provider is specified by the `TEST_FORK_URL` env variable.

##### Deployment & export of the deployed addresses

- Run `pnpm run test:e2eDeployment` or `pnpm -w run test:e2eDeployment` to deploy the smart contracts and export the deployed addresses to the web `.env`

##### Run only the tests

- Run `pnpm run test:e2eOnlyTest` or `pnpm -w run test:e2eOnlyTest` to execute the tests against the previously deployed smart contracts in the anvil environment.

##### Customize account

- In order to customize the account used to deploy the smart contracts in the anvil environment and to execute the tests, change the following env variables: `TEST_MNEMONIC`, `TEST_PRIVATE_KEY`, `TEST_ADDRESS`
