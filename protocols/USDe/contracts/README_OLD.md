# Table of contents

- Note
- Goals of Ethena Protocol
- Current progress
- Minting the stablecoin
- Yield earning/distribution mechanism
- Black swan events
- 3 Contract architecture
- Mint/redemption contract
- Staking contract
- Stablecoin contract
- Point of contact

## Goals

The goal of Ethena is to offer a permissionless stablecoin, USDe, to defi users and to offer users yield for being in our ecosystem. Unlike USDC where Circle captures the yield, USDe holders can stake their USDe in exchange to receive stUSDe, which increases in value relative to USDe as the protocol earns yield. (Similar to rETH increasing in value with respect to ETH)

### Stablecoin contract

Done - Simple extension of various ERC20 token standards with restricted mint permissions. No further work required

## How the stablecoin is minted

Users sign an RFQ stating they are happy to exchange 10 stEth for 15000 USDe. Ethena servers submits the user’s order and signature on chain (assuming all checks pass). 15000 USDe is minted and sent to user atomically, while 10 stETH is sent to our custodian wallets.

We then short 10 ETH worth of ETH perps on cefi exchanges, yielding back ~15000 USDe. The short ETH perp + long stETH position is delta neutral, no matter how much the price of ETH moves (eg up 1000% or down 95%), both the position combined does not change in value.

In the scenario where ETH goes down 90%, the long 10 stETH is worth 1500 USD. While the short perp position has an unrealized gain of 13500 USD. When user wishes to redeem their 15000 USDe, we will close the short, getting 13500 USD unrealized gain to purchase 90 ETH. 10 stETH in the custodian wallet is also moved with the 90 ETH, returning the user 100 ETH (or stETH).

## How the protocol earns yield

USDe works by users sending in their stETH in exchange for USDe to be minted. Ethena moves stETH to custodian accounts and shorts equvilant amount of ETH perps on exchanges.

stETH earns 3-4% yield annualized. Short perps earn 4-10% annualized. The yield is sent to our insurance fund 3 times a day, and a percentage of the yield is converted to USDe and sent to our staking contract increasing the value of each stUSDe with respect to USDe.

## How yield is distributed to end users

USDe holders have the option to stake their USDe in our staking contract, getting stUSDe in return. As the protocol makes money on the long stETH yield, plus short ETH perps, the profits are moved to an insurance fund (a simple gnosis multisig) controlled by the protocol. 70% of the daily profits will be converted to USDe and deposited to the staking contract, increasing the ratio of USDe to stUSDe in staking contract and stUSDe value.

Users who choose not to stake their USDe will not be earning yield. The lower the ratio of USDe being in staking contract, the higher the yield is for users who choose to stake. The remainding yield is retained by the protocol as an insurance fund, used in case of protocol losses, paying bug bounties, etc.

We do not expect this distrubiton process to be done via smart contracts any time soon. The movement of funds will be done manually, with potential to be done algorithimcally.

## Handling negative yield

In scenarios where short perps pay longs to maintain the position, if that annualized rate is higher than stETH yield, there’s a net negative yield. The negative yield is paid from the insurance fund to ensure the system is properly collateralized.

In case of long term negative yields, we will begin warning the community the insurance fund will run out with at least 9 months warning to encourage USDe holders to redeem.

If insurance fund is drained, the protocol becomes undercollateralized, and each USDe will be redeemed for less than $1 of collateral.

## Black swans considered

Loss of funds in custodian wallets, bringing the system under collateralized

Loss of minting private key, allowing hackers to mint unlimited USDe for no collateral and dumping on pools. (Mitigated by on chain mint limits, gatekeeper roles describe further down)

## Smart contract architecture

Our smart contract architecture is seperate into 3 pieces. One contract for minting/redemption, one contract for our stablecoin, USDe, an ERC20 token. And one contract for our staked, yield bearing stablecoin stUSDe, an extension of the ERC 4626 standard.

## Minting/Redemption contract

### Design

Ethena will provide RFQs for minting and redemption orders. Users can request, for example, a quote for 10 stETH and we will provide a quote of 15000 USDe.

If user agree to the price, they will perform a EIP712 style signature using the provided quote and submits it to our backend server. Ethena assumes incoming orders are adversarial and performs a series of checks (eg signed price is the price we initially provided, users have sufficient approvals/balances, etc).

