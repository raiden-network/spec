.. _ms:

Monitoring Service
##################


Overview
========

Monitoring services watch open payment channels when the user is not online. In
case one channel partner closes a channel while the counterparty is offline (or
doesn’t react for 80% of the settlement timeout after close has been called),
the monitoring service sends the latest balance proof to the channel smart
contract and thus ensures correct settlement of the channel.

To do this a Monitoring Service (MS) listens to :ref:`Monitor Requests <Monitor
Request>` in a public Matrix room. An MR is accompanied by a reward for acting
on it. Based on this reward, the MS can decide to monitor a channel and store
the corresponding MRs.

Whenever a channel is closed by calling ``closeChannel`` and if the client did
not react itself, the MS will call ``updateNonClosingBalanceProof`` with the
submitted MR on behalf of its client. For that action then MS can then claim the
reward from the :ref:`Monitoring Service contract <MonitoringServiceContract>`.

Information Flow
================

.. image:: diagrams/RaidenMonitoringService_flow_chart.png
    :alt: Monitoring Service - Flow Chart
    :width: 900px


Design of the Monitoring Service
================================

Requirements
------------

* Sybil Attack resistance (i.e. no one should be able to announce an unlimited number of possibly faulty services)
* Some degree of redundancy (ability to register a balance proof with multiple competing monitoring services)

In the current stage we opt for a simple design which is expected to help reach
a working state faster. Therefore some user friendly features are currently out
of scope.


Monitoring Service Payment
--------------------------

The MS can claim its reward after successfully submitting its client’s balance proof update. This is only allowed when the Monitoring Service is registered in the Service Registry. For more infos see the :ref:`ServiceRegistry` contract.

