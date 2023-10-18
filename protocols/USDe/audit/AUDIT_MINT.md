### Project info

Please provide us with the following:

**A short description of your project:**

Ethena offers users the ability to mint/redeem a delta-neutral stablecoin, USDe, that returns a sustainable yield to the holder.
The yield is generated through staking Ethereum and the funding rate earned from the perpetual position hedging the delta.

Users are able to “mint” USDe, “redeem” USDe, and “stake” + ”unstake” their USDe to receive their proportion of the generated yield.

**Key contact: (**we will use this in the introduction of the audit report, ie this report was Prepared For: {Eric McEvoy} )

**Link to documentation:**

**Git repo:**

https://github.com/ethena-labs/ethena

**Commit hash:**

6d967b1b16e5f1141d3d161a266a094609a7f348

## Pre-audit questionnaire

**Please provide a brief summary of the purpose and function of the system:**

Here is the mint contract design and flow whose purpose is to provide secure, trustless and atomic minting to Ethena users.

1. An Ethena server securely streams a live price to the open market

2. If users want to mint or redeem against these prices, they can capture a price within a cryptographically immutable signed EIP-712 order.

An order has a tolerated range of slippage (may be zero) allowed within the final price that is minted or redeemed, for the user, at the contract.

Since both are signed by the user and upheld at the contract, the outcome (once executed) is trustless.

3. The signed order is posted to the Ethena Server API. It is validated and checks, like the following, are performed:

- The user has adequate approvals and balances for the transaction to succeed

- The expiry has passed, within a buffer that considers it being sent to the contract

- The server can uphold the price or, depending on the order type, an affirmed price can be offered within the slippage price range the user originally signed or agreed to.

4, Once the server approves the signed order, it broadcasts it to the Ethena Minting Contract to be minted or redeemed, depending on the original order type. This is an atomic and trustless transaction where the user's funds are passed to the minting contract and on to the custody provider (potentially per some ratio required by the Server strategy) and the USDe is minted to the, per affirmed amount.

5. Upon success of this transaction, the server adds the amounts held and minted to a queue and the server process continues, ensuring delta neutrality via a suite of trading mechanisms.

**What kind of bugs are you most concerned about?**

- Bugs that could result in loss of user funds
- Bugs that could result in loss over production of USDe

**What parts of the project are most critical to its overall operation?**

- All smart contract interactions.

**Are there any specific areas or components of the project that you are particularly worried about in terms of potential bugs or defects that may require additional attention?**

## Pre-audit checklist

- [x] Code is frozen
  - If not, why?
- [ ] Test coverage is 100%
- [x] Unit tests cover both positive and negative scenarios
- [x] All tests pass
- [x] Documentation provided
- [x] Code has [Natspec](https://docs.soliditylang.org/en/v0.8.11/natspec-format.html) comments
- [x] A README is provided on how to setup and run your test suite
- [ ] If applicable - which ERC20 tokens do you plan to integrate/whitelist?
