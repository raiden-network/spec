Mediation Fees
##############

Overview
========

Mediation fees are used to incentivize people to mediate payments. There are (currently) three components:

- **Flat fees**:
  absolute fees paid per mediation.
- **Proportional fees**:
  fees that grows proportionally to the mediated amount.
- **Imbalance fees**:
  fees that can be both positive or negative, which are used incentivize mediations which put the channels into a state desired by the mediator.

Each of these fees is calculated by the mediator for both the incoming and outgoing channel. The sum of all fee components for both channels is the total mediation fee for a single mediator.

For an explanation why this fee system has been chosen, please consult the `architectural decision record`_.

.. _architectural decision record: https://github.com/raiden-network/raiden-services/blob/master/adr/003-mediation-fees.md

Imbalance Fees
==============

The imbalance fee is calculated from an Imbalance Penalty (IP) function. :math:`\mathit{IP}(\mathit{cap})` describes how much a node is willing to pay to bring a channel from the capacity :math:`\mathit{cap}` into its preferred capacity.

Mediators can choose arbitrary IP functions to describe which channel capacities are preferable for them and how important that is to them. If a node prefers to have a channel capacity of 5 while the total capacity of that channel is 10 (so that it could mediate up to 5 tokens in both directions) the IP function might look like

::

   IP
   ^
   |X                     X
   |X                     X
   | X                   X
   | X                   X
   |  X                 X
   |   X               X|
   |    X             X |
   |     X           X  |dIP = IP(cap_after) - IP(cap_before)
   |      XX       XX   |
   |        XX   XX----->
   |          XXX  amount
   +-----------+--+-----+--> Capacity
   0           5  6     9

If the node currently has a capacity of 6 and is asked to mediate a payment of 3 tokens coming from this channel, it will get into the less desired position of 9 capacity. To compensate for this, it will demand an imbalance fee of :math:`i = \mathit{IP}(9) - \mathit{IP}(6)`. If the situation was reversed and the capacity would go from 9 to 6, the absolute value would be the same, but this time it would be negative and thus incentivize moving towards the preferred state. By viewing the channel balances in this way, the imbalance fee is a zero sum game in the long term. All tokens which are earned by going into a bad state will be spent for moving into a good state again, later.

The flexible shape of the IP function allows to encode many different mediator intentions. If I use a channel solely to pay (apart from mediation), having more free capacity is always desired and any capacity gained by mediating in the reverse direction is welcome. In that case, the IP function could look like

::

   IP
   ^
   |X
   |X
   | X
   |  X
   |   XX
   |     XX
   |       XX
   |         XX
   |           XX
   |             XXX
   |                XXX
   +------------------------> Capacity

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

The mediation fees for a payment amount :math:`x` for a single channel are calculated as

.. math::

   \mathit{fee}_{\mathit{channel}}(x) := \mathit{flat} + q|x| + i(x)

where the imbalance fee for that channel is defined as

.. math::

    i(x) := \mathit{IP}(t + x) - \mathit{IP}(t)

and :math:`t` is the balance of the that channel. The amount :math:`x`
is positive for incoming channels and negative for outgoing channels to
reflect the change in balance. The values :math:`\mathit{flat}`,
:math:`\mathit{q}` and the function :math:`\mathit{IP}` comprise the
fee schedule for the channel.

To get the mediation fee for a single mediator, we have to sum up the fees
across both involved channels:

.. math::

   \begin{align}
   \mathit{fee}_m & := round(\mathit{fee}_{\mathit{in}}(\mathit{x_{in}}) + \mathit{fee}_{\mathit{out}}(-\mathit{x_{out}})) & (1)\\
   \mathit{fee}_m & := x_{in} - x_{out} & (2)
   \end{align}

When the mediator has enabled fee capping (which is the default), the result will not go below zero.

.. math::

   \mathit{fee}_{m\_capped} := max(\mathit{fee}_m, 0)



Forward calculation (used in the mediator)
------------------------------------------

A mediator already knows :math:`x_{in}`, but knows neither :math:`x_{out}` nor
:math:`\mathit{fee}_m` both of which can't be calculated directly without
knowing the other.  So instead of a directly calculating them, we solve the
equation we get by equating (1) and (2).

.. math::

   x_{in} - x_{out} = round(\mathit{fee}_{\mathit{in}}(\mathit{x_{in}}) + \mathit{fee}_{\mathit{out}}(-\mathit{x_{out}}))

The only unknown in this equation is :math:`x_{out}` which makes this
equivalent to finding the zero of
   
.. math::
   f(x_{out}) = round(\mathit{fee}_{\mathit{in}}(\mathit{x_{in}}) + \mathit{fee}_{\mathit{out}}(-\mathit{x_{out}})) - x_{in} + x_{out}

