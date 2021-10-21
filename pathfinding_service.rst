.. _pfs:

Pathfinding Service
###################

Overview
========

A pathfinding service (PFS) has a global view on a token network and can provide suitable payment paths for Raiden nodes.
Raiden nodes can request paths from a PFS via a public REST API and pay per request.

The service will keep its view on the
token network updated by listening to blockchain events and a public matrix room where current capacities and
fees are being published. Nodes will publish this information in order to advertise their channels for mediation.

Assumptions & Goals
===================

* The PFS should be able to handle a similar amount of active nodes as currently present in Ethereum (~20,000).
* Nodes are incentivized to publicly report their current capacities and fees to "advertise" their channels.
* Uncooperative nodes are dropped by the PFS, so paths provided by the service can be expected to work most of the time.
* No guarantees are or can be made about the feasibility of the path with respect to node uptime or neutrality.


High-Level-Description
======================

A node can request a list of possible paths from start point to endpoint for a given transfer value.
The ``get_paths`` method implements the bi-directional Dijkstra algorithm to return a given number of paths
for a mediated transfer of a given value. The design regards the Raiden network as an unidirectional
weighted graph, where the weights of the edges/channels are the sum of multiple penalty terms:

* a base weight of 1 per edge, to incentivize short paths
* a term proportional to the mediation fees for that channel
* if the edge is included in a route, all following routes will get a penalty
  if they include the same edge. This increases the diversity of routes and
  reduces the likelihood that multiple routes fail due to the same problem.

See `Routing Preferences`_ for information on how to configure the trade-off between these penalties.


Public REST API
===============

A pathfinding service must provide the following endpoints. The interface has to be versioned.

The examples provided for each of the endpoints is for communication with a REST endpoint.


``GET api/v1/address/<checksummed_address>/metadata``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^