Once all checks are passed, an address with the MINTER role submits the user’s order and signature to the smart contract, along with the address that will receive the user’s collateral (10 stETH). Atomically, 15000 USDe is created and transferred to the user and 10 stETH is moved to the address we defined in the transaction (one of our custody wallets). Collateral funds (stETH) are never to live within the smart contract itself, it will always be moved to the predefined custody wallet by the MINTER.

Outside of the smart contract, we will short 10 ETH on a perps exchange to hedge the exposure.

As for redemptions, the process is similar. User agrees to the price they received in the RFQ, signs the order and sends to us. Eg redeeming 30000 USDe for 20 stETH. After passing checks, we submit their signature and order to the smart contract. Atomically, 30000 USDe is moved from the user’s wallet to the smart contract, then burnt. 20 stETH is moved from this smart contract to the user’s wallet.

We will constantly top up the minting smart contract by withdrawing funds from our custodians to allow users to redeem USDe for collateral.

### Roles

There are 4 roles in this contract.

Admin - Deployer and owner of the contract. Has the ability to add/remove addresses for the other roles, and change the max mint/redemption limit per block. Cold wallet

Gatekeeper - Has the ability to disable mint and redeems only. Usage: Continuously scans latest transactions for potential issues, such as hacked mint and redemption role keys, mint and redeems occurring at incorrect pricing. (eg 0.01 stETH minted 100,000 USDe). Hot wallet

Minter - Has the ability to call the mint function with user’s signed orders. Compromise of these keys means attacker can mint up to the max_mint_per_block limit every block. Does not hold any funds (other than a bit for gas), as user’s collateral is moved to the custodian address as defined in the route. Hot wallet

Redeemer - Has the ability to call the redeem function with user’s signed orders. Compromise of these keys means attacker can redeem all the collateral in this wallet with 0 USDe, similar loss to just losing the key of any EOA wallet. Holds funds needed for redemption. Hot wallet.

### Security

max_mint_per_block - Added this feature to ensure that even in the compromise of a minter address, the attacker cannot mint $10 billion of USDe for no collateral, then dump it onto pools. Reduces the black swan risk to a $100k loss, plus loss in hot funds ready for redemption. Attacker can mint up to this max limit for 1 block, before gatekeeper role detects these transactions and disables minting/redemption.

In rare chance of pricing errors, gatekeepers will disable mint/redeems too.

max_redeem_per_block - Losing of redeemer role means attacker can redeem everything in the redeemer wallet for no collateral (it’ll hold low-mid 6 figures). Losing of redeemer role isn’t a black swan event even before this security addition, it’s to make it consistent with the max mint limit, and also in case of pricing errors allows us to disable redeems.

gatekeeper role - In seperate cloud AWS accounts, a script runs on a server scaning all mint/redeems to ensure executed prices are in line, and if not, uses the gatekeeper key to disables mint/redeems. Resuming operation requires the admin key. Post launch, we are considering having external firms hold gatekeeper keys to perform the same function.

Cold wallet - Admin key to be cold wallet, only used in rare scenarios of restarting operations after pausing mint/redeems, adding/removing minters/gatekeepers or changing the onchain mint/redeem per block limits.

## Staking contract

The staking contract modifies the ERC4626 standard with cooldown periods for unstaking and blacklisting features.

Users have the option to stake their USDe to earn yield from the stETH long - short ETH perps mechanism we use to hedge USDe. Users deposit USDe and at the prevailing rate, get stUSDe in return, which can be transferred and used immediately.

At launch, stUSDe = 1 USDe. As yield is accured from the short perps position, Ethena will move the profits to an insurance fund (likely held in USDC), and from there dedicate a percentage of daily yield to stUSDe holders. The profit is converted to USDe, then deposited into the staking contract, increasing the value of each stUSDe with respect to USDe.

### Unstaking

To unstake, users must have the stUSDe in their address. Users can unstake any amount of stUSDe up to the amount they own. Upon running the unstake function with the amount they wish to unstake, eg 1000 stUSDe, the 1000 stUSDe will be burnt from the user’s wallet immediately.

