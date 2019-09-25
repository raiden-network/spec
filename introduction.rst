Introduction
============


This is the specification of the `Raiden Network <http://raiden.network/>`_. Its goal is to provide
an exact description of the Raiden protocol.

For the Raiden clients (Raiden nodes), we will thus describe the format of messages it sends to other
raiden nodes, and the structure of a transfer composed of such messages. For implementation specific
information on the
`reference implementation of the Raiden client <https://github.com/raiden-network/raiden/>`_, like
its API, refer to the `docs <https://raiden-network.readthedocs.io/en/stable/index.html>`_ instead.

Components that the client relies on, such as the pathfinding service, monitoring service and
Raiden smart contracts, are specified here such that client implementations can be developed
against them, i. e. including a specified API.
