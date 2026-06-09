# CarbonBlockchain — xGreen Coin & Carbon NFT Technical Specification

> **Status:** Active Development Blueprint · Axina Group Inc.
> **Sub-Project:** CarbonBlockchain (under AXERP)
> **Authors:** Daniel Brody (President), Kyle Milaschewski (CTO)
> **Origin Documents:** XGCCoinPlan (Dec 2023), Tokenize Carbon Credits Requirements
> **Last Reviewed:** 2026-05-17
> **Legacy Note:** All "XGCCoin" / "XGCERP" references are superseded by "xGreen Coin" / "AXERP".

[TOC]

---

## 1. Overview

The AXERP Carbon Blockchain layer provides cryptographic verification, tokenisation, and a decentralised marketplace for carbon credits generated and tracked within the AXERP ERP system.

**Core Outputs:**
- **xGreen Coin (GC)** — a market-driven sustainable cryptocurrency whose supply is directly correlated with available verified carbon credits.
- **Carbon NFT** — an ERC-721 NFT representing a single tonne of CO₂ that has been burned/retired, issued as a digital carbon offset certificate.
- **DEX (Decentralised Exchange)** — on-chain trading of xGreen Coin between account holders.
- **SPV Client** — lightweight transaction verification for end users without running a full node.

**Dual-Chain Architecture:**

| Chain | Protocol | Use Case |
|---|---|---|
| Ethereum (mainnet) | EVM / Solidity | Public NFT certificates, Green Coin ERC-20, DEX |
| Hyperledger Fabric | Go chaincode | Private inventory data, internal brokerage contracts |

The AXERP **Serial Number** (assigned to each tonne of CO₂ in the ERP inventory) is the **cryptographic seed** for all blockchain hashing, ensuring end-to-end traceability from physical credit to on-chain token.

---

## 2. Blockchain Integration Architecture

```
AXERP ERP (Carbon Credit Inventory)
  │  Serial Number assigned to each tonne of CO₂
  │
  ▼ API call (on Sales Invoice submit)
Blockchain Microservice (axerp-blockchain-svc)
  │
  ├─► Ethereum Node (Infura / self-hosted)
  │     ├─► ERC-20: xGreen Coin mint/burn
  │     └─► ERC-721: Carbon NFT issuance
  │
  └─► Hyperledger Fabric Network
        ├─► Inventory chaincode (private ledger)
        └─► Brokerage contract chaincode
```

---

## 3. xGreen Coin (GC) — ERC-20 Token

### 3.1 Tokenomics

| Parameter | Design |
|---|---|
| Standard | ERC-20 |
| Symbol | `GC` |
| Decimal Places | 18 |
| Total Supply | Dynamic — scales with verified carbon credit inventory |
| Pricing | Market-driven; pegged to prevailing carbon credit market rate (tCO₂ spot price) |
| Minting Authority | AXERP platform smart contract only (no arbitrary mint) |
| Burning | GC can only be burned by converting to a Carbon NFT (irreversible retirement) |

### 3.2 Minting Trigger

```
Carbon Credit Inventory record status → "Sold"
  └─► AXERP webhook → blockchain-svc
        └─► Smart contract: GreenCoin.mint(buyer_wallet, amount_gc)
              └─► Amount = tonnes_purchased × current_gc_per_tonne_rate
```

### 3.3 Trading Constraints

- **Daily transaction cap** per user: configurable (default 50 trades/day) to prevent speculative abuse.
- **Conversion floor:** GC can only be burned into NFTs; no cash buy-back guarantee from the platform.
- **Marketplace trades:** User-to-user GC trading allowed within the SPV client marketplace.

---

## 4. Carbon NFT — ERC-721 Token

### 4.1 NFT Structure

Each NFT represents **one retired tonne of CO₂** from a verified project.

**Token Metadata (ERC-721 `tokenURI` JSON — stored on IPFS):**
```json
{
  "name": "AXERP Carbon Credit Certificate",
  "description": "Certified carbon offset — 1 tonne CO₂e retired",
  "image": "ipfs://Qm.../certificate-image.png",
  "attributes": [
    { "trait_type": "Serial Number", "value": "CC-2024-KE-00142" },
    { "trait_type": "Project", "value": "Kenya Mangrove Forest" },
    { "trait_type": "Standard", "value": "VCS" },
    { "trait_type": "Vintage Year", "value": "2024" },
    { "trait_type": "Sequestration (tCO2e)", "value": "1.0" },
    { "trait_type": "Country", "value": "Kenya" },
    { "trait_type": "Retirement Date", "value": "2026-05-17" }
  ]
}
```

**On-Chain Data:**
- `tokenId` — derived from SHA-256 hash of the AXERP serial number.
- `ownerAddress` — buyer's Ethereum wallet.
- `retirementHash` — irreversible Keccak-256 hash confirming retirement.

### 4.2 QR Code

Each NFT includes a QR code encoding `https://nft.axerp.io/verify/<tokenId>`. The verification page fetches on-chain data from Ethereum and displays the certificate to any third party (regulator, auditor, purchaser).

