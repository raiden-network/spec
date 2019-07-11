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
| token_network_identifier | address    | Address of the TokenNetwork contract                                           |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  channel_identifier      | uint256    | Channel identifier inside the TokenNetwork contract                            |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  additional_hash         | bytes32    | Hash of the message                                                            |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  signature               | bytes      | Elliptic Curve 256k1 signature on the above data                               |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  chain_id                | uint256    | Chain identifier as defined in EIP155                                          |
+--------------------------+------------+--------------------------------------------------------------------------------+


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

A LockedTransfer is a message used to reserve tokens for a mediated transfer.

``LockedTransfer`` message
^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``LockedTransfer`` is encoded as a JSON message and sent via our Matrix transport layer. The
message is always sent to the next mediating node, altered and (the information) forwarded until ``target`` is reached.

In order to create a valid, signed JSON message,

1. ``message_structure`` is packed
2. Packed message is hashed to create the ``additional_hash``
3. ``balance_data`` is created, packed and hashed to get ``balance_hash``
4. ``additional_hash`` and ``balance_hash`` is used to create the ``balance_proof``
5. ``balance_proof`` is packed and the signed to get the signature, that equals signed, packed ``balance_proof``

Let's assume that there is a network:

- [A] `0x540B51eDc5900B8012091cc7c83caf2cb243aa86`  
- [B] `0x2A915FDA69746F515b46C520eD511401d5CCD5e2`
- [C] `0x811957b07304d335B271feeBF46754696694b09e`

Where **A** has a channel with **B** and **B** has a channel with **C**.

A <---> B <---> C

If **A** wants to send 10 wei of a Token(0xc778417e063141139fce010982780140aa0cd5ab) to **C** he has to first
send a LockedTransfer to **B** (``recipient``) where **C** is specified as the ``target``. After receiving the message,
**B** has to send a new LockedTransfer message to **C**.

The message that will be sent from A -> B over the matrix transport would look like this.

.. code-block:: json

    {
        "type": "LockedTransfer",
        "chain_id": 337,
        "message_identifier": 123456,
        "payment_identifier": 1,
        "nonce": 1,
        "token_network_address": "0xe82ae5475589b828D3644e1B56546F93cD27d1a4",
        "token": "0xc778417E063141139Fce010982780140Aa0cD5Ab",
        "channel_identifier": 1338,
        "transferred_amount": 0,
        "locked_amount": 10,
        "recipient": "0x2A915FDA69746F515b46C520eD511401d5CCD5e2",
        "locksroot": "0x607e890c54e5ba67cd483bedae3ba9da9bf2ef2fbf237b9fb39a723b2296077b",
        "lock": {
            "type": "Lock",
            "amount": 10,
            "expiration": 1,
            "secrethash": "0x59cad5948673622c1d64e2322488bf01619f7ff45789741b15a9f782ce9290a8"
        },
        "target": "0x811957b07304d335B271feeBF46754696694b09e",
        "initiator": "0x540B51eDc5900B8012091cc7c83caf2cb243aa86",
        "fee": 0,
        "signature": "0x33b336f151f9790f40287655bd412a043be83a03d0136ef5e002229dd04d5b4c2b505b65911251b2a2eb428403de394064bdae0cd8d4a3bb47a10b1a0d924b921c"
    }

1. Message Structure
^^^^^^^^^^^^^^^^^^^^

We define the following structure of message fields ``message_structure`` of LockedTransfer. There is a function
``pack(message)`` that takes the ``message_structure`` and returns a byte array. Out of this ``message_structure`` the
necessary JSON can be created.


The message format corresponds to the packed format of LockedTransfer (INSERT LINK TO FUNCTION -> AUGUSTO).

