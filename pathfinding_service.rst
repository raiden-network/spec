Raiden Pathfinding Service Specification
########################################

Overview
========

A centralized path finding service that has a global view on a token network and provides suitable payment paths for Raiden nodes.

Assumptions
===========

* The pathfinding service in its current spec is a temporary solution.
* It should be able to handle a similar amount of active nodes as currently present in Ethereum (~20,000).
* Uncooperative nodes are dropped on the Raiden-level protocol, so paths provided by the service can be expected to work most of the time.
* User experience should be simple and free for sparse users with optional premium fee schedules for heavy users.
* No guarantees are or can be made about the feasibility of the path with respect to node uptime or neutrality.
* Hubs are incentivized to accurately report their current balances and fees to "advertise" their channels. Higher fees than reported would be rejected by the transfer initiator.
* Every pathfinding service is responsible for a single token network. Pathfinding services are scaled on process level to handle multiple token networks.


High-Level-Description
======================
A node can request a list of possible paths from start point to endpoint for a given transfer value.
The ``get_paths`` method implements the canonical Dijkstra algorithm to return a given number of paths
for a mediated transfer of a given value. The design regards the Raiden network as an unidirectional
weighted graph, where the default weights (and therefore the primary constraint of the optimization)
are the fees of each channel. Additionally we applied two heuristics to quantify desirable properties
of the resulting graph:

i) A hard coded parameter ``DIVERSITY_PEN_DEFAULT`` defined in the config; this value is added to each edge that is part of a returned path as a bias. This results in an output of "pseudo-disjoint" paths, i.e. the optimization will prefer paths with a minimal edge intersection. This should enable nodes to have a suitable amount of options for their payment routing in the case some paths are slow or broken. However, if a node has only one channel (i.e. a light client) payments could be routed through, the method will still return the specified ``number of paths``.


ii) The second heuristic is configurable via the optional argument ``bias``, which models the trade-off between speed and cost of mediated transfer; with default 0, ``get_paths`` will  optimize with respect to overall fees only (i.e. the cheapest path). On the other hand, with ``bias=1``, ``get_paths`` will look for paths with the minimal number of hops (i.e. the  -theoretical - fastest path). Any value in ``[0,1]`` is accepted, an appropriate value depends on the average ``channel_fee`` in the network (in simulations ``mean_fee`` gave decent results for the trade-off between speed and cost). The reasoning behind this heuristic is that a node may have different needs, w.r.t to good to be paid for - buying a potato should be fast, buying a yacht should incorporate low fees.

Public Interface
================

Definitions
-----------

The following data types are taken from the Raiden Core spec.

*Channel_Id*

* uint: channel_identifier

*Balance_Proof*

See :ref:`offchain balance proof <balance-proof-offchain>`.


*Lock*

* uint64: expiration
* uint256: locked_amount
* bytes32: secrethash

Public Endpoints
----------------

A path finding service must provide the following endpoints. The interface has to be versioned.

The examples provided for each of the endpoints is for communication with a REST endpoint.

``api/1/<token_network_address>/<channel_id>/balance``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Update the balance for the given channel with the provided :term:`balance proof`. The receiver can be read from the balance proof.

