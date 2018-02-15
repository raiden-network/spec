Raiden Network Monitoring Service
#################################


Terminology
===========
* *Monitoring Service (MS)* - a server (or a swarm of servers) that monitors & prevents the channel being closed with unexpected or unwanted balance proof.
* *Challenge period* - the state of a channel initiated by one of the channel participants. This phase is limited for a period of n block updates. (also called Challenge Period)
* *Challenge period Update* - update of the channel state during the Challenge period. The state can be updated either by the channel participants, or by a delegate (MS)
* *Balance Proofs* (BP) - a signed cryptographical proof of a balance state of the channel
* *User* - operator of a Raiden node willing to use Monitoring Services
* *Fee* - price paid by the User for the MS operation
* *Reward* - tokens collected by the MS operator for performing successful Challenge period Update

Usual scenario
==============

Raiden node that belongs to Alice is going offline and Alice wants to be protected against having her channels closed by Bob with an incorrect balance proof.

1) Alice broadcasts the balance proof by sending a message to a public chat room
2) Monitoring services decide if the fee is worth it and pick the balance proof 
3) Alice now goes offline
4) Bob sends an on-chain transaction in attempt to use an earlier balance proof that’s in his favor
5) Some of the monitoring servers detect that an incorrect BP is being used. They can update the channel closing state as long as the Challenge period is not over.
6) After the Challenge period expires, the channel can be settled with a balance that Alice expects to be correct.

Economic incentives
===================

Raiden node
-----------
Raiden node wants to register its BP to as many Monitoring Services as possible, while the cost of doing so should be less than loss in case of malicious channel close by the other participant.


Monitoring service
------------------
Monitoring service is motivated to collect as many BP as possible, and the reward SHOULD be higher than cost of sending the Challenge Update. The reward collected over the time SHOULD also cover costs (i.e. electricity, VPS hosting...) of running the service.

Basic requirements for the MS
=============================
* Good enough uptime (a third party service to monitor the servers can be used to provide statistics)
* Sybil Attack resistance (i.e. no one should be able announce an unlimited number of (faulty) services)
* Some degree of redundancy (ability to register balance proof with multiple competing monitoring services)
* A stable and fast ethereum node connection (channel update transactions should be propagated ASAP as there is competition among the monitoring services)
* If MS registry is used, a deposit will be required for registration


Implementation options
-----------------------

* Broadcast: All monitoring services listen on a global shared chat room for balance proofs that act as requests to monitor a given channel. This is the version we will implement.
* Selective: Users select monitoring services explicitly from a registry or similar and directly provide balance proofs to them

Spec “broadcast”
================

The incentive for providing the service is simply to collect as many BPs as possible and use  them as a challenge if a close event with an incorrect BP occurs. The first service that updates the channel collects the fee.

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


Notes/observations
------------------
The NettingChannelContract/Library as it is now doesn’t allow more than one updated BP to be submitted. 
The contract also doesn’t check if the updated BP is newer than the already provided one
How will raiden nodes specify/deposit the monitoring fee? How will it be collected?

A scheme to prevent unnecessary simultaneous updates needs to exist. Options:
MS chose an order amongst themselves

Pro:

* Easy to understand

Con:

* Complex to implement
* Prone to communications failure
* A deterministic algorithm assigns time slots within the Challenge period where MS are allowed to submit BPs (needs to tie in with the reward SC)

Pro:

* (Relatively) easy to implement

Con:

* Constraints the available time for providing BPs per MS which could lead to missed / failed updates
* Increased complexity in reward SC
* Variant of the above: As the end of the Challenge period approaches the algorithm allows increasing numbers of MSs to act simultaneously. This increases the chances of a successful update while preventing unnecessary ones in the common case.
* ‘Auction’ approach: the reward decreases depending on time/number of participants
* Mempool monitoring - if there’s multiple txs performing Closing Update, it’s less likely the MS is going to succeed



Spec “selective”
================
Client will select a service he trusts and will submit the balance proof to it.

General requirements
--------------------
MS SHOULD register themselves in [TBD] (list in a smart contract w/ required deposit for a registration? Also announce fee type and amount via this channel) 

Users wishing for a specific channel to be monitored choose one or more MS from the registry. (Could be automated through the raiden node) (Selecting a MS not in the registry is also in theory possible)

Users are RECOMMENDED to register BPs with multiple MS for increased availability and robustness.

The users provide updated BP to the selected MS via i.e. REST-API

Once the MS accepted a BP via the API it MUST monitor the associated channel until close.

MS MUST listen for the `ChannelClosed` event for channels that it is monitoring. 

Once a `ChannelClosed` event is seen the MS MUST verify that the channel’s balance matches the latest BP it accepted. If the balances do not match the MS MUST submit that BP to the channel’s `updateTransfer` method.

Choosing a service to use

A smart contract will maintain a list of trusted services. To prevent griefing attacks, MS that wants to be included in the list will register itself by depositing a reasonable amount of ETH. Another option is a community-curated list. 

Raiden node will then pick one or more MS from the list, depending on the required degree of redundancy.

Pros and cons
-------------

Pros:

* Better Privacy of Raiden nodes
* Fewer scalability concerns

Cons:

* More complicated Implementation
* Problem of selecting partner(s) to trust
* Easier to DDoS the MS


Fees/Rewards structure
----------------------

Subscription based
''''''''''''''''''
A subscription based payments might be useful with this approach. A time-based or membership fee can be used.

Payment per BP submitted
''''''''''''''''''''''''
A small fee is collected for every BP submit. As the fees will probably be too low to be sent as an on-chain transaction, a Raiden (or uRaiden) payment channel between client and service should be used.

Reward for successful update of a closing channel
'''''''''''''''''''''''''''''''''''''''''''''''''
A smart contract may release the reward to the last participant who submitted the BP. See discussion in Broadcast spec.






Problems to consider
====================


Griefing Attack against Monitoring Service (e.g. to distract competitors)
-------------------------------------------------------------------------
An adversary would not provide recent BPs and the MS would try to update the Closing with an outdated BP, which would not be accepted in the end, i.e. would not be eligible for the reward but would have TX cost. 

Multiple Reward Claiming attack against User
--------------------------------------------
If rewards could be claimed before settlement of a channel, then monitoring services could update the closing channel multiple times with old BPs and claim multiple rewards. 

Blockchain spamming
-------------------
Multiple MS may submit the Challenge Period Update, but only one of them will correct the reward, making the other transactions useless. 

Chain congestion
----------------
If there are too many transaction pending to be mined, Challenge Period Update may not be mined in time. 

Gas price
---------
If gas price is too high, and reward to be collected is too low, MS may choose not to perform the update.

Recovery of the reward by the Raiden Client
-------------------------------------------
What will happen if the Raiden node comes back online? Should it be possible to get the monitoring service fee back?

Challenge Period Update of the channel with no reward attached
--------------------------------------------------------------
It should be possible to submit BP with no reward for doing the Challenge Period Update. 

Trust of services
-----------------
How will monitoring services gain trust? Will there eventually be a third-party service to provide statistics of servers’ uptime?

