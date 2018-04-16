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
        uint settle_timeout);

- ``participant1``: Ethereum address of a channel participant.
- ``participant2``: Ethereum address of the other channel participant.
- ``settle_timeout``: Number of blocks that need to be mined between a call to ``closeChannel`` and ``settleChannel``.
- ``channel_identifier``: Channel identifier assigned by the current contract.

**Fund a channel**

Deposit more tokens into a channel. This will only increase the deposit of one of the channel participants: the ``participant``.

::

    function setDeposit(
        uint channel_identifier,
        address participant,
        uint256 total_deposit)
        public

::

    event ChannelNewDeposit(uint channel_identifier, address participant, uint deposit);

- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``participant``: Ethereum address of a channel participant whose deposit will be increased.
- ``total_deposit``: Total amount of tokens that the ``participant`` will have as ``deposit`` in the channel.
- ``deposit``: The total amount of tokens deposited in a channel by a participant.

.. Note::
    Allowed to be called multiple times. Can be called by anyone.

    This function is idempotent. The UI and internal smart contract logic has to make sure that the amount of tokens actually transferred is the difference between ``total_deposit`` and the ``deposit`` at transaction time.

**Close a channel**

Allows a channel participant to close the channel. The channel cannot be settled before the challenge period has ended.

::

    function closeChannel(
        uint channel_identifier,
        uint64 nonce,
        uint256 transferred_amount,
        bytes32 locksroot,
        bytes32 additional_hash,
        bytes signature)
        public

::

    event ChannelClosed(uint channel_identifier, address closing_participant);

- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``nonce``: Strictly monotonic value used to order transfers.
- ``transferred_amount``: The monotonically increasing counter of the partner's amount of tokens sent.
- ``locksroot``: Root of the merkle tree of all pending lock lockhashes for the partner.
- ``additional_hash``: Computed from the message. Used for message authentication.
- ``signature``: Elliptic Curve 256k1 signature of the channel partner on the balance proof data.
- ``closing_participant``: Ethereum address of the channel participant who calls this contract function.

.. Note::
    Only a participant may close the channel.

    Only a valid signed balance proof from the channel partner (the other channel participant) must be accepted. This balance proof sets the amount of tokens owed to the participant by the channel partner.

**Update transfer state**

Called after a channel has been closed. Allows the non-closing participant to provide a balance proof for the latest transfer from the closing participant. This modifies the state for the closing participant.

::

    function updateTransfer(
        uint channel_identifier,
        uint64 nonce,
        uint256 transferred_amount,
        bytes32 locksroot,
        bytes32 additional_hash,
        bytes closing_signature)
        public

    function updateTransferDelegate(
        uint channel_identifier,
        uint64 nonce,
        uint256 transferred_amount,
        bytes32 locksroot,
        bytes32 additional_hash,
        bytes closing_signature,
        bytes non_closing_signature)
        public

::

    event TransferUpdated(
        uint256 channel_identifier,
        address closing_participant
    );

- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``nonce``: Strictly monotonic value used to order transfers.
- ``transferred_amount``: The monotonically increasing counter of the closing participant's amount of tokens sent.
- ``locksroot``: Root of the merkle tree of all pending lock lockhashes for the closing participant.
- ``additional_hash``: Computed from the message. Used for message authentication.
- ``closing_signature``: Elliptic Curve 256k1 signature of the closing participant on the balance proof data.
- ``non_closing_signature``: Elliptic Curve 256k1 signature of the non-closing participant on the balance proof data.
- ``closing_participant``: Ethereum address of the participant who closed the channel.

.. Note::
    ``updateTransfer`` can only be called by the non-closing channel participant with a balance proof of the closing participant.

    ``updateTransferDelegate`` can be called by anyone with a balance proof of the closing party and a signature from the non-closing participant on the same balance proof data.

**Register a secret**

Registers a secret in the ``SecretRegistry`` smart contract, which saves the block number in which the secret was revealed.

::

    function registerSecret(bytes32 secret) public


.. Note::
    Can be called by anyone.

**Unlock lock**

Unlocks a pending transfer by providing the secret and increases the partner's transferred amount with the transfer value. A lock can be unlocked only once per a participant's balance proof.

::

    function unlock(
        uint channel_identifier,
        address partner,
        uint64 expiration_block,
        uint locked_amount,
        bytes32 secrethash,
        bytes merkle_proof,
        bytes32 secret)
        public

    function registerSecretAndUnlock(
        uint256 channel_identifier,
        address partner,
        uint64 expiration_block,
        uint256 locked_amount,
        bytes32 secrethash,
        bytes merkle_proof,
        bytes32 secret)
        external

