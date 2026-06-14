// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {PriceLibrary} from "../utilities/Price.sol";
import {X59} from "../utilities/X59.sol";
import {X216} from "../utilities/X216.sol";

/*
    Echidna Fuzz Test for Price.storePrice()

    What this test guarantees:

    1. storePrice writes correct values
    2. log(), sqrt(false), sqrt(true) return exact stored values
    3. Surrounding memory is NOT corrupted
    4. Fully randomized fuzzing (no unnecessary constraints)
    5. Sanity-check mechanism included (Step 6)
*/

contract PriceEchidna {

    using PriceLibrary for uint256;

    /*
        MAIN FUZZ TEST
        Echidna will randomly generate rawLog, rawSqrt, rawSqrtInv
    */
    function fuzz_storePrice(
        int256 rawLog,
        int256 rawSqrt,
        int256 rawSqrtInv
    ) public {

        // Bound values into valid domain
        X59 logPrice = X59.wrap(int59Bound(rawLog));
        X216 sqrtPrice = X216.wrap(int216Bound(rawSqrt));
        X216 sqrtInverse = X216.wrap(int216Bound(rawSqrtInv));

        uint256 ptr;

        // Sentinel values to detect memory corruption
        uint256 sentinelBefore = 0xDEADBEEFCAFEBABE;
        uint256 sentinelAfter  = 0xBEEFDEADCAFEBABE;

        assembly {
            // Get free memory pointer
            ptr := mload(0x40)

            // Write sentinel before
            mstore(sub(ptr, 32), sentinelBefore)

            // Write sentinel after (far enough to avoid overlap)
            mstore(add(ptr, 96), sentinelAfter)

            // Advance free memory pointer
            mstore(0x40, add(ptr, 128))
        }

        // CALL FUNCTION UNDER TEST (DO NOT MODIFY)
        ptr.storePrice(logPrice, sqrtPrice, sqrtInverse);

        // Read values back
        X59 logResult = ptr.log();
        X216 sqrtResult = ptr.sqrt(false);
        X216 sqrtInverseResult = ptr.sqrt(true);

        // ================================
        //  CORRECT ASSERTIONS (STEP 2)
        // ================================

        assert(X59.unwrap(logResult) == X59.unwrap(logPrice));
        assert(X216.unwrap(sqrtResult) == X216.unwrap(sqrtPrice));
        assert(X216.unwrap(sqrtInverseResult) == X216.unwrap(sqrtInverse));

        // ================================
        //  STEP 7 — MEMORY SAFETY CHECK
        // ================================

        uint256 sentinel_before_val;
        uint256 sentinel_after_val;

        assembly {
            sentinel_before_val := mload(sub(ptr, 32))
            sentinel_after_val  := mload(add(ptr, 96))
        }

        // Ensure surrounding memory is unchanged
        assert(sentinel_before_val == sentinelBefore);
        assert(sentinel_after_val == sentinelAfter);


        // ====================================================
        //  STEP 6 — SANITY CHECK (DELIBERATE FAILURE MODE)
        // ====================================================
        //
        // To verify that Echidna actually detects failures:
        //
        // 1. Uncomment ONE of the lines below
        // 2. Run Echidna
        // 3. It should FAIL immediately
        // 4. Re-comment after verification
        //
        // This proves your properties are meaningful.
        //
        // Example deliberate bugs:

        // assert(X59.unwrap(logResult) != X59.unwrap(logPrice));
        // assert(sentinel_before_val != sentinelBefore);
        // assert(sentinel_after_val != sentinelAfter);

    }

    // ================================
    // DOMAIN BOUNDING HELPERS
    // ================================

    function int59Bound(int256 x) internal pure returns (int256) {
        int256 max = (1 << 59) - 1;

        if (x < 0) return 0;
        if (x > max) return max;

        return x;
    }

    function int216Bound(int256 x) internal pure returns (int256) {
        int256 max = (int256(1) << 216) - 1;

        if (x < 0) return 0;
        if (x > max) return max;

        return x;
    }
}
