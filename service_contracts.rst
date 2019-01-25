Smart Contracts for Raiden Services
###################################

Overview
========

The Raiden services (:ref:`MS` and :ref:`PFS`) require a set of smart contracts to function. There are two general smart contracts:

* UserDeposit
* RaidenServiceBundle

and one additional contract for each of the services

* MonitoringService, used as integral part of how the MS functions
* OneToN, a minimal one-to-N payment solution used to pay fees to the PFS

which depend on the former two contracts.

.. image:: diagrams/sercon_overview.png
    :alt: Service Contracts Overview

There might also be an additional contract to facilitate the onboarding of new Raiden users, which has been called "`Hub Contract`_" in some discussions. There are no detailed plans for that contract, yet.

.. _Hub Contract: https://github.com/raiden-network/spec/issues/120


RaidenServiceBundle
===================

The RaidenServiceBundle provides a registry in which services have to register before becoming a full part of the Raiden services system. Services have to deposit RDN tokens in this contract for a successful registration. This avoids attacks using a large number of services and increases the incentive for service provider to not harm the Raiden ecosystem.


UserDeposit
===========

The Raiden services will ask for payment in RDN. The Monitoring Service and the Pathfinding Service require deposits to be made in advance of service usage. These deposits are handled by the User Deposit Contract.
Usage of the deposit for payments is not safe from double spending, but measures can be taken to reduce the likelihood to acceptable levels. This is a good trade off as long as the money lost on double spending is less than the savings in gas cost.

Requirements
------------

- Users can deposit and withdraw tokens.
- Tokens can be deposited to the benefit of other users. This could facilitate onboarding of new Raiden users and allow a MS to defer the monitoring to another MS.
- Tokens can't be withdrawn immediately, but only after a certain delay. This allows services to claim their deserved payments before the withdraw takes place.
- Services can read the effective balance of a user (current balance - planned withdrawals)
- Service contracts are trusted and can claim tokens for the service providers.
- Services can listen to events which notify them of decreasing user balances. A service can then claim payments before double spending becomes too likely.

Use cases
---------

Monitoring Service rewards
^^^^^^^^^^^^^^^^^^^^^^^^^^
The MS is promised a reward for each settlement in which it took part on behalf of the non-closing participant. Before accepting a monitor request, the MS checks if enough tokens are deposited in the UDC. The MS that has submit the latest BP upon settlement will receive the promised tokens on it's UDC balance.

1-n payments
^^^^^^^^^^^^
The PFS will be paid with signed IOUs, roughly a simplified uRaiden adapted to 1-n payments. The IOU contains the amount of tokens that can be claimed from the signer's UDC balance. See `OneToN`_ for details.


.. _OneToN:

OneToN
======

Specification in progress. See https://github.com/raiden-network/raiden-services/issues/38.


MonitoringService
=================

The :ref:`MS` submits an up-to-date :term:`balance proof` on behalf of users who are offline when a channel is closed to prevent them from losing tokens. This could be done without a dedicated contract by calling `TokenNetwork.updateNonClosingBalanceProof <update-channel>` but then the MS would not be able to claim a reward for its work.
To handle the rewards, the MonitoringService contract provides two functions. One for wrapping `updateNonClosingBalanceProof` and creating the reward and another one for claiming the reward after the settlement:

.. autosolcontract:: MonitoringService
    :members: monitor, claimReward