::

    event ChannelUnlocked(uint256 channel_identifier, address payer_participant, uint256 transferred_amount);

- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``partner``: Ethereum address of the channel participant that pays the ``locked_amount``.
- ``expiration_block``: The absolute block number at which the lock expires.
- ``locked_amount``: The number of tokens being transferred.
- ``secrethash``: A hashed secret, ``sha3_keccack(secret)``.
- ``merkle_proof``: The merkle proof needed to compute the merkle root.
- ``secret``: The preimage used to derive a secrethash.
- ``payer_participant``: Ethereum address of the channel participant whose ``transferred_amount`` will be increased.
- ``transferred_amount``: The total amount of tokens that the ``payer_participant`` owes to the channel participant that calls this function.

.. Note::
    Anyone can unlock a transfer on behalf of a channel participant.
    In case there is another ``updateTransfer`` that has occured after the locks have been initially unlocked, the locks have to be unlocked again if neccessary, with the new `locksroot`.

    The ``registerSecretAndUnlock`` is a wrapper function for both  ``registerSecret`` and ``unlock``.

**Settle channel**

Settles the channel by transferring the amount of tokens each participant is owed.

::

    function settleChannel(
        uint256 channel_identifier,
        address participant1,
        address participant2)
        public

::

    event ChannelSettled(uint channel_identifier);

- ``channel_identifier``: Channel identifier assigned by the current contract.

.. Note::
    Can be called by anyone after a channel has been closed and the challenge period is over.

**Cooperatively close and settle a channel**

Allows the participants to cooperate and provide both of their balances and signatures. This closes and settles the channel immediately, without triggering a challenge period.

::

    function cooperativeSettle(
        uint channel_identifier,
        address participant1,
        address participant2,
        uint256 balance1,
        uint256 balance2,
        bytes signature1,
        bytes signature2)
        public

- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``balance1``: Channel balance of ``participant1``.
- ``balance2``: Channel balance of ``participant2``.
- ``signature1``: Elliptic Curve 256k1 signature of ``participant1``.
- ``signature2``: Elliptic Curve 256k1 signature of ``participant1``.

.. Note::
    Emits the ChannelSettled event.

    Can be called by a third party as long as both participants provide their signatures.

SecretRegistry Contract
^^^^^^^^^^^^^^^^^^^^^^^

This contract will store secrets revealed in a mediating transfer. It has to keep track of the block height at which the secret was stored.
In collaboration with a monitoring service, it acts as a security measure, to allow all nodes participating in a mediating transfer to withdraw the transferred tokens even if some of the nodes might be offline.

::

    function registerSecret(bytes32 secret) public returns (bool)

::

    event SecretRevealed(bytes32 secret);

Getters
::

    function getSecretBlockHeight(bytes32 secret) public constant returns (uint64)

- ``secret``: The preimage used to derive a secrethash.

Data types definition
---------------------

Format used to encode the values must be the same as the EVM.

Balance Proof
^^^^^^^^^^^^^

+------------------------+------------+--------------------------------------------------------------+
| Field Name             | Field Type |  Description                                                 |
+========================+============+==============================================================+
|  nonce                 | uint64     | Strictly monotonic value used to order transfers             |
+------------------------+------------+--------------------------------------------------------------+
|  transferred_amount    | uint256    | Total amount of tokens transferred by a channel participant  |
+------------------------+------------+--------------------------------------------------------------+
|  locksroot             | bytes32    | Root of merkle tree of all pending lock lockhashes           |
+------------------------+------------+--------------------------------------------------------------+
|  channel_identifier    | uint256    | Channel identifier inside the TokenNetwork contract          |
+------------------------+------------+--------------------------------------------------------------+
| token_network_address  | address    | Address of the TokenNetwork contract                         |
+------------------------+------------+--------------------------------------------------------------+
| chain_id               | uint256    | Chain identifier as defined in EIP155                        |
+------------------------+------------+--------------------------------------------------------------+
|  additional_hash       | bytes32    | Computed from the message. Used for message authentication   |
+------------------------+------------+--------------------------------------------------------------+
|  signature             | bytes      | Elliptic Curve 256k1 signature                               |
+------------------------+------------+--------------------------------------------------------------+


Decisions
=========

- Batch operations should not be supported in Raiden Network smart contracts. They can be done in a smart contract wrapper instead.
   - Provide smart contract to batch operations with the same function names but vectorized types. Example: opening multiple channels in the same transaction.
   - To save on the number of transactions, add optimization functions that do multiple smart contract function calls
