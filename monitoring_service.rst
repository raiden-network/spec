Raiden Network Monitoring Service
#################################


Basic requirements for the MS
=============================
* Good enough uptime (a third party service to monitor the servers can be used to provide statistics)
* Sybil Attack resistance (i.e. no one should be able to announce an unlimited number of (faulty) services)
* Some degree of redundancy (ability to register balance proof with multiple competing monitoring services)
* A stable and fast ethereum node connection (channel update transactions should be propagated ASAP as there is competition among the monitoring services)
* If MS registry is used, a deposit will be required for registration

Usual scenario
==============

The Raiden node that belongs to Alice is going offline and Alice wants to be protected against having her channels closed by Bob with an incorrect :term:`balance proof`.

1) Alice broadcasts the balance proof by sending a message to a public chat room.
2) Monitoring services decide if the fee is worth it and picks the balance proof up.
3) Alice now goes offline.
4) Bob sends an on-chain transaction in attempt to use an earlier balance proof that is in his favor.
5) Some of the monitoring servers detect that an incorrect :term:`BP` is being used. They can update the channel closing state as long as the :term:`Challenge Period` is not over.
6) After the Challenge period expires, the channel can be settled with a balance that Alice expects to be correct.

Economic incentives
===================

Raiden node
-----------
A Raiden node wants to register its :term:`BP` to as many Monitoring Services as possible. The cost of registering should be strictly less than a potential token loss in case of malicious channel close by the other participant.


Monitoring service
------------------
:term:`Monitoring Service` is motivated to collect as many BP as possible, and the reward **should** be higher than cost of sending the :term:`Challenge Period Update`. The reward collected over the time **should** also cover costs (i.e. electricity, VPS hosting...) of running the service.


General requirements
--------------------

MS that wish to get assigned a MS address (term?) in the global chat room MUST provide a registration deposit via SC [TBD]

Users wishing to use a MS are RECOMMENDED to provide a reward deposit via smart contract [TBD]

Users that want channels to be monitored MUST post BPs concerning those channels to the global chat room along with the reward amount they’re willing to pay for the specific channel. They also MUST provide proof of a deposit equal to or exceeding the advertised reward amount. The offered reward amount MAY be zero.

Monitoring services MUST listen in the provided global chat room

They can decide to accept any balance proofs that are submitted to the chat room.

Once it does accept a BP it MUST provide monitoring for the associated channel at least until a newer BP is provided or the channel is settled. MS SHOULD continue to accept newer balance proofs for the same channel.

Once a `ChannelClosed` or `NonClosingBalanceProofUpdated` event is seen the MS MUST verify that the channel’s balance matches the latest BP it accepted. If the balances do not match the MS MUST submit that BP to the channel’s `updateNonClosingBalanceProof` method.

[TBD] There needs to be a selection mechanism which MS should act at what time (see below in “notes / observations”)

MS SHOULD inspect pending transactions to determine if there are already pending calls to `updateTransfer` for the channel. If there are a MS SHOULD delay sending its own update transaction. (Needs more details)


    
Fees/Rewards structure
----------------------

Monitoring servers compete to be the first to provide a balance proof update. This mechanism is simple to implement: MS will decide if the risk/reward ratio is worth it and submits an on-chain transaction.

Fees have to be paid upfront. A smart contract governing the reward payout is required, and will probably add an additional logic to the channel contract code.


Proposed SC logic
'''''''''''''''''

1) Raiden node will transfer tokens used as a reward to the channel smart contract.
2) Whoever calls SC’s updateTransfer method MUST supply payout address as a parameter. This address is stored in the SC. updateTransfer MAY be called multiple times, but it will only accept BP newer than the previous one.
3) When settling (calling contract suicide), the reward tokens will be sent to the payout address.

Notes/observations
------------------

How will raiden nodes specify/deposit the monitoring fee? How will it be collected?

A scheme to prevent unnecessary simultaneous updates needs to exist. Options:
MS chose an order amongst themselves

Appendix A: Interfaces
======================

Broadcast interface
-------------------
Client's request to store Balance Proof will be in the usual scenario broadcasted using Matrix as a transport layer. A public chatroom will be available for anyone to join - clients will post balance proofs to the chatroom and Monitoring Service picks them up.

Web3 Interface
--------------
Monitoring service requires a synced Ethereum node with an enabled JSON-RPC interface. All blockchain operations are performed using this connection.

Event filtering
'''''''''''''''
MS MUST filter events for each onchain channel that corresponds to the submitted Balance Proofs.
On ``ChannelClosed`` and ``NonClosingBalanceProofUpdated`` events state the channel was closed with MUST be compared with the Balance Proof. In case of any discrepancy, channel state must be updated immediately.
On ``ChannelSettled`` event any state data for this channel MAY be deleted from the MS.

REST interface
--------------
The monitoring service MAY expose some of the functionality over RESTful API.
There might be API endpoints that SHOULD be protected from public access (i.e. using some form of authentication).

Endpoints
'''''''''
* ``GET /api/1/balance_proofs`` - return a JSON list of known balance proofs
* ``DEL /api/1/balance_proofs/<channel_address>`` - remove balance proof from the internal database
* ``PUT /api/1/balance_proofs`` - register a balance proof

* ``GET /api/1/channel_update`` - return a JSON list of already performed channel updates.
* ``GET /api/1/channel_update/<channel_address>`` - return a list of updates for a given channel

* ``GET /api/1/stats`` - various statistics of the server, including count of balance proofs stored, count of balance proofs submitted, count of unique Participants etc.

Appendix B: Message format
==========================
Monitoring service uses JSON format to exchange the data.
For description of the envelope format and required fields of the message please see Transport document.


Balance proof
-------------
* nonce (uint64) - it is expected that nonce is incremented by 1 with each Balance Proof exchanged between Channel Participants
* transferred_amount (uint256) - amount of tokens transferred
* channel_address (address) - address of the netting channel
* locksroot (bytes32) - lock root state of the channel
* extra_hash (bytes32) - implementation dependent extra data
* signature (bytes32) - ecrecoverable signature of the data above, in order they are listed here

All of this fields are required. Monitoring Service MUST perform basic verification of these data, namely channel existence. Monitoring service SHOULD accept the message if and only the sender of the message is same as the sender address recovered from the signature.


Example data: Balance proof
---------------------------
::

    {
      'nonce': 13,
      'transferred_amount': 15000,
      'channel_address': '0x87F5636c67f2Fd4F11710974766a5B1b6f33FB1d',
      'extra_hash': '0xe0fa3e376941dafc9b3836f80bee307ab2eacb569ec7ccceff5e66b48b1efd9c',
      'locksroot': '0xebd7dc7d6dd7956e62104182194939a1223c738ffc2a14dbbecb6191cf76f211',
      'signature': '0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470'
    }
