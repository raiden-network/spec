.. _pfs:

Raiden Pathfinding Service
##########################

Overview
========

A path finding service having a global view on a token network can provide suitable payment paths for Raiden nodes.
Raiden nodes can request paths via public endpoints and pay per request. The service will keep its view on the
token network updated by listening to blockchain events and a public matrix room where balance proofs and
fees are being published. Nodes will publish their current balance proofs and fees in order to advertise
their channels to become mediators.

Implementation Process and Assumptions
======================================

* The path finding service will be implemented iteratively adding more complexity on every step.
* There are three steps planned - (1) Pathfinding Minimal Viable Product, (2) Adding service fees, (3) Handling mediation fees.
* It should be able to handle a similar amount of active nodes as currently present in Ethereum (~20,000).
* Nodes are incentivized to publicly report their current balances and fees to "advertise" their channels.
* Uncooperative nodes are dropped on the Raiden-level protocol, so paths provided by the service can be expected to work most of the time.
* User experience should be simple and free for sparse users with optional premium fee schedules for heavy users.
* No guarantees are or can be made about the feasibility of the path with respect to node uptime or neutrality.


High-Level-Description
======================
A node can request a list of possible paths from start point to endpoint for a given transfer value.
The ``get_paths`` method implements the canonical Dijkstra algorithm to return a given number of paths
for a mediated transfer of a given value. The design regards the Raiden network as an unidirectional
weighted graph, where the default weights and therefore the primary constraint of the optimization)
* at step (1 and 2) are 1 (no fees being implemented) and
* at step (3) are the fees of each channel.

Additionally, we will apply heuristics to quantify desirable properties of the resulting graph:

i) A hard coded parameter ``DIVERSITY_PEN_DEFAULT`` defined in the config; this value is added to each edge that is part of a returned path as a bias. This results in an output of "pseudo-disjoint" paths, i.e. the optimization will prefer paths with a minimal edge intersection. This should enable nodes to have a suitable amount of options for their payment routing in the case some paths are slow or broken. However, if a node has only one channel (i.e. a light client) payments could be routed through, the method will still return the specified ``number of paths``.


ii) (From step (3) on) The second heuristic is configurable via the optional argument ``bias``, which models the trade-off between speed and cost of a mediated transfer; with default 0, ``get_paths`` will  optimize with respect to overall fees only (i.e. the cheapest path). On the other hand, with ``bias=1``, ``get_paths`` will look for paths with the minimal number of hops (i.e. the  -theoretical - fastest path). Any value in ``[0,1]`` is accepted, an appropriate value depends on the average ``channel_fee`` in the network (in simulations ``mean_fee`` gave decent results for the trade-off between speed and cost). The reasoning behind this heuristic is that a node may have different needs, w.r.t to good to be paid for - buying a potato should be fast, buying a yacht should incorporate low fees.

Public Interfaces
=================
The path finding service needs three public interfaces

* a public endpoint for path requests by Raiden nodes
* an endpoint to get updates from blockchain events
* an endpoint to get updates about current balances and fees

Public Endpoints
----------------

A path finding service must provide the following endpoints. The interface has to be versioned.

The examples provided for each of the endpoints is for communication with a REST endpoint.

``POST api/v1/<token_network_address>/paths``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The method will do ``max_paths`` iterations of Dijkstras algorithm on the last-known state of the Raiden
Network (regarded as directed weighted graph) to return ``max_paths`` different paths for a mediated transfer of ``value``.

* Checks if an edge (i.e. a channel) has ``capacity > value``, else ignores it.

* Applies on the fly changes to the graph's weights - depends on ``DIVERSITY_PEN_DEFAULT`` from ``config``, to penalize edges which are part of a path that is returned already.

.. _path_args:

Arguments
"""""""""

The arguments are POSTed as a JSON object.

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
| fee_iou              | object        | IOU object as described in :ref:`pfs_payment` to pay the service fee  |
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


Errors
""""""

If no possible path is found, one of the following errors is returned:

* No suitable path found
* Rate limit exceeded
* 'from' or 'to' invalid
* The 'token_network_address' is invalid
* 'bias' is invalid
* 'max_paths' is invalid
* 'value' is invalid

Payment related errors:

.. note::
   In addition to the error messages, error codes will be added to easily identify the different error cases and handle them automatically.

* Wrong ``receiver``
* Outdated payment session. Please choose new ``expiration_block``.
* Too low payment ``amount``. The last IOU for the current session is included in the ``last_iou`` field of the returned object.
* Invalid payment signature
* Deposit in UserDeposit contract is too low.
* Bad client. The client behaved badly in the past and the PFS does not want to provide service to it, anymore. One reason for this could be by using a new ``expiration_block`` for each request, so that it is not profitable for the PFS to claim the service payments.

Example
"""""""
::

    // Request
    curl -X POST --data '{
        "from": "0xalice",
        "to": "0xbob",
        "value": 45,
        "max_paths": 10
    }'
    // Result for success
    {
        "result": [
        {
            "path": ["0xalice", "0xcharlie", "0xbob"],
        },
        {
            "path": ["0xalice", "0xeve", "0xdave", "0xbob"]
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
        "errors": "Rate limit exceeded, payment required. Please call 'api/v1/payment/info' to establish a payment channel or wait."
    }



``GET api/v1/<token_network_address>/payment/info``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

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
A JSON object with the following properties:

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
| price_per_request    | int           | The address of payer in the RDN token network.                        |
+----------------------+---------------+-----------------------------------------------------------------------+
| pfs_address          | address       | The PFS address in the RDN token network.                             |
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
    }'  api/v1/0xtoken_network/payment/info
    // Result for success
    {
        "result":
        {
            "price_per_request": 1000,
            "paths":
            [
                {
                    "path": ["0xrdn_alice", "0xrdn_eve", "0xrdn_service"],
                },
                ...
            ]
        }
    // Result for failure
    {
        "errors": "No suitable path found."
    }


``GET api/v1/<token_network_address>/payment/iou``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Request the last IOU used by ``sender`` to pay the PFS.
This IOU can be used by the client to generate the next IOU to pay the PFS by increasing the ``amount`` and updating the signature.

Arguments
"""""""""

