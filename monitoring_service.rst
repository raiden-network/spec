Raiden Network Monitoring Service
#################################


Basic requirements for the MS
=============================
* Good enough uptime (a third party service to monitor the servers can be used to provide statistics)
* Sybil Attack resistance (i.e. no one should be able announce an unlimited number of (faulty) services)
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



Broadcast
================

 All monitoring services listen on a global shared chat room for balance proofs that act as requests to monitor a given channel. The incentive for providing the service is simply to collect as many BPs as possible and use  them as a challenge if a close event with an incorrect BP occurs. The first service that updates the channel collects the fee.

Pros and cons
-------------

Pros:

* Easier Implementation (simply dump to a channel)
* Better privacy for MS - IPs are not exposed anywhere, MS just passively collects messages posted into the channel

Cons:

* Privacy (everyone can see all reported balance updates, i.e. reconstruct transfers)
* Scalability (number of concurrent transfers in the network become bounded by the chat rooms throughput, can be solved with sharding but increases complexity)
* Handling and payout of fees is more complicated (probably)


General requirements
--------------------

MS that wish to get assigned a MS address (term?) in the global chat room MUST provide a registration deposit via SC [TBD]

Users wishing to use a MS are RECOMMENDED to provide a reward deposit via smart contract [TBD]

Users that want channels to be monitored MUST post BPs concerning those channels to the global chat room along with the reward amount they’re willing to pay for the specific channel. They also MUST provide proof of a deposit equal to or exceeding the advertised reward amount. The offered reward amount MAY be zero.

Monitoring services MUST listen in the provided global chat room

They can decide to accept any balance proofs that are submitted to the chat room.

Once it does accept a BP it MUST provide monitoring for the associated channel at least until a newer BP is provided or the channel is closed. MS SHOULD continue to accept newer balance proofs for the same channel.

MS MUST listen for the `ChannelClosed` event for channels that it is monitoring. 

Once a `ChannelClosed` event is seen the MS MUST verify that the channel’s balance matches the latest BP it accepted. If the balances do not match the MS MUST submit that BP to the channel’s `updateTransfer` method.

[TBD] There needs to be a selection mechanism which MS should act at what time (see below in “notes / observations”)

MS SHOULD inspect pending transactions to determine if there are already pending calls to `updateTransfer` for the channel. If there are a MS SHOULD delay sending its own update transaction. (Needs more details)


    
Fees/Rewards structure
----------------------

In Broadcast mode, monitoring servers compete to be the first to provide a balance proof update. This mechanism is simple to implement: MS will decide if the risk/reward ratio is worth it and submits an on-chain transaction.

Fees have to be paid upfront. A smart contract governing the reward payout is required, and will probably add an additional logic to the NettingChannel contract code.


How fees work in Broadcast mode is still unclear - SC for the fee collection and reward payout must be spec’d properly.


Proposed SC logic
'''''''''''''''''

1) Raiden node will transfer tokens used as a reward to the NettingChannelContract
2) Whoever calls SC’s updateTransfer method MUST supply payout address as a parameter. This address is stored in the SC. updateTransfer MAY be called multiple times, but it will only accept BP newer than the previous one.
3) When settling (calling contract suicide), the reward tokens will be sent to the payout address.
