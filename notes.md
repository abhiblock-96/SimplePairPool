## Liquidity

User add liquidity to pool by adding ERC20 token pairs and gets LP tokens back for their added Liquidity.

Let user adds dx amount of TokenA as well as dy amount of TokenB to the pool.

Here the constant value: K increases when the tokens added to the pool.

**ADD LIQUIDITY**
```
    Invariant: Price before adding liquidity = Price after adding liquidity

        before liquidity update:
        xy = k

        after adding liquidity:
        (x+dx)(y+dy) = k'

                    k' > k

            dy = ydx/x              dx = xdy/y

```

<details>
<summary>ADD Liquidity Example:</summary>

```
Before Liquidity:
        Pool contains-
            ETH - 10ETH
            USDC - 30,000USDC
        K = 3,00,000
    
    Add Liquidity:
            ETH - 4ETH   
            (dx = 4  dy = ?)
            USDC - (30,000 * 4 ) / 10 = 12,000USDC

    After Liquidity:
        Pool contains -
            ETH - 14ETH
            USDC - 42,000USDC

            Invariant:
                10/30000 = 14/42000

```
</details>
<br>

**MINT SHARES(LP TOKENS)**

LP tokens are minted to user when they deposit both tokens.

        Total Liquidity = SQRT(X*Y)
```
    At Initial:
        LP Tokens = 0
                S = SQRT(X*Y)

    Ex: User adds dx amount of TokenA and dy amount of TokenB, then no. of shares minted:

                Sa = (dx * T) / X           Sb = (dy * T) / Y

                                S = min(Sa, Sb)
```
<details>
<summary>LP Accounting Example:</summary>

```
At Initial:
    User adds Liquidity:
        dx = 10ETH
        dy = 20,000USDC

    Shares(LP Tokens) minted:
        S = SQRT(10 * 20,000) = 447

        User Owns approx 100%


Pool Contains:
    ETH - 10ETH
    USDC - 20,000USDC

User adds Liquidity:
    dx = 5ETH
    dy = 10,000USDC

    Shares minted:
        S = (dx*T) / X = 5 * 447 / 10   ==     10000 * 447 / 20000
                        
                        S = 223   T = 670
        Users owns approx 33% of the pool.

```

</details><br>

**REMOVE LIQUIDITY**

User wanted to remove their Liquidity. LP tokens are burned when user withdraw their LP tokens.

```
    Pool Liquidity:
        ETH - 15ETH
        USDC - 30,000USDC

    Total LP Tokens = 670
        User's LP shares = 223

                    dx = (X*S) / T          dy = (Y*S) / T
```
<details>
<summary>Remove Liquidity Example:</summary>

```
Liquidity Pool:
        ETH - 15ETH
        USDC - 30,000USDC

User have 223 LP tokens and owns 33%

    User removes Liquidity(burns 150 LP Tokens):

        dx = 150 * 15 / 670 = 3ETH      dy = 150 * 30,000 / 670 = 6,716USDC

    Pool Contains:
        ETH - 12ETH
        USDC - 23,284USDC

```

</details>

## SWAP 

```
    TokenA -> TokenB: let dx amount of TokenA comes in to the pool then,
    dy amount of TokenB will go out from the pool.

    The Invariant (Total amount of TokenA * Total amount of TokenB) = K
    Before Swap(K) must be equal to After Swap(k).

        dy = (y dx)/x + dx          dx = (x dy)/ y + dy
```

<details>
<summary>Swap Example:</summary>

```

    Before Swap:
        Pool contains-
            ETH - 10ETH
            USDC - 30,000USDC
        K = 3,00,000
    
    Swap:
            ETH - 4ETH -> USDC
            USDC - (30,000 * 4 ) / 10 + 4 = 8,571.4

    After Swap:
        Pool contains -
            ETH - 14ETH
            USDC - 21,429USDC
```

</details>