+-----------------------+----------------------+------------------------------------------------------------+
| Field Name            | Size (Type)          |  Description                                               |
+=======================+======================+============================================================+
|  command_id           | 1 Byte               | Value 7 indicating ``LockedTransfer``                      |
+-----------------------+----------------------+------------------------------------------------------------+
|  pad                  | 3 Bytes              | Contents ignored                                           |
+-----------------------+----------------------+------------------------------------------------------------+
|  nonce                | 8 Bytes (uint64)     | See `Offchain Balance Proof`_                              |
+-----------------------+----------------------+------------------------------------------------------------+
|  chain_id             | 32 Bytes (uint256)   | See `Offchain Balance Proof`_                              |
+-----------------------+----------------------+------------------------------------------------------------+
|  message_identifier   | 8 Bytes (uint64)     | An ID for ``Delivered`` and ``Processed`` acknowledgments  |
+-----------------------+----------------------+------------------------------------------------------------+
|  payment_identifier   | 8 Bytes (uint64)     | An identifier for the payment that the initiator specifies |
+-----------------------+----------------------+------------------------------------------------------------+
|  expiration           | 32 Bytes (uint256)   | See `HashTimeLock`_                                        |
+-----------------------+----------------------+------------------------------------------------------------+
|  token_network_address| 20 Bytes (address)   | See ``token_network_id`` in `Offchain Balance Proof`_      |
+-----------------------+----------------------+------------------------------------------------------------+
|  token                | 20 Bytes (address)   | Address of the token contract                              |
+-----------------------+----------------------+------------------------------------------------------------+
|  channel_identifier   | 32 Bytes (uint256)   | See `Offchain Balance Proof`_                              |
+-----------------------+----------------------+------------------------------------------------------------+
|  recipient            | 20 Bytes (address)   | Destination for this hop of the transfer                   |
+-----------------------+----------------------+------------------------------------------------------------+
|  target               | 20 Bytes (address)   | Final destination of the payment                           |
+-----------------------+----------------------+------------------------------------------------------------+
|  initiator            | 20 Bytes (address)   | Initiator of the transfer and party who knows the secret   |
+-----------------------+----------------------+------------------------------------------------------------+
|  locksroot            | 32 Bytes (hash)      | See `Offchain Balance Proof`_                              |
+-----------------------+----------------------+------------------------------------------------------------+
|  secrethash           | 32 Bytes (hash)      | See `HashTimeLock`_                                        |
+-----------------------+----------------------+------------------------------------------------------------+
|  transferred_amount   | 32 Bytes (uint256)   | See `Offchain Balance Proof`_                              |
+-----------------------+----------------------+------------------------------------------------------------+
|  locked_amount        | 32 Bytes (uint256)   | See `Offchain Balance Proof`_                              |
+-----------------------+----------------------+------------------------------------------------------------+
|  amount               | 32 Bytes (uint256)   | Transferred amount including fees. See `HashTimeLock`_     |
+-----------------------+----------------------+------------------------------------------------------------+
|  fee                  | 32 Bytes (uint256)   | Total available fee for remaining mediators                |
+-----------------------+----------------------+------------------------------------------------------------+

2. Additional Hash
^^^^^^^^^^^^^^^^^^

We will build our ``message_structure`` using the data in the JSON message that was presented above.
This will be used to generate the a field called ``additional_hash``. 

The field is a required part of the process to create the message signature.

+-----------------------+-----------------------------------------------------------------------------------+
| Field                 | Data                                                                              |
+-----------------------+-----------------------------------------------------------------------------------+
| command_id            | 7                                                                                 |
+-----------------------+-----------------------------------------------------------------------------------+
| pad                   | three zero bytes                                                                  |
+-----------------------+-----------------------------------------------------------------------------------+
| nonce                 | 1                                                                                 |
+-----------------------+-----------------------------------------------------------------------------------+
| chain_id              | 337                                                                               |
+-----------------------+-----------------------------------------------------------------------------------+
| message_identifier    | 123456                                                                            |
+-----------------------+-----------------------------------------------------------------------------------+
| payment_identifier    | 1                                                                                 |
+-----------------------+-----------------------------------------------------------------------------------+
| expiration            | 1                                                                                 |
+-----------------------+-----------------------------------------------------------------------------------+
| token_network_address | 0xe82ae5475589b828D3644e1B56546F93cD27d1a4                                        |
+-----------------------+-----------------------------------------------------------------------------------+
| token                 | 0xc778417E063141139Fce010982780140Aa0cD5Ab                                        |
+-----------------------+-----------------------------------------------------------------------------------+
| channel_identifier    | 1338                                                                              |
+-----------------------+-----------------------------------------------------------------------------------+
| recipient             | 0x811957b07304d335B271feeBF46754696694b09e                                        |
+-----------------------+-----------------------------------------------------------------------------------+
| target                | 0x811957b07304d335B271feeBF46754696694b09e                                        |
+-----------------------+-----------------------------------------------------------------------------------+
| initiator             | 0x540B51eDc5900B8012091cc7c83caf2cb243aa86                                        |
+-----------------------+-----------------------------------------------------------------------------------+
| locksroot             | 0x607e890c54e5ba67cd483bedae3ba9da9bf2ef2fbf237b9fb39a723b2296077b                |
+-----------------------+-----------------------------------------------------------------------------------+
| secrethash            | 0x59cad5948673622c1d64e2322488bf01619f7ff45789741b15a9f782ce9290a8                |
+-----------------------+-----------------------------------------------------------------------------------+
| transferred_amount    | 0                                                                                 |
+-----------------------+-----------------------------------------------------------------------------------+
| locked_amount         | 10                                                                                |
+-----------------------+-----------------------------------------------------------------------------------+
| amount                | 10                                                                                |
+-----------------------+-----------------------------------------------------------------------------------+
| fee                   | 0                                                                                 |
+-----------------------+-----------------------------------------------------------------------------------+

