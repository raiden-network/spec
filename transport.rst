Raiden Transport
################

Requirements
============
* Unicast Messages
* Broadcast Messages
* E2E encryption for unicast messages
* Authentication (i.e. messages should be linkable to an Ethereum account)
* Low latency (~100ms)
* Scalability (??? messages/s)
* Spam protection / Sybil Attack resistance
* Decentralized (no single point of failure / censorship resistance)
* Off the shelf solution, well maintained
* JS + Python SDK
* Open Source / Open Protocol

Proposed Solution: Federation of Matrix Homeservers
===================================================
https://matrix.org/docs/guides/faq.html

Matrix is a federated open source store+forward messaging system, which supports group communication (multicast) via chat rooms. Direct messages are modeled as 2 participants in one chat room with appropriate permissions. Homeservers can be extended with custom logic (application services) e.g. to enforce certain rules (or message formats) in a room.  It provides JS and python bindings, communication is via HTTP long polling.

Use in Raiden
=============

Identity
--------

The identity verification MUST not be tied to Matrix identities. Even though Matrix provides identity server, it is a possible central point of failure. All messages passed between participants MUST be signed using privkey of the ethereum account, using Matrix only as a transport layer.
The messages MUST be validated using ecrecover by receiving parties.
In order to avoid replay attacks, message format MUST also include identity of the sender.

Discovery
---------

In the above system, clients can search matrix server for any “seen” user whose displayname or userId contains the ethereum address. These are candidates for being the actual user, but it should only be trusted after a challenge is answered with a signed message. Most of the time though trust should not be required, and all possible candidates may be contacted/invited (for a channel room, for example), as the actual interactions (messages) will then be signed.


Presence
--------

Matrix allows to check for the presence of a user.

Sending transfer messages to other nodes
----------------------------------------

Direct Message, which is modeled as a room with 2 participants.
Channel room may be derived from channel Id / event / hash. Participants may be invited, or voluntarily join upon detecting blockchain events of interest (participant).


Updating Monitoring Services
----------------------------
Either a) direct (DM to MS) or b) group communication (message in a group with all MS), possibly settings could be such, that only the MS are delivered the messages.

Updating Pathfinding Services
-----------------------------
Similar to above


Chat Rooms
----------

Peer discovery room
'''''''''''''''''''
One per each token network. Participants can discover peers willing to open more channels.

Monitoring Service Updater Room
'''''''''''''''''''''''''''''''
Raiden nodes that plan to go offline for an extended period of time can submit a :term:`balance proof` to the Monitoring Service room. The Monitoring Service will challenge Channel on their behalf in case there’s an attempt to cheat (i.e. close the channel using earlier BP)

Pathfinding Service Updater Room
''''''''''''''''''''''''''''''''
Raiden nodes can query shortest path to a node in a Pathfinding room.

Direct Communication Rooms
''''''''''''''''''''''''''
In Matrix, users can send direct e2e encrypted messages to each other.

Blockchain Event Rooms
''''''''''''''''''''''
Each RSB operator could provide a room, where relevant events from Raiden Token Networks are published. E.g. signed, so that false info could be challenged.

