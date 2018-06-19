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

Project Specification
=====================

Expose the network graph
------------------------

Clients have to collect events in order to derive the network graph.

Functional decomposition
------------------------

TokenNetworksRegistry Contract
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Attributes:

- ``address public secret_registry_address``
- ``uint256 public chain_id``

**Register a token**

Deploy a new ``TokenNetwork`` contract and add its address in the registry.

::

    function createERC20TokenNetwork(address token_address) public

::

    event TokenNetworkCreated(address token_address, address token_network_address)

- ``token_address``: address of the Token contract.
- ``token_network_address``: address of the newly deployed ``TokenNetwork`` contract.

.. Note::
    It also provides the ``SecretRegistry`` contract address to the ``TokenNetwork`` constructor.

TokenNetwork Contract
^^^^^^^^^^^^^^^^^^^^^

Provides the interface to interact with payment channels. The channels can only transfer the type of token that this contract defines through ``token_address``.

.. _channel-identifier:

:term:`Channel Identifier` is currently defined as ``keccak256(address participant1, address participant2)``, where the two participant addresses are in lexicographic order.

Attributes:

- ``Token public token``
- ``SecretRegistry public secret_registry;``
- ``uint256 public chain_id``

**Open a channel**

Opens a channel between ``participant1`` and ``participant2`` and sets the challenge period of the channel.

::

    function openChannel(address participant1, address participant2, uint settle_timeout) public returns (uint256 channel_identifier)

::

    event ChannelOpened(
        uint channel_identifier,
        address participant1,
        address participant2,
        uint settle_timeout
    );

- ``participant1``: Ethereum address of a channel participant.
- ``participant2``: Ethereum address of the other channel participant.
- ``settle_timeout``: Number of blocks that need to be mined between a call to ``closeChannel`` and ``settleChannel``.
- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.

**Fund a channel**

Deposit more tokens into a channel. This will only increase the deposit of one of the channel participants: the ``participant``.

::

    function setDeposit(
        address participant,
        uint256 total_deposit,
        address partner
    )
        public

::

    event ChannelNewDeposit(uint channel_identifier, address participant, uint deposit);

- ``participant``: Ethereum address of a channel participant whose deposit will be increased.
- ``total_deposit``: Total amount of tokens that the ``participant`` will have as ``deposit`` in the channel.
- ``partner``: Ethereum address of the other channel participant, used for computing ``channel_identifier``.
- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``deposit``: The total amount of tokens deposited in a channel by a participant.

.. Note::
    Allowed to be called multiple times. Can be called by anyone.

    This function is idempotent. The UI and internal smart contract logic has to make sure that the amount of tokens actually transferred is the difference between ``total_deposit`` and the ``deposit`` at transaction time.

**Withdraw tokens from a channel**

Allows a channel participant to withdraw tokens from a channel without closing it. Can be called by anyone. Can only be called once per each signed withdraw message.

::

    function withdraw(
        address participant,
        uint256 total_withdraw,
        address partner,
        bytes participant_signature,
        bytes partner_signature
    )
        external

::

    event ChannelWithdraw(bytes32 channel_identifier, address participant, uint256 withdrawn_amount);

- ``participant``: Ethereum address of a channel participant who will receive the tokens withdrawn from the channel.
- ``total_withdraw``: Total amount of tokens that are marked as withdrawn from the channel during the channel lifecycle.
- ``partner``: Channel partner address.
- ``participant_signature``: Elliptic Curve 256k1 signature of the channel ``participant`` on the :term:`withdraw proof` data.
- ``partner_signature``: Elliptic Curve 256k1 signature of the channel ``partner`` on the :term:`withdraw proof` data.

**Close a channel**

Allows a channel participant to close the channel. The channel cannot be settled before the challenge period has ended.

::

    function closeChannel(
        address partner,
        bytes32 balance_hash,
        uint256 nonce,
        bytes32 additional_hash,
        bytes signature
    )
        public

::

    event ChannelClosed(uint channel_identifier, address closing_participant);

