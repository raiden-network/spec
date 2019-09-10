Raiden Messages Specification
#############################

Overview
========

This is the specification of the messages used in the Raiden protocol.

There are data structures which reappear in different messages:

- The :ref:`offchain balance proof <balance-proof-offchain>`
- and the :ref:`hash time lock <hash-time-lock>`.

Messages sent between raiden nodes can be divided in three groups:

- An :term:`offchain message` is only sent between nodes and contain no state that could be of interest for the contracts.
- An :term:`envelope message` partly consists of data that could be sent to a contract.
- An :term:`onchain message`, which can (but does not have to) be sent in total to a contract.

A :term:`mediated transfer` begins with a :ref:`LockedTransfer message <locked-transfer-message>`.

We will explain the assembly of a ``LockedTransfer`` message step-by-step below.
The further messages within the transfer are based on it:

- :ref:`SecretRequest <secret-request-message>`,
  its reply :ref:`RevealSecret <reveal-secret-message>`, and
  finally the :ref:`Unlock <unlock-message>` messages that complete the transfer.
- The :ref:`LockExpired <lock-expired-message>` message in case the transfer is not completed in time.

Further messages in the protocol are:

- The :ref:`Processed and Delivered <processed-delivered-message>` messages to acknowledge received messages, and
- The withdraw-related messages :ref:`WithdrawRequest <withdraw-request-message>`,
  :ref:`WithdrawConfirmation <withdraw-confirmation-message>` and
  :ref:`WithdrawExpired <withdraw-expired-message>`.

Encoding, signing and transport
===============================

All messages are encoded in a JSON format and sent via our Matrix transport layer.

The encoding used by the transport layer is independent of this specification, as
long as the signatures using the data are encoded in the EVM big endian format.

Each :term:`offchain message` has a packed data format defined so it can be signed. The
format always consists of the message type's 1-byte command id, three zero bytes for padding
and then the respective data fields in a specified order. The following message types are
offchain messages: ``Processed``, ``Delivered``,  ``SecretRequest``, ``RevealSecret``.

Each :term:`envelope message` has a packed data format defined to compute the :term:`additional hash`
from. The format always starts with the 1-byte command id, but no padding bytes. Envelope messages
are: ``LockedTransfer``, ``Unlock`` and ``LockExpired``.

Each :term:`onchain message` has a packed data format in which it can be sent to the contract.
The format always starts with :term:`token network address`, the :term:`chain id` and a message type
constant, which is an unsigned 256-bit integer. Onchain messages are: ``WithdrawRequest``,
``WithdrawConfirmation`` and ``WithdrawExpired``.


Data Structures
===============

.. _balance-proof-offchain:

Offchain Balance Proof
----------------------

Data required by the smart contracts to update the payment channel end of the participant that signed the balance proof.
Messages into smart contracts contain a shorter form called :ref:`Onchain Balance Proof <balance-proof-onchain>`.

The offchain balance proof consists of the :term:`balance data`, the channel's :term:`canonical identifier`, the
signature, the additional hash and a nonce.

The signature must be valid and is defined as:

::

    ecdsa_recoverable(privkey, keccak256(balance_hash || nonce || additional_hash || channel_identifier || token_network_address || chain_id))

where ``additional_hash`` is the hash of the whole message being signed.

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
|  locksroot               | bytes32    | Hash of the pending locks encoded and concatenated                             |
+--------------------------+------------+--------------------------------------------------------------------------------+
| token_network_address    | address    | Address of the TokenNetwork contract                                           |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  channel_identifier      | uint256    | Channel identifier inside the TokenNetwork contract                            |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  additional_hash         | bytes32    | Hash of the message                                                            |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  signature               | bytes      | Elliptic Curve 256k1 signature on the above data                               |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  chain_id                | uint256    | Chain identifier as defined in EIP155                                          |
+--------------------------+------------+--------------------------------------------------------------------------------+

- The ``channel_identifier``, ``token_network_address`` and ``chain_id`` together are a
  globally unique identifier of the channel, also known as the :term:`canonical identifier`.

- The :term:`balance data` consists of ``transferred_amount``, ``locked_amount`` and ``locksroot``.


.. _hash-time-lock:

HashTimeLock
------------

This data structure describes a :term:`hash time lock` with which a transfer is secured. The
``locked_amount`` can be unlocked with the secret matching ``secrethash`` until ``expiration``
is reached.

Invariants
^^^^^^^^^^