The payment is paid out from a deposit in the :ref:`UserDeposit` Contract (UDC).
Ideally, only one MS submits the latest BP to the SC to avoid unnecessary gas
usage (for more infos see the description of the :ref:`Monitoring Service contract <MonitoringServiceContract>`.


MS Reliability
--------------

The Monitoring Service itself is split into two components to increase reliability and lower the attack surface.

* The request collector is a simple component that connects to the Matrix network and listens only for :ref:`Monitor Requests <Monitor Request>`, which are written to a database.
* The monitoring service itself just reads these MRs from the database and otherwise listens and reacts to blockchain events.


Privacy
-------

The recipient and the actual transferred amounts are hidden by providing a
hashed balance proof. This provides some sort of privacy even if it can
potentially be recalculated. For reference see `this issue. <https://github.com/raiden-network/raiden/issues/1309>`_


Message Format
==============

Monitoring Services uses JSON format to exchange the data. For description of
the envelope format and required fields of the message please see Transport
document.

.. _`Monitor Request`:

Monitor Request
---------------

Monitor Requests are messages that the Raiden client broadcasts to Monitoring
Services in order to request monitoring for a channel.

A Monitor Request consists of a the following fields:

+--------------------------+------------+--------------------------------------------------------------------------------+
| Field Name               | Field Type |  Description                                                                   |
+==========================+============+================================================================================+
|  balance_proof           | object     | Latest Blinded Balance Proof to be used by the monitor service                 |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  non_closing_signature   | string     | Signature of the on-chain balance proof by the client                          |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  reward_amount           | uint256    | Offered reward in RDN                                                          |
+--------------------------+------------+--------------------------------------------------------------------------------+
|  reward_proof_signature  | string     | Signature of the reward proof data.                                            |
+--------------------------+------------+--------------------------------------------------------------------------------+

- The balance proof and its signature are described in the :ref:`Balance Proof specification <balance-proof-on-chain>`.
- The creation of the ``non_closing_signature`` is specified in the :ref:`Balance Proof Update specification <balance-proof-update-on-chain>`.
- The ``reward_proof_signature`` is specified below.

All of this fields are required. Monitoring Service MUST perform verification of these data, namely channel
existence. Monitoring service SHOULD accept the message if and only if the sender of the message is same as the sender
address recovered from the signature.


Example Monitor Request
-----------------------------
::

    {
      "balance_proof": {
          "token_network_address": "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
          "chain_id": 1,
          "channel_identifier": 76,
          "balance_hash": "0x1c3a34a22ab087808ba772f40779b04e719080e86289c7a4ad1bd2098a3c751d",
          "nonce": 5,
          "additional_hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
          "signature": "0xd38c435654373983d5bdee589980853b5e7da2714d7bdcba5282ccb88ffd29210c3b1d07313aab05f7d2a514561b6796191093a9ce5726da8f1eb89bc575bc7e1b"
      },
      "non_closing_signature": "0x77857e08793165163380d50ea780cf3798d2132a61b1d43395fc6e4a766f3c1918f8365d3bef173e0f8bb32c1f373be76369f54fb0ac7fdf91dd559e6e5865431b",
      "reward_amount": 1234,
      "reward_proof_signature": "0x12345e08793165163380d50ea780cf3798d2132a61b1d43395fc6e4a766f3c1918f8365d3bef173e0f8bb32c1f373be76369f54fb0ac7fdf91dd559e6e5864444a"
    }

Reward Proof
------------

::

    ecdsa_recoverable(privkey, sha3_keccak("\x19Ethereum Signed Message:\n221"
        || monitoring_service_contract_address || chain_id || MessageTypeId.MSReward
        || token_network_address || non_closing_participant || non_closing_signature || reward_amount ))


Fields
''''''

+-----------------------+------------+--------------------------------------------------------------------------------------------+
| Field Name            | Field Type | Description                                                                                |
+=======================+============+============================================================================================+
| signature_prefix      | string     | ``\x19Ethereum Signed Message:\n``                                                         |
+-----------------------+------------+--------------------------------------------------------------------------------------------+
| message_length        | string     | ``221`` = length of message = ``20 + 32 + 32 + 65 + 20 + 20 + 32``                         |
+-----------------------+------------+--------------------------------------------------------------------------------------------+
| monitoring_service    | address    | Address of the monitoring service contract in which the reward can be claimed              |
| _contract_address     |            |                                                                                            |
+-----------------------+------------+--------------------------------------------------------------------------------------------+
| chain_id              | uint256    | Chain identifier as defined in EIP155                                                      |
+-----------------------+------------+--------------------------------------------------------------------------------------------+
| MessageTypeId.MSReward| uint256    | A constant with the value of 6 used to make sure that no other messages accidentally share |
|                       |            | the same signature.                                                                        |
+-----------------------+------------+--------------------------------------------------------------------------------------------+
| token_network_address | address    | Address of TokenNetwork that the request is about                                          |
+-----------------------+------------+--------------------------------------------------------------------------------------------+
| non_closing_address   | address    | Address of the client that signed ``non_closing_signature``                                |
+-----------------------+------------+--------------------------------------------------------------------------------------------+
| non_closing_signature | bytes      | Signature of the on-chain balance proof by the client                                      |
+-----------------------+------------+--------------------------------------------------------------------------------------------+
| reward_amount         | uint256    | Rewards received for updating the channel                                                  |
+-----------------------+------------+--------------------------------------------------------------------------------------------+
| signature             | bytes      | Elliptic Curve 256k1 signature on the above data from participant paying the reward        |
+-----------------------+------------+--------------------------------------------------------------------------------------------+

Appendix A: Interfaces
======================

Broadcast Interface
-------------------

Client's request to store a balance proof will be broadcasted using Matrix as a
transport layer. A public room will be available for anyone to join - clients
will post balance proofs to the chatroom and Monitoring Services picks them up.

Web3 Interface
--------------

Monitoring Service are required to have a synced Ethereum node with an enabled JSON-RPC interface. All blockchain
operations are performed using this connection.

Event Filtering
'''''''''''''''

MS must filter events for each on-chain channel that corresponds to the submitted balance proofs.
On ``ChannelClosed`` and ``NonClosingBalanceProofUpdated`` events state the channel was closed with the Monitoring
Service must call ``updateNonClosingBalanceProof`` with the respective latest balance proof provided by its client.
On ``ChannelSettled`` event any state data for this channel can be deleted from the MS.


Appendix B: Security Analysis
=============================

This is inspired by the security analysis in the `PISA paper <https://www.cs.cornell.edu/~iddo/pisa.pdf>`_.

State Privacy
-------------

Blinded BPs are published to the MS as part of the Monitor Request in the matrix room and then submitted to the smart
contract.

Fair Exchange
-------------

Clients can freely choose the reward for the MS, so it is easy for him to choose the amount in a way that makes the
exchange attractive for himself. The client can’t know if a MS started monitoring his payment channel, so he can’t use
such feedback to arrive at a reward where he knows that the deal is attractive for both him and the MS. Neither can he
recognize if there is no such possible reward.
The MS on the other hand can freely choose to ignore requests when the reward is too low, so he will only choose
requests that he deems fairly rewarded. If the MS ignores the client’s request, the client keeps his deposit and it can
be used by other MSs or for later BPs. In summary, the exchange is fair for both parties, but there is a high likelihood
that no exchange will happen at all.

Non-frameability
----------------

MSs can put the clients channel deposit at risk by ignoring all client requests. But since a MS can’t force other MSs to
ignore client requests, this can not be considered as framing. When only a single MS is monitoring the channel, the MS’s
dispute intervention and the reward payment happen atomically inside the SC. In this case, no party can frame the other.

When multiple MSs try to settle the same dispute, only the first one doing so receives a reward, but all of them have to
invest resources to monitor the channel and spend gas to interact with the SC. If you find a way to continuously front
run other MSs, you can drain their resources and block their only income. However, while doing so you fulfilled the MS’s
duty to settle the payment channel correctly and protect the client’s deposit.
In the short run, this is an acceptable outcome for the client. In the long run, this will drive other MSs out of
business and thus reduce redundancy and reliability of the overall MS ecosystem. Since all MSs try to be the first to
submit a BP, it is unlikely that a single MS will continuously be the fastest, but slightly slower MSs will still not
get any rewards even if they are well behaved and reliable.

If a client wants to waste the resources of MSs, he can first broadcast a BP with a high reward and keep more recent BPs
to himself. When a dispute happens, he can wait for the MSs to act before submitting his latest BPs, which prevents the
MSs from receiving a reward. Doing this at a large scale is expensive, since the client needs to open and close a
payment channel for this at his own cost.

Recourse as a Financial Deterrent
---------------------------------

There is no possibility of recourse which lets MSs operate without any incentive of high reliability. A client must
expect MSs to ignore their requests and have no means to force a highly reliable monitoring.

Efficiency Requirements
-----------------------

For each channel, only the latest (as indicated by the nonce) BP has to be saved. Unless an extremely high amount of
channels is being monitored, this efficiency should not be a concern for the MS.
A client can use a single deposit to request an MS to monitor all his payment channels. If this causes the MS to monitor
a problematically high amount of channels, he can start to ignore requests made by this client, or even drop old
requests. Since there is no punishment for failing to monitor a channel, stopping to monitor is a simple way to reduce
resource usage when desired, although it should not be necessary under normal circumstances.
