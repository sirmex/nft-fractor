# NFT Fractor

A Clarity smart contract for fractionalizing expensive NFTs into smaller tradeable shares on the Stacks blockchain.

## Overview

NFT Fractor allows NFT owners to split their valuable NFTs into multiple shares, making them more accessible to a broader range of investors. Share holders can trade their portions and even buy out the entire NFT if they accumulate enough shares.

## Features

- **Fractionalize NFTs**: Split any NFT into a specified number of shares with custom pricing
- **Trade Shares**: Buy and sell fractional ownership using STX tokens
- **Buyout Mechanism**: Majority shareholders can claim the full NFT
- **Secure Storage**: NFTs are safely held in the contract during fractionalization
- **Flexible Thresholds**: Customizable buyout thresholds (51-100% ownership required)

## Contract Functions

### Core Functions

#### `fractionalize-nft`
```clarity
(fractionalize-nft (nft-contract <nft-trait>) (token-id uint) (total-shares uint) (share-price uint) (buyout-threshold uint))
```
- Splits an NFT into the specified number of shares
- **Parameters**:
  - `nft-contract`: The NFT contract implementing the standard trait
  - `token-id`: The specific NFT token ID to fractionalize
  - `total-shares`: Total number of shares to create
  - `share-price`: Price per share in microSTX
  - `buyout-threshold`: Percentage ownership required for buyout (51-100)
- **Returns**: Fraction key for tracking

#### `buy-shares`
```clarity
(buy-shares (nft-contract principal) (token-id uint) (shares-to-buy uint))
```
- Purchase shares of a fractionalized NFT
- **Parameters**:
  - `nft-contract`: The NFT contract address
  - `token-id`: The NFT token ID
  - `shares-to-buy`: Number of shares to purchase
- **Returns**: Number of shares purchased

#### `sell-shares`
```clarity
(sell-shares (nft-contract principal) (token-id uint) (shares-to-sell uint))
```
- Sell shares back to the contract
- **Parameters**:
  - `nft-contract`: The NFT contract address
  - `token-id`: The NFT token ID
  - `shares-to-sell`: Number of shares to sell
- **Returns**: Number of shares sold

#### `buyout-nft`
```clarity
(buyout-nft (nft-contract <nft-trait>) (token-id uint))
```
- Claim the full NFT if you own enough shares
- **Parameters**:
  - `nft-contract`: The NFT contract implementing the standard trait
  - `token-id`: The NFT token ID
- **Returns**: Boolean success indicator

### Read-Only Functions

#### `get-fraction-info`
```clarity
(get-fraction-info (nft-contract principal) (token-id uint))
```
Returns detailed information about a fractionalized NFT including owner, total shares, price, and buyout threshold.

#### `get-user-shares`
```clarity
(get-user-shares (user principal) (nft-contract principal) (token-id uint))
```
Returns the number of shares owned by a specific user for a given NFT.

#### `get-share-balance`
```clarity
(get-share-balance (nft-contract principal) (token-id uint))
```
Returns the total supply of shares for a fractionalized NFT.

## Usage Example

### 1. Fractionalize an NFT
```clarity
;; Split an NFT into 1000 shares at 1000 microSTX each
;; Require 75% ownership for buyout
(contract-call? .nft-fractor fractionalize-nft 
  .my-nft-contract 
  u123 
  u1000 
  u1000 
  u75)
```

### 2. Buy Shares
```clarity
;; Buy 50 shares of the fractionalized NFT
(contract-call? .nft-fractor buy-shares 
  'SP1234567890ABCDEF.my-nft-contract 
  u123 
  u50)
```

### 3. Check Your Shares
```clarity
;; Check how many shares you own
(contract-call? .nft-fractor get-user-shares 
  tx-sender 
  'SP1234567890ABCDEF.my-nft-contract 
  u123)
```

### 4. Attempt Buyout
```clarity
;; Try to buy out the NFT (requires threshold ownership)
(contract-call? .nft-fractor buyout-nft 
  .my-nft-contract 
  u123)
```

## Error Codes

- `u401`: Not authorized
- `u404`: Not found
- `u409`: Already exists
- `u400`: Invalid amount
- `u402`: Insufficient balance
- `u403`: Not owner
- `u405`: Fraction not found
- `u406`: Invalid share amount
- `u407`: Buyout threshold not met

## Security Features

- **Input Validation**: All parameters are validated before execution
- **Ownership Verification**: Only NFT owners can fractionalize their tokens
- **Safe Transfers**: Uses standard NFT trait for secure transfers
- **Emergency Withdrawal**: Contract owner can withdraw NFTs in emergencies
- **Buyout Protection**: Requires significant ownership percentage for buyouts

## Requirements

- NFT contracts must implement the standard `nft-trait` with `transfer` and `get-owner` functions
- Users need STX tokens to purchase shares
- Clarinet for development and testing

## Installation

1. Clone the repository
2. Install Clarinet: `npm install -g @stacks/clarinet`
3. Run tests: `clarinet test`
4. Deploy: `clarinet deploy`

## Development

### Running Tests
```bash
clarinet test
```

### Checking Contract Syntax
```bash
clarinet check
```

### Local Development
```bash
clarinet console
```
