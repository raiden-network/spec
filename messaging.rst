Raiden Messages Specification
#############################

Overview
========

This is the specification document for the messages used in the Raiden protocol.

Terminology
===========

- ``transferred_amount``: The monotonically increasing counter of one channel participant’s amount of tokens sent.
- ``hashlock``: A hashed secret, sha3_keccack(secret)
- ``locksroot``: The root of the merkle tree of all pending locks' lockhashes.
- ``lockhash``: The hash of a lock.  ``sha3_keccack(lock)``
- ``secret``: The preimage used to derive a hashlock

Data Structures
===============

Balance Proof
-------------

Data required by the smart contracts to update the payment channel end of the participant that signed the balance proof.

Invariants
^^^^^^^^^^

- Transferred amount starts at 0 and is monotonic.
- Nonce starts at 1 and is strictly monotonic.
- Locksroot is the root node of the merkle tree of current pending locks.
- Signature must be valid and is defined as: ``ecdsa_recoverable(privkey, sha3_keccak(nonce || transferred amount || locksroot || unique_channel_id || additional hash)``

Fields
^^^^^^

+----------------------+-------------+------------------------------------------------------------+
| Field Name           | Field Type  |  Description                                               |
+======================+=============+============================================================+
|  nonce               | uint64      | Strictly monotonic nonce                                   |
+----------------------+-------------+------------------------------------------------------------+
|  transferred_amount  | uint256     | counter of tokens sent                                     |
+----------------------+-------------+------------------------------------------------------------+
|  locksroot           | bytes32     | Root of merkle tree of all pending lock lockhashes         |
+----------------------+-------------+------------------------------------------------------------+
|  unique_channel_id   | bytes32     | Channel specific data for reply attack prevention          |
+----------------------+-------------+------------------------------------------------------------+
|  additional_hash     | bytes32     | Computed from the message. Used for message authentication |
+----------------------+-------------+------------------------------------------------------------+
|  signature           | bytes       | An elliptic curve 256k1 signature                          |
+----------------------+-------------+------------------------------------------------------------+


Merkle Tree
-----------

A binary tree composed of the hash of the locks. The root of the tree is the value used in the balance proofs. The tree is changed by the ``MediatedTransfer``, ``RemoveExpiredLock`` and ``Unlock`` message types.

HashTimeLock
------------

Invariants
^^^^^^^^^^

- Expiration must be larger than the current block number and smaller than the channel’s settlement period.

Hash
^^^^^

- ``sha3_keccak(expiration || amount || hashlock)``

Fields
^^^^^^

+----------------------+-------------+------------------------------------------------------------+
| Field Name           | Field Type  |  Description                                               |
+======================+=============+============================================================+
|  expiration          | uint64      | Block number until which transfer can be settled           |
+----------------------+-------------+------------------------------------------------------------+
|  locked_amount       | uint256     | amount of tokens held by the lock                          |
+----------------------+-------------+------------------------------------------------------------+
|  hashlock            | bytes32     | sha3 of the secret                                         |
+----------------------+-------------+------------------------------------------------------------+


Messages
========

Direct Transfer
---------------

A non cancellable, non expirable payment.

Invariants
^^^^^^^^^^

- Only valid if the transferred amount is larger than the previous value and it increased by an amount smaller than the participant's current capacity.

Fields
^^^^^^

+----------------------+---------------+------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                               |
+======================+===============+============================================================+
|  balance_proof       | BalanceProof  | Balance proof for this transfer                            |
+----------------------+---------------+------------------------------------------------------------+

Mediated Transfer
-----------------

Cancellable and expirable transfer. Sent by a node when a transfer is being initiated, this message adds a new lock to the corresponding merkle tree of the sending participant node.


Invariants
^^^^^^^^^^

- The balance proof's locksroot must be equal to the previous valid merkle tree with the lock provided in the messaged added into it.
- The transfer is valid only if the lock amount is smaller than the sender's capacity.

Fields
^^^^^^

+----------------------+---------------+------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                               |
+======================+===============+============================================================+
|  lock                | HashTimeLock  | The lock for this mediated transfer                        |
+----------------------+---------------+------------------------------------------------------------+
|  balance_proof       | BalanceProof  | Balance proof for this transfer                            |
+----------------------+---------------+------------------------------------------------------------+
|  initiator           | address       | Initiator of the transfer and person who knows the secret  |
+----------------------+---------------+------------------------------------------------------------+
|  target              | address       | Final target for this transfer                             |
+----------------------+---------------+------------------------------------------------------------+


Secret Request
--------------

Message used to request the secret that unlocks a lock. Sent by the payment target to the initiator once a mediated transfer is received.

Invariants
^^^^^^^^^^

- The initiator must check that the payment target received a valid payment.

Fields
^^^^^^

+----------------------+---------------+------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                               |
+======================+===============+============================================================+
|  payment_amount      | uint256       | The amount received by the node once secret is revealed    |
+----------------------+---------------+------------------------------------------------------------+
|  lock_hashlock       | bytes32       | Specifies which lock is being unlocked                     |
+----------------------+---------------+------------------------------------------------------------+
|  signature           | bytes         | Elliptic Curve 256k1 signature                             |
+----------------------+---------------+------------------------------------------------------------+

Secret Reveal
--------------

Message used by the nodes to inform others that the secret is known. Used to request an updated balance proof with the transferred amount increased and the lock removed.

Fields
^^^^^^

+----------------------+---------------+------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                               |
+======================+===============+============================================================+
|  lock_secret         | bytes32       | The secret that unlocks the lock                           |
+----------------------+---------------+------------------------------------------------------------+
|  signature           | bytes         | Elliptic Curve 256k1 signature                             |
+----------------------+---------------+------------------------------------------------------------+

Unlock
------

.. Note:: At the current (15/02/2018) Raiden implementation as of commit ``cccfa572298aac8b14897ee9677e88b2b55c9a29`` this message is known in the codebase as ``Secret``.

Non cancellable, Non expirable. Updated balance proof, increases the transferred amount and removes the unlocked lock from the merkle tree.

Invariants
^^^^^^^^^^

- The balance proof merkle tree must have the corresponding lock removed (and only this lock).
- This message is only sent after the corresponding partner has sent a SecretReveal message.


Fields
^^^^^^

+----------------------+---------------+------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                               |
+======================+===============+============================================================+
|  balance_proof       | BalanceProof  | Balance proof to update                                    |
+----------------------+---------------+------------------------------------------------------------+
|  lock_secret         | bytes32       | The secret that unlocked the lock                          |
+----------------------+---------------+------------------------------------------------------------+
|  signature           | bytes         | Elliptic Curve 256k1 signature                             |
+----------------------+---------------+------------------------------------------------------------+

RemoveExpiredLock
-----------------

Removes one lock that has expired. Used to trim the merkle tree and recover the locked capacity. This message is only valid if the corresponding lock expiration is lower than the latest block number for the corresponding blockchain.

Fields
^^^^^^

+----------------------+---------------+------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                               |
+======================+===============+============================================================+
|  hashlock            | bytes32       | The hashlock to remove                                     |
+----------------------+---------------+------------------------------------------------------------+
|  balance_proof       | BalanceProof  | The updated balance proof                                  |
+----------------------+---------------+------------------------------------------------------------+
|  signature           | bytes         | Elliptic Curve 256k1 signature                             |
+----------------------+---------------+------------------------------------------------------------+


Specification
=============

The encoding used by the transport layer is independent of this specification, as long as the signatures using the data are encoded in the EVM big endian format.

Transfers
---------

The protocol supports two types of transfers, direct and mediated. Direct transfers are non cancellable and unexpirable, while mediated transfers may be cancelled and can expire.

A mediated transfer is done in two stages, possibly on a series of channels:
Reserve token capacity for a given payment
Use the reserved token amount to complete payments

Message Flow
------------

TODO: Use message flow from Raiden docs and 101 (https://raiden.network/101.html) page here.



Nodes may use direct or mediated transfers.

Direct transfers can only be used with a direct channel open among the participants. The node that wants to make a payment must increase the transferred amount of the balance proof by the payment amount. The node receiving a direct transfer must validate the balance proof and ensure that the nonce was increased, the transferred amount was increased but not by an amount larger than the available capacity, and that the locksroot used in the balance proof corresponds to the unmodified merkle tree.

Mediated transfers are done with the support of other nodes in the network, there are three roles: initiator, mediator and target.

The initiator starts a transfer, it is responsible to choose a random secret that it considers secure and start the mediated transfer using one of it’s available channels.

Mediator nodes are all the nodes that participate in the transfer, but are neither the initiator nor the target, these nodes don’t control the secret and are only