At the prevailing rate, it’s settled for 1100 USDe (assuming rate is 1 stUSDe = 1.1 USDe). However the 1100 USDe is sent to a seperate smart contract that's initiated in the constructor of the staking contract (hereby called Silo contract).

The funds are locked for the cooldown period, default at 14 days. Only after 14 days cooldown can the user withdraw the 1100 USDe and no interest is earned during cooldown. An additional transaction is needed from the user to withdraw. The withdraw function is called on the same staking contract, which calls the silo contract and moves the user's USDe in silo contract to the user's address.

If the user calls unstake function again while there's existing balances being unstaked, the cooldown period is reset to 14 days and the new amount that's to be unstaked will be the sum of the current amount in the tx call plus the previous amount waiting in cooldown to be unstaked.

### Silo contract

It's a smart contract that receives all USDe upon user calling unstake in the staking contract and holds it will cooldown expires and user withdraws. Silo contract requires msg.sender to be the staking contract to withdraw funds.
Silo contract is ownerless and stateless, records of USDe attributable to each user is stored in staking contract instead of silo contract.

### Cooldown period

A configurable period with a pre-defined maximum of 90 days and adjustable by the admin role of the contract. The goal of the cooldown period is to smooth out periods of panic redemptions such as during market crashes.

The cooldown period will be 90 days for the first 3 months of launch, as there’s one-off incentives to stake with the lock up period during our launch, after which it’ll be reduced to 14 days.

### Rescue Tokens

Admins can withdraw non-USDe ERC20 tokens from the staking contract. To be uses in case users accidentally send tokens, stablecoins or our future governence token to this contract.

### Roles

Admin - Owner of the contract, can adjust cooldown period, add/remove gatekeepers, wipe balances of fully restricted addresses and re-issue to another. Cold wallet

Gatekeepers - Can blacklist addresses

### Blacklisting

There’s 2 levels of blacklisting in the staking contract.

Restricted staking - Address cannot invoke the contract function to stake. All other functions are possible, eg transfer, unstaking.

Full restriction - Address cannot interact with the staking smart contract at all. Owner can wipe balance of fully restricted addresses and re-issue elsewhere. Their stUSDe will be burnt and total supply reduced by the burnt amount, effectively increasing the value of stUSDe with respect to USDe for other token holders.

Restricted staking is used for addresses in countries not legally compliant with receiving yield from Ethena. Full restriction is for sanctioned addresses or addresses involved in hacks.

## Stablecoin contract

The USDe stablecoin contract is a standard ERC20 contract, extended with open zepplin’s ERC20 permit and ERC20 burnable interfaces. The mint function is overridden with a modifier to allow only address with the Minter role to mint USDe.

The admin role can add and remove Minters.

There’s no other changes. The intention of USDe is to be as open and permissionless as possible.

# Auditing scope

We’d like auditors to consider the following

Security audits - Smart contract behaving in unexpected ways

Economic attack vectors - How can an attacker make money off our protocol in unintended ways (outside of solidity bugs), causing us unexpected losses, no matter how large or small.

Loss of private keys - Understanding the worse case scenario of damages that can be done to the protocol when hot wallets are compromised, and propose methods to limit those damages.

Unfair value extraction from our protocol - For example, ways to earn yield while only locking in capital for a fraction of the time as a user using the protocol fairly.

Below are the attacks outside of smart contracts we’ve considered and have taken steps to mitigate.

## Economic attack mitigation

Mint and redeems are limited to $100k per block. Because for instance if a $10m mint occurs, the hedge cannot be complete before the order becomes public information. Attackers know we have yet to hedge majority of that $10m order, which they could front run by shorting ETH and buying it back at a lower price as we sell to them.

The $100k limit makes it uneconomical for front running attacks as it requires 1-2 orders of magnitude larger sizes to move the market and it doesn’t make sense to spend $5m to front run a $100k order.

We intend to adjust this limit based on market liquidity and conditions.

## Loss of private keys

Losing the minter private key would’ve been a black swan event, allowing attacker to mint unlimited USDe for no collateral and dumping them on pools. The $100k limit per block, and use of gatekeeper roles to disable mint/redeems reduces this black swan event to a manageble $100k loss + full loss of funds in the minting contract.

## Point of contact

Ka Yin Cheung - @kayincheung
Available to jump on calls to clarify our smart contract design.
