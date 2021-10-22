Transport
#########

Overview
========

Raiden is a network agnostic protocol. Protocol messages can in general be transferred over
any network, e.g. ip, mesh networks, etc., where the only requirement is access to an
Ethereum node.
For efficient and reliable messaging, the reference implementation of Raiden currently **only**
supports Matrix, an open standard for peer-to-peer messaging based on a server federation.


Requirements
============
* Unicast Messages
* Broadcast Messages
* E2E encryption for unicast messages
* Authentication (i.e. messages should be linkable to an Ethereum account)
* Low latency (~100ms)
* Scalability
* Spam protection / Sybil Attack resistance
* Decentralization (no single point of failure / censorship resistance)
* Off the shelf solution, well maintained
* JS + Python SDK
* Open Source / Open Protocol

Current Solution: Federation of Matrix Homeservers
===================================================
https://matrix.org/docs/guides/faq.html

Matrix is a federated open source messaging system, which supports group communication
(multicast) via chat rooms. Direct messages are modeled as 2 participants in a private chat room.
Homeservers can be extended with custom logic (application services, password providers) e.g. to enforce certain rules (or message formats) in a room.
It provides JS and Python bindings and communication is done via REST API and HTTP long polling.



Use in Raiden
=============

Identity
--------

The identity verification MUST not be tied to Matrix identities.
Even though Matrix provides an identity system, it is a possible central point of failure.
All state-changing messages passed between participants MUST be signed using the private key of the ethereum account,
using Matrix only as a transport layer.

The messages MUST be validated using ecrecover by receiving parties.

The conventions below provide the means for the discovery process, and affect only the transport layer (thus not tying the whole stack to Matrix).

Authentication
--------------

A Matrix ``userId`` is required to be of the form ``@<eth-address>:<homeserver-uri>``, an ``@``, followed by
the lowercased ``0x`` prefixed ethereum address of the node and the homeserver uri, separated from the username by a colon.

To prevent malicious name squatting all Matrix servers joining the Raiden federation must enforce the following rules:

#. Account registration must be disabled
#. A password provider that ensures only users in control of the private key corresponding to their node address can log in.
   This is done by using an ec-recoverable signature of the server name the Raiden node is connecting to (without any protocol prefix) as the password.
   The password provider must verify the following:

   #. The user-id matches the format described above.
   #. The ``homeserver_uri`` part of the user-id matches the local hostname.
   #. The password is a valid ``0x`` prefixed, hex encoded ec-recoverable signature of the local hostname.
   #. The recovered address matches the ``eth-address`` part of the user-id.

#. Every Raiden node must set it's Matrix ``displayName`` to a ``0x`` prefixed hex encoded ec-recoverable signature of their complete user-id.

Example:
::

    username = web3.eth.defaultAccount  # 0-left-padded
    # 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    password = web3.eth.sign(server_uri)
    matrix.login_with_password(username, password)
    userid = "@" + username + ":" + server_uri
    matrix.get_user(userid).set_display_name(web3.eth.sign(userid))


.. _transport-discovery-presence:

Discovery & Presence
--------------------

Discovery and presence (online/offline status of participants) is currently handled by the Pathfinding Services ("PFS"):
A PFS connects to all known Matrix home servers and gathers the ``userId`` and presence status of 
all users connected to the corresponding home server.
The matrix server needs to give the connected services special permission to be able 
to receive the presences of the connected matrix-clients. A compliant homeserver should only grant 
those permissions to services that are :ref:`registered on the blockchain <ServiceRegistry>`. 

With the combined information of all avaible home servers, a PFS can construct a global view of all 
particpant's online statuses and user-ids and provide this information to nodes of the Raiden network.

The Raiden nodes will need this information for peer-to-peer ("P2P") communication, especially adjacent
nodes on the graph of payment channels will require knowledge of each other's discovery and presence information.

A Raiden node interested in the peer's transport information should be able to either query this information 
for free at a specific endpoint at a PFS or receive this information as part of a paid path-request for all nodes 
along the returned path.

Since it would be infeasible for each node along a payment path to query a peer's information during the transfer individually,
the initiator should retrieve discovery and presence information along a payment's route once, and include it in the transfer's :ref:`metadata <metadata>`.
Like that, all nodes along the path can extract the necessary peer's information and avoid an explicit request to the PFS.


Sending transfer messages to other nodes
----------------------------------------

There are two different ways to send messages between Raiden nodes:

* Matrix ``toDevice`` P2P messages
* Messages over WebRTC channels


Matrix ``toDevice`` messages
''''''''''''''''''''''''''''

Matrix supports so-called ``toDevice`` messages. These are not stored permanently as
part of a shared communication history and are delivered exactly once to each
client device.

As Raiden does not rely on the messaging history, this feature can be used for P2P 
communication between nodes as well as communication between nodes and services.

The ability to handle and send Matrix based P2P messages is a requirement for a functioning node.

Node to node communication
^^^^^^^^^^^^^^^^^^^^^^^^^^

P2P communication for Raiden protocol messages is done via Matrix to-device messages.
The message sending node needs to know the recipient node's current ``userId`` (and therefore implicitly the node's current homeserver),
either from a direct request to the PFS, or from address-metadata provided from a previous node (see :ref:`Discovery & Presence <transport-discovery-presence>`).

Nodes are expected to  set their ``deviceId`` to ``RAIDEN``,
so that clients sending ``toDevice`` messages have to specify ``RAIDEN`` as the target ``deviceId``.

Broadcast from node to services
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Raiden nodes will push some updates about their state to the Raiden services:
they can broadcast a :term:`MonitoringRequest` to the Monitoring Services ("MS") when they go
offline. A Monitoring Service will then submit their balance proof on their behalf.
A node can also publish a :term:`PFSCapacityUpdate` and :term:`PFSFeeUpdate` to the PFSes. With this information the PFSes can
compute efficient routes throughout the network and provide these routes to requesting nodes.

On the transport level, this one-way flow of information is conceptually a broadcast from the node to all services of a specific kind.
Internally, the broadcast is implemented as several individual to-device messages to all services of a specific
kind. Here, the ``userId`` of each service registered on-chain is constructed deterministically from the node, so that:

::

        "@<address registered on-chain>:<home server of sender's raiden node>"


Also, the ``deviceId`` has to be set to ``PATH_FINDING`` for messages to the PFSes and to ``MONITORING`` for messages 
to the MSes.

The services therefore have to have one Matrix client listening and registered per registered transport server and the
``deviceId`` of those clients has to be set to ``PATH_FINDING`` or ``MONITORING`` accordingly.

WebRTC messaging
''''''''''''''''
To further optimize the communication, exchanging messages in a peer-to-peer
manner is possible with WebRTC. In that case matrix is only used to initiate the
WebRTC connection via P2P ``toDevice`` messages, and successive communication between 
nodes is handled over a webRTC data-channel.

