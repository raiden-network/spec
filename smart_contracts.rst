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

- The system must work with the most popular token standard (ERC20 tokens).
- The system must hold tokens in escrow for the lifetime of a channel.
- There must not be a way for a single party to hold other user’s tokens hostage.
- There must be no way for a party to steal funds.
- The proof must be non malleable.
- Losing funds as a penalty is not considered stealing, but must be clearly documented.
- The system must support smart locks.
- Determine if and how different version of the smart contracts should interoperate.
- Channels should be automatically upgraded.

Project Specification
=====================

Expose the network graph
------------------------

Clients have to collect events in order to derive the network graph.

Functional decomposition
------------------------

TokenNetworksRegistry Contract
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Register a token**

Deploy a new ``TokenNetwork`` contract and add its address in the registry.

::

    function createERC20TokenNetwork(address token_address) public

::

    event TokenNetworkCreated(address token_address, address token_network_addrress)

- ``token_address``: address of the Token contract.
- ``token_network_addrress``: address of the newly deployed ``TokenNetwork`` contract.

TokenNetwork Contract
^^^^^^^^^^^^^^^^^^^^^

Provides the interface to interact with payment channels. The channels can only transfer the type of token that this contract defines through ``token_address``.

Attribute: ``address token_address public constant``

**Open a channel**

Opens a channel between ``participant1`` and ``participant2`` and sets the challenge period of the channel.

::

    function openChannel(address participant1, address participant2, uint settle_timeout) public returns (address)

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

Deposit more tokens into a channel. This will only increase the balance of one of the channel participants: the ``beneficiary``.

::

    function deposit(
        uint channel_identifier,
        address beneficiary,
        uint256 added_amount)
        public
        returns (bool)

::

    event ChannelNewBalance(uint channel_identifier, address participant, uint balance);

- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``beneficiary``: Ethereum address of a channel participant whom's balance will be increased.
- ``added_amount``: Amount of tokens with which the ``beneficiary``'s ``balance`` will increase.
- ``participant``: Ethereum address of a channel participant.
- ``balance``: The total amount of tokens deposited in a channel by a participant.

.. Note::
    Allowed to be called multiple times.

    Can be called by anyone.

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

    event ChannelClosed(uint channel_identifier, address closing_address);

- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``nonce``: Strictly monotonic value used to order transfers.
- ``transferred_amount``: The monotonically increasing counter of the counterparty's amount of tokens sent.
- ``locksroot``: Root of the merkle tree of all pending lock lockhashes for the counterparty.
- ``additional_hash``: Computed from the message. Used for message authentication.
- ``signature``: Elliptic Curve 256k1 signature of the counterparty.
- ``closing_address``: Ethereum address of the channel participant who calls this contract function.

.. Note::
    Only a participant may close the channel.

    Only a valid signed balance proof from the counterparty (the other channel participant) must be accepted.

**Update transfer state**

Called after a channel has been closed. Allows the non-closing participant to provide a balance proof for the latest transfer from the closing participant. This modifies the state for the closing participant.

::

    function updateTransfer(
        uint channel_identifier,
        uint64 nonce,
        uint256 transferred_amount,
        bytes32 locksroot,
        bytes32 additional_hash,
        bytes signature)
        public

::

    event TransferUpdated(uint channel_identifier, address participant);

- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``nonce``: Strictly monotonic value used to order transfers.
- ``transferred_amount``: The monotonically increasing counter of the closing participant's amount of tokens sent.
- ``locksroot``: Root of the merkle tree of all pending lock lockhashes for the closing participant.
- ``additional_hash``: Computed from the message. Used for message authentication.
- ``signature``: Elliptic Curve 256k1 signature of the closing participant.
- ``participant``: Ethereum address of the non-closing participant.

.. Note::
    Can be called by a third party with a balance proof of the closing party.

**Unlock lock**

Unlocks a pending transfer by providing the secret and increases the counterparty's transferred amount with the transfer value. A lock can be unlocked only once per participant.