Due to the constraints on the fee schedule, this function is monotonically
decreasing. Thus there is only a single solution and it can be found easily by
following the slope into the right direction. Additionally, the current
implementation uses the fact that the mediation fees are a piecewise linear
function by only searching for the section that includes the solution and then
interpolating to get the exact solution.

Backward calculation (in the PFS)
------------------------------------

This works analogous to the forward calculation with the only difference that :math:`x_{in}` is the unknown variable and :math:`x_{out}` is given as input.

Example
-------

Let's assume no fees for the incoming channel and:

- :math:`\mathit{flat}_{out} = 100`
- :math:`q_{out} = 0.1`
- :math:`x_{in} = 1200`
- :math:`x_{out} = 1000`

Now forward and backward calculation should let us confirm that :math:`x_{in}`
and :math:`x_{out}` are correct.

**Mediator**

:math:`x_{in}` is known:

.. math::

   \begin{align}
   f(x_{out}) \stackrel{!}{=} 0 & = round(\mathit{fee}_{\mathit{in}}(\mathit{x_{in}}) + \mathit{fee}_{\mathit{out}}(-\mathit{x_{out}})) - x_{in} + x_{out} \\
   & = round(\mathit{fee}_{\mathit{out}}(-\mathit{x_{out}})) - x_{in} + x_{out} \\
   & = round(\mathit{flat_{out}} + q|x_{out}| + i(-x_{out}) - x_{in} + x_{out} \\
   & = round(100 + 0.1 \cdot x_{out}) - 1200 + x_{out} \\
   & \implies x_{out} = 1000
   \end{align}

.. plot::

   import matplotlib.pyplot as plt
   xs = [800, 1200]
   plt.plot(xs, [round(100 + 0.1 * x) - 1200 + x for x in xs])
   plt.axhline(0, color='gray')
   plt.plot([1000, 1000], [0,-220], linestyle='dashed')
   plt.xlabel('x_out')
   plt.ylabel('f(x_out)')

**PFS**

:math:`x_{out}` is known:

.. math::

   \begin{align}
   f(x_{out}) \stackrel{!}{=} 0 & = round(\mathit{fee}_{\mathit{in}}(\mathit{x_{in}}) + \mathit{fee}_{\mathit{out}}(-\mathit{x_{out}})) - x_{in} + x_{out} \\
   & = round(\mathit{fee}_{\mathit{out}}(-\mathit{x_{out}})) - x_{in} + x_{out} \\
   & = round(\mathit{flat_{out}} + q|x_{out}| + i(-x_{out}) - x_{in} + x_{out} \\
   & = round(100 + 0.1 \cdot 1000) - 1200 + 1000 \\
   & = round(200) - 200 = 0 \\
   \end{align}

Due to the simple example this is true for any :math:`x_{in}`. If there was a scheduling involving proportional or imbalance fees, we would need to find the intersection with the x-axis as above for the mediator.

Default Imbalance Penalty Curve
===============================

Requirements
------------

In order to make it easier to enable imbalance fees, the Raiden client
includes a default imbalance penalty (IP) function that can be configured by a single
parameter (``--proportional-imbalance-fee`` on the Raiden CLI).

The function is chosen to have the following properties:

1. It is convex, symmetric and defined for all values in the range :math:`[0,
   \mathit{capacity}]`
2. The penalty is zero when both channel participants have the same balance.
3. The highest point should have a given value :math:`f(0) := c`.
4. The slope should not exceed :math:`s := 0.1` to avoid awarding extreme
   incentives for transferring tokens.

To get reasonable values for channels with greatly varying capacity, the
maximum :math:`c` is chosen in proportion to the channel capacity.

Used Function
-------------

One function that fulfills these requirements is

.. math::
   f(x) := a|x-o|^b \\

where

.. math::
   \quad b := \frac{so}{c}, \quad a := \frac{c}{o^b}, \quad o > 0

when the offset :math:`o` is chosen to be half the total channel capacity (own balance + partner balance).

Derivation of :math:`a` and :math:`b`
-------------------------------------

Starting with the function formula and its derivative

.. math::
   \begin{align}
   f(x) &= a|x-o|^b \\
   f'(x) &= ab(x-o)|o-x|^{b-2}
   \end{align}

as well as the slope constraint

.. math::
   f(0) := c \quad\text{and}\quad f'(0) := -s

from the requirements, we can deduce the values for :math:`a`

.. math::
   \begin{align}
   f(0) &= c \\
   ao^b &= c \\
   a &= \frac{c}{o^b}
   \end{align}

and :math:`b`

.. math::
   \begin{align}
   f'(0) &= -s \\
   ab(-o)o^{b-2} &= -s \\
   abo^{b-1} &= s \quad \text{(now substitute a)}\\
   \frac{c}{o^b}bo^{b-1} = \frac{cb}{o} &= s \\
   b &= \frac{so}{c}
   \end{align}