+---------------------+------------+---------------------------------------------------------+
| Field Name          | Field Type | Description                                             |
+=====================+============+=========================================================+
| sender              | address    | Sender of the payment (Ethereum address of client)      |
+---------------------+------------+---------------------------------------------------------+
| receiver            | address    | Receiver of the payment (Ethereum address of PFS)       |
+---------------------+------------+---------------------------------------------------------+
| timestamp           | string     | Current UTC date and time in ISO 8601 format            |
|                     |            | (e.g. 2019-02-25T12:53:16Z)                             |
+---------------------+------------+---------------------------------------------------------+
| signature           | bytes      | Signature over the other three arguments [#sig]_        |
+---------------------+------------+---------------------------------------------------------+

.. [#sig] The signature is calculated by
          ::

               ecdsa_recoverable(privkey,
                                 sha3_keccak("\x19Ethereum Signed Message:\n[LENGTH]"
                                             || sender || receiver || timestamp ))

Returns
"""""""
A JSON object with a single property:

+----------------------+---------------+-----------------------------------------------+
| Field Name           | Field Type    | Description                                   |
+======================+===============+===============================================+
| last_iou             | object        | IOU object as described in :ref:`pfs_payment` |
+----------------------+---------------+-----------------------------------------------+


Network Topology Updates
------------------------

The creation of new token networks can be followed by listening for:
- `TokenNetworkCreated` events on the `TokenNetworksRegistry` contract.

To learn about updates of the network topology of a token network the PFS must
listen for the following events:

- `ChannelOpenened`: Update the network to include the new channel
- `ChannelClosed`: Remove the channel from the network

Additionally it must listen to the `ChannelNewDeposit` event in order to learn
about new deposits.

Balance and Fee Updates (Graph Weights)
---------------------------------------
Updates for channel balances and fees are published over a public matrix room. Path finding services can pick these
balance proofs from there and update the topology represented internally.
The Raiden nodes that want to earn fees mediating payments would be incentivized to publish their balance proofs in
order to provide a path.

Balance Update
^^^^^^^^^^^^^^

Balance Updates are messages that the Raiden client broadcasts to Pathfinding Services in order to let them know about updated
channel balances.

Fields
""""""

+--------------------------+------------+--------------------------------------------------------------------------------+
| Field Name               | Field Type |  Description                                                                   |
+==========================+============+================================================================================+
| chain_id                 | uint256    | Chain identifier as defined in EIP155                                          |
+--------------------------+------------+--------------------------------------------------------------------------------+
| token_network_identifier | address    | Address of the TokenNetwork contract                                           |
+--------------------------+------------+--------------------------------------------------------------------------------+
| channel_identifier       | uint256    | Channel identifier inside the TokenNetwork contract                            |
+--------------------------+------------+--------------------------------------------------------------------------------+
| updating_participant     | address    | Channel participant who sends the balance update                               |
+--------------------------+------------+--------------------------------------------------------------------------------+
| other_participant        | address    | Channel participant who doesn't send the balance update                               |
+--------------------------+------------+--------------------------------------------------------------------------------+
| updating_nonce           | uint256    | Strictly monotonic value used to order transfers. The nonce starts at 1        |
+--------------------------+------------+--------------------------------------------------------------------------------+
| other_nonce              | uint256    | Strictly monotonic value used to order transfers. The nonce starts at 1        |
+--------------------------+------------+--------------------------------------------------------------------------------+
| updating_capacity        | uint256    | Available capacity for the participant sending the update                                                          |
+--------------------------+------------+--------------------------------------------------------------------------------+
| other_capacity           | uint256    | Available capacity for the participant not sending the update                             |
+--------------------------+------------+--------------------------------------------------------------------------------+
| reveal_timeout           | uint256    | Reveal timeout of this channel                                                 |
+--------------------------+------------+--------------------------------------------------------------------------------+
| signature                | bytes      | Elliptic Curve 256k1 signature on the above data                               |
+--------------------------+------------+--------------------------------------------------------------------------------+

Signature
^^^^^^^^^

The signature of the message is calculated by:

::

    ecdsa_recoverable(privkey, sha3_keccak(chain_id || token_network_address || channel_identifier || updating_participant || other_participant || updating_nonce || other_nonce || updating_capacity || other_capacity || reveal_timeout))

All of this fields are required. The Pathfinding Service MUST perform verification of these data, namely channel
existence. A Pathfinding service SHOULD accept the message if and only if the sender of the message is same as the sender
address recovered from the signature.


Future Work
===========

The methods will be rate-limited in a configurable way. If the rate limit is exceeded,
clients can be required to pay the path-finding service with RDN tokens via the Raiden Network.
The required path for this payment will be provided by the service for free. This enables a simple
user experience for light users without the need for additional on-chain transactions for channel
creations or payments, while at the same time monetizing extensive use of the API.
