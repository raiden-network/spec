.. _pfs:

Raiden Pathfinding Service
##########################

Overview
========

A path finding service having a global view on a token network can provide suitable payment paths for Raiden nodes.
Raiden nodes can request paths via public endpoints and pay per request. The service will keep its view on the
token network updated by listening to blockchain events and a public matrix room where current capacities and
fees (``Capacity Updates``) are being published. Nodes will publish their ``Capacity Updates`` in order to advertise
their channels to become mediators.

Implementation Process and Assumptions
======================================

* The path finding service will be implemented iteratively adding more complexity on every step.
* There are three steps planned - (1) Pathfinding Minimal Viable Product, (2) Adding service fees, (3) Handling mediation fees.
* It should be able to handle a similar amount of active nodes as currently present in Ethereum (~20,000).
* Nodes are incentivized to publicly report their current capacities and fees to "advertise" their channels.
* Uncooperative nodes are dropped on the Raiden-level protocol, so paths provided by the service can be expected to work most of the time.
* User experience should be simple and free for sparse users with optional premium fee schedules for heavy users.
* No guarantees are or can be made about the feasibility of the path with respect to node uptime or neutrality.


High-Level-Description
======================
A node can request a list of possible paths from start point to endpoint for a given transfer value.
The ``get_paths`` method implements the bi-directional Dijkstra algorithm to return a given number of paths
for a mediated transfer of a given value. The design regards the Raiden network as an unidirectional
weighted graph, where the weights of the edges/channels are the sum of multiple penalty terms:

* a base weight of 1 per edge, to incentivize short paths
* a term proportional to the mediations fees for that channel
* if the edge is included in a route, all following routes will get a penalty
  if they include the same edge. This increases the diversity of routes and
  reduces the likelihood that multiple routes fail due to the same problem.

See `Routing Preferences`_ for information on how to configure the trade-off between these penalties.


Public REST API
===============

A pathfinding service must provide the following endpoints. The interface has to be versioned.

The examples provided for each of the endpoints is for communication with a REST endpoint.


.. _pfs_api_paths:

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
| iou                  | object        | IOU object as described in :ref:`pfs_payment` to pay the service fee  |
+----------------------+---------------+-----------------------------------------------------------------------+
| diversity_penalty    | float         | (optional) Routing penalty per channel that is reused across multiple |
|                      |               | different routes returned in the same response.                       |
+----------------------+---------------+-----------------------------------------------------------------------+
| fee_penalty          | float         | (optional) Penalty applied to a channel for requiring 1 RDN as        |
|                      |               | mediation fee.                                                        |
+----------------------+---------------+-----------------------------------------------------------------------+

Returns
"""""""

A list of path objects and a feedback token when successful.

Each path object consists of the following information:

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
| path                 | List[address] | An ordered list of the addresses that make up the payment path.       |
+----------------------+---------------+-----------------------------------------------------------------------+
| estimated_fee        | int           | An estimate of the fees required for that path.                       |
+----------------------+---------------+-----------------------------------------------------------------------+

The feedback token is the 32-character hexadecimal string representation of a UUID and is valid for all routes that
are included in the response.

Routing Preferences
"""""""""""""""""""

The PFS will search for routes that are:

* short
* cheap
* diverse (using different channels for different routes when multiple routes are returned)

Since these goals can be conflicting, a trade-off between them has to be
chosen. This is done by assigning a penalty to all undesired properties of a
channel, summing up these penalties across all channels used in a route and
then choosing the route with the lowest total penalty.

When requesting a route, the calculated penalties depend on the
``diversity_penalty`` and ``fee_penalty`` parameters. If those parameters are
omitted, reasonable defaults are chosen. A ``diversity_penalty`` of 5 means that
a channel which has already been used in previous route is as bad as adding 5
more channels to the path which have not been used, yet. A ``fee_penalty`` of 100
means that spending 1 RDN is as bad as adding 100 more channels to the route
(or that spending 0.01 RDN is as bad as adding one more channel).

Errors
""""""

Each error consists of three parts:

* ``errors``: a human readable error message
* ``error_code``: a machine readable identifier for the type of error
* ``error_details``: additional information on the failure, e.g. values that
  caused the failure or expected input values (can be empty for some errors)

Please have a look at the full `list of errors
<https://github.com/raiden-network/raiden-services/blob/master/src/pathfinding_service/exceptions.py>`_.

Example
"""""""
::

    // Request
    curl -X POST --header 'Content-Type: application/json' --data '{
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
            "estimated_fee": 110,
        },
        {
            "path": ["0xalice", "0xeve", "0xdave", "0xbob"]
            "estimated_fee": 142,
        },
        ...
        ],
        "feedback_token": "aaabbbcccdddeeefff"
    }
    // Wrong IOU signature
    {
        'errors': 'The signature did not match the signed content',
        'error_code': 2001,
    }
    // Missing `amount` in IOU
    {
        'errors': 'Request parameter failed validation. See `error_details`.',
        'error_code': 2000,
        'error_details': {'iou': {'amount': ['Missing data for required field.']}}
    }


``GET api/v1/info``
^^^^^^^^^^^^^^^^^^^

Request price and path information on how and how much to pay the service for additional path requests.
The service is paid in RDN tokens, so they payer might need to open an additional channel in the RDN token network.

Returns
"""""""
A JSON object with at least the following properties:

+----------------------+---------------+-------------------------------------------------------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                                                                      |
+======================+===============+===================================================================================================================+
| price_info           | int           | Amount of RDN per request expected by the PFS                                                                     |
+----------------------+---------------+-------------------------------------------------------------------------------------------------------------------+
| network_info.chain_id| int           | The `chain ID <https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md>`_ for the network this PFS works on  |
+----------------------+---------------+-------------------------------------------------------------------------------------------------------------------+

