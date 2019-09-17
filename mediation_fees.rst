Raiden Mediation Fee Specification
##################################

Overview
========

Mediation fees are used to incentivize people to mediate payments. There are (currently) three components:

- Flat fees
- Proportional fees
- Imbalance penalty fees


Nomenclature
============

In this description a simple mediation node is assumed. The incoming channel (for the mediated payment) is also called **payer channel** and the outgoing channel is also called **payee channel**. This scenario is shown in the following graphic:

::

               c
    --> a --> (M) --> b -->

- :math:`a` is the locked amount of the payer channel. This locked amount includes fees.
- :math:`b` is the locked amount of the payee channel. This locked amount includes fees for further hops.
- :math:`c` is a helper value for making the calculation of mediation fees simpler. It is not exposed to the user.


In the calculation the different fees are used.

- :math:`f` is the flat fee
- :math:`i` is the imbalance fee


Converting per-hop proportional fees in per-channel proportional fees
=====================================================================

User usually think about deducting mediation fees as an atomic action, so it's
easier to let them define a *per-hop* proportional mediation fee (called
:math:`p`). However, this setting then needs to be converted into a
*per-channel* proportional fee (called :math:`q`).

.. math::

    \begin{split}
    b(1+p) &= b + bq + bq(1+p)  \\
    (1+p) &= 1 + q + q(1+p)  \\
    q + q(1+p) &= p \\
    q(2+p) &= p \\
    q &= \frac{p}{2+p}
    \end{split}

Fee calculation
===============

There are two fundamental formula to relate :math:`a`, :math:`b` and :math:`c`.

1. :math:`a = c + aq + f + i(-a)`

2. :math:`c = b + bq + f + i(b)`

The other fundamental relations are:

- :math:`a - {fee}_{in} = c`
- :math:`c - {fee}_{out} = b`

The imbalance fee :math:`i(x)` is defined as follows, where :math:`t` is the total channel balance and :math:`IP(x)` is the imbalance penalty function.

.. math::

    i(x) = IP(t + x) - IP(t)


.. note::

    These equations only have symbolic solutions when no imbalance fees are used. With imbalance fees only approximate solutions are presented below. This means that forward and backwards fee calculations can differ slightly.



Forward calculation (as in the client)
--------------------------------------

For the fee calculation in the client, only :math:`a` is known and it needs to calculate :math:`c` and :math:`b.`.

From (1) follows:

.. math::

    {fee}_{in} = a - c = qa + f + i(-a)

From (2) follows:

.. math::

    \begin{split}
    c &= b + bq + f + i(b) \\
    b &= \frac{c - f - i(b)}{1+q}
    \end{split}

This leads to

.. math::

    {fee}_{out} = c - b = c - \frac{c - f - i(b)}{1+q}

Here one can see that the calculation depends on both :math:`b` and :math:`c`. This formula doesn't have a symbolic solution for arbitrary functions :math:`i(x)`.

We approximate the solution by calculating :math:`b \approx b' = \frac{c - f}{1+q}` and than use that to solve for :math:`b` (which is the first iteration towards the solution which assumes :math:`i = 0`):

.. math::

    {fee}_{out} = c - b \approx c - \frac{c - f - i(b')}{1+q}

Backward calculation (as in the PFS)
------------------------------------

In the case of fee calculation in the PFS, only :math:`b` is known and it needs to calculate :math:`c` and :math:`a`.

From (2) follows:

.. math::

    {fee}_{out} = c - b = bq + f + i(b)

From (1) follows:

.. math::

    {fee}_{in} = a - c = \frac{c + f + i(-a)}{1-q} - c

Here the same approximation approach is used for the imbalance fee. The approximation :math:`i(-a')` with :math:`a' = \frac{c + f}{1+q}` is used in the symbolic solution.

.. math::

    {fee}_{in} = a - c \approx \frac{c + f + i(-a')}{1-q} - c



Example
-------

Let's assume:

- :math:`f = 100`
- :math:`q = 0.1`
- :math:`c = 1200`
- :math:`b = 1000`

Now forward and backward calculation should let us recalculate :math:`b` or :math:`c`.

**Client**

.. math::

    {fee}_{out} = c - b = c - \frac{c - f - i}{1+q} = 1200 - \frac{1200 - 100}{1 + 0.1} = 200

**PFS**

.. math::

    {fee}_{out} = c - b = bq + f + i = 1000 * 0.1 + 100 = 200
