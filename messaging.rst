Messages
########

Overview
========

Documentation of the messages, their fields and types. For information how the
messages are used refer to :ref:`the mediated transfer example <mediated-transfers>`.

Encoding, signing and transport
===============================

All messages are encoded in a JSON format and sent via the Matrix transport layer.

The encoding used by the transport layer is independent of this specification, as
long as the signatures using the data are encoded in the EVM big endian format.

.. _message-classes:

The messages of the protocol can be divided in three groups with different format/hashing/signing
conventions:

- **Envelope messages**, which contain a balance proof which can be sent to a contract. The
  balance proof in turn contains an :term:`additional hash`, which is a hash over the rest of
  the message. Each envelope message has a defined packed data format to compute the additional
  hash. The format always starts with the 1-byte command id. Envelope messages are:
  ``LockedTransfer``, ``RefundTransfer``, ``Unlock`` and ``LockExpired``.

- The second group is messages that will never result in on-chain transactions, as they contain
  no information that could be forwarded to a contract. There are four types of such messages,
  which we will call **internal messages**: ``SecretRequest``, ``RevealSecret``, ``Processed``, ``Delivered`` and ``WithdrawExpired``. Internal messages have a packed data format in which they are signed.
  The format always starts with the message type's 1-byte command id, but unlike the packing
  format in envelope messages described above, the command id is followed by a padding of three
  zero bytes.

- In addition, there are two withdraw-related messages: ``WithdrawRequest`` and ``WithdrawConfirmation``. They have a signature format starting with the
  :term:`token network address`, the :term:`chain id` and a message type constant, which is an
  unsigned 256-bit integer. The signatures of both messages are used when withdrawing tokens in the ``TokenNetwork`` contract.

  Since ``WithdrawExpired`` signatures are not used on-chain, they don't follow this format but the one for internal messages.

Data Structures
===============

Structures used as part of many protocol messages.

Off-chain Balance Proof
-----------------------

.. _balance-proof-off-chain:

This data structure encapsulates most of the data required by the token network
smart contract and is used by many messages. Each instance of this data
structure determines the state of one participant in a given channel. Messages
into smart contracts contain a shorter form called :ref:`On-chain Balance Proof
<balance-proof-on-chain>`.

Fields
^^^^^^

+--------------------------+------------+--------------------------------------------------------------------------------+
| Field Name               | Field Type |  Description                                                                   |
+==========================+============+================================================================================+
|  chain_id                | uint256    | Chain identifier as defined in EIP155.                                         |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  nonce                   | uint256    | Strictly monotonic value used to order transfers. The nonce starts at 1.       |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  transferred_amount      | uint256    | Total transferred amount in the history of the channel (monotonic value).      |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  locked_amount           | uint256    | Current locked amount.                                                         |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  locksroot               | bytes32    | Hash of the pending locks encoded and concatenated.                            |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  channel_identifier      | uint256    | Channel identifier inside the TokenNetwork contract.                           |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  token_network_address   | address    | Address of the TokenNetwork contract.                                          |
+--------------------------+------------+--------------------------------------------------------------------------------+

- The ``channel_identifier``, ``token_network_address`` and ``chain_id``
  together are a globally unique identifier of the channel, also known as the
  :term:`canonical identifier`, this data is used to pin a balance proof to an
  unique channel to prevent replay.

HashTimeLock
------------

.. _hash-time-lock:

Fields
^^^^^^

+----------------------+-------------+------------------------------------------------------------+
| Field Name           | Field Type  |  Description                                               |
+======================+=============+============================================================+
|  expiration          | uint256     | Block number until which transfer can be settled           |
+----------------------+-------------+------------------------------------------------------------+
|  amount              | uint256     | amount of tokens held by the lock                          |
+----------------------+-------------+------------------------------------------------------------+
|  secrethash          | bytes32     | keccak256 hash of the secret                               |
+----------------------+-------------+------------------------------------------------------------+

Metadata
--------

.. _metadata:

Message metadata that can be used to provide additional information to a transfer.
A route with additional ``routes`` metadata related to the transport discovery has to be provided
from the initiator of the payment.

The ``secret`` of the corresponding LockedTransfer ("LT") can optionally already be sent along by including it to
the LT's ``metadata``. In order to not compromise the security-properties of the LT, the secret has 
to be encrypted in a specific way, so that only the target of the LT can decrypt it.
If the encrypted secret is included in the ``Metadata``, the transfer can't be cancelled by the initiator by not 
revealing the secret via the additionally required :ref:`RevealSecret <reveal-secret-message>` message.

..

The secret should be encrypted with the public key of the LT's target, using the ECIES encryption scheme (look e.g. `here <https://ecies.org/>`__ for reference implementations).
The encrypted data has to be encoded as an object containing secret and additional metadata needed for validation::

        secret = encrypt_ecies(target_publickey, { "secret": <bytes32>, "amount": <uint256>, "payment_identifier": <uint64> })

Note the encoding of the encrypted object's fields is not part of this specification.

When the target receives a transfer with an encrypted secret, it may try to decrypt it::

        { "secret": <bytes32>, "amount": <uint256>, "payment_identifier": <uint64> } = encrypt_ecies(target_privatekey, secret)


The target should only accept the decrypted secret, if the decrypted objects fields comply to the following properties:

- ``secret`` must hash to the LT's ``lock.secrethash``
- ``amount`` must be less than or equal to the received LT's ``lock.amount``
- ``payment_identifier`` must be equal to LT's ``payment_identifier``

If the validation passes, the target uses "secret" as this transfer's secret and skips sending a :ref:`SecretRequest <secret-request-message>` to the initator.
Therefore the target can immediately start the unlock phase by sending a corresponding :ref:`RevealSecret <reveal-secret-message>` to the last mediator in the transfer's route.
Otherwise, the usual ``SecretRequest`` protocol should be performed as a fallback; even in unrecoverable cases like not enough `amount` (meaning mediators took more than initiator expected/were willing to pay), sending the received-by-target payment info back to initiator in ``SecretRequest``'s payload is useful to inform initiator if and why this transfer failed, and allow them to notify user.

The Metadata should be determined by the initiator. All mediators of a transfer should pass it to the next hop of the transfer as-is and
should not modify it even though unknown fields are present. Complying to this behaviour is advertised as the :ref:`capability <transport-capabilities>` `immutableMetada=1`.

Fields
^^^^^^

+----------------------+------------------------------+---------------------------------------------------------+
| Field Name           | Field Type                   | Description                                             |
+======================+==============================+=========================================================+
|  routes              | List[RouteMetadata]          | A list of possible routes and additional route metadata |
+----------------------+------------------------------+---------------------------------------------------------+
|  secret              | Optional[bytes32]            | The LT's secret encrypted with the target's public key  |
+----------------------+------------------------------+---------------------------------------------------------+

RouteMetadata
-------------

.. _route-metadata:

This datastructure describes a single route and the metadata for all nodes included in that route.

Each entry in the ``route`` field list is a Raiden node address (both EIP55-checksum addresses and plain hex encoded addresses with ``0x``-prefix should be compatible). The last of
the addresses in each list must be the target of the transfer, the former the
desired mediators in order.
An initiator can, but does not have to include its own address in the route.

The address metadata is used for transport related information and is essential for a functional
communication between nodes of the route. It does not strictly have to be provided by the initiator,
but without address metadata for all nodes in the route (including the initiator), a functioning transfer is not guaranteed.


Fields
^^^^^^

+----------------------+--------------------------------------------+------------------------------------------------------------+
| Field Name           | Field Type                                 |  Description                                               |
+======================+============================================+============================================================+
| route                | List[Address]                              | A list of the node addresses which comprise one routes     |
+----------------------+--------------------------------------------+------------------------------------------------------------+
| address_metadata     | Optional[Dict[Address, AddressMetadata]]   | A mapping from address (from route) to address-metadata    |
+----------------------+---------------------------------------------------------------------------------------------------------+