To generate the ``additional_hash`` we can start by packing the ``message_structure`` data.

.. code-block:: 

    packed_message_data = pack(message_structure)

    0x0700000000000000000000010000000000000000000000000000000000000000000000000000000000000151000000000001e24000000000000000010000000000000000000000000000000000000000000000000000000000000001e82ae5475589b828d3644e1b56546f93cd27d1a4c778417e063141139fce010982780140aa0cd5ab000000000000000000000000000000000000000000000000000000000000053a2a915fda69746f515b46c520ed511401d5ccd5e2811957b07304d335b271feebf46754696694b09e540b51edc5900b8012091cc7c83caf2cb243aa86607e890c54e5ba67cd483bedae3ba9da9bf2ef2fbf237b9fb39a723b2296077b59cad5948673622c1d64e2322488bf01619f7ff45789741b15a9f782ce9290a80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000

After creating the packed form of the data we can use ``keccak256`` to create the ``additional_hash``. 

.. code-block:: 

    additional_hash = keccak256(packed_message_data)

    0x219f8ba12d6dd5c4076af98d9b608ab10351294d4433fde115fbd23243b48306

3. Balance Hash
^^^^^^^^^^^^^^^

Before we generate the message signature another hash need to be created. This is the ``balance_hash`` that is 
generated using the ``balance_data``:

You can see the structure of the balance_data below

+-----------------------+----------------------------------------------------------------------+
| Field                 | Data                                                                 |
+-----------------------+----------------------------------------------------------------------+
| transferred_amount    | 0                                                                    |
+-----------------------+----------------------------------------------------------------------+
| locked_amount         | 10                                                                   |
+-----------------------+----------------------------------------------------------------------+
| locksroot             | 0x607e890c54e5ba67cd483bedae3ba9da9bf2ef2fbf237b9fb39a723b2296077b   |
+-----------------------+----------------------------------------------------------------------+

In order to create the `balance_hash` you first need to pack the `balance_data`:

.. code-block:: 

    packed_balance = pack(balance_data)

    0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a607e890c54e5ba67cd483bedae3ba9da9bf2ef2fbf237b9fb39a723b2296077b

Add then use the `keccak256` hash function on the packed form.

.. code-block::

    balance_hash = keccak256(packed_balance)

    0x1d9479b298eb0a60edaf962f4cf092465456ad7a0265dfe28a0fe3a2a8ecef4e


4. Balance Proof
^^^^^^^^^^^^^^^^

The signature of a ``LockedTransfer`` is creating by signing the packed form of a ``balance_proof``.

A `balance_proof` contains the following fields:

