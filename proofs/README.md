Proofs
======

Settlement.thy proves that [the settlement algorithm](https://github.com/raiden-network/spec/blob/c0e0316d09407df956b3368a4f05d98184d1e262/smart_contracts.rst#settlement-algorithm---solidity-implementation) produces numbers that make sense in terms of accounting.

How to see it's a proof
=======================

1. get Isabelle 2018 from https://isabelle.in.tum.de/.
2. open Settlement.thy in the Isabelle IDE with `$ Isabelle2018 Settlement.thy`
3. for the first time, wait 10 mins while Isabelle thinks through all basic facts about integers and so.
4. try removing an assumption 'valid (D1 + D2)' from lemmas.  Now the sum of the deposited amounts might overflow. Isabelle IDE should indicate that the proof is broken (you'll see a red '!').
