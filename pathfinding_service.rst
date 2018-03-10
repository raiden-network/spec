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


Public Interface
================

Definitions
-----------

The following data types are taken from the Raiden Core spec.

*ChannelId*

* uint: channel_identifier

*BalanceProof*

* uint64: nonce
* uint256: transferred_amount
* bytes32: locksroot
* uint256: channel_identifier
* address: token_network_address
* uint256: chain_id
* bytes32: additional_hash
* bytes: signature


*Lock*

* uint64: expiration
* uint256: locked_amount
* bytes32: hashlock

Public Endpoints
----------------

A path finding service must provide the following endpoints. The interface has to be versioned.

The examples provided for each of the endpoints is for communication with a REST endpoint.

``api/1/balance``
^^^^^^^^^^^^^^^^^

Update the balance for the given channel with the provided balance proof. The receiver can be read from the balance proof.

Arguments
"""""""""

+----------------------+---------------+-------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                      |
+======================+===============+===================================================================+
| channel_id           | int           | The channel for which the balance proof should be updated.        |
+----------------------+---------------+-------------------------------------------------------------------+
| balance_proof        | BalanceProof  | The new balance proof which should be used for the given channel. |
+----------------------+---------------+-------------------------------------------------------------------+
| locks                | List[Lock]    | The list of all locks used to compute the locksroot.              |
+----------------------+---------------+-------------------------------------------------------------------+

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
            "nonce" = 1234,
            "transferred_amount" = 23,
            "locksroot" = "<keccak-hash>",
            "channel_id" = 123,
            "token_network_address" = "0xtoken"],
            "chain_id" = 1,
            "additional_hash" = "<keccak-hash>",
            "signature" = "<signature>"
        },
        "locks": [
            {
                "expiration": 200
                "locked_amount": 40
                "hashlock": "<keccak-hash>"
            },
            {
                "expiration": 50
                "locked_amount": 10
                "hashlock": "<keccak-hash>"
            },
        ],
    }'  /api/1/balance
    // Result for success
    {
        "result": "OK"
    }
    // Result for failure
    {
        "error": "Invalid balance proof"
    }


``api/1/channels/<channel_id>/fee``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Update the fee for the given channel, for the outgoing channel from the partner who signed the message.

Arguments
"""""""""

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
| channel_id           | int           | The channel for which the fee should be updated.                      |
+----------------------+---------------+-----------------------------------------------------------------------+
| fee                  | int           | The new fee to be set.                                                |
+----------------------+---------------+-----------------------------------------------------------------------+
| signature            | bytes         | The signature of the channel partner for whom the channel is outgoing.|
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
        "signature" = "<signature>"
    }'  /api/1/channels/123/fee
    // Result for success
    {
        "result": "True"
    }
    // Result for failure
    {
        "error": "Invalid signature."
    }

``api/1/paths``
^^^^^^^^^^^^^^^

Request a list of possible paths from startpoint to endpoint for a given transfer value.

This method will be rate-limited in a configurable way. If the rate limit is exceeded, clients can be required to pay the path-finding service with RDN tokens via the Raiden Network. The required path for this payment will be provided by the service for free. This enables a simple user experience for light users without the need for additional on-chain transactions for channel creations or payments, while at the same time monetizing extensive use of the API.
To get payment information the *get_payment_info* method is used.

Arguments
"""""""""

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
| from                 | address       | The address of the payment initiator.                                 |
+----------------------+---------------+-----------------------------------------------------------------------+
| to                   | address       | The address of the payment target.                                    |
+----------------------+---------------+-----------------------------------------------------------------------+
| value                | int           | The amount of token to be sent.                                       |
+----------------------+---------------+-----------------------------------------------------------------------+
| num_paths            | int           | The maximum number of paths returned.                                 |
+----------------------+---------------+-----------------------------------------------------------------------+
| extra_data           | string        | ptional implementation specific marker for path finding preferences.  |
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

Example
"""""""
::

    // Request
    curl -X GET --data '{
        "from": "0xalice",
        "to": "0xbob",
        "value": 45,
        "num_paths": 10
    }'  /api/1/paths
    // Request with specific preference
    curl -X PUT --data '{
        "from": "0xalice",
        "to": "0xbob",
        "value": 45,
        "num_paths": 10,
        "extra_data": "min-hops"
    }'  /api/1/paths
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
        "error": "No suitable path found."
    }
    // Result for exceeded rate limit
    {
        "error": "Rate limit exceeded, payment required. Please call 'api/1/payment/info' to establish a payment channel or wait."
    }


``api/1/payment/info``
^^^^^^^^^^^^^^^^^^^^^^

Request price and path information on how and how much to pay the service for additional path requests.
The service is paid in RDN tokens, so they payer might need to open an additional channel in the RDN token network.

Arguments
"""""""""

+----------------------+---------------+-----------------------------------------------------------------------+
| Field Name           | Field Type    |  Description                                                          |
+======================+===============+=======================================================================+
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
|                      |               | *estimated_fee* property.                                             |
+----------------------+---------------+-----------------------------------------------------------------------+

If no possible path is found, the following error is returned:

* No suitable path found

Example
"""""""
::

    // Request
    curl -X GET --data '{
        "rdn_source_addressfrom": "0xrdn_alice",
    }'  api/1/payment/info
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
        "error": "No suitable path found."
    }


Open questions
==============

* How do clients open channels? Additional service offered by the pathfinding server?
* Is it OK to assume that clients address in the RDN token network is the same as in the (possibly) different network it asks the pathfinding service for a path?
* Are the updating endpoints publicly available or just for the matrix channel listener?
