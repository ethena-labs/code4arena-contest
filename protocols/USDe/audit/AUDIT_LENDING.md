Project info
Please provide us with the following:
A short description of your project:

Ethena is an ETH-powered delta-neutral stablecoin protocol that aims to achieve price stability through futures arbitrage across centralized and decentralized venues. It provides staking returns to users and offers various hedging solutions, such as ETH expiring futures and perpetual swaps, to construct floating versus fixed return profiles.

- Link to documentation:
  https://app.gitbook.com/o/uL0A7ZhBdOBWE4R46usw/s/sBsPyff5ft3inFy9jyjt/

- Git repo:
  https://github.com/ethena-labs/ethena (protocols/USDe/contracts/lending directory)

- Commit hash:
  0bdceecf8b57c26e56a717c0dacda4cd89ede71a

Pre-audit questionnaire

- Please provide a brief summary of the purpose and function of the system:

The Ethena system’s primary purpose is to offer a Stablecoin solution powered by ETH that achieves price stability while providing staking returns to users. By leveraging futures arbitrage across centralized and decentralized platforms, the protocol aims to maintain the stablecoin’s value. Additionally, Ethena focuses on developing ETH expiring futures and perpetual swap hedging solutions to create various floating versus fixed return profiles.

- What kind of bugs are you most concerned about?

The ones that can compromise the security, stability, or accuracy of the Ethena system. This may include vulnerabilities in smart contracts, potential flaws in the collateralization mechanisms, issues related to yield calculations, or any other bugs that could impact the integrity and reliability of the stablecoin protocol.
What parts of the project are most critical to its overall operation?
Stablecoin Mechanism, Collateral Management, Smart Contracts and Security Measures, Integration with Exchanges and Platforms and Risk Management.

- Are there any specific areas or components of the project that you are particularly worried about in terms of potential bugs or defects that may require additional attention?
  The staking and minting mechanism. The lending integration with the Aave market V3 shouldn’t be too concerning as we only modified small portions of the code, nonetheless its worth to take a good look.
  Pre-audit checklist

[ ] Code is frozen
If not, why? Still under development.
[ ] Test coverage is 100%
[X] Unit tests cover both positive and negative scenarios
[X] All tests pass
[X] Documentation provided
[X] Code has Natspec comments
[ ] A README is provided on how to setup and run your test suite
[X] If applicable - which ERC20 tokens do you plan to to integrate/whitelist? For now USDe, wEth, stEth, corresponding ATokens from the Aave lending integration… more TDB