Arguments
"""""""""

The arguments are passed as part of the request path:

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
| checksummed_address  | address       | The Raiden node address for which the metadata is requested.          |
+----------------------+---------------+-----------------------------------------------------------------------+


.. _pfs-address-metadata:

Returns
"""""""

.. TODO insert cross references to the transport section (for "Matrix transport", displayname, capabilities and user-id) 



An ``AddressMetadata`` object is returned for the node who's metadata was requested.
It provides all necessary information in order to communicate with the node via the Matrix transport:


+----------------------+---------------+----------------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                               |
+======================+===============+============================================================================+
| capabilities         | string        | Capabilities url of the participant the metadata was requested for         |
+----------------------+---------------+----------------------------------------------------------------------------+
| displayname          | bytes         | Displayname of the participant the metadata was requested for              |
+----------------------+---------------+----------------------------------------------------------------------------+
| user_id              | string        | User-id of the participant the metadata was requested for                  |
+----------------------+---------------+----------------------------------------------------------------------------+


An example response looks like:

::

        {
            "capabilities": "mxc://raiden.network/cap?Receive=1&Mediate=1&Delivery=1&webRTC=1&toDevice=1&immutableMetadata=1",
            "displayname": "0xf61a67340eeb9ad9d1767a5bbc7347868e6366a082d1015cfa7b6f2dd56170024ff315c3b9df4825bb8dfca3da4bf8e22cbe16f8a0bb8554f8e3fc45d79caa341b",
            "user_id": "@0x4d156a78ed6dfdfbbf3e569558eaf895b40217d6:transport.transport01.raiden.network"
        }


.. _pfs_api_paths:

``POST api/v1/<token_network_address>/paths``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The method will do ``max_paths`` iterations of Dijkstras algorithm on the last-known state of the Raiden
Network (regarded as directed weighted graph) to return ``max_paths`` different paths for a mediated transfer of ``value``.

* Checks if an edge (i.e. a channel) has ``capacity > value``, else ignores it.
* Checks that further constraints are met, like the lock timeout being smaller than the settle timeout.
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

When successful, the request returns a list of path objects and a feedback
token. A feedback token is the 32-character hexadecimal string
representation of a UUID and is valid for all routes that are included in the
response.

Each path object consists of the following information:


+----------------------+---------------------------------+-------------------------------------------------------------------------------------------------+
| Field Name           | Field Type                      |  Description                                                                                    |
+======================+=================================+=================================================================================================+
| path                 | List[address]                   | An ordered list of the addresses that make up the payment path.                                 |
+----------------------+---------------------------------+-------------------------------------------------------------------------------------------------+
| address_metadata     | Dict[address, AddressMetadata]  | An mapping from address in the path to transport :ref:`address metadata <pfs-address-metadata>` |
+----------------------+---------------------------------+-------------------------------------------------------------------------------------------------+
| estimated_fee        | int                             | An estimate of the fees required for that path.                                                 |
+----------------------+---------------------------------+-------------------------------------------------------------------------------------------------+


An example response looks like:

::

  {
    "result": [
      {
        "path": [
          "0xCb27B9DAb141aA97Cfdce98AC50A9d4Df355D688",
          "0x0ADdD863A406dDA82c93948267878108A8325E47",
          "0xAD63746Dd8BD889542D3E45198dB5Cc7a0eB762c",
          "0xB16326b4c7E3c546c1C22372123f05e40975781e"
        ],
        "address_metadata": {
          "0xCb27B9DAb141aA97Cfdce98AC50A9d4Df355D688": {
            "user_id": "@0xcb27b9dab141aa97cfdce98ac50a9d4df355d688:transport.transport01.raiden.network",
            "capabilities": "mxc://raiden.network/cap?Receive=1&Mediate=1&Delivery=1&webRTC=1&toDevice=1&immutableMetadata=1",
            "displayname": "0xa4e5b92a6bedaf8841f10d57542ed758c6dfe425c5fda150cb72f0b64b78abc9046e352f7033e3ea7f81a36569e4201c9b83b3e4216e4336cbdc0e52942cf1531b"
          },
          "0x0ADdD863A406dDA82c93948267878108A8325E47": {
            "user_id": "@0x0addd863a406dda82c93948267878108a8325e47:transport.transport01.raiden.network",
            "capabilities": "mxc://raiden.network/cap?Receive=1&Mediate=1&Delivery=1&webRTC=1&toDevice=1&immutableMetadata=1",
            "displayname": "0x2dc328eb50cf5b9d6a3cb0fb538350d34efb79ed1822f5703d0f769199615d2278b9e33a247ce3887edbe66103cee25469353dc1c38cae2e25168e49590d6b701c"
          },
          "0xAD63746Dd8BD889542D3E45198dB5Cc7a0eB762c": {
            "user_id": "@0xad63746dd8bd889542d3e45198db5cc7a0eb762c:transport.transport01.raiden.network",
            "capabilities": "mxc://raiden.network/cap?Receive=1&Mediate=1&Delivery=1&webRTC=1&toDevice=1&immutableMetadata=1",
            "displayname": "0x0935fe9a32a364a689208f234c92c0a740e362b37abaa14bdfbb9724695c4bf15a27147ffe614a64dbe02c17f47d10b9faf82ff9abf9e08aa377990721493c181b"
          },
          "0xB16326b4c7E3c546c1C22372123f05e40975781e": {
            "user_id": "@0xb16326b4c7e3c546c1c22372123f05e40975781e:transport.transport01.raiden.network",
            "capabilities": "mxc://raiden.network/cap?Receive=1&Mediate=1&Delivery=1&webRTC=1&toDevice=1&immutableMetadata=1",
            "displayname": "0xfa3b725d0877e42e83ba8df59c4436c7377e98c017db8b84519fe8379d6c9dc60f55aac7e0454d7cb969a003a64afe96a686dcfb173171ee34183aeeab0eb17b1c"
          }
        },
        "estimated_fee": 0
      }
    ],
    "feedback_token": "f6f0fb9b279e44faac9e3c1f9201fb66"
  }


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


``GET api/v1/online_addresses``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This returns the list of all Raiden node addresses 
that the PFS is tracking the presence of and that currently
are considered as online.

Arguments
"""""""""

This endpoint does not provide any arguments.


Returns
"""""""
A list of checksum addresses.

::

    // Request
    curl -X GET api/v1/online_addresses

    // Result for success
        [
            "0x38c32a05D3782B22Df9A86968c107699eC5B3C3F",
            "0x559A3E31d27faDec43D725673D0fC381d235B3b8",
            "0x68E7846B25FD85548c1054F41D88FDC6DbC27B67",
            "0x872E8494c5400D5387910d97c5d8A428e384D4Ea",
            "0x3223587948d0490A4F625A8F241a5FF1D1733675"
        ]



``GET api/v2/info``
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
| matrix_server        | url           | URL of the Matrix server the PFS is connected to                                                                  |
+----------------------+---------------+-------------------------------------------------------------------------------------------------------------------+
| network_info.chain_id| int           | The `chain ID <https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md>`_ for the network this PFS works on  |
+----------------------+---------------+-------------------------------------------------------------------------------------------------------------------+
| payment_address      | address       | Address of the PFS for the IOU payments used to pay path requests                                                 |
+----------------------+---------------+-------------------------------------------------------------------------------------------------------------------+


