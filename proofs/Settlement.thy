theory Settlement

imports Main

begin

text "This file contains an analysis of the settlement algorithm in the TokenNetwork contract.
https://raiden-network-specification.readthedocs.io/en/latest/smart_contracts.html#protocol-values-and-settlement-algorithm-analysis
The result so far confirms two things:
  lemma s1_correct: The value calculated as 'S1 = RmaxP1 - SL2' is equal to 'S1 = D1 - W1 + T2 - T1 - L1'.
  lemma s2_correct: Similarly for 'S2 = RmaxP2 - SL1' and 'S2 = D2 - W2 + T1 - T2 - L2'.
The required conditions appear in the statements of the lemma.
"

text "TODO:
* Make sure that, you can only lose tokens if you submit an older balance proof.
"

type_synonym impl_number = "int option"

definition valid :: "int \<Rightarrow> bool"
  where "valid a = (0 \<le> a \<and> a < 2 ^ 256)"

definition chop :: "int \<Rightarrow> impl_number"
  where
    "chop a = (if valid a then Some a else None)" (* has to change it to min/max*)

fun impl_add :: "impl_number \<Rightarrow> impl_number \<Rightarrow> impl_number"
  where
  "impl_add None _ = None"
| "impl_add _ None = None"
| "impl_add (Some a) (Some b) =
     chop (a + b)"

value "impl_add (Some 10) (Some 25)"
value "impl_add (Some 10) (Some 1)"


fun impl_sub :: "impl_number \<Rightarrow> impl_number \<Rightarrow> impl_number"
  where
  "impl_sub None _ = None"
| "impl_sub _ None = None"
| "impl_sub (Some a) (Some b) =
    chop (a - b)"

value "impl_sub (Some 100) (Some 200)"


fun impl_min :: "impl_number \<Rightarrow> impl_number \<Rightarrow> impl_number"
  where
  "impl_min None _ = None"
| "impl_min _ None = None"
| "impl_min (Some a) (Some b) =
    chop (min a b)"

value "impl_sub (Some 100) (Some 200)"


(*** settlement algorithm ***)

definition TLmax1 :: "int \<Rightarrow> int \<Rightarrow> impl_number" where
"TLmax1 T1 L1 = impl_add (Some T1) (Some L1)"

definition TLmax2 :: "int \<Rightarrow> int \<Rightarrow> impl_number" where
"TLmax2 T2 L2 = impl_add (Some T2) (Some L2)"

definition RmaxP1_pre :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> impl_number" where
"RmaxP1_pre T1 L1 T2 L2 D1 W1 =
  impl_sub (impl_add (impl_sub (TLmax2 T2 L2) (TLmax1 T1 L1)) (Some D1)) (Some W1)"

definition TAD :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> impl_number" where
"TAD D1 D2 W1 W2 = impl_sub (impl_sub (impl_add (Some D1) (Some D2)) (Some W1)) (Some W2)"

definition RmaxP1 :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> impl_number" where
"RmaxP1 T1 L1 T2 L2 D1 W1 D2 W2 =
  impl_min (TAD D1 D2 W1 W2) (RmaxP1_pre T1 L1 T2 L2 D1 W1)"

definition SL2 :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> impl_number" where
"SL2 T1 L1 T2 L2 D1 W1 D2 W2 =
   impl_min (RmaxP1 T1 L1 T2 L2 D1 W1 D2 W2) (Some L2)"

definition S1 :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> impl_number" where
"S1 T1 L1 T2 L2 D1 W1 D2 W2 =
   impl_sub (RmaxP1 T1 L1 T2 L2 D1 W1 D2 W2) (SL2 T1 L1 T2 L2 D1 W1 D2 W2)"

definition RmaxP2 :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> impl_number"
  where
"RmaxP2 T1 L1 T2 L2 D1 W1 D2 W2 =
    impl_sub (TAD D1 D2 W1 W2) (RmaxP1 T1 L1 T2 L2 D1 W1 D2 W2)"

definition SL1 :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> impl_number"
  where
"SL1 T1 L1 T2 L2 D1 W1 D2 W2 = impl_min (RmaxP2 T1 L1 T2 L2 D1 W1 D2 W2) (Some L1)"

definition S2 :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> impl_number"
  where