- Expiration must be larger than the current block number and smaller than the channel’s settlement period.

Hash
^^^^^^

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

A Locked Transfer is a message used to reserve tokens for a mediated transfer to another node
called the **target**.

Locked Transfer message
^^^^^^^^^^^^^^^^^^^^^^^^

The message is always sent to the next mediating node, altered and forwarded until the
**target** is reached.

In order to create a valid, signed JSON message, four consecutive steps are conducted.

1. Compute the :term:`additional hash`
2. Compute the ``balance_hash`` from the :term:`balance data`
3. Create the ``balance_proof`` with ``additional_hash`` and ``balance_hash``
4. Pack and sign the ``balance_proof`` to get the signature of the Locked Transfer

The ``LockedTransfer`` message consists of the fields of a :ref:`hash time lock <hash-time-lock>`,
an :ref:`offchain balance proof <balance-proof-offchain>` and the following:

+-----------------------+------------+-----------------------------------------------------------+
| Field Name            | Type       |  Description                                              |
+=======================+============+===========================================================+
|  message_identifier   | uint64     | An ID for ``Delivered`` and ``Processed`` acknowledgments |
+-----------------------+------------+-----------------------------------------------------------+
|  payment_identifier   | uint64     | An identifier for the payment that the initiator specifies|
+-----------------------+------------+-----------------------------------------------------------+
|  token                | address    | Address of the token contract                             |
+-----------------------+------------+-----------------------------------------------------------+
|  recipient            | address    | Destination for this hop of the transfer                  |
+-----------------------+------------+-----------------------------------------------------------+
|  target               | address    | Final destination of the payment                          |
+-----------------------+------------+-----------------------------------------------------------+
|  initiator            | address    | Initiator of the transfer and party who knows the secret  |
+-----------------------+------------+-----------------------------------------------------------+
|  fee                  | uint256    | Total available fee for remaining mediators               |
+-----------------------+------------+-----------------------------------------------------------+

In addition there is a ``metadata`` field with a list of possible routes for the transfer.

1. Additional Hash
^^^^^^^^^^^^^^^^^^

The data will be packed as follows to compute the :term:`additional hash`:

+--------------------------------------+---------+-------------+
| Field                                | Type    | Size (bytes)|
+======================================+=========+=============+
| command_id (7 for ``LockedTransfer``)| uint8   |   1         |
+--------------------------------------+---------+-------------+
| message_identifier                   | uint64  |   8         |
+--------------------------------------+---------+-------------+
| payment_identifier                   | uint64  |   8         |
+--------------------------------------+---------+-------------+
| expiration                           | uint256 |  32         |
+--------------------------------------+---------+-------------+
| token_network_address                | address |  20         |
+--------------------------------------+---------+-------------+
| token                                | address |  20         |
+--------------------------------------+---------+-------------+
| recipient                            | address |  20         |
+--------------------------------------+---------+-------------+
| target                               | address |  20         |
+--------------------------------------+---------+-------------+
| initiator                            | address |  20         |
+--------------------------------------+---------+-------------+
| secrethash                           | bytes32 |  32         |
+--------------------------------------+---------+-------------+
| amount                               | uint256 |  32         |
+--------------------------------------+---------+-------------+
| fee                                  | uint256 |  32         |
+--------------------------------------+---------+-------------+
| metadata_hash                        | bytes32 |  32         |
+--------------------------------------+---------+-------------+

The computation of the ``metadata_hash`` as well as the exact format of the ``metadata`` itself
are implementation specific.

This will be used to generate the the data field called ``additional_hash``, which is a required
part of the process to create the message signature. It is computed as the ``keccak256``-hash
of the data structure given above::

    additional_hash = keccak256(pack(additional_hash_data))

.. note ::

  The ``additional_hash`` is sometimes called ``message_hash`` in the reference implementation.

2. Balance Hash
^^^^^^^^^^^^^^^

Before we generate the message signature another hash needs to be created. This is
the ``balance_hash`` that is generated using the :term:`balance data`:

+-----------------------+----------+-------+
| Field                 | Data     | Size  |
+-----------------------+----------+-------+
| transferred_amount    | uint256  | 32    |
+-----------------------+----------+-------+
| locked_amount         | uint256  | 32    |
+-----------------------+----------+-------+
| locksroot             | bytes32  | 32    |
+-----------------------+----------+-------+

In order to create the ``balance_hash`` you first need to pack the :term:`balance data`::

    packed_balance = pack(balance_data)
    balance_hash = keccak256(packed_balance)