AddressMetadata
---------------

.. _address-metadata:


The `AddressMetadata` provides additional information about the transport and node configuration of a participant 
in a route. This information might be mandatory to provide for all participants in the route, when a node 
does not have the possibility to retrieve this information about other nodes by themselves - or when 
the transfer speed should be optimized.

Fields
^^^^^^

+----------------------+----------------+---------------------------------------------------------------------------------------------------+
| Field Name           | Field Type     |  Description                                                                                      |
+======================+================+===================================================================================================+
| user_id              | str            | ``userId`` string for the :ref:`matrix transport authentication <transport-authentication>`       |
+----------------------+----------------+---------------------------------------------------------------------------------------------------+
| capabilities         | str            | the node's capabilities encoded as the Matrix :ref:`avatar_url <transport-capabilities>`          |
+----------------------+----------------+---------------------------------------------------------------------------------------------------+
| displayname          | str            |  ``displayName`` string for the :ref:`matrix transport authentication <transport-authentication>` |
+----------------------+----------------+---------------------------------------------------------------------------------------------------+


.. _address-metadata-recover:

Since the ``displayname`` is the signature of the ``user_id`` of the participant, a participant's public key can be recovered 
from the ``AddressMetadata``::

    ecdsa_recover(sha3_keccak("\x19Ethereum Signed Message:\n || len(user_id) || user_id", displayname)


Messages
========

.. _locked-transfer-message:

Locked Transfer
-----------------

Locked Transfer message
^^^^^^^^^^^^^^^^^^^^^^^^

+-----------------------+--------------+-----------------------------------------------------------+
| Field Name            | Type         |  Description                                              |
+=======================+==============+===========================================================+
|  payment_identifier   | uint64       | An identifier for the payment, chosen by the initiator.   |
+-----------------------+--------------+-----------------------------------------------------------+
|  token                | address      | Address of the token contract                             |
+-----------------------+--------------+-----------------------------------------------------------+
|  recipient            | address      | Destination for this hop of the transfer                  |
+-----------------------+--------------+-----------------------------------------------------------+
|  lock                 | HashTimeLock | A :ref:`lock <hash-time-lock>`                            |
+-----------------------+--------------+-----------------------------------------------------------+
|  target               | address      | Final destination of the payment                          |
+-----------------------+--------------+-----------------------------------------------------------+
|  initiator            | address      | Initiator of the transfer and party who knows the secret  |
+-----------------------+--------------+-----------------------------------------------------------+
|  metadata             | Metadata     | Transfer metadata, used for optimisations and discovery   |
+-----------------------+--------------+-----------------------------------------------------------+
|  message_identifier   | uint64       | An ID for ``Delivered`` and ``Processed`` acknowledgments |
+-----------------------+--------------+-----------------------------------------------------------+

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
| metadata_hash                        | bytes32 |  32         |
+--------------------------------------+---------+-------------+


The ``metadata_hash`` is defined using `JCS <https://datatracker.ietf.org/doc/html/rfc8785>`__, right after JSON parsing (i.e. before any decoding/transformation is performed). It is given as::

    metadata_hash = keccak256(jcs(metadata))

This will be used to generate the data field called ``additional_hash``, which is a required
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
are the same as in the :ref:`off-chain balance proof <balance-proof-off-chain>` datastructure, except
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

.. _locked-transfer-example:

Example
^^^^^^^

Consider an example network of three participants **A**, **B** and **C**, where
**A** has a channel with **B** and **B** has a channel with **C**. **A** wants
to send 10 wei of a token to **C**, using **B** as a mediator. So he will send a
``LockedTransfer`` to **B** (recipient), where **C** is specified as the target.
After receiving the message, **B** sends a new ``LockedTransfer`` message to
**C**.

Our example accounts are:

+------+-----------+--------------------------------------------+------------------------------------------------------------------+
| Name | Role      | Address                                    | Private Key                                                      |
+======+===========+============================================+==================================================================+
|  A   | initiator | 0x540B51eDc5900B8012091cc7c83caf2cb243aa86 | 377261472824796f2c4f6a73753136587b5624777a4537503b39324a227e227d |
+------+-----------+--------------------------------------------+------------------------------------------------------------------+
|  B   | mediator  | 0x811957b07304d335B271feeBF46754696694b09e | 7c250a70410d7245412f6d576b614d275f0b277953433250777323204940540c |
+------+-----------+--------------------------------------------+------------------------------------------------------------------+
|  C   | target    | 0x2A915FDA69746F515b46C520eD511401d5CCD5e2 | 2e20593e0b5923294a6d6f3223604433382b782b736e3d63233c2d3a2d357041 |
+------+-----------+--------------------------------------------+------------------------------------------------------------------+

Our example token is deployed at ``0x05ab44f56e36b2edff7b36801d509ca0067f3f6d``
and the ``TokenNetwork`` contract at
``0x67b0dd5217da3f7028e0c9463fdafbf0181e1e0a``.

The ``LockedTransfer`` message generated by **A** looks like this:

.. code-block:: json

   {
      "chain_id": "337",
      "channel_identifier": "1338",
      "initiator": "0x540b51edc5900b8012091cc7c83caf2cb243aa86",
      "lock": {
         "amount": "10",
         "expiration": "1",
         "secrethash": "0x59cad5948673622c1d64e2322488bf01619f7ff45789741b15a9f782ce9290a8"
      },
      "locked_amount": "10",
      "locksroot": "0x607e890c54e5ba67cd483bedae3ba9da9bf2ef2fbf237b9fb39a723b2296077b",
      "message_identifier": "123456",
      "metadata": {
         "routes": [
            {
                  "route": [
                     "0x811957b07304d335b271feebf46754696694b09e",
                     "0x2a915fda69746f515b46c520ed511401d5ccd5e2"
                  ]
            }
         ]
      },
      "nonce": "1",
      "payment_identifier": "1",
      "recipient": "0x2a915fda69746f515b46c520ed511401d5ccd5e2",
      "signature": "0xa4beb47c2067e196de4cd9d5643d1c7af37caf4ac87de346e10ac27351505d405272f3d68960322bd53d1ea95460e4dd323dbef7c862fa6596444a57732ddb2b1c",
      "target": "0x811957b07304d335b271feebf46754696694b09e",
      "token": "0x05ab44f56e36b2edff7b36801d509ca0067f3f6d",
      "token_network_address": "0x67b0dd5217da3f7028e0c9463fdafbf0181e1e0a",
      "transferred_amount": "0",
      "type": "LockedTransfer"
   }

From this data the following values can be computed::

   message hash: 0xb6ab946232e2b8271c21a921389b8fc8537ebb05e25e7d5eca95e25ce82c7da5
   balance hash: 0x1d9479b298eb0a60edaf962f4cf092465456ad7a0265dfe28a0fe3a2a8ecef4e
   metadata hash: 0x48a094f09ca6f63f59bf2c4f226ebb95c304e06d694586b3bc81b2c627a1db5a
   packed: 0xe82ae5475589b828d3644e1b56546f93cd27d1a400000000000000000000000000000000000000000000000000000000000001510000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000053a1d9479b298eb0a60edaf962f4cf092465456ad7a0265dfe28a0fe3a2a8ecef4e0000000000000000000000000000000000000000000000000000000000000001b6ab946232e2b8271c21a921389b8fc8537ebb05e25e7d5eca95e25ce82c7da5
   signature: 0xa4beb47c2067e196de4cd9d5643d1c7af37caf4ac87de346e10ac27351505d405272f3d68960322bd53d1ea95460e4dd323dbef7c862fa6596444a57732ddb2b1c


.. _refund-transfer-message:

Refund Transfer
---------------

The ``RefundTransfer`` message is very similiar to :ref:`LockedTransfer <locked-transfer-message>`,
with the following differences:

- there is no ``metadata`` field
- when computing the ``additional_hash``, there is thus no ``metadata_hash`` field at the end of the packed data, and
- the command id is 8 instead of 7.

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

The ``LockExpired`` message consists of an :ref:`off-chain balance proof <balance-proof-off-chain>` and the following fields:

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

Fields and signature
^^^^^^^^^^^^^^^^^^^^

``SecretRequest`` is an :ref:`internal message <message-classes>` with the following fields plus a ``signature``
field:

+----------------------+-----------+----------------------------------------------------------+
| Field Name           | Field Type|  Description                                             |
+======================+===========+==========================================================+
|  cmdid               | uint8     | Value 3 (indicating ``Secret Request``),                 |
+----------------------+-----------+----------------------------------------------------------+
|  (padding)           | bytes3    | three zero bytes                                         |
+----------------------+-----------+----------------------------------------------------------+
|  message identifier  | uint64    | An ID used in ``Delivered`` and ``Processed``            |
|                      |           | acknowledgments                                          |
+----------------------+-----------+----------------------------------------------------------+
|  payment_identifier  | uint64    | An identifier for the payment chosen by the initiator    |
+----------------------+-----------+----------------------------------------------------------+
|  lock_secrethash     | bytes32   | Specifies which lock is being unlocked                   |
+----------------------+-----------+----------------------------------------------------------+
|  payment_amount      | uint256   | The amount received by the node once secret is revealed  |
+----------------------+-----------+----------------------------------------------------------+
|  expiration          | uint256   | See `HashTimeLock`_                                      |
+----------------------+-----------+----------------------------------------------------------+

The ``signature`` is obtained by signing the data packed in this format.

Example
^^^^^^^

In the above :ref:`example <locked-transfer-example>` of a mediated transfer, **C** will send a
secret request to **A**. The data to sign would be::

   cmdid = 0x03
   padding = 0x000000
   message_identifier = 8492128289064395926
   payment_identifier = 1
   secrethash = 0xd4683a22c1ce39824d931eedc68ea8fa5259ceb03528b1a22f7075863ef8baf0
   amount = 50
   expiration = 1288153

In packed form::

   0x0300000075da19af88baa4960000000000000001d4683a22c1ce39824d931eedc68ea8fa5259ceb03528b1a22f7075863ef8baf00000000000000000000000000000000000000000000000000000000000000032000000000000000000000000000000000000000000000000000000000013a7d9

Signing this with **C**'s private key yields::

   0xfc3c0cd04b339936bb0001a8aff196b767ed49d8eaa3a57e53121f7077584846390c843bc16a04fab8d6e9f9f80004663e183899441a4f7a4e1509e9cdada7351c


.. _reveal-secret-message:

Reveal Secret
-------------

Message used by the nodes to inform others that the :term:`secret` is known. Used to request an updated :term:`balance proof` with the :term:`transferred amount` increased and the lock removed.

Fields and signature
^^^^^^^^^^^^^^^^^^^^

``RevealSecret`` is an :ref:`internal message <message-classes>` with the following fields plus a ``signature`` field:

+----------------------+-----------+------------------------------------------------------------+
| Field Name           | Field Type|  Description                                               |
+======================+===========+============================================================+
|  cmdid               | uint8     | Value 11 (indicating ``Reveal Secret``)                    |
+----------------------+-----------+------------------------------------------------------------+
|  (padding)           | bytes3    | three zero bytes.                                          |
+----------------------+-----------+------------------------------------------------------------+
|  message_identifier  | uint64    | An ID use in ``Delivered`` and ``Processed``               |
|                      |           | acknowledgments                                            |
+----------------------+-----------+------------------------------------------------------------+
|  lock_secret         | bytes32   | The secret that unlocks the lock                           |
+----------------------+-----------+------------------------------------------------------------+

The ``signature`` is obtained by signing the data packed in this format.

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

The ``Unlock`` message consists of an :ref:`off-chain balance proof <balance-proof-off-chain>` and the following fields:

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

This message is used by a channel participant node to request the other participant's signature on a new increased ``total_withdraw`` value.

Preconditions
^^^^^^^^^^^^^

These preconditions must be validated when a ``WithdrawRequest`` is received

.. TODO (might be out of date - to be updated)

- The channel for which the withdraw is requested must be open.
- The ``total_withdraw`` value must only ever increase.
- The participant's channel unlocked balance must be larger or equal to ``withdraw_amount``, which is calculated using ``new_total_withdraw - previous_total_withdraw``.
- The new total_withdraw value must not cause an underflow or overflow.
- The message must be sent by one of the channel participants.
- The :term:`nonce` is increased by ``1`` with respect to the previous :term:`nonce`.
- The message sender address must be the same as ``participant``.
- The ``signature`` must be from the :term:`sender` of the request.

Fields and signature
^^^^^^^^^^^^^^^^^^^^

The table below specifies the data fields of a ``WithdrawRequest``.
Column DTS (Data to sign) marks the data that needs to be signed on


+-------------------------------+-----+---------------+----------------------------------------------------------------+
| Field Name                    | DTS | Field Type    |  Description                                                   |
+===============================+=====+===============+================================================================+
|  type                         | no  | str           | Message type                                                   |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  nonce                        | no  | uint256       | Monotonically increasing number to order messages              |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  signature                    | no  | uint256       | Sender's signature of data to be signed                        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  message identifier           | no  | uint256       | An ID used in ``Delivered`` and ``Processed`` acknowledgements |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  coop settle                  | no  | optional(bool)| If true, the withdraw is meant to initiate a coop settle       |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  token network address        | yes | address       | Part of the :term:`canonical identifier` of the channel        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  chain identifier             | yes | uint256       | Part of the :term:`canonical identifier` of the channel        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  message type                 | yes | uint256       | 3 for withdraw messages                                        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  channel identifier           | yes | uint256       | Part of the :term:`canonical identifier` of the channel        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  participant                  | yes | address       | The address of the withdraw requesting node                    |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  total withdraw               | yes | uint256       | The new monotonic ``total_withdraw`` value                     |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  expiration                   | yes | uint256       | The block number at which withdraw request is no longer        |
|                               |     |               | usable on-chain.                                               |
+-------------------------------+-----+---------------+----------------------------------------------------------------+

.. _withdraw-confirmation-message:

Withdraw Confirmation
------------------------

Message used by the :ref:`withdraw-request-message` receiver to confirm the request after validating its input.

Preconditions
^^^^^^^^^^^^^
These preconditions must be validated when a ``WithdrawRequest`` is received

.. TODO (might be out of date - to be updated)

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


The table below specifies the data fields of a ``WithdrawConfirmation``. The signatures of both channel participants
are needed for the call to the smart contract's ``setTotalWithdraw`` function.
Column DTS (Data to sign) marks the data that needs to be signed on


+-------------------------------+-----+---------------+----------------------------------------------------------------+
| Field Name                    | DTS | Field Type    |  Description                                                   |
+===============================+=====+===============+================================================================+
|  type                         | no  | str           | Message type                                                   |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  nonce                        | no  | uint256       | Monotonically increasing number to order messages              |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  signature                    | no  | uint256       | Sender's signature of data to be signed                        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  message identifier           | no  | uint256       | An ID used in ``Delivered`` and ``Processed`` acknowledgements |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  token network address        | yes | address       | Part of the :term:`canonical identifier` of the channel        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  chain identifier             | yes | uint256       | Part of the :term:`canonical identifier` of the channel        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  message type                 | yes | uint256       | 3 for withdraw messages                                        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  channel identifier           | yes | uint256       | Part of the :term:`canonical identifier` of the channel        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  participant                  | yes | address       | The address of the withdraw requesting node                    |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  total withdraw               | yes | uint256       | The new monotonic ``total_withdraw`` value                     |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  expiration                   | yes | uint256       | The block number at which withdraw request is no longer        |
|                               |     |               | usable on-chain.                                               |
+-------------------------------+-----+---------------+----------------------------------------------------------------+

.. _withdraw-expired-message:

Withdraw Expired
-------------------

This message is used by the withdraw-requesting node to inform the partner that the
earliest-requested, non-confirmed withdraw has expired.

Preconditions
^^^^^^^^^^^^^
These preconditions must be validated when a ``WithdrawRequest`` is received

.. TODO (might be out of date - to be updated)

- The channel for which the withdraw is confirmed should be open.
- The sender waits ``expiration_block + NUMBER_OF_CONFIRMATION * 2`` until the message is sent.
- The receiver should only accept the expiration message if the block at which the withdraw expires is confirmed.
- The received withdraw expiration should map to an existing withdraw state.
- The message should be sent by one of the channel participants.
- The :term:`nonce` is increased by ``1`` with respect to the previous :term:`nonce`
- The ``signature`` must be from the :term:`sender` of the request.


Fields
^^^^^^

The table below specifies the format in which ``WithdrawExpired`` is packed to compute its
signature. Column DTS (Data to sign) marks the data that needs to be signed on

+-------------------------------+-----+---------------+----------------------------------------------------------------+
| Field Name                    | DTS | Field Type    |  Description                                                   |
+===============================+=====+===============+================================================================+
|  type (cmdid)                 | no  | uint8         | Value 17 (indicating ``Withdraw Expired``)                     |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  signature                    | no  | uint256       | Sender's signature of data to be signed                        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  nonce                        | yes | uint256       | Monotonically increasing number to order messages              |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  message identifier           | yes | uint256       | An ID used in ``Delivered`` and ``Processed`` acknowledgements |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  token network address        | yes | address       | Part of the :term:`canonical identifier` of the channel        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  chain identifier             | yes | uint256       | Part of the :term:`canonical identifier` of the channel        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  message type                 | yes | uint256       | 3 for withdraw messages                                        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  channel identifier           | yes | uint256       | Part of the :term:`canonical identifier` of the channel        |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  participant                  | yes | address       | The address of the withdraw requesting node                    |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  total withdraw               | yes | uint256       | The new monotonic ``total_withdraw`` value                     |
+-------------------------------+-----+---------------+----------------------------------------------------------------+
|  expiration                   | yes | uint256       | The block number at which withdraw request is no longer        |
|                               |     |               | usable on-chain.                                               |
+-------------------------------+-----+---------------+----------------------------------------------------------------+

.. _processed-delivered-message:

Processed/Delivered
--------------------

The ``Processed`` and ``Delivered`` messages are sent to let other parties in a transfer know that
a message has been processed/received.

Fields and signature
^^^^^^^^^^^^^^^^^^^^

``Processed`` and ``Delivered`` are :ref:`internal messages <message-classes>` with the following
fields plus a ``signature``:

+-------------------------------+-----------+----------------------------------------------------+
| Field Name                    | Field Type|  Description                                       |
+===============================+===========+====================================================+
|  cmdid                        | uint8     | Value 0 for ``Processed`` or 12 for ``Delivered``  |
+-------------------------------+-----------+----------------------------------------------------+
|  message_identifier           | uint64    | The identifier of the processed/delivered message. |
+-------------------------------+-----------+----------------------------------------------------+

The ``signature`` is obtained by signing the data packed in this format.


References
==========

Message fromat specifications
-----------------------------

All the tables in the fields sections of the message spec should match the
`reference implementation <https://github.com/raiden-network/raiden/tree/develop/raiden/messages>`__.
For example, the packing of a :ref:`locked transfer <locked-transfer-message>` message can be found
`here <https://github.com/raiden-network/raiden/blob/c8cc0adcfd160339ed662d46a5434e0bee1da18e/raiden/messages/transfers.py#L408>`__.