+-----------------------+----------------------------------------------------------------------+
| Field                 | Data                                                                 |
+-----------------------+----------------------------------------------------------------------+
| token_network_address | 0xe82ae5475589b828d3644e1b56546f93cd27d1a4                           |
+-----------------------+----------------------------------------------------------------------+
| chain_id              | 337                                                                  |
+-----------------------+----------------------------------------------------------------------+
| msg_type              | 1                                                                    |
+-----------------------+----------------------------------------------------------------------+
| channel_identifier    | 1338                                                                 |
+-----------------------+----------------------------------------------------------------------+
| balance_hash          | 0x1d9479b298eb0a60edaf962f4cf092465456ad7a0265dfe28a0fe3a2a8ecef4e   |
+-----------------------+----------------------------------------------------------------------+
| nonce                 | 1                                                                    |
+-----------------------+----------------------------------------------------------------------+
| additional_hash       | 0x219f8ba12d6dd5c4076af98d9b608ab10351294d4433fde115fbd23243b48306   |
+-----------------------+----------------------------------------------------------------------+

The ``additional_hash`` and the ``balance_hash`` were calculated in the previous steps and we can now use them in the
``balance_proof``.

In order to create the ``singature` of the ``LockedTransfer`` we first need to pack the ``balance_proof``:

.. code-block:: 

    packed_balance_proof = pack(balance_proof)

    0xe82ae5475589b828d3644e1b56546f93cd27d1a400000000000000000000000000000000000000000000000000000000000001510000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000053a1d9479b298eb0a60edaf962f4cf092465456ad7a0265dfe28a0fe3a2a8ecef4e0000000000000000000000000000000000000000000000000000000000000001219f8ba12d6dd5c4076af98d9b608ab10351294d4433fde115fbd23243b48306

5. Signature
^^^^^^^^^^^^

After getting the packed form of the ``balance_proof`` we have to sign it in order to generate the message signature.

.. code-block:: 

    signature = eth_sign(privkey=private_key, data=packed_balance_proof)

    0x33b336f151f9790f40287655bd412a043be83a03d0136ef5e002229dd04d5b4c2b505b65911251b2a2eb428403de394064bdae0cd8d4a3bb47a10b1a0d924b921c

Preconditions for LockedTransfer
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

For a ``LockedTransfer`` to be considered valid there are the following conditions. The message will be rejected otherwise:

- (PC1) :term:`nonce` is increased by ``1`` with respect to the previous balance changing message in that direction, e.g.
:term:`balance proof` (RECHECK WITH AUGUSTO AND  SPECIFY BETTER)
- (PC2) :term:`chain id`, :term:`token network` address, and :term:`channel identifier` refers to an existing and open channel
- (PC3) :term:`expiration` must be greater than the current block number
- (PC4) :term:`locksroot` must be equal to the hash of a new list of all currently pending locks, always the latest one
appended at last position
- (PC5) :term:`transferred amount` must not change compared to the last :term:`balance proof`
- (PC6) :term:`locked amount` must increase by exactly :term:`amount` [#PC6]_
- (PC7) :term:`amount` must be smaller than the current :term:`capacity` [#PC7]_

.. [#PC6] If the :term:`locked amount` is increased by more, then funds may get locked in the channel. If the
``locked_amount`` is increased by less, then the recipient will reject the message as it may mean it received the funds
with an on-chain unlock. The initiator will stipulate the fees based on the available routes and incorporate it in the
lock's amount. Note that with permissive routing it is not possible to predetermine the exact `fee` amount, as the
initiator does not know which nodes are available, thus an estimated value is used..
.. [#PC7] If the amount is higher then the recipient will reject it, as it means he will be spending money it does not
own.

Example Data
""""""""""""

All the examples are made using three predifined accounts, so that you can replicate the results and verify:

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

.. _secret-request-message:

Secret Request
--------------

Message used to request the :term:`secret` that unlocks a lock. Sent by the payment :term:`target` to the :term:`initiator` once a :ref:`locked transfer <locked-transfer-message>` is received.

Invariants
^^^^^^^^^^

- The :term:`initiator` must have initiated a payment to the :term:`target` with the same ``payment_identifier``, ``lock_secrethash``, ``payment_amount`` and ``expiration``.
- The :term:`target` must have received a :term:`Locked Transfer` for the payment.
- The ``signature`` must be from the :term:`target`.

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

.. _reveal-secret-message:

Reveal Secret
-------------

Message used by the nodes to inform others that the :term:`secret` is known. Used to request an updated :term:`balance proof` with the :term:`transferred amount` increased and the lock removed.

Fields
^^^^^^

This should match `the encoding implementation <https://github.com/raiden-network/raiden/blob/8ead49a8ee688691c98828a879d93f822f60ae53/raiden/encoding/messages.py#L132>`__.