3. Balance Proof
^^^^^^^^^^^^^^^^

The signature of a Locked Transfer is created by signing the packed form of a ``balance_proof``.

A ``balance_proof`` contains the following fields - using our example data. Notice that the fields
are the same as in the :ref:`offchain balance proof <balance-proof-offchain>` datastructure, except
there is no signature yet and the :term:`balance data` has been hashed into ``balance_hash``.

+--------------------------------+----------+------+
| Field                          | Type     | Size |
+--------------------------------+----------+------+
| token_network_address          | address  | 20   |
+--------------------------------+----------+------+
| chain_id                       | uint256  | 32   |
+--------------------------------+----------+------+
| msg_type (1 for balance proof) | uint256  | 32   |
+--------------------------------+----------+------+
| channel_identifier             | uint256  | 32   |
+--------------------------------+----------+------+
| balance_hash                   | bytes32  | 32   |
+--------------------------------+----------+------+
| nonce                          | uint256  | 32   |
+--------------------------------+----------+------+
| additional_hash                | bytes32  | 32   |
+--------------------------------+----------+------+

4. Signature
^^^^^^^^^^^^

Lastly we pack the ``balance_proof`` and sign it, to obtain the ``signature`` field of our
``LockedTransfer`` message::

    packed_balance_proof = pack(balance_proof)
    signature = eth_sign(privkey=private_key, data=packed_balance_proof)

Preconditions for LockedTransfer
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

For a Locked Transfer to be considered valid there are the following conditions. The message will be rejected otherwise:

- (PC1) :term:`nonce` is increased by ``1`` with respect to the previous balance changing message in that direction
- (PC2) The :term:`canonical identifier` refers to an existing and open channel
- (PC3) :term:`expiration` must be greater than the current block number
- (PC4) :term:`locksroot` must be equal to the hash of a new list of all currently pending locks in chronological order
- (PC5) :term:`transferred amount` must not change compared to the last :term:`balance proof`
- (PC6) :term:`locked amount` must increase by exactly :term:`amount` [#PC6]_
- (PC7) :term:`amount` must be smaller than the current :term:`capacity` [#PC7]_

.. [#PC6] If the :term:`locked amount` is increased by more, then funds may get locked in the channel. If the :term:`locked amount` is increased by less, then the recipient will reject the message as it may mean it received the funds with an on-chain unlock. The initiator will stipulate the fees based on the available routes and incorporate it in the lock's amount. Note that with permissive routing it is not possible to predetermine the exact `fee` amount, as the initiator does not know which nodes are available, thus an estimated value is used.
.. [#PC7] If the amount is higher then the recipient will reject it, as it means he will be spending money it does not own.

.. _lock-expired-message:

Lock Expired
--------------

Message used to inform partner that the :term:`Hash Time Lock` has expired. Sent by the :term:`initiator` to the :term:`mediator` or :term:`target` when the following conditions are met:

Preconditions
^^^^^^^^^^^^^^^^
- The current block reached the lock's expiry block number plus `NUMBER_OF_BLOCK_CONFIRMATIONS`.
- For the lock expired message to be sent, the :term:`initiator` waits until the
  `expiration + NUMBER_OF_BLOCK_CONFIRMATIONS * 2` is reached.
- For the :term:`mediator` or :term:`target`, the lock expired is accepted once the current
  `expiration + NUMBER_OF_BLOCK_CONFIRMATIONS` is reached.
- The :term:`initiator` or :term:`mediator` must wait until the lock removal block is reached.
- The :term:`initiator`, :term:`mediator` or :term:`target` must not have registered the secret on-chain before expiring the lock.
- The :term:`nonce` is increased by ``1`` in respect to the previous :term:`balance proof`
- The :term:`locksroot` must change, the new value must be equal to the root of a new tree after the expired lock is removed.
- The :term:`locked amount` must decrease, the new value should be to the old value minus the lock's amount.
- The :term:`transferred amount` must not change.

Message Fields
^^^^^^^^^^^^^^

The ``LockExpired`` message consists of an :ref:`offchain balance proof <balance-proof-offchain>` and the following fields:

+-----------------------+----------------------+------------------------------------------------------------+
| Field Name            | Field Type           |  Description                                               |
+=======================+======================+============================================================+
|  message_identifier   | uint64               | An ID for ``Delivered`` and ``Processed`` acknowledgments  |
+-----------------------+----------------------+------------------------------------------------------------+
|  recipient            | address              | Destination for this hop of the transfer                   |
+-----------------------+----------------------+------------------------------------------------------------+
|  secrethash           | bytes32              | From the transfer's `HashTimeLock`_                        |
+-----------------------+----------------------+------------------------------------------------------------+

Additional Hash
^^^^^^^^^^^^^^^

The data will be packed as follows to compute the :term:`additional hash`:

+-------------------------------------+-----------+---------------+
| Field                               | Type      | Size (bytes)  |
+=====================================+===========+===============+
| command_id (13 for ``LockExpired``) | uint8     |   1           |
+-------------------------------------+-----------+---------------+
| message_identifier                  | uint64    |   8           |
+-------------------------------------+-----------+---------------+
| recipient                           | address   |  20           |
+-------------------------------------+-----------+---------------+
| secrethash                          | bytes32   |  32           |
+-------------------------------------+-----------+---------------+


.. _secret-request-message:

Secret Request
--------------

Message used to request the :term:`secret` that unlocks a lock. Sent by the payment :term:`target` to the :term:`initiator` once a :ref:`locked transfer <locked-transfer-message>` is received.

Invariants
^^^^^^^^^^

- The :term:`initiator` must have initiated a payment to the :term:`target` with the same ``payment_identifier`` and
  :term:`Hash Time Lock`
- The :term:`target` must have received a :term:`Locked Transfer` for the payment.
- The ``signature`` must be from the :term:`target`.

Fields
^^^^^^

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

.. _reveal-secret-message:

Reveal Secret
-------------

Message used by the nodes to inform others that the :term:`secret` is known. Used to request an updated :term:`balance proof` with the :term:`transferred amount` increased and the lock removed.

Fields
^^^^^^

+----------------------+---------------+------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                               |
+======================+===============+============================================================+
|  cmdid               | one byte      | Value 11 (indicating ``Reveal Secret``)                    |
+----------------------+---------------+------------------------------------------------------------+
|  pad                 | three bytes   | Ignored                                                    |
+----------------------+---------------+------------------------------------------------------------+
|  message_identifier  | uint64        | An ID use in ``Delivered`` and ``Processed``               |
|                      |               | acknowledgments                                            |
+----------------------+---------------+------------------------------------------------------------+
|  lock_secret         | bytes32       | The secret that unlocks the lock                           |
+----------------------+---------------+------------------------------------------------------------+
|  signature           | bytes         | Elliptic Curve 256k1 signature                             |
+----------------------+---------------+------------------------------------------------------------+

.. _unlock-message:

Unlock
------

Non cancellable, Non expirable.

Invariants
^^^^^^^^^^

- The :term:`balance proof` must contain the hash of the new list of pending locks, from which the unlocked lock has been removed.
- This message is only sent after the corresponding partner has sent a :ref:`Reveal Secret message <reveal-secret-message>`.
- The :term:`nonce` is increased by ``1`` with respect to the previous :term:`balance proof`
- The :term:`locked amount` must decrease and the :term:`transferred amount` must increase by the amount held in the unlocked lock.


Fields
^^^^^^

The ``Unlock`` message consists of an :ref:`offchain balance proof <balance-proof-offchain>` and the following fields:

+----------------------+------------------------+------------------------------------------------------------+
| Field Name           | Field Type             |  Description                                               |
+======================+========================+============================================================+
|  message_identifier  | uint64                 | An ID used in ``Delivered`` and ``Processed``              |
|                      |                        | acknowledgments                                            |
+----------------------+------------------------+------------------------------------------------------------+
|  payment_identifier  | uint64                 | An identifier for the :term:`Payment` chosen by the        |
|                      |                        | :term:`Initiator`                                          |
+----------------------+------------------------+------------------------------------------------------------+
|  lock_secret         | bytes32                | The secret that unlocked the lock                          |
+----------------------+------------------------+------------------------------------------------------------+

Additional Hash
^^^^^^^^^^^^^^^

The data is packed as follows to compute the :term:`additional hash`:

+-------------------------------+-----------+---------------+
| Field                         | Type      | Size (bytes)  |
+===============================+===========+===============+
| command_id (4 for ``Unlock``) | uint8     |   1           |
+-------------------------------+-----------+---------------+
| message_identifier            | uint64    |   8           |
+-------------------------------+-----------+---------------+
| recipient                     | address   |  20           |
+-------------------------------+-----------+---------------+
| secrethash                    | bytes32   |  32           |
+-------------------------------+-----------+---------------+

.. _withdraw-request-message:

Withdraw Request
--------------------

Message used by the a channel participant node to request the other participant signature on a new increased ``total_withdraw`` value.

Preconditions
^^^^^^^^^^^^^

- The channel for which the withdraw is requested must be open.
- The ``total_withdraw`` value must only ever increase.
- The participant's channel unlocked balance must be larger or equal to ``withdraw_amount``,
  which is calculated using ``new_total_withdraw - previous_total_withdraw``.
- The new total_withdraw value must not cause an underflow or overflow.
- The message must be sent by one of the channel participants.
- The :term:`nonce` is increased by ``1`` with respect to the previous :term:`nonce`.
- The message sender address must be the same as ``participant``.
- The ``signature`` must be from the :term:`sender` of the request.

Fields
^^^^^^

+-------------------------------+---------------+----------------------------------------------------------------+
| Field Name                    | Field Type    |  Description                                                   |
+===============================+===============+================================================================+
|  cmdid                        | one byte      | Value 15 (indicating ``Withdraw Request``)                     |
+-------------------------------+---------------+----------------------------------------------------------------+
|  chain identifier             | uint256       | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  channel identifier           | uint256       | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  token network address        | address       | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  message identifier           | uint64        | An ID used in ``Delivered`` and ``Processed`` acknowledgements |
+-------------------------------+---------------+----------------------------------------------------------------+
|  participant                  | address       | The address of the withdraw requesting node                    |
+-------------------------------+---------------+----------------------------------------------------------------+
|  total_withdraw               | uint256       | The new monotonic ``total_withdraw`` value                     |
+-------------------------------+---------------+----------------------------------------------------------------+
|  expiration                   | uint256       | The block number at which withdraw request is no longer        |
|                               |               | usable on-chain.                                               |
+-------------------------------+---------------+----------------------------------------------------------------+
|  nonce                        | uint64        | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  signature                    | bytes         | Elliptic Curve 256k1 signature                                 |
|                               |               | Signed data:                                                   |
|                               |               | - Chain identifier                                             |
|                               |               | - Message type, 3 for withdraw                                 |
|                               |               | - Channel identifier                                           |
|                               |               | - Participant (address of the withdraw requesting node)        |
|                               |               | - Total withdraw                                               |
|                               |               | - Expiration block number                                      |
+-------------------------------+---------------+----------------------------------------------------------------+

.. _withdraw-confirmation-message:

Withdraw Confirmation
------------------------

Message used by the :ref:`withdraw-request-message` receiver to confirm the request after validating its input.

Preconditions
^^^^^^^^^^^^^

- The channel for which the withdraw is confirmed should be open.
- The received confirmation should map to a previously sent request.
- The block at which withdraw expires should not have been reached.
- The participant's channel balance should still be larger or equal to ``withdraw_amount``.
- The new total_withdraw value should not cause an underflow or overflow.
- The message should be sent by one of the channel participants.
- The :term:`nonce` is increased by ``1`` with respect to the previous :term:`nonce`
- The ``signature`` must be from the :term:`sender` of the request.


Fields
^^^^^^

+-------------------------------+---------------+----------------------------------------------------------------+
| Field Name                    | Field Type    |  Description                                                   |
+===============================+===============+================================================================+
|  cmdid                        | one byte      | Value 16 (indicating ``Withdraw Confirmation``)                |
+-------------------------------+---------------+----------------------------------------------------------------+
|  chain identifier             | uint256       | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  channel identifier           | uint256       | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  token network address        | address       | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  message identifier           | uint64        | An ID used in ``Delivered`` and ``Processed`` acknowledgements |
+-------------------------------+---------------+----------------------------------------------------------------+
|  participant                  | address       | The address of the withdraw requesting node                    |
+-------------------------------+---------------+----------------------------------------------------------------+
|  total_withdraw               | uint256       | The new monotonic ``total_withdraw`` value                     |
+-------------------------------+---------------+----------------------------------------------------------------+
|  expiration                   | uint256       | The block number at which withdraw request is no longer        |
|                               |               | usable on-chain.                                               |
+-------------------------------+---------------+----------------------------------------------------------------+
|  nonce                        | uint64        | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  signature                    | bytes         | Elliptic Curve 256k1 signature                                 |
|                               |               | Signed data: see :ref:`withdraw-request-message`               |
+-------------------------------+---------------+----------------------------------------------------------------+

.. _withdraw-expired-message:

Withdraw Expired
-------------------

Message used by the withdraw-requesting node to inform the partner that the earliest-requested, non-confirmed withdraw has expired.

Preconditions
^^^^^^^^^^^^^

- The channel for which the withdraw is confirmed should be open.
- The sender waits ``expiration_block + NUMBER_OF_CONFIRMATION * 2`` until the message is sent.
- The receiver should only accept the expiration message if the block at which the withdraw expires is confirmed.
- The received withdraw expiration should map to an existing withdraw state.
- The message should be sent by one of the channel participants.
- The :term:`nonce` is increased by ``1`` with respect to the previous :term:`nonce`
- The ``signature`` must be from the :term:`sender` of the request.


Fields
^^^^^^

+-------------------------------+---------------+----------------------------------------------------------------+
| Field Name                    | Field Type    |  Description                                                   |
+===============================+===============+================================================================+
|  cmdid                        | one byte      | Value 17 (indicating ``Withdraw Expired``)                     |
+-------------------------------+---------------+----------------------------------------------------------------+
|  chain identifier             | uint256       | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  channel identifier           | uint256       | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  token network address        | address       | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  message identifier           | uint64        | An ID used in ``Delivered`` and ``Processed`` acknowledgements |
+-------------------------------+---------------+----------------------------------------------------------------+
|  participant                  | address       | The address of the withdraw requesting node                    |
+-------------------------------+---------------+----------------------------------------------------------------+
|  total_withdraw               | uint256       | The new monotonic ``total_withdraw`` value                     |
+-------------------------------+---------------+----------------------------------------------------------------+
|  expiration                   | uint256       | The block number at which withdraw request is no longer        |
|                               |               | usable on-chain.                                               |
+-------------------------------+---------------+----------------------------------------------------------------+
|  nonce                        | uint64        | See :ref:`balance-proof-offchain`                              |
+-------------------------------+---------------+----------------------------------------------------------------+
|  signature                    | bytes         | Elliptic Curve 256k1 signature                                 |
|                               |               | Signed data: see :ref:`withdraw-request-message`               |
+-------------------------------+---------------+----------------------------------------------------------------+

.. _processed-delivered-message:

Processed/Delivered
--------------------

The ``Processed`` and ``Delivered`` message is sent to let other parties in a transfer know that
a message has been processed/received.

Fields
^^^^^^
+-------------------------------+---------------+----------------------------------------------------------------+
| Field Name                    | Field Type    |  Description                                                   |
+===============================+===============+================================================================+
|  cmdid                        | one byte      | Value 0 for ``Processed``, 12 for ``Delivered``                |
+-------------------------------+---------------+----------------------------------------------------------------+
|  pad                          | 3 bytes       | ignored                                                        |
+-------------------------------+---------------+----------------------------------------------------------------+
|  message_identifier           | uint64        | The identifier of the message that has been processed.         |
+-------------------------------+---------------+----------------------------------------------------------------+

References
==========

Locked transfer example
-----------------------

All the examples in the :ref:`locked transfer <locked-transfer-message>` section are made using
three predefined accounts, so that you can replicate the results and verify:

+----+--------------------------------------------+------------------------------------------------------------------+
| No | Address                                    | Private Key                                                      |
+----+--------------------------------------------+------------------------------------------------------------------+
| 1  | 0x540B51eDc5900B8012091cc7c83caf2cb243aa86 | 377261472824796f2c4f6a73753136587b5624777a4537503b39324a227e227d |
+----+--------------------------------------------+------------------------------------------------------------------+
| 2  | 0x811957b07304d335B271feeBF46754696694b09e | 7c250a70410d7245412f6d576b614d275f0b277953433250777323204940540c |
+----+--------------------------------------------+------------------------------------------------------------------+
| 3  | 0x2A915FDA69746F515b46C520eD511401d5CCD5e2 | 2e20593e0b5923294a6d6f3223604433382b782b736e3d63233c2d3a2d357041 |
+----+--------------------------------------------+------------------------------------------------------------------+

The sender of the message should be computable from ``signature`` so is not included in the message.

Message fromat specifications
-----------------------------

All the tables in the fields sections of the message spec should match the
`reference implementation <https://github.com/raiden-network/raiden/tree/develop/raiden/messages>`__.
For example, the packing of a :ref:`locked transfer <locked-transfer-message>` message can be found
`here <https://github.com/raiden-network/raiden/blob/c8cc0adcfd160339ed662d46a5434e0bee1da18e/raiden/messages/transfers.py#L408>`__.
