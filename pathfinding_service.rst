Pathfinding Service Specification
#################################

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

The following data types are taken from the Raiden Core spec. **TODO**

*channel_id*

* **TODO**

*balance_proof*

* Uint64: nonce
* Uint256: transferred_amount
* Bytes32: locksroot
* Bytes32: extra_hash
* Bytes: signature

Public Endpoints
----------------

A path finding service must provide the following endpoints. The communication protocol is not yet decided (**TODO**). The interface has to be versioned as well.

The examples provided for each of the endpoints is for communication in JSON-RPC format.

``v1.update_balance(channel_id, balance_proof)``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Update the balance for the given channel with the provided balance proof. The receiver can be read from the balance proof.

Arguments
"""""""""
* *channel_id*: The channel for which the balance proof should be updated.
* *balance_proof*: The new balance proof which should be used for the given channel.

Returns
"""""""
True when the balance was updated or one of the following errors:

* Invalid balance proof
* Invalid channel id

Example
"""""""
::

    // Request
    curl -X POST --data '{
        "jsonrpc": "2.0",
        "method": "update_balance",
        "params": ["0x12345", balance_proof],
        "id": 67
    }'
    // Result for success
    {
        "id": 67,
        "jsonrpc": "2.0",
        "result": true
    }
    // Result for failure
    {
        "id": 67,
        "jsonrpc": "2.0",
        "error": "Invalid balance proof"
    }


``v1.update_fee(channel_id, fee, signature)``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Update the fee for the given channel, for the outgoing channel from the partner who signed the message.

Arguments
"""""""""
* *channel_id*: The channel for which the fee should be updated.
* *fee*: The new fee to be set.
* *signature*: The signature of the channel partner for whom the channel is outgoing.

Returns
"""""""
True when the fee was updated or one of the following errors:

* Invalid channel id
* Invalid signature

Example
"""""""
::

    // Request
    curl -X POST --data '{
        "jsonrpc": "2.0",
        "method": "update_fee",
        "params": ["0x12345", 2345, "0xsignature"],
        "id":67
    }'
    // Result for success
    {
        "id": 67,
        "jsonrpc": "2.0",
        "result": true
    }
    // Result for failure
    {
        "id": 67,
        "jsonrpc": "2.0",
        "error": "Invalid signature."
    }

``v1.get_paths(from, to, token_address, payment_value, num_paths, extra_data)``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Request a list of possible paths from startpoint to endpoint for a given transfer value.

This method will be rate-limited in a configurable way. If the rate limit is exceeded, clients can be required to pay the path-finding service with RDN tokens via the Raiden Network. The required path for this payment will be provided by the service for free. This enables a simple user experience for light users without the need for additional on-chain transactions for channel creations or payments, while at the same time monetizing extensive use of the API.
To get payment information the *get_payment_info* method is used.

Arguments
"""""""""
* *from*: The address of the payment initiator.
* *to*: The address of the payment target.
* *token_address*: The new fee to be set.
* *payment_value*: The amount of token to be sent.
* *num_paths*: The maximum number of paths returned.
* *extra_data*: Optional implementation specific marker for path finding preferences, e.g. shortest path or minimal fees.

Returns
"""""""
A list of path objects. A path object consists of the following information:

* An ordered list of the addresses that make up the payment path
* An estimate of the fees required for that path.

If no possible path is found, one of the following errors is returned:

* No suitable path found
* Rate limit exceeded
* From or to invalid

Example
"""""""
::

    // Request
    curl -X POST --data '{
        "jsonrpc": "2.0",
        "method": "get_paths",
        "params": ["0xalice", "0xbob", 100, 10],
        "id": 67
    }'
    // Request with specific preference
    curl -X POST --data '{
        "jsonrpc": "2.0",
        "method": "get_paths",
        "params": ["0xalice", "0xbob", 100, 10, "min-fee"],
        "id": 67
    }'
    // Result for success
    {
        "id": 67,
        "jsonrpc": "2.0",
        "result": [
        {
            "path": ["0xalice", "0xcharlie", "0xbob"],
            "estimated_fees": 12_000
        },
        {
            "path": ["0xalice", "0xeve", "0xdave", "0xbob"]
            "estimated_fees": 25_000
        },
        ...
        ]
    }
    // Result for failure
    {
        "id": 67,
        "jsonrpc": "2.0",
        "error": "No suitable path found."
    }
    // Result for exceeded rate limit
    {
        "id": 67,
        "jsonrpc": "2.0",
        "error": "Rate limit exceeded, payment required. Please call ‘get_payment_info’ to establish a payment channel or wait."
    }


``v1.get_payment_info(rdn_source_address)``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Request price and path information on how and how much to pay the service for additional path requests.
The service is paid in RDN tokens, so they payer might need to open an additional channel in the RDN token network.

Arguments
"""""""""
* *rdn_source_address*: The address of payer in the RDN token network.

Returns
"""""""
An object consisting of two properties:

* *price_per_request*: The price of one path request for this path finding service
* *paths*: A list of possible paths to pay the path finding service in the RDN token network. Each object in the list contains a path and an estimated_fee property.

If no possible path is found, the following error is returned:

* No suitable path found

Example
"""""""
::

    // Request
    curl -X POST --data '{
        "jsonrpc": "2.0",
        "method": "get_payment_info",
        "params": ["0xrdn_alice"],
        "id":67
    }'
    // Result for success
    {
        "id": 67,
        "jsonrpc": "2.0",
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
        "id": 67,
        "jsonrpc": "2.0",
        "error": "No suitable path found."
    }


Open questions
==============

* How do clients open channels? Additional service offered by the pathfinding server?
* Is it OK to assume that clients address in the RDN token network is the same as in the (possibly) different network it asks the pathfinding service for a path?
* Do we need some kind of monitoring?
* Are the updating endpoints publicly available or just for the matrix channel listener?
* Is JSON-RPC a suitable communication protocol? What is the plan for the Monitoring service?

Next steps
==========

* Wait for a final specification of a channel id and balance proof and link the raiden protocol spec
* Define data types for all arguments
