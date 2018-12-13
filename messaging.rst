Raiden Messages Specification
#############################

Overview
========

This is the specification document for the messages used in the Raiden protocol.

Data Structures
===============

.. _balance-proof-offchain:

Offchain Balance Proof
----------------------

Data required by the smart contracts to update the payment channel end of the participant that signed the balance proof.
Messages into smart contracts contain a shorter form called :ref:`Onchain Balance Proof <balance-proof-onchain>`.

The signature must be valid and is defined as:

::

    ecdsa_recoverable(privkey, keccak256(balance_hash || nonce || additional_hash || channel_identifier || token_network_address || chain_id))

Also see :term:`additional_hash`.

Fields
^^^^^^

+--------------------------+------------+--------------------------------------------------------------------------------+
| Field Name               | Field Type |  Description                                                                   |
+==========================+============+================================================================================+
|  nonce                   | uint256    | Strictly monotonic value used to order transfers. The nonce starts at 1        |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  transferred_amount      | uint256    | Total transferred amount in the history of the channel (monotonic value)       |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  locked_amount           | uint256    | Current locked amount                                                          |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  locksroot               | bytes32    | Root of the merkle tree of lock hashes (see below)                             |
+--------------------------+------------+--------------------------------------------------------------------------------+
| token_network_identifier | address    | Address of the TokenNetwork contract                                           |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  channel_identifier      | uint256    | Channel identifier inside the TokenNetwork contract                            |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  message_hash            | bytes32    | Hash of the message                                                            |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  signature               | bytes      | Elliptic Curve 256k1 signature on the above data                               |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  chain_id                | uint256    | Chain identifier as defined in EIP155                                          |
+--------------------------+------------+--------------------------------------------------------------------------------+


Merkle Tree
-----------

A binary tree composed of the hash of the locks. For each payment channel, each participant keeps track of two Merkle trees: one for the hashlocks that have been sent out to the partner, and the other for the hashlocks that have been received from the partner. Conceptually, each direction of a payment channel has one Merkle tree, and each participant has a copy of it. Only the sender of the hashlocks can change the Merkle tree of this direction.

The root of the tree is the value used in the :term:`balance proof`. The tree is changed by the ``LockedTransfer``, ``RemoveExpiredLock`` and ``Unlock`` message types. The sender of these messages applies the change to its copy of the tree and computes the root hash of the new tree. The receiver applies the same change to its copy of the tree and checks the root hash of the new tree against the root hash in the messages.

HashTimeLock
------------

Invariants
^^^^^^^^^^

- Expiration must be larger than the current block number and smaller than the channel’s settlement period.

Hash
^^^^

- ``keccak256(expiration || amount || secrethash)``

Fields
^^^^^^

+----------------------+-------------+------------------------------------------------------------+
| Field Name           | Field Type  |  Description                                               |
+======================+=============+============================================================+
|  expiration          | uint256     | Block number until which transfer can be settled           |
+----------------------+-------------+------------------------------------------------------------+
|  locked_amount       | uint256     | amount of tokens held by the lock                          |
+----------------------+-------------+------------------------------------------------------------+
|  secrethash          | bytes32     | keccak256 hash of the secret                               |
+----------------------+-------------+------------------------------------------------------------+

Messages
========

.. _locked-transfer-message:

Locked Transfer
-----------------

Cancellable and expirable :term:`transfer`. Sent by a node when a transfer is being initiated, this message adds a new lock to the corresponding merkle tree of the sending participant node.

Invariants
^^^^^^^^^^

Only valid if all the following hold:

- There is a channel which matches the given :term:`chain id`, :term:`token network` address, and :term:`channel identifier`.
- The corresponding channel is in the open state.
- The :term:`nonce` is increased by ``1`` in respect to the previous :term:`balance proof`
- The :term:`locksroot` must change, the new value must be equal to the root of a new tree, which has all the previous locks plus the lock provided in the message.
- The :term:`locked amount` must increase, the new value is equal to the old value plus the lock's amount.
- The lock's amount must be smaller then the participant's :term:`capacity`.
- The lock expiration must be greater than the current block number.
- The :term:`transferred amount` must not change.