- ``partner``: Channel partner of the participant who calls the function.
- ``balance_hash``: Hash of the balance data ``keccak256(transferred_amount, locked_amount, locksroot)``
- ``nonce``: Strictly monotonic value used to order transfers.
- ``additional_hash``: Computed from the message. Used for message authentication.
- ``transferred_amount``: The monotonically increasing counter of the partner's amount of tokens sent.
- ``locked_amount``: The sum of the all the tokens that correspond to the locks (pending transfers) contained in the merkle tree.
- ``locksroot``: Root of the merkle tree of all pending lock lockhashes for the partner.
- ``signature``: Elliptic Curve 256k1 signature of the channel partner on the :term:`balance proof` data.
- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``closing_participant``: Ethereum address of the channel participant who calls this contract function.

.. Note::
    Only a participant may close the channel.

    Only a valid signed :term:`balance proof` from the channel partner (the other channel participant) must be accepted. This :term:`balance proof` sets the amount of tokens owed to the participant by the channel partner.

**Update non-closing participant balance proof**

Called after a channel has been closed. Can be called by any Ethereum address and allows the non-closing participant to provide the latest :term:`balance proof` from the closing participant. This modifies the stored state for the closing participant.

::

    function updateNonClosingBalanceProof(
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
        uint256 channel_identifier,
        address closing_participant
    );

- ``closing_participant``: Ethereum address of the channel participant who closed the channel.
- ``non_closing_participant``: Ethereum address of the channel participant who is updating the balance proof data.
- ``balance_hash``: Hash of the balance data
- ``nonce``: Strictly monotonic value used to order transfers.
- ``additional_hash``: Computed from the message. Used for message authentication.
- ``closing_signature``: Elliptic Curve 256k1 signature of the closing participant on the :term:`balance proof` data.
- ``non_closing_signature``: Elliptic Curve 256k1 signature of the non-closing participant on the :term:`balance proof` data.
- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``closing_participant``: Ethereum address of the participant who closed the channel.

.. Note::
    Can be called by any Ethereum address due to the requirement of providing signatures from both channel participants.

**Settle channel**

Settles the channel by transferring the amount of tokens each participant is owed. We need to provide the entire balance state because we only store the balance data hash when closing the channel and updating the non-closing participant balance.