Example
"""""""
::

    // Request
    curl -X GET api/v2/info

    // Result for success
    {
        "UTC": "2021-10-18T15:22:12.407699",
        "contracts_version": "0.40.0rc0",
        "matrix_server": "https://transport.transport01.raiden.network",
        "message": "PFS at pfs.tranport01.raiden.network with fee",
        "network_info": {
            "chain_id": 5,
            "confirmed_block": {
                "number": "5693235"
            },
            "service_token_address": "0x5Fc523e13fBAc2140F056AD7A96De2cC0C4Cc63A",
            "token_network_registry_address": "0x44c886653B536178831CF2Ca0724e0dd3f75FEd6",
            "user_deposit_address": "0xEC139fBAED94c54Db7Bfb49aC4e143A76bC422bB"
        },
        "operator": "Raiden testnet RSB 01",
        "payment_address": "0x23A74bd16E98a83be6F9c61807010C8e778ED3E2",
        "price_info": "50000000000000000",
        "version": "0.18.3"
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


``GET api/v1/<token_network_address>/suggest_partner``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

When a Raiden node joins a token network, it should connect to nodes which will
be able to mediate payments. Since the PFS observes the whole network, it is in
a better position than the client to choose suitable partners for a channel
opening. This endpoint provides partners recommended by the PFS.

The endpoint is free to use to encourage users to join the network. To avoid
load on the PFS for these free requests, the recommendations can be
aggressively cached by the PFS.


Arguments
"""""""""

None. A custom limit on the number of results is not used to facilitate caching.

Returns
"""""""

A sorted list of objects describing the suggested partners. The best
recommendations come first, so the simplest approach to use the results is to
connect to the node address given in the first element.

Each object has an ``address`` attribute containing the recommended node's
Ethereum address.
For advanced use cases and for debugging, additional scoring information is
provided (The overall score in the ``score`` attribute, as well as
``centrality``, ``uptime`` and ``capacity``). There is no long term guarantee
regarding the meaning of the specific values, but greater values will always
indicate better recommendations.

Example
"""""""
::

    // Request
    curl -X GET api/v1/0x3EA2a1fED7FdEf300DA19E97092Ce8FdF8bf66A3/suggest_partner

    // Result for success
    [
      {
        "address": "0x99eB1aADa98f3c523BE817f5c45Aa6a81B7c734B",
        "score": 2906634538666422000,
        "centrality": 0.0004132990448199853,
        "uptime": 7032.763746,
        "capacity": 1000000000000000000
      },
      {
        "address": "0x4Fc53fBa9dFb545B66a0524216c982536012186e",
        "score": 2906693668947465000,
        "centrality": 0.0004132990448199853,
        "uptime": 7032.906815,
        "capacity": 1000000000000000000
      }
    ]


Network Topology Updates
========================

The creation of new token networks can be followed by listening for ``TokenNetworkCreated`` events on the ``TokenNetworksRegistry`` contract.

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

When to send PFSFeeUpdates
^^^^^^^^^^^^^^^^^^^^^^^^^^

The fees depend on the total channel capacity across both participants, so whenever that changes, a PFSFeeUpdate should be sent. The capacity changes when participants deposit to or withdraw from a channel. For both of these actions, there is a time of uncertainty between the initiation and the confirmation of the action. The updates should assume the lower capacity during time, since it is the safe thing to do and it matches the node's internal state.

Deposit
"""""""
With this pessimistic approach, the update must be sent when the blockchain confirms the deposit (``ContractReceiveChannelDeposit``).

Withdraw
""""""""
The update will be sent when the withdraw is successfully initiated (``SendWithdrawRequest`` and ``ReceiveWithdrawRequest``). If the withdraw succeeds on-chain, this fee remains correct. In the unlikely case that the withdraw never reaches the blockchain, we have to revert back to the old fee schedule by sending a new fee update on the ``SendWithdrawExpired``/``ReceiveWithdrawExpired`` state change.


Routing feedback
================

In order to improve the calculated routes, the PFS requires feedback about the routes it provides to Raiden clients. For that reason the routing feedback mechanism is introduced.

When a client requests a route from a PFS (see :ref:`pfs_api_paths`), the PFS returns a *feedback token* together with the number of routes requested.
This feedback token is a UUID in version 4. The client stores it together with the payment id and then initiates the payment. Whenever a particular
route fails or the payment succeeds by using a certain route, this feedback is given to the PFS.

While the individual feedback cannot be trusted by the PFS, it can use general trends to improve it's routing algorithm, e.g. lowering the precedence or removing channels
from the routing table when payments including them often fail.
