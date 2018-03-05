Raiden Messages Specification
#############################

Overview
========

This is the specification document for the messages used in the Raiden protocol.

Data Structures
===============

Balance Proof
-------------

Data required by the smart contracts to update the payment channel end of the participant that signed the balance proof.

Invariants
^^^^^^^^^^

- :term:`Transferred amount` starts at 0 and is monotonic.
- Nonce starts at 1 and is strictly monotonic.
- :term:`Locksroot` is the root node of the merkle tree of current pending locks.
- Signature must be valid and is defined as: ``ecdsa_recoverable(privkey, sha3_keccak(nonce || transferred amount || locksroot || unique_channel_id || additional hash)``

Fields
^^^^^^

+-----------------------+-------------+------------------------------------------------------------+
| Field Name            | Field Type  |  Description                                               |
+=======================+=============+============================================================+
|  nonce                | uint64      | Strictly monotonic nonce                                   |
+-----------------------+-------------+------------------------------------------------------------+
|  transferred_amount   | uint256     | counter of tokens sent                                     |
+-----------------------+-------------+------------------------------------------------------------+
|  locksroot            | bytes32     | Root of merkle tree of all pending lock lockhashes         |
+-----------------------+-------------+------------------------------------------------------------+
|  channel_identifier   | uint256     | Channel identifier inside the TokenNetwork contract        |
+-----------------------+-------------+------------------------------------------------------------+
| token_network_address | address     | Address of the TokenNetwork contract                       |
+-----------------------+-------------+------------------------------------------------------------+
| chain_id              | uint256     | Chain identifier as defined in EIP155                      |
+-----------------------+-------------+------------------------------------------------------------+
|  additional_hash      | bytes32     | Computed from the message. Used for message authentication |
+-----------------------+-------------+------------------------------------------------------------+
|  signature            | bytes       | An elliptic curve 256k1 signature                          |
+-----------------------+-------------+------------------------------------------------------------+


Merkle Tree
-----------

A binary tree composed of the hash of the locks. The root of the tree is the value used in the balance proofs. The tree is changed by the ``MediatedTransfer``, ``RemoveExpiredLock`` and ``Unlock`` message types.

HashTimeLock
------------

Invariants
^^^^^^^^^^

- Expiration must be larger than the current block number and smaller than the channel’s settlement period.

Hash
^^^^

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

- Only valid if the :term:`transferred amount` is larger than the previous value and it increased by an amount smaller than the participant's current :term:`capacity`.

Fields
^^^^^^

+----------------------+---------------+------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                               |
+======================+===============+============================================================+
|  balance_proof       | BalanceProof  | Balance proof for this transfer                            |
+----------------------+---------------+------------------------------------------------------------+

Mediated Transfer
-----------------

Cancellable and expirable :term:`transfer`. Sent by a node when a transfer is being initiated, this message adds a new lock to the corresponding merkle tree of the sending participant node.


Invariants
^^^^^^^^^^

- The :term:`balance proof` locksroot must be equal to the previous valid merkle tree with the lock provided in the messaged added into it.
- The transfer is valid only if the lock amount is smaller than the sender's :term:`capacity`.

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

Message used to request the :term:`secret` that unlocks a lock. Sent by the payment :term:`target` to the :term:`initiator` once a :term:`mediated transfer` is received.

Invariants
^^^^^^^^^^

- The :term:`initiator` must check that the payment :term:`target` received a valid payment.

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
-------------

Message used by the nodes to inform others that the :term:`secret` is known. Used to request an updated :term:`balance proof` with the :term:`transferred amount` increased and the lock removed.

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

Non cancellable, Non expirable. Updated :term:`balance proof`, increases the :term:`transferred amount` and removes the unlocked lock from the merkle tree.

Invariants
^^^^^^^^^^

- The :term:`balance proof` merkle tree must have the corresponding lock removed (and only this lock).
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

The protocol supports two types of transfers, direct and mediated. A :term:`Direct transfer` is non cancellable and unexpirable, while a :term:`mediated transfer` may be cancelled and can expire.

A mediated transfer is done in two stages, possibly on a series of channels:
Reserve token :term:`capacity` for a given payment
Use the reserved token amount to complete payments

Message Flow
------------

Nodes may use direct or mediated transfers to send payments.

Direct Transfer
^^^^^^^^^^^^^^^

A ``DirectTransfer`` does not rely on locks to complete. It is automatically completed once the network packet is sent off. Since Raiden runs on top of an asynchronous network that can not guarantee delivery, transfers can not be completed atomically. The main points to consider about direct transfers are the following:

- The messages are not locked, meaning the envelope :term:`transferred amount` is incremented and the message may be used to withdraw the token. This means that a :term:`sender` is unconditionally transferring the token, regardless of getting a service or not. Trust is assumed among the :term:`sender`/:term:`receiver` to complete the goods transaction.

- The sender must assume the transfer is completed once the message is sent to the network, there is no workaround. The acknowledgement in this case is only used as a synchronization primitive, the payer will only know about the transfer once the message is received.

A succesfull direct transfer involves only 2 messages. The direct transfer message and an ``ACK``. For an Alice - Bob example:

* Alice wants to transfer ``n`` tokens to Bob.
* Alice creates a new transfer with.
    - transferred_amount = ``current_value + n``
    - ``locksroot`` = ``current_locksroot_value``
    - nonce = ``current_value + 1``
* Alice signs the transfer and sends it to Bob and at this point should consider the transfer complete.

Mediated Transfer
^^^^^^^^^^^^^^^^^
A :term:`Mediated Transfer` is a hashlocked transfer. Currently raiden supports only one type of lock. The lock has an amount that is being transferred, a :term:`hashlock` used to verify the secret that unlocks it, and a :term:`lock expiration` to determine its validity.

Mediated transfers have an :term:`initiator` and a :term:`target` and a number of hops in between. The number of hops can also be zero as these transfers can also be sent to a direct partner. Assuming ``N`` number of hops a mediated transfer will require ``6N + 8`` messages to complete. These are:

- ``N + 1`` mediated or refund messages
- ``1`` secret request
- ``N + 1`` secret reveal
- ``N + 1`` secret
- ``3N + 4`` ACK

For the simplest Alice - Bob example:

- Alice wants to transfer ``n`` tokens to Bob.
- Alice creates a new transfer with:
    * transferred_amount = ``current_value``
    * lock = ``Lock(n, hash(secret), expiration)``
    * locksroot = ``updated value containing  the lock``
    * nonce = ``current_value + 1``
- Alice signs the transfer and sends it to Bob.
- Bob requests the secret that can be used for withdrawing the transfer by sending a ``SecretRequest`` message.
- Alice sends the ``SecretReveal`` to Bob and at this point she must assume the transfer is complete.
- Bob receives the secret and at this point has effectively secured the transfer of ``n`` tokens to his side.
- Bob sends an ``Unlock`` message back to Alice to inform her that the secret is known and acts as a request for off-chain synchronization.
- Finally Alice sends an ``Unlock`` message to Bob. This acts also as a synchronization message informing Bob that the lock will be removed from the merkle tree and that the transferred_amount and locksroot values are updated.
