Smart Contracts for Raiden Services
###################################

Overview
========

The Raiden services (:ref:`MS` and :ref:`PFS`) require a set of smart contracts to function. There are two general smart contracts:

* UserDeposit
* ServiceRegistry

and one additional contract for each of the services

* MonitoringService, used as integral part of how the MS functions
* OneToN, a minimal one-to-N payment solution used to pay fees to the PFS

which depend on the former two contracts.

.. image:: diagrams/sercon_overview.png
    :alt: Service Contracts Overview

There might also be an additional contract to facilitate the onboarding of new Raiden users, which has been called "`Hub Contract`_" in some discussions. There are no detailed plans for that contract, yet.

.. _Hub Contract: https://github.com/raiden-network/spec/issues/120


.. _ServiceRegistry:

ServiceRegistry
===============

The ServiceRegistry provides a registry in which services have to register before becoming a full part of the Raiden services system. Services have to deposit RDN tokens in this contract for a successful registration. This avoids attacks using a large number of services and increases the incentive for service provider to not harm the Raiden ecosystem.


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

Overview
--------

The OneToN contract handles payments for the PFS. It has been chosen with the
following properties in mind:

-  easy to implement
-  low initial gas cost even when fees are paid to many PFSs
-  a certain risk of double spends is accepted

The concept is based on the idea to use a user's single deposit in the
UDC as a security deposit for off-chain payments to all PFSs. The client
sends an IOU consisting of (sender, receiver, amount, expiration,
signature) to the PFS with every path finding request. The PFS verifies
the IOU and checks that ``amount >= prev_amount + pfs_fee``. At any
time, the PFS can claim the payment by submitting the IOU on-chain.
Afterwards, no further IOU with the same (sender, receiver, expiration)
can be claimed.

Related:

-  `https://github.com/raiden-network/team/issues/257`_
-  `https://github.com/raiden-network/team/issues/256`_
-  `https://gist.github.com/heikoheiko/214dbbd954e0f97e0e13b2fefdc7c753`_

.. _`https://github.com/raiden-network/team/issues/257`: https://github.com/raiden-network/team/issues/257
.. _`https://github.com/raiden-network/team/issues/256`: https://github.com/raiden-network/team/issues/256
.. _`https://gist.github.com/heikoheiko/214dbbd954e0f97e0e13b2fefdc7c753`: https://gist.github.com/heikoheiko/214dbbd954e0f97e0e13b2fefdc7c753

Requirements
------------

-  low latency (<1s)
-  reliability, high probability of success (P > 0.99)
-  low cost overhead (<5% of transferred amount)
-  low fraud rate (< 3%, i.e. some fraud is tolerable)
-  can be implemented quickly

Communication between client and PFS
------------------------------------

When requesting a route, the IOU is added as five separate arguments to
the `existing HTTP query params`_.

.. _`existing HTTP query params`: https://raiden-network-specification.readthedocs.io/en/latest/pathfinding_service.html#arguments

.. raw:: html

   <table>
     <tr><th>Field Name</th><th>Field Type</th><th>Description</th></tr>
     <tr><td>sender</td><td>address</td><td></td></tr>
     <tr><td>receiver</td><td>address</td><td></td></tr>
     <tr><td>amount</td><td>uint256</td><td></td></tr>
     <tr><td>expiration_block</td><td>uint256</td><td>last block in which the IOU can be claimed</td></tr>
     <tr><td>signature</td><td>bytes</td><td>Signature over (`\x19Ethereum Signed Message:\n`, message_length, sender, receiver, amount, expiration_block) signed by sender's private key</td></tr>
   </table>

The PFS then thoroughly checks the IOU:

-  Is the PFS the receiver
-  Did the amount increase enough to make the request profitable for the
   PFS (``amount >= prev_amount + pfs_fee``)
-  Is ``expiration_block`` far enough in the future to potentially
   accumulate a reasonable amount of fees and claim the payment
-  Is the IOU for (sender, receiver, expiration) still unclaimed
-  Did the client create too many small IOU instead of increasing the
   value of an existing one? This would make claiming the IOU
   unprofitable for the PFS
-  Is the signature valid
-  Is the deposit much larger than ``amount``

If one of the conditions is not met, a corresponding error message is
returned and the client can try to submit a request with a proper IOU or
try a different PFS. Otherwise, the PFS returns the requested routes as
described in the current spec and saves the latest IOU for this (sender,
expiration_block).


Claiming the IOU
----------------

A OneToN contract (OTNC) which is trusted by the UDC accepts IOUs (see
table above for parameters) and uses the UDC to transfer ``amount`` from
``sender`` to ``receiver``. The OTNC stores a mapping
``hash(receiver, sender, expiration_block) => expiration_block`` to make
sure that each IOU can only be claimed once. To make claims more gas
efficient, multiple claims can be done in a single transaction and
expired claims can be removed from the storage.

Expiration
----------

Having the field ``expiration_block`` as part of the IOU serves multiple
purposes:

-  Combined with the ``sender`` and ``receiver`` fields it identifies a
   single payment session. Under this identifier, multiple payments are
   aggregated by continuously increasing the ``amount`` and only a
   single on-chain transaction is needed to claim the total payment sum.
   After claiming, the identifier is stored on-chain and used to prevent
   the receiver from claiming the same payments, again.
-  When old IOUs have expired (``current_block > expiration_block``),
   the sender can be sure that he won't have to pay this IOU. So after
   waiting for expiry, the sender knows that IOUs which have been lost
   for some reason (e.g. disk failure) won't be redeemed and does not
   have to prepare for unpredictable claims of very old IOUs.
-  Entries can be deleted from the
   ``hash(receiver, sender, expiration_block) => expiration_block``
   mapping which is used to prevent double claims after expiry. This
   frees blockchain storage and thereby reduces gas costs.

Double Spending
---------------

Since the same deposit is used for payments to multiple parties, it is
possible that the deposit is drained before each party has been paid.
This is an accepted trade-off, because the amounts are small and low gas
costs are more important, as long as the actual double spending does not
reach a high level. To somewhat reduce the risks of double spends, the
following precautions are taken:

-  Users can't immediately withdraw tokens from the UDC. They first have
   to announce their intention and then wait until a withdraw delay has
   elapsed.
-  The PFS demands a higher deposit than it's currently owed ``amount``
   to give it some safety margin when other parties claim tokens
-  Only PFSs registered in the ServiceRegistry are allowed to claim IOUs. This is
   important because claims allow circumventing the UDC's withdraw
   delay.

A user and a PFS can theoretically collude to quickly withdraw the
complete deposit (via a claim) before other services are paid. This
should be unlikely due to the following aspects:

-  The savings achieved by cheating the other services are low compared
   to the coordination cost for the collusion
-  The PFS is itself a party receiving payments of services and does not
   want to promote cheating against services
-  If this becomes widespread, cheating users can theoretically be
   blacklisted by PFSs. This will require them to close their existing
   channels and reopen new channels at a cost which will most likely be
   higher than the profit gained by cheating


MonitoringService
=================

The :ref:`MS` submits an up-to-date :term:`balance proof` on behalf of users who are offline when a channel is closed to prevent them from losing tokens. This could be done without a dedicated contract by calling `TokenNetwork.updateNonClosingBalanceProof <update-channel>` but then the MS would not be able to claim a reward for its work.
To handle the rewards, the MonitoringService contract provides two functions. One for wrapping `updateNonClosingBalanceProof` and creating the reward and another one for claiming the reward after the settlement:

.. autosolcontract:: MonitoringService
    :members: monitor, claimReward


