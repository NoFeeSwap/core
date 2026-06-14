# Fuzz Testing for NoFeeSwap Core

## Overview

This document describes the **Echidna-based fuzz tests** implemented for the **NoFeeSwap core** repository.

Fuzz testing is used to randomly exercise critical smart contract functions in order to uncover:

- Edge-case failures  
- Memory safety issues  
- Assertion violations  

These are issues that traditional unit tests may not reliably detect.

## Implemented Fuzz Tests

Two main fuzz tests were implemented:

- **`PriceEchidna.sol`**  
  Tests the `Price.storePrice()` function.

- **`PriceEchidnaModifyPosition.sol`**  
  Tests `readModifyPositionInput()` as part of the  
  `INofeeswapDelegatee.modifyPosition()` execution flow.

## Test Coverage Goals

These fuzz tests focus on validating:

- Correctness of memory layout  
- Proper input decoding  
- Robustness against malformed or invalid inputs  

Together, they help ensure the safety and correctness of critical low-level logic in the NoFeeSwap core contracts.

---

## 1. PriceEchidna.sol – Testing `storePrice()`

### Purpose

This fuzz test ensures that the `storePrice()` function correctly writes price-related values to memory, specifically:

- `logPrice`
- `sqrtPrice`
- `sqrtInverse`

It also verifies that subsequent calls to:

- `log()`
- `sqrt(false)`
- `sqrt(true)`

return the exact values that were stored.

Additionally, the test checks surrounding memory regions to detect any unintended memory corruption.

### Highlights

- **Randomized Inputs**  
  Echidna generates random `int256` inputs for:
  - `log`
  - `sqrt`
  - `sqrtInverse`

- **Memory Safety**  
  Sentinel values are placed immediately before and after the target memory block. These sentinels are checked after execution to ensure no memory overwrite has occurred.

### Assertions

The following assertions validate correctness and memory safety:

```solidity
assert(X59.unwrap(logResult) == X59.unwrap(logPrice));
assert(X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice));
assert(X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInverse));
assert(sentinel_before_val == sentinelBefore);
assert(sentinel_after_val == sentinelAfter);
```
### Sanity Check

Optional deliberate errors (currently commented out) can be uncommented to confirm that Echidna properly detects and reports assertion failures.

### Commands to run:

```bash
echidna contracts/test/PriceEchidna.sol \
  --contract PriceEchidna \
  --test-mode assertion \
  --corpus-dir ./corpus
```

---

## 2. PriceEchidnaModifyPosition.sol – Testing `readModifyPositionInput()`

### Purpose

This fuzz test simulates calldata decoding for the `modifyPosition()` function and validates the correctness of how inputs are read and laid out in memory.

Specifically, it verifies:

- Correct assignment of `poolId`
- Proper decoding of `logPriceMin` and `logPriceMax`
- Correct handling of `shares`
- Accurate placement and copying of `hookData` in memory
- Correct calculation of the free memory pointer

It also ensures that arbitrary starting positions for `hookData` are handled safely.

### Highlights

- **Randomized Inputs**  
  Echidna generates random values for:
  - `poolId`
  - `logPriceMin` and `logPriceMax`
  - `shares`
  - `hookData` starting pointer and contents

- **Memory Safety**  
  Sentinel values are placed before and after the `hookData` memory region to detect any memory corruption or overwrite.

### Assertions

The following assertions enforce correctness, bounds, and memory safety:

```solidity
assert(logPriceMin > 0 && logPriceMin < (1 << 64));
assert(logPriceMax > 0 && logPriceMax < (1 << 64));
assert(shares != 0 && shares >= -(2**127) && shares <= 2**127 - 1);
assert(_hookDataByteCount <= type(uint16).max);
assert(_freeMemoryPointer == _hookDataPtr + _hookDataByteCount);
assert(sentinelBeforeVal == sentinelBefore);
assert(sentinelAfterVal == sentinelAfter);
```

### Sanity Check 

Optional deliberate failures (currently commented out) can be uncommented to confirm that Echidna correctly detects assertion violations.
Deliberate Failure Assertions (Optional)

The following assertions can be temporarily enabled to confirm that Echidna correctly detects failures and reports counterexamples:

```solidity
assert(_shares != shares);                   // mismatch test
assert(sentinelBeforeVal != sentinelBefore); // memory corruption test
assert(_hookDataByteCount != hookDataByteCount); // hookData length test
assert(logPriceMin <= 0);                    // zero-input failure (optional)
```

### Commands to run:

```bash
echidna contracts/test/PriceEchidnaModifyPosition.sol \
  --contract PriceEchidnaModifyPosition \
  --test-mode assertion \
  --corpus-dir ./corpus

```

---

### Key Learnings

- Solidity memory safety requires careful placement of sentinel values when fuzz testing.

- Randomized testing with Echidna complements unit tests, catching edge-case failures that deterministic tests may miss.

- Sanity-checking deliberate failures validates that your test properties are meaningful and enforceable.

- Arbitrary hookData starting positions can expose subtle bugs in calldata parsing.

---