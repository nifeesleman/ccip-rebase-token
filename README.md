# 🔁 Cross-Chain Rebase Token Protocol

This project implements a **Cross-Chain Rebase Token Protocol** where users can deposit assets into a vault and receive dynamic, interest-accruing tokens in return. These rebase tokens **automatically reflect yield** over time and enable seamless cross-chain interactions.

---

## 🔧 Key Features

### ⛏️ 1. Vault-Based Deposits

- Users deposit assets into a **secure vault**.
- In return, they receive **rebase tokens** representing their deposit.

### 📈 2. Rebase Token with Dynamic Balance

- The `balanceOf()` function is dynamic:
  - Token balance increases **linearly over time**.
  - Rebase occurs automatically on every action:
    - Minting
    - Burning
    - Transferring
    - Bridging

### 💰 3. Interest Accrual per User

- Each user has a **personalized interest rate** fixed at the time of deposit.
- The interest is calculated based on a **global protocol interest rate**.
- The global rate is designed to **only decrease over time**:
  - **Early adopters benefit more.**
  - Incentivizes early participation and adoption.

---

## 🧠 How It Works

1. **Deposit into Vault**
   - Users deposit approved assets into the protocol vault.

2. **Mint Rebase Tokens**
   - Protocol mints rebase tokens to user address.
   - Initial balance is proportional to the deposit value.

3. **Interest Calculation**
   - Each user’s balance increases linearly using their fixed interest rate.
   - The balance increases without needing manual claims.

4. **Bridging Across Chains**
   - The rebase token is designed for **cross-chain compatibility**.
   - Rebase logic ensures consistent balance on any supported chain.

---

## 🛠️ Technologies Used

- [Solidity](https://docs.soliditylang.org/) — For smart contract logic
- [Foundry](https://book.getfoundry.sh/) — Fast, efficient smart contract testing
- [Chainlink](https://chain.link/) — (Optional) Oracle integration for price feeds
- [OpenZeppelin](https://openzeppelin.com/) — Secure, reusable smart contract libraries

---

## 🚀 Getting Started

```bash
# Clone the repository
git clone https://github.com/nifeesleman/ccip-rebase-token.git
cd ccip-rebase-token

# Install dependencies
forge install

# Run tests
forge test