Arguments
"""""""""

+----------------------+----------------------+-------------------------------------------------------------------+
| Field Name           | Field Type           |  Description                                                      |
+======================+======================+===================================================================+
| token_network_address| address              | The token network address for which the balance is updated.       |
+----------------------+----------------------+-------------------------------------------------------------------+
| channel_id           | int                  | The channel for which the balance proof should be updated.        |
+----------------------+----------------------+-------------------------------------------------------------------+
| balance_proof        | OffchainBalanceProof | The new balance proof which should be used for the given channel. |
+----------------------+----------------------+-------------------------------------------------------------------+
| locks                | List[Lock]           | The list of all locks used to compute the locksroot.              |
+----------------------+----------------------+-------------------------------------------------------------------+

Returns
"""""""
*True* when the balance was updated or one of the following errors:

* Invalid balance proof
* Invalid channel id

Example
"""""""
::

    // Request
    curl -X PUT --data '{
        "balance_proof": {
            "nonce": 1234,
            "transferred_amount": 23,
            "locked_amount": 0,
            "locksroot": "<keccak-hash>",
            "channel_id": 123,
            "token_network_address": "0xtoken",
            "chain_id": 1,
            "additional_hash": "<keccak-hash>",
            "balance_hash": "<keccak-hash>",
            "signature": "<signature>",
            "message_type": "BalanceProof",
        },
        "locks": [
            {
                "expiration": 200
                "locked_amount": 40
                "secrethash": "<keccak-hash>"
            },
            {
                "expiration": 50
                "locked_amount": 10
                "secrethash": "<keccak-hash>"
            },
        ],
    }'  /api/1/0xtoken_network/balance
    // Result for success
    {
        "result": "OK"
    }
    // Result for failure
    {
        "errors": "Invalid balance proof"
    }


``api/1/<token_network_address>/<channel_id>/fee``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Update the fee for the given channel, for the outgoing channel from the partner who signed the message.
A nonce is required to be incorporated in the signature for replay protection.

* Reconstructs the signers ``public_key`` of a requested fee update with coincurve's ``from_signature_and_message`` method.

* Derives the two ``channel_participants`` with ``from channel_id``. Checks if the signing ``public_key`` matches one of the ``channel participant``'s ``address`` or returns an error if the signature doesn't match.

Arguments
"""""""""

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
| token_network_address| address       | The token network address for which the payment info is requested.    |
+----------------------+---------------+-----------------------------------------------------------------------+
| Channel_id           | int           | The channel for which the fee should be updated.                      |
+----------------------+---------------+-----------------------------------------------------------------------+
| Nonce                | int           | A nonce for replay protection.                                        |
+----------------------+---------------+-----------------------------------------------------------------------+
| Fee                  | int           | The new fee to be set.                                                |
+----------------------+---------------+-----------------------------------------------------------------------+
| Signature            | bytes         | Signature of a channel partner                                        |
+----------------------+---------------+-----------------------------------------------------------------------+

Returns
"""""""
*True* when the fee was updated or one of the following errors:

* Invalid channel id
* Invalid signature


Example
"""""""
::

    // Request
    curl -X PUT --data '{
        "fee": 3,
        "signature": "<signature>"
    }'  /api/1/0xtoken_network/123/fee
    // Result for success
    {
        "result": "True"
    }
    // Result for failure
    {
        "errors": "Invalid signature."
    }

``api/1/<token_network_address>/paths``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The method will do ``max_paths`` iterations of Dijkstras algorithm on the last-known state of the Raiden
Network (regarded as directed weighted graph) to return ``max_paths`` different paths for a mediated transfer of ``value``.

* Checks if an edge (i.e. a channel) has ``capacity > value``, else ignores it.

* Applies on the fly changes to the graph's weights - depends on ``DIVERSITY_PEN_DEFAULT`` from ``config``, to penalize edges which are part of a path that is returned already.

* Depends on a user preference via the ``bias`` argument, to decided the trade off between fee-level vs. path-length (i.e. cost vs. speed) - default ``bias = 0``, i.e. full fee minimization.