Fields
^^^^^^

+----------------------+----------------------+------------------------------------------------------------+
| Field Name           | Field Type           |  Description                                               |
+======================+======================+============================================================+
|  lock                | HashTimeLock         | The lock for this locked transfer                          |
+----------------------+----------------------+------------------------------------------------------------+
|  balance_proof       | OffchainBalanceProof | Balance proof for this transfer                            |
+----------------------+----------------------+------------------------------------------------------------+
|  initiator           | address              | Initiator of the transfer and person who knows the secret  |
+----------------------+----------------------+------------------------------------------------------------+
|  target              | address              | Final target for this transfer                             |
+----------------------+----------------------+------------------------------------------------------------+

.. _secret-request-message:

Secret Request
--------------

Message used to request the :term:`secret` that unlocks a lock. Sent by the payment :term:`target` to the :term:`initiator` once a :ref:`locked transfer <locked-transfer-message>` is received.

Invariants
^^^^^^^^^^

- The :term:`initiator` must check that the payment :term:`target` received a valid payment.

Fields
^^^^^^

This should match `the encoding implementation <https://github.com/raiden-network/raiden/blob/16384b555b63c69aef8c2a575afc7a67610eb2bc/raiden/encoding/messages.py#L99>`_.

+----------------------+---------------+------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                               |
+======================+===============+============================================================+
|  cmdid               | one byte      | Value 3 (indicating ``Secret Request``)                    |
+----------------------+---------------+------------------------------------------------------------+
|  pad                 | three bytes   | Ignored                                                    |
+----------------------+---------------+------------------------------------------------------------+
|  message identifier  | uint64        | An ID used in ``Delivered`` and ``Processed``              |
|                      |               | acknowledgments                                            |
+----------------------+---------------+------------------------------------------------------------+
|  payment_identifier  | uint64        | An identifier for the payment chosen by the initiator      |
+----------------------+---------------+------------------------------------------------------------+
|  lock_secrethash     | bytes32       | Specifies which lock is being unlocked                     |
+----------------------+---------------+------------------------------------------------------------+
|  payment_amount      | uint256       | The amount received by the node once secret is revealed    |
+----------------------+---------------+------------------------------------------------------------+
|  expiration          | uint256       | See `HashTimeLock`_                                        |
+----------------------+---------------+------------------------------------------------------------+
|  signature           | bytes         | Elliptic Curve 256k1 signature                             |
+----------------------+---------------+------------------------------------------------------------+

.. _secret-reveal-message:

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

.. _unlock-message:

Unlock
------

.. Note:: At the current (15/02/2018) Raiden implementation as of commit ``cccfa572298aac8b14897ee9677e88b2b55c9a29`` this message is known in the codebase as ``Secret``.

Non cancellable, Non expirable.

Invariants
^^^^^^^^^^

- The :term:`balance proof` merkle tree must have the corresponding lock removed (and only this lock).
- This message is only sent after the corresponding partner has sent a :ref:`Secret Reveal message <secret-reveal-message>`.
- The :term:`nonce` is increased by ``1`` with respect to the previous :term:`balance proof`
- The :term:`locked amount` must decrease and the :term:`transferred amount` must increase by the amount held in the unlocked lock.


Fields
^^^^^^

+----------------------+------------------------+------------------------------------------------------------+
| Field Name           | Field Type             |  Description                                               |
+======================+========================+============================================================+
|  balance_proof       | OffchainBalanceProof   | Balance proof to update                                    |
+----------------------+------------------------+------------------------------------------------------------+
|  lock_secret         | bytes32                | The secret that unlocked the lock                          |
+----------------------+------------------------+------------------------------------------------------------+
|  signature           | bytes                  | Elliptic Curve 256k1 signature                             |
+----------------------+------------------------+------------------------------------------------------------+


