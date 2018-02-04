# Balance Proof
Data required by the smart contracts to update a single end of a payment channel.
## Invariants:
- Transferred amount starts 0 and is monotonic.
- Nonce starts at 1 and is strictly monotonic.
- Locksroot is the root node of the merkle tree of current pending locks.
- Signature must be valid and is defined as:
  ```
    ecdsa_recoverable(
      privkey,
      sha3_keccak(
        nonce ||
        transferred amount ||
        locksroot ||
        channel specific data ||
        additional hash
      )
    )
    ```
.

## Fields:
| type | Name |
| ---  | --- |
| uint64  | Nonce |
| uint256 | Transferred amount|
| bytes32 | Locksroot|
| bytes32 | Channel specific data (channel ID + chain ID)|
| bytes32 | Additional Hash|
| bytes   | Signature (elliptic curve 256k1 signature)|
