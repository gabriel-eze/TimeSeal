# TimeSeal – Conditional Time-Locked Payments

TimeSeal is a **Clarity smart contract** that enables secure, conditional, and time-locked payments. Funds can only be released when **two conditions** are satisfied:

1. A specified **block height** has been reached.
2. An **external oracle condition** (e.g., price feed, weather data, or other real-world input) is fulfilled.

This contract is ideal for **escrow services, milestone-based payments, or conditional transfers** that depend on blockchain time and off-chain data.

---

## Core Features

* **Time-Locked Payments**: Funds are locked until the blockchain reaches a given block height.
* **Oracle-Based Conditions**: Payments also depend on external data (e.g., values provided by an authorized oracle).
* **Secure Fund Management**:

  * Only the **recipient** can claim funds once conditions are met.
  * Only the **sender** can cancel before fulfillment.
* **Oracle Authorization**: Only contract-approved oracle providers can update oracle values.
* **Payment Tracking**: Each payment has a unique ID and can be queried for status.

---

## Key Components

### Data Structures

* **`payments` map** – Stores payment details:

  * Sender, recipient, amount, unlock height, oracle key, threshold, fulfillment status, cancellation status.
* **`oracle-values` map** – Stores values provided by authorized oracles with a timestamp.
* **`authorized-oracles` map** – Tracks which principals are allowed to set oracle values.
* **`payment-id-nonce`** – Ensures unique identifiers for payments.

### Constants

* **`max-lock-blocks`** – Maximum lock duration (\~1 year at 10-minute blocks).
* **`min-amount` / `max-amount`** – Enforces payment size limits.
* **`contract-deployer`** – Contract owner who manages oracle authorization.

---

## Public Functions

### Payments

* **`create-payment`**: Locks STX into the contract with specified conditions.
* **`claim-payment`**: Allows recipient to claim if block height and oracle threshold are met.
* **`cancel-payment`**: Allows sender to cancel and retrieve funds if not fulfilled.

### Oracle Management

* **`set-oracle-value`**: Updates oracle data (only callable by authorized oracles).
* **`add-authorized-oracle`**: Grants oracle privileges (only contract owner).

### Read-Only Queries

* **`get-payment-status`**: Retrieves details of a specific payment.
* **`is-payment-claimable`**: Checks if conditions are satisfied for claiming.
* **`get-oracle-value`**: Reads the latest oracle value for a key.
* **`check-oracle-authorization`**: Verifies if a principal is an authorized oracle.
* **`get-payment-nonce`**: Returns the current payment counter.

---

## Workflow Example

1. **Sender creates a payment** → Locks funds with recipient, block height, oracle key, and threshold.
2. **Oracle updates values** → Authorized oracle pushes external data (e.g., BTC price, weather index).
3. **Recipient claims payment** → If block height and oracle threshold are met, recipient receives funds.
4. **Sender cancels (optional)** → If conditions remain unmet, sender can cancel and reclaim funds.

---

## Error Codes

* **u1 – u5**: Invalid parameters (amount, lock period, oracle key, recipient).
* **u6 – u7**: Invalid oracle key or unauthorized oracle.
* **u8 – u10**: Invalid or unauthorized oracle provider.
* **u11 – u17**: Payment-related errors (not found, wrong claimant, already fulfilled/canceled, locked, threshold not met).
* **u18 – u21**: Cancellation errors.
* **u22 – u23**: Status/claimability query errors.

---

## Use Cases

* **Escrow services** – Conditional fund release upon verified events.
* **Milestone payments** – Developers or contractors get paid only if goals are met.
* **Insurance payouts** – Triggered by oracle-fed events (e.g., weather data).
* **Trustless conditional agreements** – Ensures both time and data-driven requirements are satisfied before fund release.
