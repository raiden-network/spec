#########################
Raiden transport messages
#########################

Transport
=========
Messages are exchanged in JSON format using Matrix as a transport layer. Messages can be sent either via broadcast channel or via direct messaging
channel.

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
* For ecrecover-able signatures, Sender identity SHOULD be verified.

Simplest valid message is defined as follows

``
{}
``


Example of a message
-------------------

``
{
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


