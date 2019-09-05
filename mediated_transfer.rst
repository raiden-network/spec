Mediated transfers
##################

Overview
========

The protocol supports mediated transfers. Nodes may use them to send payments.
A :term:`Mediated transfer` may be cancelled and can expire until the initiator reveals the secret.

A mediated transfer is done in two stages, possibly on a series of channels:

- Reserve token :term:`capacity` for a given payment, using a :ref:`locked transfer message <locked-transfer-message>`.
- Use the reserved token amount to complete payments, using the :ref:`unlock message <unlock-message>`

Mediated Transfers
==================

A :term:`Mediated Transfer` is a hash-time-locked transfer. Currently raiden supports only one type of lock. The lock has an amount that is being transferred, a :term:`secrethash` used to verify the secret that unlocks it, and a :term:`lock expiration` to determine its validity.

Mediated transfers have an :term:`initiator` and a :term:`target` and a number of mediators in between. The number of mediators can also be zero as these transfers can also be sent to a direct partner. Assuming ``N`` number of mediators, a mediated transfer will require ``10N + 16`` messages to complete. These are:

- ``N + 1`` :term:`locked transfer` or :term:`refund transfer` messages
- ``1`` :term:`secret request`
- ``N + 2`` :term:`reveal secret`
- ``N + 1`` :term:`unlock`
- ``2N + 3`` processed (one for everything above)
- ``5N + 8`` delivered

For the simplest Alice - Bob example:

- Alice wants to transfer ``n`` tokens to Bob.
- Alice creates a new transfer with:
    * transferred_amount = ``current_value``
    * lock = ``Lock(n, hash(secret), expiration)``
    * locked_amount = ``updated value containing the lock amount``
    * locksroot = ``updated value containing the lock``
    * nonce = ``current_value + 1``
- Alice signs the transfer and sends it to Bob.
- Bob requests the secret that can be used for withdrawing the transfer by sending a ``SecretRequest`` message.
- Alice sends the ``RevealSecret`` to Bob and at this point she must assume the transfer is complete.
- Bob receives the secret and at this point has effectively secured the transfer of ``n`` tokens to his side.
- Bob sends a ``RevealSecret`` message back to Alice to inform her that the secret is known and acts as a request for off-chain synchronization.
- Finally Alice sends an ``Unlock`` message to Bob. This acts also as a synchronization message informing Bob that the lock will be removed from the list of pending locks and that the transferred_amount and locksroot values are updated.

Mediated Transfer - Best Case Scenario
--------------------------------------

In the best case scenario, all Raiden nodes are online and send the final balance proofs off-chain.

.. image:: diagrams/RaidenClient_mediated_transfer_good.png
    :alt: Mediated Transfer Good Behaviour
    :width: 900px

Mediated Transfer - Worst Case Scenario
---------------------------------------

In case a Raiden node goes offline or does not send the final balance proof to its payee, then the payee can register the ``secret`` on-chain, in the ``SecretRegistry`` smart contract before the ``secret`` expires. This can be used to ``unlock`` the lock on-chain after the channel is settled.

.. image:: diagrams/RaidenClient_mediated_transfer_secret_reveal.png
    :alt: Mediated Transfer Bad Behaviour
    :width: 900px

Restrictions to mediated transfers
==================================

Limit to number of simultaneously pending transfers
---------------------------------------------------

The number of simultaneously pending transfers per channel is limited. The client will not initiate, mediate or accept a further pending transfer if the limit is reached. This is to avoid the risk of not being able to unlock the transfers, as the gas cost for this operation grows with the number of the pending locks and thus the number of pending transfers.

The limit is currently set to 160. It is a rounded value that ensures the gas cost of unlocking will be less than 40% of Ethereum's traditional pi-million (3141592) block gas limit.