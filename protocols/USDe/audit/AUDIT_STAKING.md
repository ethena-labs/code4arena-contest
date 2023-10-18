### Project info

Please provide us with the following:

**A short description of your project:**

Ethena offers users the ability to mint/redeem a delta-neutral stablecoin, USDe, that returns a sustainable yield to the holder.
The yield is generated through staking Ethereum and the funding rate earned from the perpetual position hedging the delta.

The EthenaStaking contract allows users to stake USDe tokens and earn a portion of protocol LST and perpetual yield that is allocated
to stakers by the Ethena DAO governance voted yield distribution algorithm. The algorithm seeks to balance the stability of the protocol by funding the protocol's insurance fund, DAO activities, and rewarding stakers with a portion of the protocol's yield.

**Key contact: (**we will use this in the introduction of the audit report, ie this report was Prepared For: {Eric McEvoy} )

**Git repo:**

https://github.com/ethena-labs/ethena

**Commit hash:**

6d967b1b16e5f1141d3d161a266a094609a7f348

## Pre-audit questionnaire

**Please provide a brief summary of the purpose and function of the system:**

**What kind of bugs are you most concerned about?**

- Bugs that could result in loss of users staked funds
- Bugs that could result in loss of users reward funds

**What parts of the project are most critical to its overall operation?**

- All smart contract interactions.

**Are there any specific areas or components of the project that you are particularly worried about in terms of potential bugs or defects that may require additional attention?**

## Pre-audit checklist

- [x] Code is frozen
  - If not, why?
- [x] Test coverage is 100%
- [x] Unit tests cover both positive and negative scenarios
- [x] All tests pass
- [x] Documentation provided
- [x] Code has [Natspec](https://docs.soliditylang.org/en/v0.8.11/natspec-format.html) comments
- [x] A README is provided on how to setup and run your test suite
- [ ] If applicable - which ERC20 tokens do you plan to integrate/whitelist?
