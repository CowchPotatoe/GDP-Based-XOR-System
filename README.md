# GDP-Based XOR System (8-bit)

Designed a datapath-based system using the provided modified GDP to compute an 8-bit bitwise XOR operation. 
The design was implemented in SystemVerilog and verified using a testbench in ModelSim.

---

## Overview
This system computes:
```
Z = X XOR Y
```
Since the ALU does not support XOR directly, the operation is implemented using:
```
Z = (~X & Y) | (X & ~Y)
```
## Features
* 8-bit XOR computation using ALU NOT, AND, OR
* Sequential input handling (X then Y)
* Finite State Machine (FSM)-based Control Unit
* Verified using 10 test vectors from file input

---

## Datapath Notes
* ALU modified to use bitwise NOT (`~`) instead of logical NOT (`!`)
* XOR implemented using:
  * `~X`
  * `~Y`
  * AND operations
  * OR combination
* Intermediate results stored across states

---
## Control Unit Design
### States (example)
* `S0`: Idle / انتظار Start
* `S1`: Load X
* `S2`: Load Y
* `S3`: Compute ~X
* `S4`: Compute ~Y
* `S5`: Compute (~X & Y)
* `S6`: Compute (X & ~Y)
* `S7`: Compute final OR → Z
* `S8`: Done

## Testbench
* Reads 10 input pairs from `testvector.txt`
* Each line format:
  ```
  XX YY
  ```
* Applies inputs using Start signal (active-low)
* Computes expected result using:
  ```
  expected = X ^ Y
  ```
* Compares with system output

---

### Output Format
```
X=__ Y=__ Expected=__ Got=__ PASS/FAIL
```

---

