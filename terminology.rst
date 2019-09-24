Terminology
===========

.. glossary::
   :sorted:

   payment
       The process of sending tokens from one account to another. May be composed of multiple transfers (Direct or HTL). A payment goes from :term:`Initiator` to :term:`Target`.

   payment channel
       An object living on a blockchain that has all the capabilities required to enable secure off-chain payment channels.

   channel identifier
       Identifier assigned by :term:`Token Network` to a :term:`Payment Channel`. Must be unique inside the :term:`Token Network` contract. See the :ref:`implementation definition <channel-identifier>`.

   canonical identifier
       The globally unique identifier of a channel, consisting of the :term:`channel identifier`, the :term:`token network address` and the :term:`chain id`.

   Unidirectional Payment Channel
       Payment Channel where the roles of :term:`Initiator` and :term:`Target` are determined in the channel creation and cannot be changed.

   Bidirectional Payment Channel
       Payment Channel where the roles of :term:`Initiator` and :term:`Target` are interchangeable between the channel participants.

   Raiden Channel
       The Payment Channel implementation used in Raiden.

   Token Network
       A network of payment channels for a given Token.

   Token Network Address
       The ethereum address on which the :ref:`contract <token-network-contract>`
       representing a :term:`token network` is deployed.
       It serves as the identifier of the token network and as part of the
       :term:`canonical identifier` of channels within the token network.

   Raiden Network
       A collection of :term:`Token networks <Token Network>`.

   Transfer
       A movement of tokens from a :term:`Sender` to a :term:`Receiver`.

   Token Swaps
       Exchange of one token for another.

   HTL Transfer
       An expirable potentially cancellable Transfer secured by a :term:`Hash Time Lock`.

   Hash Time Locked Transfer
   Mediated Transfer
       A token Transfer composed of multiple :term:`HTL transfers <HTL Transfer>`.

   Hash Time Lock
   HTL
       An expirable lock locked by a secret.

   HTL Unlock
       The action of unlocking a given :term:`Hash Time Lock`. This is the message used to finalize a transfer once the path is found and the reserve is acknowledged.

   lock expiration
       The lock expiration is the highest block_number until which the transfer can be settled.

   locksroot
       The hash of the pending locks. To compute this, encode all pending locks in binary, and hash the concatenation using ``sha3_keccak``.

   lockhash
       The hash of a lock.  ``sha3_keccack(lock)``

   locked amount
       Total amount of tokens locked in all currently pending :term:`HTL` transfers sent by a channel participant. This amount corresponds to the :term:`locksroot` of the HTL locks.

   balance data
       The data relevant to a channel's balance: :term:`locked amount`, :term:`transferred amount` and :term:`locksroot`.

   secrethash
       The hash of a :term:`secret`.  ``sha3_keccack(secret)``

   balance proof
   BP
       Signed data required by the :term:`Payment Channel` to prove the balance of one of the parties. Different formats exist for off-chain communication and on-chain communication.  See the :ref:`on-chain balance proof definition <balance-proof-on-chain>` and :ref:`off-chain balance proof definition <balance-proof-off-chain>`.

   balance proof update
       Signed balance proof with a countersignature.  Depending on the message ID, a balance proof update message either shows the second signer's intention to close the channel (with a ``closeChannel()`` call) or submit the balance proof during the settlement period (with an ``updateNonClosingBalanceProof()`` call).

   withdraw proof
   Participant Withdraw Proof
       Signed data required by the :term:`Payment Channel` to allow a participant to withdraw tokens. See the :ref:`message definition <withdraw-proof>`.

   cooperative settle proof
       Signed data required by the :term:`Payment Channel` to allow :term:`Participants` to close and settle a :term:`Payment Channel` without undergoing through the :term:`Settlement Window`. See the :ref:`message definition <cooperative-settle-proof>`.

   nonce
       Strictly monotonic value used to order off-chain transfers. It starts at ``1``. It is a :term:`balance proof` component. The ``nonce`` differentiates between older and newer balance proofs that can be sent by a delegate to the :term:`Token Network` contract and updated through :ref:`updateNonClosingBalanceProof <update-channel>`.

   chain id
       Chain identifier as defined in EIP155_.

       .. _EIP155: https://eips.ethereum.org/EIPS/eip-155

   Message
       Any message sent from one Raiden Node to the other.

   Initiator
       The node that sends a :term:`Payment`.

   Target
       The node that receives a :term:`Payment`.

   Mediator
       A node that mediates a :term:`Payment`.

   Sender
       The node that is sending a :term:`Message`.  The address of the sender can be inferred from the signature.

   Receiver
       The node that is receiving a Message.

   Locked Transfer
   Locked Transfer message
       A message that reserves an amount of tokens for a specific :term:`Payment`. See :ref:`locked-transfer-message` for details.

   Refund Transfer
   Refund Transfer message
       A message for a :term:`Transfer` seeking a rerouting. When a receiver of a :term:`Locked Transfer` message gives up reaching the target, they return a Refund Transfer message. The Refund Transfer message locks an amount of tokens in the direction opposite from the previous :term:`Locked Transfer` allowing the previous hop to retry with a different path.

   Monitoring Service
   MS
       The service that monitors channel state on behalf of the user and takes an action if the channel is being closed with a balance proof that would violate the agreed on balances. Responsibilities
       - Watch channels
       - Delegate closing

   Pathfinding Service
       A centralized path finding service that has a global view on a token network and provides suitable payment paths for Raiden nodes.

   Unlock
   Unlock message
       A message that contains a new :term:`balance proof` after a :term:`Hash Time Lock` is unlocked.  See :ref:`unlock-message` for details.

   Raiden Light Client
       A client that does not mediate payments.

   Sleeping Payment
       A payment received by a :term:`Raiden Light Client` that is not online.

   Capacity
       Current amount of tokens available for a given participant to make transfers.  See :ref:`settlement-algorithm` for how this is computed.

   Deposit
       Amount of token locked in the contract.

   Transferred amount
       Monotonically increasing amount of tokens transferred from one Raiden node to another. It represents all the finalized transfers. For the pending transfers, check :term:`locked amount`.

   Net Balance
       Net of balance in a contract. May be negative or positive. Negative for ``A(B)`` if ``A(B)`` received more tokens than it spent. For example ``net_balance(A) = transferred_amount(A) - transferred_amount(B)``

   Challenge Period Update
       Update of the channel state during the :term:`Challenge period`. The state can be updated either by the non-closing participant, or by a delegate (:term:`MS`).

   Challenge Period
   Settlement Window
   Settle Timeout
       The state of a channel after one channel participant closes the channel. During this period the other participant (or any delegate) is able to provide balance proofs by calling :ref:`updateNonClosingBalanceProof() <update-channel>`. This phase is limited for a number of blocks, after which the channel can be :ref:`settled <settle-channel>`. The length of the challenge period can be configured when each channel is opened.

   Secret Request
       A message from the target that asks for the :term:`secret` of the payment. See :ref:`secret-request-message` for details.

   Reveal Secret
   Reveal Secret message
       A message that contains the secret that can open a :term:`Hash Time Lock`. See :ref:`reveal-secret-message` for details.

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

   additional hash
   additional_hash
       Hash of additional data (in addition to a balance proof itself) used on the Raiden protocol (and potentially in the future also the application layer). Currently this is the hash of the off-chain message that contains the balance proof. In the future, for example, some form of payment metadata can be hashed in.

   amount
        Number of tokens that is referred to in a specific message, e.g. amount in :term:`locked transfer` means number of tokens to be added to the already locked tokens as part of a transfer

   expiration
        Specific block after which the lock in the :term:`locked transfer` expires