Arguments
"""""""""

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
| token_network_address| address       | The token network address for which the paths are requested.          |
+----------------------+---------------+-----------------------------------------------------------------------+
| from                 | address       | The address of the payment initiator.                                 |
+----------------------+---------------+-----------------------------------------------------------------------+
| to                   | address       | The address of the payment target.                                    |
+----------------------+---------------+-----------------------------------------------------------------------+
| value                | int           | The amount of token to be sent.                                       |
+----------------------+---------------+-----------------------------------------------------------------------+
| max_paths            | int           | The maximum number of paths returned.                                 |
+----------------------+---------------+-----------------------------------------------------------------------+
| kwargs               | any           | Currently only 'bias' to implement the speed/cost opt. trade-off      |
+----------------------+---------------+-----------------------------------------------------------------------+

Returns
"""""""
A list of path objects. A path object consists of the following information:

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
| path                 | List[address] | An ordered list of the addresses that make up the payment path.       |
+----------------------+---------------+-----------------------------------------------------------------------+
| estimated_fee        | int           | An estimate of the fees required for that path.                       |
+----------------------+---------------+-----------------------------------------------------------------------+

If no possible path is found, one of the following errors is returned:

* No suitable path found
* Rate limit exceeded
* From or to invalid
* The token network address is invalid
* Bias is invalid
* Max_path is invalid
* Value is invalid

Example
"""""""
::

    // Request
    curl -X GET --data '{
        "from": "0xalice",
        "to": "0xbob",
        "value": 45,
        "max_paths": 10
    }'  /api/1/paths
    // Request with specific preference
    curl -X PUT --data '{
        "from": "0xalice",
        "to": "0xbob",
        "value": 45,
        "max_paths": 10,
        "extra_data": "min-hops"
    }'  /api/1/0xtoken_network/paths
    // Result for success
    {
        "result": [
        {
            "path": ["0xalice", "0xcharlie", "0xbob"],
            "estimated_fees": 3
        },
        {
            "path": ["0xalice", "0xeve", "0xdave", "0xbob"]
            "estimated_fees": 5
        },
        ...
        ]
    }
    // Result for failure
    {
        "errors": "No suitable path found."
    }
    // Result for exceeded rate limit
    {
        "errors": "Rate limit exceeded, payment required. Please call 'api/1/payment/info' to establish a payment channel or wait."
    }


``api/1/<token_network_address>/payment/info``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Request price and path information on how and how much to pay the service for additional path requests.
The service is paid in RDN tokens, so they payer might need to open an additional channel in the RDN token network.

Arguments
"""""""""

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
| token_network_address| address       | The token network address for which the fee is updated.               |
+----------------------+---------------+-----------------------------------------------------------------------+
| rdn_source_address   | address       | The address of payer in the RDN token network.                        |
+----------------------+---------------+-----------------------------------------------------------------------+

Returns
"""""""
An object consisting of two properties:

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
| price_per_request    | int           | The address of payer in the RDN token network.                        |
+----------------------+---------------+-----------------------------------------------------------------------+
| paths                | list          | A list of possible paths to pay the path finding service in the RDN   |
|                      |               | token network. Each object in the list contains a *path* and an       |
|                      |               | *estimated_fee* property.                                             |
+----------------------+---------------+-----------------------------------------------------------------------+

If no possible path is found, the following error is returned:

* No suitable path found

Example
"""""""
::

    // Request
    curl -X GET --data '{
        "rdn_source_addressfrom": "0xrdn_alice",
    }'  api/1/0xtoken_network/payment/info
    // Result for success
    {
        "result":
        {
            "price_per_request": 1000,
            "paths":
            [
                {
                    "path": ["0xrdn_alice", "0xrdn_eve", "0xrdn_service"],
                    "estimated_fees": 10_000
                },
                ...
            ]
        }
    // Result for failure
    {
        "errors": "No suitable path found."
    }


Implementation notes
====================

Network topology updates
------------------------

.. Note::
    A pathfinding service might want to cover multiple token networks. However,
    it always needs to cover the *RDN* token network in order to be able to
    provide routing information for payments.
    
    The creation of new token networks can be followed by listening for
    `TokenNetworkCreated` events on the `TokenNetworksRegistry` contract. 

To learn about updates of the network topology of a token network the PFS must
listen for the following events:

- `ChannelOpenened`: Update the network to include the new channel
- `ChannelClosed`: Remove the channel from the network

Additionally it must listen to the `ChannelNewDeposit` event in order to learn
about new deposits.

Updates for channel balances and fees are received over the designated API endpoints.

Future Work
===========

The methods will be rate-limited in a configurable way. If the rate limit is exceeded,
clients can be required to pay the path-finding service with RDN tokens via the Raiden Network.
The required path for this payment will be provided by the service for free. This enables a simple
user experience for light users without the need for additional on-chain transactions for channel
creations or payments, while at the same time monetizing extensive use of the API.
