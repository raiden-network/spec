Transport
#########

Overview
========

Raiden is a network agnostic protocol. Protocol messages can in general be transferred over
any network, e.g. ip, mesh networks, etc., where the only requirement is access to an
Ethereum node.
For efficient and reliable messaging, the reference implementation of Raiden currently **only**
supports Matrix, an open standard
for peer-to-peer messaging based on a server federation.


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

Proposed Solution: Federation of Matrix Homeservers
===================================================
https://matrix.org/docs/guides/faq.html

Matrix is a federated open source messaging system, which supports group communication
(multicast) via chat rooms. Direct messages are modeled as 2 participants in a private chat room.
Homeservers can be extended with custom logic (application services) e.g. to enforce certain rules (or message formats) in a room.  It provides JS and Python bindings and communication is done via HTTP long polling. Although additional server logic may be implemented to enforce some of the rules below, this enforcement must not be a requirement for a server to join the servers federation. Therefore, any standard Matrix server should work on the network.

Use in Raiden
=============

Identity
--------

The identity verification MUST not be tied to Matrix identities.
Even though Matrix provides an identity server, it is a possible central point of failure. All state-changing messages passed between participants MUST be signed using the private key of the ethereum account, using Matrix only as a transport layer.

The messages MUST be validated using ecrecover by receiving parties.

The conventions below provide the means for the discovery process, and affect only the transport layer (thus not tying the whole stack to Matrix). It's enforced by the clients, and is not a requirement enforced by the server.

Matrix's ``userId`` (defined at registration time, in the form ``@<userId>:<homeserver_uri>``) is required to be an ``@``, followed by the lowercased ethereum address of the node, possibly followed by a 4-bytes hex-encoded random suffix, separated from the address by a dot, and continuing with the domain/server uri, separated from the username by a colon.

This random suffix to the username serves to avoid a client being unable to register/join the network due to someone already having taken the canonical address on an open-registration server. It may be pseudo-randomly/deterministically generated from a secret known only by the account (e.g. a Python's ``Random()`` generator initialized with a secret derived from the user's privatekey). The same can be applied to the password generation, possibly including the server's URI on the generation process to avoid password-reuse. These conventions about how to determine the suffix and password can't be enforced by other clients, but may be useful to allow retrieval of credentials upon state-loss.

As anyone can register any ``userId`` on any server, to avoid the need to process every invalid message, it's required that ``displayName`` (an attribute for every matrix-user) is the signature of the full ``userId`` with the same ethereum key. This is just an additional layer of protection, as the state-changing messages have their signatures validated further up in the stack.

Example:

::

    seed = int.from_bytes(web3.eth.sign(b'seed')[-32:], 'big')
    rand = Random()
    rand.seed(seed)
    suffix = rand.randint(0, 0xffffffff)
    # 0xdeadbeef
    username = web3.eth.defaultAccount + "." + hex(suffix)  # 0-left-padded
    # 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.deadbeef
    password = web3.eth.sign(server_uri)
    matrix.register_with_password(username, password)
    userid = "@" + username + ":" + server_uri
    matrix.get_user(userid).set_display_name(web3.eth.sign(userid))


Discovery
---------

In the above system, clients can search the matrix server for any “seen” user whose ``displayName`` or ``userId`` contains the ethereum address (through server-side user directory search). The server is made to know about users in the network by sharing a "global" presence room. Candidates for being the actual user should only be considered after validating their ``displayName`` as being the signed ``userId``. Most of the time though trust should not be required and all possible candidates may be contacted/invited (for a channel room, for example), as the actual interactions (messages) will always be validated up the stack. Privacy can be provided by using private p2p rooms (invite-only, encrypted rooms with 2 participants).
The global presence rooms shouldn't be listened for messages nor written to in order to avoid spam. They should have the name in the format ``raiden_<network_name_or_id>_discovery`` (e.g. ``raiden_ropsten_discovery``), and be in a hardcoded homeserver. Such a server isn't a single point of failure because it's federated between all the servers in the network but it must have an owner server to be found by other clients/servers.


Presence
--------

Matrix allows to check for the presence of a user. Clients should listen for changes in presence status of users of interest (e.g. peers), and update user status if required (e.g. gone offline), which will allow the Raiden node to avoid trying to use this user e.g. for mediating transfers.

Sending transfer messages to other nodes
----------------------------------------


Private channel rooms have random room_ids in the format ``random_room_id:homeserver``, where the
random room_id is generated by the server. For convenience, they have an alias in the format
``raiden_<network_name_or_id>_<peerA>_<peerB>``,
where ``peerA`` and ``peerB`` are sorted in lexical-order.
As the users may roam to other homeservers, participants should keep listening for user-join events
in the presence room, if it's a user of interest (with which it shares a room), with valid signed
``displayName`` and not yet in the room we share with it, invite it to the room.



Chat Rooms
----------

Peer discovery room
'''''''''''''''''''
One per network. Participants can discover peers willing to open more channels. It may be implemented in the future as one presence/peer discovery room per token network, but it'd complicate the room-ownership/creation/server problem (rooms need to belong to a server. Whose server? Who created it? Who has admin rights for it?).

Monitoring Service Updates Room
'''''''''''''''''''''''''''''''
Raiden nodes can submit a :term:`MonitoringRequest` to the Monitoring Service room when they go
offline. The Monitoring Service will submit their balance proof on their behalf.

Pathfinding Service Updates Room
''''''''''''''''''''''''''''''''
Raiden Nodes publish :term:`PFSCapacityUpdate` and :term:`PFSFeeUpdate` to the Pathfinding Service room. The Pathfinding Service can
 compute efficient routes throughout the network and provide these routes to requesting nodes.