Nodes that support WebRTC messages signal this functionality with the ``webRTC`` capability.
The requirement is optional, but lack thereof will reduce transfer speeds significantly.

To establish a WebRTC data-channel with another peer, the clients are expected to:

#. Get peer's presence/address-metadata information, either from a PFS's specific endpoint or from a passing-through ``LockedTransfer``
#. Verify that the peer has ``webRTC`` capability
#. Signaling messages are sent to peer's ``userId`` using ``toDevice`` matrix messages, with ``type`` as ``m.room.message`` (even though it's not in a Matrix room) and ``content`` as ``{ "msgtype": "m.notice", "body": <payload> }``, where ``payload`` is the JSON-encoded string of an object in the format ``{ "type": <signal_type>, "call_id": <dataChannel.label>, ...<rest of payload> }``
#. In parallel, start a call of its own, and also listen for calls/offers from peers of interest:

   #. On the caller side:

      #. create a ``RTCPeerConnection`` and a ``dataChannel`` on it, with whatever label is desired, to uniquely identify this channel upon related messages (e.g. ``<0xCaller_address>|<0xCallee_address>|<timestamp>``)
      #. start listening for ``ICECandidates`` on this connection, and send them to peer, with ``type="candidates"`` and a ``candidates`` payload member containing an array with the gathered candidates
      #. create an ``offer``, set it as ``local description`` on connecting, and send it to the peer with ``type="offer"`` and a ``sdp`` payload member containing the offer string
      #. wait for an ``answer`` message from peer, and upon receiving it, set it as ``remote description``; ``RTCDataChannel`` should then become ``open``
      #. a timeout may be put, to retry if neither this call nor callee's side managed to get a channel opened

   #. On the callee side:

      #. listen for ``offer`` messages
      #. when receiving an ``offer`` message from a peer of interest, create an ``RTCPeerConnection`` and set ``offer`` as ``remote description``
      #. start listening for ``ICECandidates`` on this connection, and send it to peer, the same as on caller's side
      #. create ``answer``, set it as ``local description`` and send it to peer, with ``type="answer"`` and ``sdp`` payload member containing the answer string
      #. wait for ``dataChannel`` to be emitted and to become ``open``
      #. listening for offers on callee is permanent and any new offer coming through, if successful, may disconnect previous callee or caller channels

#. Both caller and callee's codepaths can race; the winner of this race (first channel to become ``open``) for each pair of peers (by address) will disconnect the other direction, and this now-open ``RTCDataChannel`` will be kept and used for this partner's messaging
#. Upon channel error or close, peers may send a ``type="hangup"`` message, without additional payload members, and then possibly retry the loop above
#. Clients may retry whenever they want, if the peer is online; any new open RTC channel for each peer disconnects the previous one; usually, it's ok to retry this just a couple of times and give up, as partner seems to be offline or not responding, and assume they'll call when they come back online; additionally, they may trigger the loop again upon certain events, as new raiden ``ChannelOpen`` is detected or a message needs to be sent


Capabilities
------------

Raiden clients need a way to signal their capabilities to other nodes. This is done by encoding the capabilities in the ``avatar_url`` field of the user profile.

Serialization for use in ``avatar_url``
'''''''''''''''''''''''''''''''''''''''

The following template is used to encode the capabilities in the avatar URL field:
::

    mxc://raiden.network/cap?{capabilities_url_encoded}

Here ``{capabilities_url_encoded}`` is the url query parameter encoding of the capabilities.

Rules for url encoding:

* boolean values are encoded as truthy values, e.g. ``"0"`` and ``"1"``
* other values are encoded as strings
* lists of values are allowed

Deserialization
'''''''''''''''

The final interpretation of capability values is up to the receiving client, or rather the specified capability. It's expected that clients use truthiness of the supplied value when decoding boolean values.

Handling of unknown values
''''''''''''''''''''''''''

* Intentionally omitting (falsy or whatever) known default values is **discouraged**. Client implementations are asked to **explicitly** state all known capabilities.
* Client implementations have to deal with receiving new/unknown capabilities gracefully, i.e. they should expect the peer to act backwards compatible.
* Client implementations have to deal with not receiving known capabilities gracefully, i.e. assume the peer implementation is going to exert *legacy behavior* and therefore act backwards compatible.

Example
'''''''

::

    avatar_url = "mxc://raiden.network/cap?Delivered=0&Mediate=1&Receive=1&webRTC=1&list_capability=one&list_capability=two"
    capabilities_decoded = {
        'Delivered': False,
        'Mediate': True,
        'Receive': True,
        'webRTC': True,
        'list_capability': ['one', 'two']
    }