::

    function unlock(
        uint channel_identifier,
        uint64 expiration,
        uint amount,
        bytes32 hashlock,
        bytes merkle_proof,
        bytes32 secret)
        public

::

    event ChannelUnlocked(uint channel_identifier, uint transferred_amount);

- ``channel_identifier``: Channel identifier assigned by the current contract.
- ``expiration``: The absolute block number at which the lock expires.
- ``amount``: The number of tokens being transferred.
- ``hashlock``: A hashed secret, ``sha3_keccack(secret)``.
- ``merkle_proof``: The merkle proof needed to compute the merkle root.
- ``secret``: The preimage used to derive a hashlock.
- ``transferred_amount``: The monotonically increasing counter of the counterparty’s amount of tokens sent.

.. Note::
    Must register the corresponding secret in the SecretRegistry smart contract, saving the block number in which the secret was revealed.

**Settle channel**

Settles the channel by transferring the amount of tokens each participant is owed.

::

    function settleChannel(uint channel_identifier) public

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

    function registerSecret(bytes32 secret) public  returns (bool)

::

    event ChannelSecretRevealed(bytes32 secret, address receiver_address);

Getters
::

    function getSecretBlockHeight(bytes32 secret) public constant returns (uint64)

- ``secret``: The preimage used to derive a hashlock.
- ``receiver_address``: Ethereum address of the channel participant who has received the ``secret``.

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
|  channel_identifier    | uint       | Channel identifier inside the TokenNetwork contract          |
+------------------------+------------+--------------------------------------------------------------+
| token_network_addrress | address    | Address of the TokenNetwork contract                         |
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

Open Questions
==============

- add facade functions, e.g. ``openChannelAndDeposit``
- What token standard should we support? We can wait for a winner to detach itself or support multiple (compatible!) standards.
   - https://github.com/ethereum/EIPs/issues/223, https://github.com/ethereum/EIPs/issues/677,  https://github.com/ethereum/EIPs/issues/777 , https://github.com/ethereum/EIPs/issues/827 (not compatible with 223)
   - Linked issues: https://github.com/raiden-network/raiden/issues/1105
- What should be the channel identifier? This is required for third party services. The channel identifier will be included in the channel creation event.
   - Just a increasing uint ID.
   - A hash composed (sender, receiver, block number). Used by itself, there is no additional advantage compared to using a simple ``uint``. It actually introduces an additional ``keccak256`` operation. However, this can be useful if we decide to only store the hash instead of the data inside it (sender, receiver, block number or anything that can be retrieved from contract events), reducing gas cost. We need to test how much gas will we actually save.
- Channel specific data discussion. We settled on the ``channel_identifier`` + ``TokenNetwork`` contract address. This does not protect against forks. There is an already open issue here: https://github.com/raiden-network/raiden/issues/292.
- Settle on contract and channels upgradability pattern.
- Discuss third party channel closing ``closeChannel`` using a whitelist or providng a second signature for the participant on behalf of which the closing is done. Example: ``closeChannelDelegate`` with additional argument: "bytes signature_closer". Signature message should contain ``token_network_address``, ``channel_identifier``.
- Discuss support for https://github.com/ethereum/EIPs/pull/712 when finalized.
- Deposit allows for a beneficiary -- do we need functionality to have a beneficiary of settle payouts? Example: embedded devices with their own privatekey that are funded by human user with a different privatekey. This can also apply to third party services that can provide token deposits on behalf of a channel participant (e.g. easier onboarding).
- What should the monitoring service do if the node callled update but it did not unlock all the locks that have the secret revealed?
- How are rewards paid? Add a boolean to the functions that need a monitoring service call.
- Integrate interest rates for keeping a channel open
- Assess whether we can support withdrawing tokens without closing the channel.
- How does this play with pathfinding and the raiden wallet?
- Support for distributed pathfinding - it must enforce structure in the network
- Which special flows exists for the raiden wallet that may required additional functions?