::

    function settleChannel(
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

    event ChannelSettled(uint256 channel_identifier, uint256 participant1_amount, uint256 participant2_amount);

- ``participant1``: Ethereum address of one of the channel participants.
- ``participant1_transferred_amount``: The monotonically increasing counter of the amount of tokens sent by ``participant1`` to ``participant2``.
- ``participant1_locked_amount``: The sum of the all the tokens that correspond to the locks (pending transfers sent by ``participant1`` to ``participant2``) contained in the merkle tree.
- ``participant1_locksroot``: Root of the merkle tree of all pending lock lockhashes (pending transfers sent by ``participant1`` to ``participant2``).
- ``participant2``: Ethereum address of the other channel participant.
- ``participant2_transferred_amount``: The monotonically increasing counter of the amount of tokens sent by ``participant2`` to ``participant1``.
- ``participant2_locked_amount``: The sum of the all the tokens that correspond to the locks (pending transfers sent by ``participant2`` to ``participant1``) contained in the merkle tree.
- ``participant2_locksroot``: Root of the merkle tree of all pending lock lockhashes (pending transfers sent by ``participant2`` to ``participant1``).
- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.

.. Note::
    Can be called by anyone after a channel has been closed and the challenge period is over.

    We currently enforce an ordering of the participant data based on the following rule: ``participant2_transferred_amount + participant2_locked_amount >= participant1_transferred_amount + participant1_locked_amount``. This is an artificial rule to help the settlement algorithm handle overflows and underflows easier, without failing the transaction.

**Cooperatively close and settle a channel**

Allows the participants to cooperate and provide both of their balances and signatures. This closes and settles the channel immediately, without triggering a challenge period.

::

    function cooperativeSettle(
        address participant1_address,
        uint256 participant1_balance,
        address participant2_address,
        uint256 participant2_balance,
        bytes participant1_signature,
        bytes participant2_signature
    )
        public

- ``participant1_address``: Ethereum address of one of the channel participants.
- ``participant1_balance``: Channel balance of ``participant1_address``.
- ``participant2_address``: Ethereum address of the other channel participant.
- ``participant2_balance``: Channel balance of ``participant2_address``.
- ``participant1_signature``: Elliptic Curve 256k1 signature of ``participant1`` on the :term:`cooperative settle proof` data.
- ``participant2_signature``: Elliptic Curve 256k1 signature of ``participant2`` on the :term:`cooperative settle proof` data.

.. Note::
    Emits the ChannelSettled event.

    Can be called by a third party as long as both participants provide their signatures.


**Unlock lock**

Unlocks all pending transfers by providing the entire merkle tree of pending transfers data. The merkle tree is used to calculate the merkle root, which must be the same as the ``locksroot`` provided in the latest :term:`balance proof`.

::

    function unlock(
        address participant,
        address partner,
        bytes merkle_tree_leaves
    )
        public

::

    event ChannelUnlocked(uint256 channel_identifier, address participant, uint256 unlocked_amount, uint256 returned_tokens);

- ``participant``: Ethereum address of the channel participant who will receive the unlocked tokens that correspond to the pending transfers that have a revealed secret.
- ``partner``: Ethereum address of the channel participant that pays the amount of tokens that correspond to the pending transfers that have a revealed secret. This address will receive the rest of the tokens that correspond to the pending transfers that have not finalized and do not have a revelead secret.
- ``merkle_tree_leaves``: The data for computing the entire merkle tree of pending transfers. It contains tightly packed data for each transfer, consisting of ``expiration_block``, ``locked_amount``, ``secrethash``.
- ``expiration_block``: The absolute block number at which the lock expires.
- ``locked_amount``: The number of tokens being transferred from ``partner`` to ``participant`` in a pending transfer.
- ``secrethash``: A hashed secret, ``sha3_keccack(secret)``.
- ``channel_identifier``: :term:`Channel identifier` assigned by the current contract.
- ``unlocked_amount``: The total amount of unlocked tokens that the ``partner`` owes to the channel ``participant``.
- ``returned_tokens``: The total amount of unlocked tokens that return to the ``partner`` because the secret was not revealed, therefore the mediating transfer did not occur.

.. Note::
    Anyone can unlock a transfer on behalf of a channel participant.
    ``unlock`` must be called after ``settleChannel`` because it needs the ``locksroot`` from the latest :term:`balance proof` in order to guarantee that all locks have either been unlocked or have expired.


SecretRegistry Contract
^^^^^^^^^^^^^^^^^^^^^^^

This contract will store the block height at which the secret was revealed in a mediating transfer.
In collaboration with a monitoring service, it acts as a security measure, to allow all nodes participating in a mediating transfer to withdraw the transferred tokens even if some of the nodes might be offline.

::

    function registerSecret(bytes32 secret) public returns (bool)

::

    event SecretRevealed(bytes32 indexed secrethash, bytes32 secret);

Getters
::

    function getSecretRevealBlockHeight(bytes32 secrethash) public view returns (uint256)

- ``secret``: The preimage used to derive a secrethash.
- ``secrethash``: ``keccak256(secret)``.

Data types definition
---------------------

A detailed description of the :term:`balance proof` can be found in the :ref:`message definition <balance-proof-message>`.
A detailed description of the :term:`withdraw proof` can be found in the :ref:`message definition <withdraw-proof-message>`.
A detailed description of the :term:`cooperative settle proof` can be found in the :ref:`message definition <cooperative-settle-proof-message>`.

Decisions
=========

- Batch operations should not be supported in Raiden Network smart contracts. They can be done in a smart contract wrapper instead.
   - Provide smart contract to batch operations with the same function names but vectorized types. Example: opening multiple channels in the same transaction.
   - To save on the number of transactions, add optimization functions that do multiple smart contract function calls