Example
"""""""
::

    // Request
    curl -X GET --data '{
        "rdn_source_addressfrom": "0xrdn_alice",
    }'  api/v1/info

    // Result for success
    {
        "price_info": 0,
        "network_info": {
            "chain_id": 3,
            "registry_address": "0x4a6E1fe3dB979e600712E269b26207c49FEe116E"
        },
        "settings": "PLACEHOLDER FOR PATHFINDER SETTINGS",
        "version": "0.0.1",
        "operator": "PLACEHOLDER FOR PATHFINDER OPERATOR",
        "message": "PLACEHOLDER FOR ADDITIONAL MESSAGE BY THE PFS"
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


``POST api/v1/<token_network_address>/feedback``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Send feedback about a given route to the pathfinding service. For more information see the
`routing feedback ADR <https://github.com/raiden-network/raiden-services/blob/master/adr/002-routing-feedback.md>`_.

Arguments
"""""""""

+---------------------+-------------+---------------------------------------------------------+
| Field Name          | Field Type  | Description                                             |
+=====================+=============+=========================================================+
| token               | string      | Hexadecimal string representation of the token          |
+---------------------+-------------+---------------------------------------------------------+
| success             | boolean     | Whether or not the route worked                         |
+---------------------+-------------+---------------------------------------------------------+
| path                |List[address]| The route feedback is given for                         |
+---------------------+-------------+---------------------------------------------------------+

Returns
"""""""

* HTTP 200 when feedback was accepted
* HTTP 400 when feedback was not accepted

Network Topology Updates
========================

The creation of new token networks can be followed by listening for:
- ``TokenNetworkCreated`` events on the ``TokenNetworksRegistry`` contract.

To learn about updates of the network topology of a token network the PFS must
listen for the following events:

- ``ChannelOpenened``: Update the network to include the new channel
- ``ChannelClosed``: Remove the channel from the network


Capacity and Fee Updates
========================
Updates for channel capacities and fees are published over a public matrix room. Path finding services can pick these
capacity updates from there and update the topology represented internally.
The Raiden nodes that want to earn fees mediating payments would be incentivized to publish their capacity updates in
order to provide a path.

Capacity Update
^^^^^^^^^^^^^^^

``PFSCapacityUpdate``\s are messages that the Raiden client broadcasts to Pathfinding Services in order to let them know about updated
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
| other_participant        | address    | Channel participant who doesn't send the balance update                        |
+--------------------------+------------+--------------------------------------------------------------------------------+
| updating_nonce           | uint256    | Strictly monotonic value used to order transfers. The nonce starts at 1        |
+--------------------------+------------+--------------------------------------------------------------------------------+
| other_nonce              | uint256    | Strictly monotonic value used to order transfers. The nonce starts at 1        |
+--------------------------+------------+--------------------------------------------------------------------------------+
| updating_capacity        | uint256    | Available capacity for the participant sending the update                      |
+--------------------------+------------+--------------------------------------------------------------------------------+
| other_capacity           | uint256    | Available capacity for the participant not sending the update                  |
+--------------------------+------------+--------------------------------------------------------------------------------+
| reveal_timeout           | uint256    | Reveal timeout of this channel                                                 |
+--------------------------+------------+--------------------------------------------------------------------------------+

Signature
^^^^^^^^^

The signature is created by using ``ecdsa_recoverable`` on the fields in the order given above and stored in the ``signature`` field.

All of these fields are required. The Pathfinding Service MUST perform verification of these data, namely channel
existence. A Pathfinding service SHOULD accept the message if and only if the sender of the message is same as the sender
address recovered from the signature.

Fee Update
^^^^^^^^^^

``PFSFeeUpdate``\s are broadcast by the Raiden Client to Pathfinding Services in order to let them know about updated
mediation fee schedules.

Fields
""""""

+-------------------------------+---------------+-------------------------------------------------------------------------+
| Field Name                    | Field Type    |  Description                                                            |
+===============================+===============+=========================================================================+
| chain_id                      | uint256       | Chain identifier as defined in EIP155                                   |
+-------------------------------+---------------+-------------------------------------------------------------------------+
| token_network_identifier      | address       | Address of the TokenNetwork contract                                    |
+-------------------------------+---------------+-------------------------------------------------------------------------+
| channel_identifier            | uint256       | Channel identifier inside the TokenNetwork contract                     |
+-------------------------------+---------------+-------------------------------------------------------------------------+
| updating_participant          | address       | Channel participant who sends the balance update                        |
+-------------------------------+---------------+-------------------------------------------------------------------------+
| fee_schedule.flat             | uint256       | Flat mediation fee in Wei of the mediated token                         |
+-------------------------------+---------------+-------------------------------------------------------------------------+
| fee_schedule.proportional     | uint256       | Proportional mediation fee as parts-per-million of the mediated token   |
+-------------------------------+---------------+-------------------------------------------------------------------------+
| fee_schedule.imbalance_penalty| array of [int,| (capacity, penalty) pairs for the IP function.                          |
|                               | int] pairs    | This is RLP encoded in the signature.                                   |
+-------------------------------+---------------+-------------------------------------------------------------------------+
| timestamp                     | string        | Current UTC date and time in ISO 8601 format                            |
|                               |               | (e.g. 2019-02-25T12:53:16Z)                                             |
+-------------------------------+---------------+-------------------------------------------------------------------------+

Signature
^^^^^^^^^

The signature is created by using ``ecdsa_recoverable`` on the fields in the order given above and stored in the ``signature`` field.


Routing feedback
================

In order to improve the calculated routes, the PFS requires feedback about the routes it provides to Raiden clients. For that reason the routing feedback mechanism is introduced.

When a client requests a route from a PFS (see :ref:`pfs_api_paths`), the PFS returns a *feedback token* together with the number of routes requested.
This feedback token is a UUID in version 4. The client stores it together with the payment id and then initiates the payment. Whenever a particular
route fails or the payment succeeds by using a certain route, this feedback is given to the PFS.

While the individual feedback cannot be trusted by the PFS, it can use general trends to improve it's routing algorithm, e.g. lowering the precedence or removing channels
from the routing table when payments including them often fail.

Future Work
===========

The methods will be rate-limited in a configurable way. If the rate limit is exceeded,
clients can be required to pay the path-finding service with RDN tokens via the Raiden Network.
The required path for this payment will be provided by the service for free. This enables a simple
user experience for light users without the need for additional on-chain transactions for channel
creations or payments, while at the same time monetizing extensive use of the API.
