Raiden Terminology
==================

.. glossary::
   :sorted:

   payment
       The process of sending tokens from one account to another. May be composed of multiple transfers (Direct or HTL). A payment goes from :term:`Initiator` to :term:`Target`.

   payment channel
       An object living on a blockchain that has all the capabilities required to enable secure off-chain payment channels.

   channel identifier
       Identifier assigned by :term:`Token Network` to a :term:`Payment Channel`. Must be unique inside the :term:`Token Network` contract. See the :ref:`implementation definition <channel-identifier>`.

   Unidirectional Payment Channel
       Payment Channel where the roles of :term:`Initiator` and :term:`Target` are determined in the channel creation and cannot be changed.

   Bidirectional Payment Channel
       Payment Channel where the roles of :term:`Initiator` and :term:`Target` are interchangeable between the channel participants.

   Raiden Channel
       The Payment Channel implementation used in Raiden.

   Off-Chain Payment Channel
       The portion of a Payment Channel that is used by applications to perform payments without interacting with a blockchain.

   Token Network
       A network of payment channels for a given Token.

   Raiden Network
       A collection of Token networks.

   Transfer
       A movement of tokens from a :term:`Sender` to a :term:`Receiver`.

   Direct Transfer
       A non-refundable non-cancellable off-chain Payment done with a single Transfer.

   Token Swaps
       Exchange of one token for another.

   HTL Transfer
       An expirable potentially cancellable Transfer secured by a Hash Time Lock.

   Hash Time Locked Transfer
   Mediated Transfer
       A token Transfer composed of multiple HTL transfers.

   Hash Time Lock
   HTL
       An expirable lock locked by a secret.

   HTL Commit
       The action of asking a node to commit to reserving a given amount of token for a :term:`Hash Time Lock`. This is the message used to find a path through the network for a transfer.

   HTL Unlock
       The action of unlocking a given :term:`Hash Time Lock`. This is the message used to finalize a transfer once the path is found and the reserve is acknowledged.

   lock expiration
       The lock expiration is the highest block_number until which the transfer can be settled.

   merkletree root
   locksroot
       The root of the merkle tree which holds the hashes of all the locks in the channel.

   lockhash
       The hash of a lock.  ``sha3_keccack(lock)``

   locked amount
       Total amount of tokens locked in all currently pending :term:`HTL` transfers sent by a channel participant. This amount corresponds to the :term:`locksroot` of the HTL locks.

   secrethash
       The hash of a :term:`secret`.  ``sha3_keccack(secret)``

   balance proof
   Participant Balance Proof
   BP
       Signed data required by the :term:`Payment Channel` to prove the balance of one of the parties. Different formats exist for offchain communication and onchain communication.  See the :ref:`onchain balance proof definition <balance-proof-onchain>` and :ref:`offchain balance proof definition <balance-proof-offchain>`.

   withdraw proof
   Participant Withdraw Proof
       Signed data required by the :term:`Payment Channel` to allow a participant to withdraw tokens. See the :ref:`message definition <withdraw-proof>`.

   cooperative settle proof
       Signed data required by the :term:`Payment Channel` to allow :term:`Participants` to close and settle a :term:`Payment Channel` without undergoing through the :term:`Settlement Window`. See the :ref:`message definition <cooperative-settle-proof>`.

   nonce
       Strictly monotonic value used to order off-chain transfers. It starts at ``1``. It is a :term:`balance proof` component. The ``nonce`` differentiates between older and newer balance proofs that can be sent by a delegate to the :term:`Token Network` contract and updated through :ref:`updateNonClosingBalanceProof <update-channel>`.

   chain id
       Chain identifier as defined in EIP155.

   Message
       Any message sent from one Raiden Node to the other.

   Initiator
       The node that sends a :term:`Payment`.

   Target
       The node that receives a :term:`Payment`.

   Mediator
       A node that mediates a transfer.

   Sender
       The node that is sending a Message.  The address of the sender can be inferred from the signature.

   Receiver
       The node that is receiving a Message.

   Inbound Transfer
       A :term:`locked transfer` received by a node. The node may be a :term:`Mediator` in the path or the :term:`Target`.

   Outbound Transfer
       A :term:`locked transfer` sent by a node. The node may be a :term:`Mediator` in the path or the :term:`Initiator`.

   Monitoring Service
   MS
       The service that monitors channel state on behalf of the user and takes an action if the channel is being closed with a balance proof that would violate the agreed on balances. Responsibilities
       - Watch channels
       - Delegate closing

   Pathfinding Service
       A centralized path finding service that has a global view on a token network and provides suitable payment paths for Raiden nodes.

   Raiden Light Client
       A client that does not mediate payments.

   Sleeping Payment
       A payment received by a :term:`Raiden Light Client` that is not online.

   Capacity
       Current amount of tokens available for a given participant to make transfers.

   Deposit
       Amount of token locked in the contract.

   Transferred amount
       Monotonically increasing amount of tokens transferred from one Raiden node to another. It represents all the finalized transfers. For the pending transfers, check :term:`locked amount`.

   Net Balance
       Net of balance in a contract. May be negative or positive. Negative for ``A(B)`` if ``A(B)`` received more tokens than it spent. For example ``net_balance(A) = transferred_amount(A) - transferred_amount(B)``

   Challenge Period
       The state of a channel initiated by one of the channel participants. This phase is limited for a period of ``n`` block updates.

   Challenge Period Update
       Update of the channel state during the :term:`Challenge period`. The state can be updated either by the channel participants, or by a delegate (:term:`MS`).

   Settlement Window
   Settle Timeout
       The number of blocks from the time of closing of a channel until it can be settled.

   Reveal Timeout
          The number of blocks in a channel allowed for learning about a secret being revealed through the blockchain and acting on it.

   Settle Expiration
       The exact block at which the channel can be settled.

   Fee Model
       Total fees for a Mediated Transfer announced by the Raiden Node doing the Transfer.

   Secret
       A value used as a preimage in a :term:`Hash Time Locked Transfer`. Its size should be 32 bytes.

   Partner
       The other node in a channel. The node with which we have an open :term:`Payment Channel`.

   Participants
       The two nodes participating in a :term:`Payment Channel` are called the channel's participants.

   Additional Hash
   additional_hash
       Hash of additional data (in addition to a balance proof itself) used on the Raiden protocol (and potentially in the future also the application layer). Currently this is the hash of the offchain message that contains the balance proof. In the future, for example, some form of payment metadata can be hashed in.

   Payment Receipt
       TBD