Specification
=============

The encoding used by the transport layer is independent of this specification, as long as the signatures using the data are encoded in the EVM big endian format.

Transfers
---------

The protocol supports mediated transfers. A :term:`Mediated transfer` may be cancelled and can expire unless the initiator reveals the secret.

A mediated transfer is done in two stages, possibly on a series of channels:

- Reserve token :term:`capacity` for a given payment, using a :ref:`locked transfer message <locked-transfer-message>`.
- Use the reserved token amount to complete payments, using the :ref:`unlock message <unlock-message>`

Message Flow
------------

Nodes may use mediated transfers to send payments.

Mediated Transfer
^^^^^^^^^^^^^^^^^

A :term:`Mediated Transfer` is a hash-time-locked transfer. Currently raiden supports only one type of lock. The lock has an amount that is being transferred, a :term:`secrethash` used to verify the secret that unlocks it, and a :term:`lock expiration` to determine its validity.

Mediated transfers have an :term:`initiator` and a :term:`target` and a number of mediators in between. The number of mediators can also be zero as these transfers can also be sent to a direct partner. Assuming ``N`` number of mediators, a mediated transfer will require ``10N + 16`` messages to complete. These are:

- ``N + 1`` mediated or refund messages
- ``1`` secret request
- ``N + 2`` secret reveal
- ``N + 1`` unlock
- ``2N + 3`` processed (one for everything above)
- ``5N + 8`` delivered

For the simplest Alice - Bob example:

- Alice wants to transfer ``n`` tokens to Bob.
- Alice creates a new transfer with:
    * transferred_amount = ``current_value``
    * lock = ``Lock(n, hash(secret), expiration)``
    * locked_amount = ``updated value containing the lock amount``
    * locksroot = ``updated value containing the lock``
    * nonce = ``current_value + 1``
- Alice signs the transfer and sends it to Bob.
- Bob requests the secret that can be used for withdrawing the transfer by sending a ``SecretRequest`` message.
- Alice sends the ``RevealSecret`` to Bob and at this point she must assume the transfer is complete.
- Bob receives the secret and at this point has effectively secured the transfer of ``n`` tokens to his side.
- Bob sends a ``RevealSecret`` message back to Alice to inform her that the secret is known and acts as a request for off-chain synchronization.
- Finally Alice sends an ``Unlock`` message to Bob. This acts also as a synchronization message informing Bob that the lock will be removed from the merkle tree and that the transferred_amount and locksroot values are updated.

**Mediated Transfer - Best Case Scenario**

In the best case scenario, all Raiden nodes are online and send the final balance proofs off-chain.

.. image:: diagrams/RaidenClient_mediated_transfer_good.png
    :alt: Mediated Transfer Good Behaviour
    :width: 900px

**Mediated Transfer - Worst Case Scenario**

In case a Raiden node goes offline or does not send the final balance proof to its payee, then the payee can register the ``secret`` on-chain, in the ``SecretRegistry`` smart contract before the ``secret`` expires. This can be used to ``unlock`` the lock on-chain after the channel is settled.

.. image:: diagrams/RaidenClient_mediated_transfer_secret_reveal.png
    :alt: Mediated Transfer Bad Behaviour
    :width: 900px

**Limit to number of simultaneously pending transfers**

The number of simultaneously pending transfers per channel is limited. The client will not initiate, mediate or accept a further pending transfer if the limit is reached. This is to avoid the risk of not being able to unlock the transfers, as the gas cost for this operation grows with the size of the Merkle tree and thus the number of pending transfers.

The limit is currently set to 160. It is a rounded value that ensures the gas cost of unlocking will be less than 40% of Ethereum's traditional pi-million (3141592) block gas limit.
