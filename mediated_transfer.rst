Mediated transfers
##################

Overview
========

Nodes can use a :term:`mediated transfer` to send payments to another node without opening a
direct channel to it.

A mediated transfer is done in two stages, usually through multiple channels:

- **Allocation:** Reserve token :term:`capacity` for a given payment, using a
  :ref:`locked transfer message <locked-transfer-message>`.
- **Finalization:** Use the reserved token amount to complete payments, using the
  :ref:`unlock message <unlock-message>`

A mediated transfer may be cancelled and can expire until the initiator reveals the secret.

Mediated Transfers
==================

A :term:`mediated transfer` is a hash-locked transfer. Currently Raiden supports only one type of lock, a :term:`hash time lock`. This lock has an amount that is being transferred, a :term:`secrethash` used to verify the secret that unlocks it, and a :term:`lock expiration` to determine its validity.

Mediated transfers have an :term:`initiator` and a :term:`target` and a number of mediators in between. Assuming ``N`` number of mediators, a mediated transfer will require ``10N + 16`` messages to complete. These are:

- ``N + 1`` :term:`locked transfer` or :term:`refund transfer` messages
- ``1`` :term:`secret request`
- ``N + 2`` :term:`reveal secret`
- ``N + 1`` :term:`unlock`
- ``2N + 3`` processed (one for everything above)
- ``5N + 8`` delivered

For a simple example with one mediator:

- Alice wants to transfer ``n`` tokens to Charlie, using Bob as a mediator.
- Alice creates a new transfer with:

  - ``transferred_amount`` = previous ``transferred_amount``, unchanged
  - ``lock`` = ``Lock(n, hash(secret), expiration)``
  - ``locked_amount`` = previous ``locked_amount`` plus ``n``
  - ``locksroot`` = updated value containing the new ``lock``
  - ``nonce`` = previous ``nonce`` plus 1.

- Alice signs the transfer and sends it to Bob.
- Bob forwards the transfer to Charlie.
- Charlie requests the secret that can be used for withdrawing the transfer by sending a ``SecretRequest`` message to Alice.
- Alice sends the ``RevealSecret`` to Charlie and at this point she must assume the transfer is complete.
- Charlie receives the secret and at this point has effectively secured the transfer of ``n`` tokens to his side.
- Charlie sends a ``RevealSecret`` message to Bob to inform him that the secret is known and acts as a request for off-chain synchronization.
- Bob sends an ``Unlock`` message to Charlie. This acts also as a synchronization message informing Charlie that the lock will be removed from the list of pending locks and that the ``transferred_amount`` and ``locksroot`` values are updated.
- Bob sends a ``RevealSecret`` message to Alice.
- Finally Alice sends an ``Unlock`` to Bob, completing the transfer.

.. note::

  The number of mediators can also be zero. There are currently no dedicated message types for
  direct transfers in Raiden, so a direct transfer is just realized as a mediated transfer with
  no mediators.

Mediated Transfer - Happy Path Scenario
---------------------------------------

In the happy path scenario, all Raiden nodes are online and send the final balance proofs off-chain.

.. image:: diagrams/RaidenClient_mediated_transfer_good.png
    :alt: Mediated Transfer Good Behaviour
    :width: 900px

Mediated Transfer - Unhappy Path Scenario
-----------------------------------------

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