"S2 T1 L1 T2 L2 D1 W1 D2 W2
 = impl_sub (RmaxP2 T1 L1 T2 L2 D1 W1 D2 W2) (SL1 T1 L1 T2 L2 D1 W1 D2 W2)"

definition spec_s1 :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int"
  where
"spec_s1 T1 T2 D1 W1 L1 = D1 - W1 + T2 - T1 - L1"

definition spec_s2 :: "int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int"
  where
"spec_s2 T1 T2 D2 W2 L2 = D2 - W2 + T1 - T2 - L2"

lemma s1_correct :
"
valid T1 \<Longrightarrow> (* because it's uint256 *)
valid T2 \<Longrightarrow> (* because it's uint256 *)
valid L1 \<Longrightarrow> (* because it's uint256 *)
valid L2 \<Longrightarrow> (* because it's uint256 *)
valid D1 \<Longrightarrow> (* because it's uint256 *)
valid D2 \<Longrightarrow> (* because it's uint256 *)
valid W1 \<Longrightarrow> (* because it's uint256 *)
valid W2 \<Longrightarrow> (* because it's uint256 *)
valid (T1 + L1) \<Longrightarrow> (* (11 R) *)
valid (T2 + L2) \<Longrightarrow> (* (11 R) *)
valid (D1 + D2) \<Longrightarrow> (* (12) *)
D1 - W1 + T2 - T1 - L1 \<ge> 0 \<Longrightarrow>  (* (5 R) *)
D1 - W1 + T2 - T1 - L1 \<le> D1 + D2 - W1 - W2 \<Longrightarrow> (* (5 R) *)
-(D1 - W1) <= T2 + L2 - T1 - L1 \<and> T2 + L2 - T1 - L1 <= D2 - W2 \<Longrightarrow> (* (7 R) *)
T2 + L2 \<ge> T1 + L1 \<Longrightarrow>
S1 T1 L1 T2 L2 D1 W1 D2 W2 = (Some (spec_s1 T1 T2 D1 W1 L1))"
  by(auto simp add: valid_def spec_s1_def S1_def RmaxP1_def RmaxP1_pre_def TAD_def chop_def
 TLmax2_def SL2_def TLmax1_def chop_def )



lemma s2_correct :
"
valid T1 \<Longrightarrow> (* because it's uint256 *)
valid T2 \<Longrightarrow> (* because it's uint256 *)
valid L1 \<Longrightarrow> (* because it's uint256 *)
valid L2 \<Longrightarrow> (* because it's uint256 *)
valid D1 \<Longrightarrow> (* because it's uint256 *)
valid D2 \<Longrightarrow> (* because it's uint256 *)
valid W1 \<Longrightarrow> (* because it's uint256 *)
valid W2 \<Longrightarrow> (* because it's uint256 *)
valid (T1 + L1) \<Longrightarrow> (* (11 R) *)
valid (T2 + L2) \<Longrightarrow> (* (11 R) *)
valid (D1 + D2) \<Longrightarrow> (* (12) *)
D1 - W1 + T2 - T1 - L1 \<ge> 0 \<Longrightarrow>  (* (5 R) *)
D2 - W2 + T1 - T2 - L2 \<ge> 0 \<Longrightarrow>  (* something similar to (5 R) but not documented in the spec *)
D1 - W1 + T2 - T1 - L1 \<le> D1 + D2 - W1 - W2 \<Longrightarrow> (* (5 R) *)
D2 - W2 + T1 - T2 - L2 \<le> D1 + D2 - W1 - W2 \<Longrightarrow> (* something similar to (5 R) but not documented in the spec *)
-(D1 - W1) <= T2 + L2 - T1 - L1 \<and> T2 + L2 - T1 - L1 <= D2 - W2 \<Longrightarrow> (* (7 R) *)
T2 + L2 \<ge> T1 + L1 \<Longrightarrow>
S2 T1 L1 T2 L2 D1 W1 D2 W2 = (Some (spec_s2 T1 T2 D2 W2 L2))"
  apply(auto simp add: valid_def spec_s2_def S2_def RmaxP2_def SL1_def TLmax1_def spec_s1_def S1_def RmaxP1_def RmaxP1_pre_def TAD_def chop_def
 TLmax2_def SL2_def)
  by linarith

end