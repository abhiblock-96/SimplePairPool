# SimplePairPool

A minimal **constant-product Automated Market Maker (AMM)** built from scratch in Solidity using **Foundry**.

SimplePairPool is an educational implementation of a token pair pool inspired by the core mechanics of **Uniswap V2-style AMMs**. The project focuses on understanding how liquidity pools manage reserves, calculate LP shares, execute token swaps, and maintain the constant-product pricing model.

> **Educational Project — Not Production Ready**
>
> This implementation is designed for learning DeFi protocol mechanics, Solidity development, and smart contract testing. It has not been audited and should not be used with real funds.

---

## Overview

An Automated Market Maker allows users to trade tokens directly against a liquidity pool instead of matching orders through a traditional order book.

SimplePairPool maintains two token reserves:

```text
Token A Reserve
       +
Token B Reserve
       ↓
  Liquidity Pool
```

The pool uses the **constant-product invariant**:

$$
x \times y = k
$$

Where:

* `x` = reserve of Token A
* `y` = reserve of Token B
* `k` = constant product

When a swap changes one reserve, the output amount is determined from the relationship between the two reserves.

---

## Features

### 1. Liquidity Provision

Liquidity providers can supply both tokens to the pool.

When liquidity is added, the pool:

* Receives Token A and Token B
* Updates the pool reserves
* Calculates the corresponding LP shares
* Increases total LP supply
* Records the provider's LP ownership

Liquidity therefore becomes represented by an internal share-based accounting system.

---

### 2. LP Share Accounting

LP shares represent a provider's proportional ownership of the pool.

For example:

```text
Total LP Shares = 1,000

Alice = 250 LP Shares
Bob   = 750 LP Shares
```

Alice owns:

$$
\frac{250}{1000}=25\%
$$

of the pool's liquidity.

The same ownership ratio is used when determining how much underlying Token A and Token B an LP can withdraw.

---

### 3. Proportional Liquidity Removal

Liquidity providers can remove liquidity by redeeming their LP shares.

The amount of each token received is proportional to the provider's ownership of the total LP supply.

Conceptually:

$$
TokenAmount =
\frac{UserShares}{TotalShares}
\times
PoolReserve
$$

This means an LP receives their proportional claim on **both assets**, rather than simply receiving the original deposited amounts.

---

### 4. Token Swaps

The pool supports swapping between the two paired tokens.

A simplified swap follows:

```text
User
 │
 │ Input Token
 ▼
┌─────────────────┐
│ SimplePairPool  │
│                 │
│ Read Reserves   │
│ Calculate Out   │
│ Update Reserves │
└────────┬────────┘
         │
         │ Output Token
         ▼
        User
```

The swap calculation uses the pool's current reserves and the constant-product model.

**There is currently no swap fee implemented.**

---

### 5. Reserve Management

The pool maintains reserves for both tokens.

Reserves change as a result of:

* Adding liquidity
* Removing liquidity
* Executing swaps

The reserve state is fundamental to the AMM because it determines the exchange rate between the two assets.

---

## Constant-Product AMM

The core pricing model is:

$$
x \times y = k
$$

Consider a pool containing:

```text
Token A = 1,000
Token B = 2,000
```

The initial invariant is:

$$
k = 1000 \times 2000
$$

$$
k = 2,000,000
$$

If a trader adds Token A to the pool, the amount of Token B that can be removed is determined using the new reserve relationship.

This creates an automated pricing mechanism without requiring an order book.

---

## Price Relationship

The pool's spot price is derived from the ratio of its reserves.

For Token A denominated in Token B:

$$
Price_A \approx \frac{Reserve_B}{Reserve_A}
$$

For example:

```text
Token A Reserve = 1,000
Token B Reserve = 2,000
```

Then the reserve ratio implies:

```text
1 Token A ≈ 2 Token B
```

A swap changes the reserve ratio, which consequently changes the pool's implied price.

This is the fundamental mechanism behind AMM price movement.

---

## Liquidity & LP Ownership

The important relationship in the pool is:

```text
Liquidity
    ↓
Pool Reserves
    ↓
LP Shares
    ↓
Ownership
    ↓
Withdrawal Amount
```

LP shares allow the protocol to represent ownership without storing every user's individual contribution to each reserve.

For an LP owning `L` shares out of `S` total shares:

$$
Ownership = \frac{L}{S}
$$

The provider's withdrawal amount is then derived from that ownership percentage.

---

## Swap & Reserve Flow

A simplified swap lifecycle is:

```text
1. User provides input token
             ↓
2. Pool reads current reserves
             ↓
3. Output amount is calculated
             ↓
4. Output token is transferred
             ↓
5. Pool reserves are updated
```

The important state variables are therefore connected:

```text
User Balances
      ↕
Token Balances
      ↕
Pool Reserves
      ↕
Swap Calculation
      ↕
Constant-Product Invariant
```

---

## Testing

The project uses **Foundry** for smart contract development and testing.

The test suite focuses on validating the pool's core accounting and state transitions.

Current testing areas include:

* Liquidity provision
* LP share calculation
* LP share ownership
* Liquidity removal
* Proportional token withdrawal
* Token swaps
* Exact swap output behavior
* User token balances
* Pool reserve changes
* Swap-related state transitions

The tests are designed to verify not only whether transactions succeed, but whether the **resulting protocol state is correct**.

---

## Testing Philosophy

For a DeFi protocol, successful transaction execution is only one part of correctness.

For example, after a swap, the important questions are:

```text
Did the user receive the expected amount?
              ↓
Did the pool send the correct token amount?
              ↓
Did reserves change correctly?
              ↓
Is the pool state consistent?
              ↓
Is the constant-product relationship respected?
```

This accounting-focused approach is important when developing and auditing AMMs.

---

## Security Considerations

This project is also intended as a foundation for studying common DeFi security problems.

Areas that require careful analysis include:

### Reentrancy

Token transfers create external calls and therefore require careful consideration of state-update ordering.

### Reserve Accounting

Incorrect reserve updates can result in incorrect pricing or inconsistent pool state.

### Integer Rounding

Solidity uses integer arithmetic.

Therefore, AMM calculations involving division are subject to rounding:

$$
a / b
$$

does not preserve fractional values.

Rounding behavior must therefore be considered when calculating:

* Swap output
* LP shares
* Liquidity withdrawals
* Reserve relationships

### Initial Liquidity

The first liquidity provider is fundamentally different from subsequent providers because there is no existing LP supply or established reserve ratio.

Initial liquidity calculations therefore require separate reasoning from subsequent deposits.

### Liquidity Share Dilution

Subsequent liquidity providers must receive shares according to the existing pool reserves and total LP supply to prevent incorrect ownership accounting.

---

## Technology Stack

| Technology     | Purpose                                     |
| -------------- | ------------------------------------------- |
| Solidity       | Smart contract development                  |
| Foundry        | Development and testing                     |
| Forge          | Build and test execution                    |
| Cast           | Contract interaction                        |
| GitHub Actions | CI                                          |
| OpenZeppelin   | Supporting Solidity components/dependencies |

---

## Project Structure

```text
SimplePairPool/
│
├── src/
│   └── ...
│
├── test/
│   └── ...
│
├── lib/
│   └── ...
│
├── .github/
│   └── workflows/
│
├── foundry.toml
├── foundry.lock
├── notes.md
└── README.md
```

---

## Getting Started

### Clone

```bash
git clone https://github.com/abhiblock-96/SimplePairPool.git
cd SimplePairPool
```

### Install Dependencies

```bash
forge install
```

### Build

```bash
forge build
```

### Run Tests

```bash
forge test
```

### Run Tests With Verbose Output

```bash
forge test -vvvv
```

---

## Learning Objectives

This project was built to develop a practical understanding of:

* Automated Market Makers
* Constant-product formulas
* Liquidity pools
* LP shares
* Liquidity accounting
* Reserve management
* Token swaps
* Price calculation
* Price impact
* Integer rounding
* Solidity state transitions
* Foundry unit testing
* DeFi security considerations

---

## Future Improvements

The current implementation can be extended with additional AMM functionality:

* [ ] Add swap fees
* [ ] Add minimum-output / slippage protection
* [ ] Add transaction deadlines
* [ ] Add comprehensive fuzz testing
* [ ] Add invariant testing
* [ ] Implement LP tokens as ERC-20
* [ ] Add protocol fee mechanism
* [ ] Analyze donation/inflation scenarios
* [ ] Add TWAP oracle functionality
* [ ] Analyze MEV and sandwich attacks
* [ ] Compare implementation against Uniswap V2
* [ ] Perform a dedicated security review
* [ ] Build a frontend for pool interaction

---

## Why I Built This

The goal of SimplePairPool is not simply to reproduce an AMM interface.

The project is intended to understand the **accounting and mathematical foundations of DeFi protocols** at the smart-contract level.

The core learning path is:

```text
Token Balances
      ↓
Pool Reserves
      ↓
Liquidity
      ↓
LP Shares
      ↓
Ownership
      ↓
Swaps
      ↓
Price Movement
      ↓
Invariant
```

Understanding these relationships provides the foundation for studying more complex DeFi protocols such as lending markets, vaults, and production AMMs.

---

## Disclaimer

SimplePairPool is an educational project.

The contracts have **not been audited** and are **not intended for production use or real funds**.

Use the repository for learning, experimentation, testing, and security research only.

---
