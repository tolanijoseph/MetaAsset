# MetaAsset

A on-chain registry of verified virtual world and metaverse asset contracts, deployed on the [Stacks](https://www.stacks.co/) blockchain and written in [Clarity](https://docs.stacks.co/clarity/overview).

---

## Overview

MetaAsset allows developers, creators, and platforms to register their metaverse asset contracts (land parcels, wearables, in-game items, etc.) on-chain and have them verified by trusted verifiers. Any dApp, marketplace, or wallet can then query the registry to confirm whether a given asset contract is legitimate and active — acting as a decentralized trust layer for the metaverse.

---

## Features

- **Open registration** — Anyone can register an asset contract they own
- **Verified badge** — Approved verifiers can mark assets as verified (or revoke it)
- **Soft delete** — Asset owners can deactivate/reactivate entries without losing history
- **Ownership transfer** — Registry ownership of an asset can be transferred to a new principal
- **Owner index** — Tracks up to 20 registered assets per owner address
- **Read-only queries** — Gas-free lookups for asset data, verification status, and more

---

## Roles

| Role | Description |
|---|---|
| **Contract Owner** | The deployer. Manages the verifier whitelist. |
| **Verifier** | A trusted address authorized to verify or revoke asset verification. |
| **Asset Owner** | The address that registered an asset. Controls its lifecycle. |

---

## Data Structures

### Asset Record

Each asset is stored in the `assets` map, keyed by its contract principal:

| Field | Type | Description |
|---|---|---|
| `name` | `string-ascii 64` | Human-readable asset name |
| `world` | `string-ascii 64` | Virtual world (e.g. `"Decentraland"`) |
| `asset-type` | `string-ascii 32` | Category (e.g. `"land"`, `"wearable"`, `"item"`) |
| `owner` | `principal` | Address that registered the asset |
| `verified` | `bool` | Whether a verifier has approved this asset |
| `active` | `bool` | Whether the asset is currently active |
| `registered-at` | `uint` | Stacks block height at registration time |

---

## Public Functions

### Verifier Management _(Contract Owner only)_

```clarity
(add-verifier (verifier principal))
```
Adds an address to the approved verifier list.

```clarity
(remove-verifier (verifier principal))
```
Removes an address from the verifier list.

---

### Asset Registration _(Anyone)_

```clarity
(register-asset (asset-contract principal)
                (name string-ascii 64)
                (world string-ascii 64)
                (asset-type string-ascii 32))
```
Registers a new asset contract in the registry. The caller becomes the asset owner. All string fields must be non-empty.

---

### Asset Verification _(Verifier or Contract Owner)_

```clarity
(verify-asset (asset-contract principal))
```
Marks a registered asset as verified.

```clarity
(revoke-verification (asset-contract principal))
```
Removes the verified status from an asset.

---

### Asset Management _(Asset Owner only)_

```clarity
(deactivate-asset (asset-contract principal))
```
Soft-deletes an asset by setting `active` to `false`. History is preserved.

```clarity
(reactivate-asset (asset-contract principal))
```
Re-enables a previously deactivated asset.

```clarity
(transfer-asset-ownership (asset-contract principal) (new-owner principal))
```
Transfers the registry ownership of an asset to a new principal.

---

## Read-Only Functions

```clarity
(get-asset (asset-contract principal))
```
Returns the full asset record, or `none` if not found.

```clarity
(is-verified-asset (asset-contract principal))
```
Returns `true` if the asset is both verified **and** active. Useful for quick on-chain checks.

```clarity
(get-total-assets)
```
Returns the total number of registered assets.

```clarity
(get-assets-by-owner (owner principal))
```
Returns a list of asset contract principals registered by the given owner (up to 20).

```clarity
(is-approved-verifier (addr principal))
```
Returns `true` if the given address is an approved verifier.

```clarity
(get-contract-owner)
```
Returns the contract owner's principal.

---

## Error Codes

| Code | Constant | Description |
|---|---|---|
| `u100` | `ERR-NOT-OWNER` | Caller is not the contract owner |
| `u101` | `ERR-ALREADY-REGISTERED` | Asset contract is already in the registry |
| `u102` | `ERR-NOT-FOUND` | Asset contract not found in the registry |
| `u103` | `ERR-NOT-VERIFIED` | Asset is not verified |
| `u104` | `ERR-UNAUTHORIZED` | Caller lacks permission for this action |
| `u105` | `ERR-INVALID-INPUT` | One or more input fields are empty or invalid |
| `u106` | `ERR-ALREADY-VERIFIER` | Address is already a verifier |
| `u107` | `ERR-NOT-VERIFIER` | Address is not a verifier |

---

## Usage Example

**1. Deploy the contract**
The deploying address becomes the `CONTRACT-OWNER`.

**2. Add a trusted verifier**
```clarity
(contract-call? .meta-asset add-verifier 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

**3. Register an asset**
```clarity
(contract-call? .meta-asset register-asset
  'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sand-parcel-01
  "Parcel #1042"
  "The Sandbox"
  "land")
```

**4. Verify the asset**
```clarity
(contract-call? .meta-asset verify-asset
  'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sand-parcel-01)
```

**5. Query verification status**
```clarity
(contract-call? .meta-asset is-verified-asset
  'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sand-parcel-01)
;; => (ok true)
```

---

## Limitations

- Each owner address can track a maximum of **20 asset contracts** in the ownership index. Registration beyond this limit is silently capped in the index (the asset record itself is still stored).
- Asset records cannot be fully deleted from the chain — only deactivated.
- String fields are ASCII only (max 64 chars for `name`/`world`, 32 chars for `asset-type`).

---

## Requirements

| Requirement | Version |
|---|---|
| Clarity | 2 |
| Stacks Node | 2.4+ |

> **Note:** This contract uses `stacks-block-height` (Clarity 2+). If targeting a Clarity 1 environment, replace it with `block-height`.