+----------------------+---------------+------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                               |
+======================+===============+============================================================+
|  cmdid               | one byte      | Value 11 (indicating ``Reveal Secret``)                    |
+----------------------+---------------+------------------------------------------------------------+
|  pad                 | three bytes   | Ignored                                                    |
+----------------------+---------------+------------------------------------------------------------+
|  message identifier  | uint64        | An ID use in ``Delivered`` and ``Processed``               |
|                      |               | acknowledgments                                            |
+----------------------+---------------+------------------------------------------------------------+
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

- The :term:`balance proof` must contain the hash of the new list of pending locks, from which the unlocked lock has been removed.
- This message is only sent after the corresponding partner has sent a :ref:`Reveal Secret message <reveal-secret-message>`.
- The :term:`nonce` is increased by ``1`` with respect to the previous :term:`balance proof`
- The :term:`locked amount` must decrease and the :term:`transferred amount` must increase by the amount held in the unlocked lock.


Fields
^^^^^^

This should match `the Secret message in encoding/messages file <https://github.com/raiden-network/raiden/blob/a19a6c853b55f13725f2545c77b0475cbcc86807/raiden/encoding/messages.py#L113>`_.

+----------------------+------------------------+------------------------------------------------------------+
| Field Name           | Field Type             |  Description                                               |
+======================+========================+============================================================+
|  command id          | one byte               | Value 4 indicating Unlock                                  |
+----------------------+------------------------+------------------------------------------------------------+
|  padding             | three bytes            | Ignored                                                    |
+----------------------+------------------------+------------------------------------------------------------+
|  chain identifier    | uint256                | See :ref:`balance-proof-offchain`                          |
+----------------------+------------------------+------------------------------------------------------------+
|  message identifier  | uint64                 | An ID used in ``Delivered`` and ``Processed``              |
|                      |                        | acknowledgments                                            |
+----------------------+------------------------+------------------------------------------------------------+
|  payment identifier  | uint64                 | An identifier for the :term:`Payment` chosen by the        |
|                      |                        | :term:`Initiator`                                          |
+----------------------+------------------------+------------------------------------------------------------+
| token network        | address                | See :ref:`balance-proof-offchain`                          |
| identifier           |                        |                                                            |
+----------------------+------------------------+------------------------------------------------------------+
|  lock_secret         | bytes32                | The secret that unlocked the lock                          |
+----------------------+------------------------+------------------------------------------------------------+
|  nonce               | uint64                 | See :ref:`balance-proof-offchain`                          |
+----------------------+------------------------+------------------------------------------------------------+
|  channel identifier  | uint256                | See :ref:`balance-proof-offchain`                          |
+----------------------+------------------------+------------------------------------------------------------+
|  transferred amount  | uint256                | See :ref:`balance-proof-offchain`                          |
+----------------------+------------------------+------------------------------------------------------------+
|  locked amount       | uint256                | See :ref:`balance-proof-offchain`                          |
+----------------------+------------------------+------------------------------------------------------------+
|  lockedsroot         | bytes32                | See :ref:`balance-proof-offchain`                          |
+----------------------+------------------------+------------------------------------------------------------+
|  signature           | bytes                  | See :ref:`balance-proof-offchain`. Note ``additional_hash``|
|                      |                        | is the hash of the whole message                           |
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

- ``N + 1`` :term:`locked transfer` or :term:`refund transfer` messages
- ``1`` :term:`secret request`
- ``N + 2`` :term:`reveal secret`
- ``N + 1`` :term:`unlock`
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
- Finally Alice sends an ``Unlock`` message to Bob. This acts also as a synchronization message informing Bob that the lock will be removed from the list of pending locks and that the transferred_amount and locksroot values are updated.

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

The number of simultaneously pending transfers per channel is limited. The client will not initiate, mediate or accept a further pending transfer if the limit is reached. This is to avoid the risk of not being able to unlock the transfers, as the gas cost for this operation grows with the number of the pending locks and thus the number of pending transfers.

The limit is currently set to 160. It is a rounded value that ensures the gas cost of unlocking will be less than 40% of Ethereum's traditional pi-million (3141592) block gas limit.