### 4.3 Consolidated NFT (Batch Retirement)

Multiple individual credits can be aggregated into a single NFT (e.g., 100 tCO₂e) while maintaining individual serial-number traceability via a Merkle tree structure embedded in the token metadata.

---

## 5. Smart Contract Architecture

### 5.1 Contracts

| Contract | Language | Responsibility |
|---|---|---|
| `GreenCoin.sol` | Solidity ERC-20 | Mint/burn GC tokens; enforce daily trade limits |
| `CarbonNFT.sol` | Solidity ERC-721 | Mint Carbon NFT certificates on GC burn |
| `CarbonDEX.sol` | Solidity | Peer-to-peer GC trading; order book on-chain |
| `CarbonRegistry.sol` | Solidity | Immutable registry of all serial numbers (AXERP → chain) |
| `InventoryChaincode.go` | Go (Fabric) | Private ledger for inventory batches, brokerage contracts |

### 5.2 Smart Contract Security

- All contracts audited before mainnet deployment (third-party security audit required).
- Upgradability: Proxy pattern (OpenZeppelin `TransparentUpgradeableProxy`) for `GreenCoin` and `CarbonNFT`; `CarbonRegistry` is intentionally non-upgradable (immutable record).
- Access control: `onlyOwner` (AXERP platform address) for mint functions; burn is callable by any token holder.

### 5.3 Encryption Layers

| Layer | Mechanism | Purpose |
|---|---|---|
| Reversible | PKI encryption (RSA-4096) | Transaction details (buyer/seller PII) stored off-chain |
| Irreversible | Keccak-256 hash (Solidity) | Token ID derivation from serial number |
| Certificate fingerprint | SHA-256 | NFT metadata integrity verification |

---

## 6. SPV Client

An SPV (Simplified Payment Verification) client is provided within the AXERP customer portal and mobile app, allowing users to verify carbon credit transactions without running a full Ethereum node.

**Capabilities:**
- Download block headers only (not full blocks).
- Merkle proof verification of any Carbon NFT transaction.
- Integrated marketplace for GC peer-to-peer trading.
- Wallet balance display for GC and owned NFTs.

**Implementation:** Web3.js + Ethers.js in the Frappe Vue frontend; connects to an AXERP-managed Ethereum node (Infura as fallback).

---

## 7. Carbon Offset Mining & 'Gas' Economy

| Concept | Implementation |
|---|---|
| Transaction gas | GC-denominated fees on DEX trades; portion recycled into carbon project funding |
| Mining incentive | Partners operating validator nodes earn GC as block rewards |
| Environmental offset of mining | Energy consumption assessed quarterly; equivalent carbon credits burned (NFT issuance) as proof of offset |
| Eco-mining protocol | Validators required to demonstrate renewable energy source or purchase offset NFTs |

---

## 8. Project Monitoring (AXERP ↔ Blockchain)

Each physical carbon project (e.g., Kenya Mangrove Forest) has its lifecycle tracked across both AXERP and the blockchain:

| Milestone | AXERP Action | Blockchain Action |
|---|---|---|
| Project approved | Carbon Project DocType status → Active | `CarbonRegistry.registerProject(project_id, metadata_hash)` |
| Credit batch verified | Carbon Credit Batch submitted | — |
| Credits inventoried | Serial numbers assigned to Carbon Credit Inventory | — |
| Credits sold | Sales Invoice submitted | `GreenCoin.mint()` triggered |
| Credits burned | Carbon Trade with burn flag | `CarbonNFT.mintCertificate()` + `GreenCoin.burn()` |
| Project completion | Carbon Project status → Complete | `CarbonRegistry.closeProject()` |

---

## 9. Regulatory Compliance

| Regulation | Compliance Mechanism |
|---|---|
| Verified Carbon Standard (VCS) | Project metadata + serial numbers match VCS registry; certification docs stored on IPFS |
| Gold Standard | Same as VCS; Gold Standard registry cross-reference |
| FATF Travel Rule | Off-chain KYC (via AXERP Customer KYC DocType); wallet addresses linked to verified identity |
| MiCA (EU) | GC classified as utility token; legal opinion obtained before EU market launch |
| SEC / Canadian Securities | Legal review required before GC is listed on any public exchange |

---

## 10. Development Roadmap (CarbonBlockchain Sub-Project)

| Phase | Deliverable | Status |
|---|---|---|
| Phase 1 | `CarbonRegistry.sol` deployed on Ethereum testnet; AXERP serial number sync | In Progress |
| Phase 2 | `GreenCoin.sol` + `CarbonNFT.sol` on testnet; AXERP webhook integration | Planned |
| Phase 3 | Hyperledger Fabric network setup; `InventoryChaincode.go` deployed | Planned |
| Phase 4 | `CarbonDEX.sol`; SPV client in AXERP portal | Planned |
| Phase 5 | Security audit; mainnet deployment | Planned |
| Phase 6 | EEX bridge; GC marketplace launch | Planned |

---
