Raiden Network Smart Contracts Specification
############################################

Overview
========

This is the specification document for the Solidity smart contracts required for building the Raiden Network. All functions, their signatures, and their semantics.


General Requirements
====================

Secure
------

- A participant may never receive more tokens than it was paid
- The participants don’t need to be anonymous
- The amount transferred don’t need to be unknown
- The channel balances don’t need to be unknown

Fast
----

- It must provide means to do faster transfers (off-chain transaction)

Cheap
-----

- Gas usage optimization is a target

Project Requirements
====================

- The system must work with the most popular token standards (e.g. ERC20).
- There must not be a way for a single party to hold other user’s tokens hostage, therefore the system must hold in escrow any tokens that are deposited in a channel.
- There must be no way for a party to steal funds.
- The proof must be non malleable.
- Losing funds as a penalty is not considered stealing, but must be clearly documented.
- The system must support smart locks.
- Determine if and how different versions of the smart contracts should interoperate.
- Determine if and how channels should be upgraded.

Data structures
===============

.. _balance-proof-message:

Balance Proof
-------------

Data required by the smart contracts to update the payment channel end of the participant that signed the balance proof.
The signature must be valid and is defined as:

::

    ecdsa_recoverable(privkey, keccak256(balance_hash || nonce || additional_hash || channel_identifier || token_network_address || chain_id)

Fields
^^^^^^

+------------------------+------------+--------------------------------------------------------------------------------+
| Field Name             | Field Type |  Description                                                                   |
+========================+============+================================================================================+
|  balance_hash          | bytes32    | Balance data hash                                                              |
+------------------------+------------+--------------------------------------------------------------------------------+
|  nonce                 | uint256    | Strictly monotonic value used to order transfers. The nonce starts at 1        |
+------------------------+------------+--------------------------------------------------------------------------------+
|  additional_hash       | bytes32    | Hash of additional data used on the application layer, e.g.: payment metadata  |
+------------------------+------------+--------------------------------------------------------------------------------+
|  channel_identifier    | uint256    | Channel identifier inside the TokenNetwork contract                            |
+------------------------+------------+--------------------------------------------------------------------------------+
| token_network_address  | address    | Address of the TokenNetwork contract                                           |
+------------------------+------------+--------------------------------------------------------------------------------+
| chain_id               | uint256    | Chain identifier as defined in EIP155                                          |
+------------------------+------------+--------------------------------------------------------------------------------+
|  signature             | bytes      | Elliptic Curve 256k1 signature on the above data                               |
+------------------------+------------+--------------------------------------------------------------------------------+

Balance Data Hash
^^^^^^^^^^^^^^^^^

``balance_hash`` = ``keccak256(transferred_amount || locked_amount || locksroot)``

+------------------------+------------+---------------------------------------------------------------------------------------+
| Field Name             | Field Type |  Description                                                                          |
+========================+============+=======================================================================================+
|  transferred_amount    | uint256    | Monotonically increasing amount of tokens transferred by a channel participant        |
+------------------------+------------+---------------------------------------------------------------------------------------+
|  locked_amount         | uint256    | Total amount of tokens locked in pending transfers                                    |
+------------------------+------------+---------------------------------------------------------------------------------------+
|  locksroot             | bytes32    | Root of merkle tree of all pending lock lockhashes                                    |
+------------------------+------------+---------------------------------------------------------------------------------------+

.. _withdraw-proof-message:

Withdraw Proof
--------------

Data required by the smart contracts to allow a user to withdraw funds from a channel without closing it. It contains the withdraw message data and signatures from both participants on the withdraw message.

Signatures must be valid and is defined as:

::

    ecdsa_recoverable(privkey, sha3_keccak(participant_address || total_withdraw || channel_identifier || token_network_address || chain_id)

Invariants
^^^^^^^^^^

- ``total_withdraw`` is strictly monotonically increasing. This is required for protection against replay attacks with old withdraw proofs.

Fields
^^^^^^

+------------------------+------------+--------------------------------------------------------------------------------+
| Field Name             | Field Type |  Description                                                                   |
+========================+============+================================================================================+
|  participant_address   | address    | Channel participant, who withdraws the tokens                                  |
+------------------------+------------+--------------------------------------------------------------------------------+
|  total_withdraw        | uint256    | Total amount of tokens that participant_address has withdrawn from the channel |
+------------------------+------------+--------------------------------------------------------------------------------+
|  channel_identifier    | uint256    | Channel identifier inside the TokenNetwork contract                            |
+------------------------+------------+--------------------------------------------------------------------------------+
| token_network_address  | address    | Address of the TokenNetwork contract                                           |
+------------------------+------------+--------------------------------------------------------------------------------+
| chain_id               | uint256    | Chain identifier as defined in EIP155                                          |
+------------------------+------------+--------------------------------------------------------------------------------+
|  participant_signature | bytes      | Elliptic Curve 256k1 signature of the participant on the above data            |
+------------------------+------------+--------------------------------------------------------------------------------+
|  partner_signature     | bytes      | Elliptic Curve 256k1 signature of the partner on the above data                |
+------------------------+------------+--------------------------------------------------------------------------------+

.. _cooperative-settle-proof-message:

Cooperative Settle Proof
------------------------

Data required by the smart contracts to allow the two channel participants to close and settle the channel instantly, in one transaction. It contains the cooperative settle message data and signatures from both participants on the cooperative settle message.
Signatures must be valid and is defined as:

::

    ecdsa_recoverable(privkey, sha3_keccak(participant1_address || participant1_balance || participant2_address || participant2_balance || channel_identifier || token_network_address || chain_id)

Fields
^^^^^^

+------------------------+------------+--------------------------------------------------------------------------------+
| Field Name             | Field Type |  Description                                                                   |
+========================+============+================================================================================+
|  participant1_address  | address    | One of the channel participants                                                |
+------------------------+------------+--------------------------------------------------------------------------------+
|  participant1_balance  | uint256    | Amount of tokens that participant1_address will receive after settling         |
+------------------------+------------+--------------------------------------------------------------------------------+
|  participant2_address  | address    | The other channel participant                                                  |
+------------------------+------------+--------------------------------------------------------------------------------+
|  participant2_balance  | uint256    | Amount of tokens that participant2_address will receive after settling         |
+------------------------+------------+--------------------------------------------------------------------------------+
|  channel_identifier    | uint256    | Channel identifier inside the TokenNetwork contract                            |
+------------------------+------------+--------------------------------------------------------------------------------+
| token_network_address  | address    | Address of the TokenNetwork contract                                           |
+------------------------+------------+--------------------------------------------------------------------------------+
| chain_id               | uint256    | Chain identifier as defined in EIP155                                          |
+------------------------+------------+--------------------------------------------------------------------------------+
|  participant1_signature| bytes      | Elliptic Curve 256k1 signature of participant1 on the above data               |
+------------------------+------------+--------------------------------------------------------------------------------+
|  participant2_signature| bytes      | Elliptic Curve 256k1 signature of participant2 on the above data               |
+------------------------+------------+--------------------------------------------------------------------------------+

Project Specification
=====================

Expose the network graph
------------------------

Clients have to collect events in order to derive the network graph.

Functional decomposition
------------------------

TokenNetworkRegistry Contract
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Attributes:

- ``address public secret_registry_address``
- ``uint256 public chain_id``
- ``uint256 public settlement_timeout_min``
- ``uint256 public settlement_timeout_max``

**Register a token**

Deploy a new ``TokenNetwork`` contract and add its address in the registry.

::

    function createERC20TokenNetwork(address token_address) public

::

    event TokenNetworkCreated(address token_address, address token_network_address)

- ``token_address``: address of the Token contract.
- ``token_network_address``: address of the newly deployed ``TokenNetwork`` contract.
- ``settlement_timeout_min``: Minimum settlement timeout to be used in every ``TokenNetwork``
- ``settlement_timeout_max``: Maximum settlement timeout to be used in every ``TokenNetwork``

.. Note::
    It also provides the ``SecretRegistry`` contract address to the ``TokenNetwork`` constructor.

TokenNetwork Contract
^^^^^^^^^^^^^^^^^^^^^

Provides the interface to interact with payment channels. The channels can only transfer the type of token that this contract defines through ``token_address``.

.. _channel-identifier:

:term:`Channel Identifier` is currently defined as ``uint256``, a global monotonically increasing counter of all the channels inside a ``TokenNetwork``.

.. Note::
    A ``channel_identifier`` value of ``0`` is not a valid value for an active channel. The counter starts at ``1``.

**Attributes**

- ``Token public token``
- ``SecretRegistry public secret_registry;``
- ``uint256 public chain_id``

**Getters**

.. _get-channel-identifier:

We currently limit the number of channels between two participants to one. Therefore, a pair of addresses can have at most one ``channel_identifier``. The ``channel_identifier`` will be ``0`` if the channel does not exist.

::

    function getChannelIdentifier(address participant, address partner)
        view
        public
        returns (uint256 channel_identifier)

.. _get-channel-info:

::

    function getChannelInfo(
        uint256 channel_identifier,
        address participant1,
        address participant2
    )
        view
        external
        returns (uint256 settle_block_number, ChannelState state)

- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``participant1``: Ethereum address of a channel participant.
- ``participant2``: Ethereum address of the other channel participant.
- ``state``: Channel state. It can be ``NonExistent`` - ``0``, ``Opened`` - ``1``, ``Closed`` - ``2``, ``Settled`` - ``3``, ``Removed`` - ``4``.

.. Note::
    Channel state ``Settled`` means the channel was settled and channel data removed. However, there is still data remaining in the contract for calling ``unlock`` - for at least one participant.

    Channel state ``Removed`` means that no channel data and no ``unlock`` data remain in the contract.

.. _get-channel-participant-info:

::

    function getChannelParticipantInfo(
            uint256 channel_identifier,
            address participant,
            address partner
    )
        view
        external
        returns (
            uint256 deposit,
            uint256 withdrawn_amount,
            bool is_the_closer,
            bytes32 balance_hash,
            uint256 nonce,
            bytes32 locksroot,
            uint256 locked_amount
        )

- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``participant``: Ethereum address of a channel participant.
- ``partner``: Ethereum address of the other channel participant.
- ``deposit``: Can be ``>=0`` after the channel has been opened. Must be ``0`` when the channel is in ``Settled`` or ``Removed`` state.
- ``withdrawn_amount``: Can be ``>=0`` after the channel has been opened. Must be ``0`` when the channel is in ``Settled`` or ``Removed`` state.
- ``is_the_closer``: Can be ``true`` if the channel is in ``Closed`` state and if ``participant`` closed the channel. Must be ``false`` otherwise.
- ``balance_hash``: Can be set when the channel is in ``Closed`` state. Must be ``0`` otherwise.
- ``nonce``: Can be set when the channel is in a ``Closed`` state. Must be ``0`` otherwise.
- ``locksroot``: Can be set when the channel is in a ``Settled`` state. Must be ``0`` otherwise.
- ``locked_amount``: Can be set when the channel is in a ``Settled`` state. Must be ``0`` otherwise.

.. _open-channel:

**Open a channel**

Opens a channel between ``participant1`` and ``participant2`` and sets the challenge period of the channel.

::

    function openChannel(address participant1, address participant2, uint256 settle_timeout) public returns (uint256 channel_identifier)

::

    event ChannelOpened(
        uint256 indexed channel_identifier,
        address indexed participant1,
        address indexed participant2,
        uint256 settle_timeout
    );

- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``participant1``: Ethereum address of a channel participant.
- ``participant2``: Ethereum address of the other channel participant.
- ``settle_timeout``: Number of blocks that need to be mined between a call to ``closeChannel`` and ``settleChannel``.

.. _deposit-channel:

**Fund a channel**

Deposit more tokens into a channel. This will only increase the deposit of one of the channel participants: the ``participant``.

::

    function setTotalDeposit(
        uint256 channel_identifier,
        address participant,
        uint256 total_deposit,
        address partner
    )
        public

::

    event ChannelNewDeposit(
        uint256 indexed channel_identifier,
        address indexed participant,
        uint256 total_deposit
    );

- ``participant``: Ethereum address of a channel participant whose deposit will be increased.
- ``total_deposit``: Total amount of tokens that the ``participant`` will have as ``deposit`` in the channel.
- ``partner``: Ethereum address of the other channel participant, used for computing ``channel_identifier``.
- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``deposit``: The total amount of tokens deposited in a channel by a participant.

.. Note::
    Allowed to be called multiple times. Can be called by anyone.

    This function is idempotent. The UI and internal smart contract logic has to make sure that the amount of tokens actually transferred is the difference between ``total_deposit`` and the ``deposit`` at transaction time.

.. _withdraw-channel:

**Withdraw tokens from a channel**

Allows a channel participant to withdraw tokens from a channel without closing it. Can be called by anyone. Can only be called once per each signed withdraw message.

::

    function setTotalWithdraw(
        uint256 channel_identifier,
        address participant,
        uint256 total_withdraw,
        bytes participant_signature,
        bytes partner_signature
    )
        external

::

    event ChannelWithdraw(
        uint256 indexed channel_identifier,
        address indexed participant,
        uint256 total_withdraw
    );

- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``participant``: Ethereum address of a channel participant who will receive the tokens withdrawn from the channel.
- ``total_withdraw``: Total amount of tokens that are marked as withdrawn from the channel during the channel lifecycle.
- ``participant_signature``: Elliptic Curve 256k1 signature of the channel ``participant`` on the :term:`withdraw proof` data.
- ``partner_signature``: Elliptic Curve 256k1 signature of the channel ``partner`` on the :term:`withdraw proof` data.

.. _close-channel:

**Close a channel**

Allows a channel participant to close the channel. The channel cannot be settled before the challenge period has ended.

::

    function closeChannel(
        uint256 channel_identifier,
        address partner,
        bytes32 balance_hash,
        uint256 nonce,
        bytes32 additional_hash,
        bytes signature
    )
        public

::

    event ChannelClosed(uint256 indexed channel_identifier, address indexed closing_participant);

- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``partner``: Channel partner of the participant who calls the function.
- ``balance_hash``: Hash of the balance data ``keccak256(transferred_amount, locked_amount, locksroot)``
- ``nonce``: Strictly monotonic value used to order transfers.
- ``additional_hash``: Computed from the message. Used for message authentication.
- ``transferred_amount``: The monotonically increasing counter of the partner's amount of tokens sent.
- ``locked_amount``: The sum of the all the tokens that correspond to the locks (pending transfers) contained in the merkle tree.
- ``locksroot``: Root of the merkle tree of all pending lock lockhashes for the partner.
- ``signature``: Elliptic Curve 256k1 signature of the channel partner on the :term:`balance proof` data.
- ``closing_participant``: Ethereum address of the channel participant who calls this contract function.

.. Note::
    Only a participant may close the channel.

    Only a valid signed :term:`balance proof` from the channel partner (the other channel participant) must be accepted. This :term:`balance proof` sets the amount of tokens owed to the participant by the channel partner.

.. _update-channel:

**Update non-closing participant balance proof**

Called after a channel has been closed. Can be called by any Ethereum address and allows the non-closing participant to provide the latest :term:`balance proof` from the closing participant. This modifies the stored state for the closing participant.

::

    function updateNonClosingBalanceProof(
        uint256 channel_identifier,
        address closing_participant,
        address non_closing_participant,
        bytes32 balance_hash,
        uint256 nonce,
        bytes32 additional_hash,
        bytes closing_signature,
        bytes non_closing_signature
    )
        external

::

    event NonClosingBalanceProofUpdated(
        uint256 indexed channel_identifier,
        address indexed closing_participant,
        uint256 nonce
    );

- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``closing_participant``: Ethereum address of the channel participant who closed the channel.
- ``non_closing_participant``: Ethereum address of the channel participant who is updating the balance proof data.
- ``balance_hash``: Hash of the balance data
- ``nonce``: Strictly monotonic value used to order transfers.
- ``additional_hash``: Computed from the message. Used for message authentication.
- ``closing_signature``: Elliptic Curve 256k1 signature of the closing participant on the :term:`balance proof` data.
- ``non_closing_signature``: Elliptic Curve 256k1 signature of the non-closing participant on the :term:`balance proof` data.
- ``closing_participant``: Ethereum address of the participant who closed the channel.

.. Note::
    Can be called by any Ethereum address due to the requirement of providing signatures from both channel participants.

.. _settle-channel:

**Settle channel**

Settles the channel by transferring the amount of tokens each participant is owed. We need to provide the entire balance state because we only store the balance data hash when closing the channel and updating the non-closing participant balance.

::

    function settleChannel(
        uint256 channel_identifier,
        address participant1,
        uint256 participant1_transferred_amount,
        uint256 participant1_locked_amount,
        bytes32 participant1_locksroot,
        address participant2,
        uint256 participant2_transferred_amount,
        uint256 participant2_locked_amount,
        bytes32 participant2_locksroot
    )
        public

::

    event ChannelSettled(
        uint256 indexed channel_identifier,
        uint256 participant1_amount,
        uint256 participant2_amount
    );

- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``participant1``: Ethereum address of one of the channel participants.
- ``participant1_transferred_amount``: The monotonically increasing counter of the amount of tokens sent by ``participant1`` to ``participant2``.
- ``participant1_locked_amount``: The sum of the all the tokens that correspond to the locks (pending transfers sent by ``participant1`` to ``participant2``) contained in the merkle tree.
- ``participant1_locksroot``: Root of the merkle tree of all pending lock lockhashes (pending transfers sent by ``participant1`` to ``participant2``).
- ``participant2``: Ethereum address of the other channel participant.
- ``participant2_transferred_amount``: The monotonically increasing counter of the amount of tokens sent by ``participant2`` to ``participant1``.
- ``participant2_locked_amount``: The sum of the all the tokens that correspond to the locks (pending transfers sent by ``participant2`` to ``participant1``) contained in the merkle tree.
- ``participant2_locksroot``: Root of the merkle tree of all pending lock lockhashes (pending transfers sent by ``participant2`` to ``participant1``).

.. Note::
    Can be called by anyone after a channel has been closed and the challenge period is over.

    We currently enforce an ordering of the participant data based on the following rule: ``participant2_transferred_amount + participant2_locked_amount >= participant1_transferred_amount + participant1_locked_amount``. This is an artificial rule to help the settlement algorithm handle overflows and underflows easier, without failing the transaction.

.. _cooperative-settle-channel:

**Cooperatively close and settle a channel**

Allows the participants to cooperate and provide both of their balances and signatures. This closes and settles the channel immediately, without triggering a challenge period.

::

    function cooperativeSettle(
        uint256 channel_identifier,
        address participant1_address,
        uint256 participant1_balance,
        address participant2_address,
        uint256 participant2_balance,
        bytes participant1_signature,
        bytes participant2_signature
    )
        public

- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract
- ``participant1_address``: Ethereum address of one of the channel participants.
- ``participant1_balance``: Channel balance of ``participant1_address``.
- ``participant2_address``: Ethereum address of the other channel participant.
- ``participant2_balance``: Channel balance of ``participant2_address``.
- ``participant1_signature``: Elliptic Curve 256k1 signature of ``participant1`` on the :term:`cooperative settle proof` data.
- ``participant2_signature``: Elliptic Curve 256k1 signature of ``participant2`` on the :term:`cooperative settle proof` data.

.. Note::
    Emits the ChannelSettled event.

    Can be called by a third party as long as both participants provide their signatures.

.. _unlock-channel:

**Unlock lock**

Unlocks all pending transfers by providing the entire merkle tree of pending transfers data. The merkle tree is used to calculate the merkle root, which must be the same as the ``locksroot`` provided in the latest :term:`balance proof`.

::

    function unlock(
        uint256 channel_identifier,
        address participant,
        address partner,
        bytes merkle_tree_leaves
    )
        public

::

    event ChannelUnlocked(
        uint256 indexed channel_identifier,
        address indexed participant,
        address indexed partner,
        bytes32 locksroot,
        uint256 unlocked_amount,
        uint256 returned_tokens
    );

- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``participant``: Ethereum address of the channel participant who will receive the unlocked tokens that correspond to the pending transfers that have a revealed secret.
- ``partner``: Ethereum address of the channel participant that pays the amount of tokens that correspond to the pending transfers that have a revealed secret. This address will receive the rest of the tokens that correspond to the pending transfers that have not finalized and do not have a revelead secret.
- ``merkle_tree_leaves``: The data for computing the entire merkle tree of pending transfers. It contains tightly packed data for each transfer, consisting of ``expiration_block``, ``locked_amount``, ``secrethash``.
- ``expiration_block``: The absolute block number at which the lock expires.
- ``locked_amount``: The number of tokens being transferred from ``partner`` to ``participant`` in a pending transfer.
- ``secrethash``: A hashed secret, ``sha3_keccack(secret)``.
- ``unlocked_amount``: The total amount of unlocked tokens that the ``partner`` owes to the channel ``participant``.
- ``returned_tokens``: The total amount of unlocked tokens that return to the ``partner`` because the secret was not revealed, therefore the mediating transfer did not occur.

.. Note::
    Anyone can unlock a transfer on behalf of a channel participant.
    ``unlock`` must be called after ``settleChannel`` because it needs the ``locksroot`` from the latest :term:`balance proof` in order to guarantee that all locks have either been unlocked or have expired.


SecretRegistry Contract
^^^^^^^^^^^^^^^^^^^^^^^

This contract will store the block height at which the secret was revealed in a mediating transfer.
In collaboration with a monitoring service, it acts as a security measure, to allow all nodes participating in a mediating transfer to withdraw the transferred tokens even if some of the nodes might be offline.

.. _register-secret:

::

    function registerSecret(bytes32 secret) public returns (bool)

    function registerSecretBatch(bytes32[] secrets) public returns (bool)

::

    event SecretRevealed(bytes32 indexed secrethash, bytes32 secret);

Getters
::

    function getSecretRevealBlockHeight(bytes32 secrethash) public view returns (uint256)

- ``secret``: The preimage used to derive a secrethash.
- ``secrethash``: ``keccak256(secret)``.


Protocol Overview
=================

Opened Channel Lifecycle
------------------------

.. image:: diagrams/RaidenSC_channel_open_lifecycle.png
    :alt: Opened Channel Lifecycle
    :width: 500px


Channel Settlement
------------------

.. image:: diagrams/RaidenSC_channel_settlement.png
    :alt: Channel Settlement
    :width: 400px

Channel Settlement Window
-------------------------

The non-closing participant can update the closing participant's balance proof during the settlement window, by calling ``TokenNetwork.updateNonClosingBalanceProof``.

.. image:: diagrams/RaidenSC_channel_update.png
    :alt: Channel Settlement Window Updating NonClosing BalanceProof
    :width: 650px

Unlocking Pending Transfers
---------------------------

.. image:: diagrams/RaidenSC_channel_unlock.png
    :alt: Channel Unlock Pending Transfers
    :width: 500px


Protocol Value Constraints
==========================

These are constraints imposed on the values used in the signed messages: :ref:`balance proof <balance-proof-message>`,
:ref:`withdraw proof <withdraw-proof-message>`, :ref:`cooperative settle proof <cooperative-settle-proof-message>`.

Definitions
-----------

- ``valid last BP`` = a balance proof that respects the official Raiden client constraints and is the last balance proof known
- ``valid old BP`` = a balance proof that respects the official Raiden client constraints, but there are other newer balance proofs that were created after it (additional transfers happened)
- ``invalid BP`` = a balance proof that does not respect the official Raiden client constraints
- ``P``: A channel participant - :term:`Participants`
- ``P1``: One of the two channel participants
- ``P2``: The other channel participant, or ``P1``'s partner
- ``D1``: Total amount of tokens deposited by ``P1`` in the channel using :ref:`setTotalDeposit <deposit-channel>` and shown by :ref:`getChannelParticipantInfo <get-channel-participant-info>`
- ``W1``: Total amount of tokens withdrawn from the channel by ``P1`` using :ref:`setTotalWithdraw <withdraw-channel>` and shown by :ref:`getChannelParticipantInfo <get-channel-participant-info>`
- ``T1``: Off-chain :term:`Transferred amount` from ``P1`` to ``P2``, representing finalized transfers.
- ``L1``: Locked tokens in pending transfers sent by ``P1`` to ``P2``, that have not finalized yet or have expired. Corresponds to a :term:`locksroot` provided to the smart contract in :ref:`settleChannel <settle-channel>`. ``L1 = Lc1 + Lu1``
- ``Lc1``: Locked amount that will be transferred to ``P2`` if :ref:`unlock <unlock-channel>` is called with ``P1``'s pending transfers. This only happens if the :term:`secret` s of the pending :term:`Hash Time Locked Transfer` s have been registered with :ref:`registerSecret <register-secret>`
- ``Lu1``: Locked amount that will return to ``P1`` because the :term:`secret` s were not registered on-chain
- ``TAD``: Total available deposit
- ``B1``: Total, final amount that must be received by ``P1`` after channel is settled and no unlocks are left to be done.
- ``AB1``: available balance for P1: :term:`Capacity`. Determines if ``P1`` can make additional transfers to ``P2`` or not.
- ``D1k`` = ``D1`` at ``time = k``; same for all of the above.

All the above definitions are also valid for ``P2``. Example: ``D2``, ``T2`` etc.

Value constraints
------------------

Must be enforced by the TokenNetwork smart contract
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

::

    (1SC) Dk <= Dt, k < t
    (2SC) Wk <= Wt, k < t
    (3SC) TAD = D1 + D2 - W1 - W2 ; TAD >= 0

Must be enforced by the Raiden Client
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

::

    (1R) Tk <= Tt, k < t
    (2R) AB1 = D1 - W1 + T2 - T1 - L1; AB1 >= 0
    (3R) W1 <= D1 + T2 - T1 - L1
    (4R) T1 + L1 < 2^256 ; T2 + L2 < 2^256
    (5R) Tk + Lck <= Tt + Lct, k < t

.. Note::
    Any two consecutive balance proofs for ``P1``, named ``BP1k`` and ``BP1t`` were `k < t`,  must respect the following constraints:

    1. A :term:`Direct Transfer` or a succesfull :term:`HTL Transfer` with ``value`` tokens was finalized, therefore ``T1t == T1k + value`` and ``L1t == L1k``.
    2. A :ref:`locked transfer message <locked-transfer-message>` with ``value`` was sent, part of a :term:`HTL Transfer`, therefore ``T1t == T1k`` and ``L1t == L1k + value``.
    3. A :term:`HTL Unlock` for a previous ``value`` was finalized, therefore ``T1t == T1k + value`` and ``L1t == L1k - value``.
    4. A :term:`lock expiration` message for a previous ``value`` was done, therefore ``T1t == T1k`` and ``L1t == L1k - value``.


Settlement algorithm
--------------------

The following must be true if the two participants use their ``last valid BP``:

::

    (1) B1 = D1 - W1 + T2 - T1 + Lc2 - Lc1
    (2) B2 = D2 - W2 + T1 - T2 + Lc1 - Lc2
    (3) B1 + B2 = TAD
