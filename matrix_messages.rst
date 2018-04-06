#########################
Raiden transport messages
#########################

Definitions
===========
* Sender: entity sending the message
* Recipient: entity able to receive and decode the message
* Message: A data object exchanged between Sender and Recipient
* Message Field: an attribute of JSON data format that is required to be included in the message

Transport
=========
Messages are exchanged in JSON format.
Message itself contains metadata that allow recipient to verify sender of the message (via use of PK signatures).

Rationale
---------
* plaintext JSON messages are easy to read for both humans and machines
* JSON format is widely used and can be easily validated using JSON-schema (http://json-schema.org/)
* JSON is easily extensible and extension can be made backward-compatible
* Message format must not be dependent on the transport used - it should not matter whether the message is sent via Matrix or REST
* Sender identity verification must not be part of the transport. It should be possible to submit the message over an untrusted channel or delegate.

Fields validation
-----------------
* Receiver SHOULD use JSON schema to validate integrity of received message depending on the message type.
* For messages that contain data later used as a smart contract parameters, receiver MUST check for overflows and conversion errors.
* Any values to be used on-chain MUST NOT in any circuimstances be floats.
* For ecrecover-able signatures, sender identity SHOULD be verified.

Message format
--------------
The message MUST contain ``body`` field. Contents of the field are implementation dependent. Message MAY also contain other fields in the root
JSON object, but the application MUST NOT depend on existence of these fields.


Simplest message that MUST be accepted by the protocol is defined as follows

``
{ 'body': {} }
``


Example of a message
-------------------

``
{
    'body': {
        'type': 'SubmitBalanceProof',
        'network_id': 1,
        'balance_proof': {
            'signature': '0x123...abc',
            'nonce': 1
        },
        'reward_proof': {
            'signature': '0x234...def',
            'reward_amount': 100,
            'channel_id': 23
        }
    }
}
``

See also `Messaging SPEC
<https://github.com/raiden-network/spec/blob/master/messaging.rst>`_.


