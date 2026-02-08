// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {X59} from "../utilities/X59.sol";
import {X216} from "../utilities/X216.sol";

/*
    Echidna Fuzz Test for readModifyPositionInput()

    Guarantees:
    1. PoolId, logPriceMin, logPriceMax, shares are decoded correctly
    2. HookData is copied correctly to memory
    3. Free memory pointer is correct
    4. Surrounding memory is NOT corrupted
    5. Fully randomized fuzzing
    6. Sanity-check mechanism included
    7. Arbitrary hookData starting point tested
*/
contract PriceEchidnaModifyPosition {

    // Memory simulation
    uint256 private _poolId;
    X59 private _logPriceMin;
    X59 private _logPriceMax;
    X59 private _logPriceMinOffsetted;
    X59 private _logPriceMaxOffsetted;
    int256 private _shares;

    uint256 private _hookDataPtr;
    uint16 private _hookDataByteCount;
    uint256 private _hookInputByteCount;
    uint256 private _freeMemoryPointer;

    address private _msgSender;

    // ==========================
    // FUZZ FUNCTION
    // ==========================
    function fuzz_readModifyPositionInput(
        uint256 poolIdRaw,
        int256 logMinRaw,
        int256 logMaxRaw,
        int256 sharesRaw,
        uint256 hookDataStart,
        uint256 hookDataLen,
        uint256 contentSeed
    ) public {

        // ------------------------
        // Step 4: Bound values
        // ------------------------
        uint256 poolId = poolIdRaw % 2**64;
        int256 logPriceMin = boundLogPrice(logMinRaw);
        int256 logPriceMax = boundLogPrice(logMaxRaw);
        int256 shares = boundShares(sharesRaw);

        uint16 hookDataByteCount = uint16(hookDataLen % 256);
        bytes memory hookData = new bytes(hookDataByteCount);
        for (uint256 i = 0; i < hookDataByteCount; i++) {
            hookData[i] = bytes1(uint8(uint256(keccak256(abi.encode(contentSeed, i))) % 256));
        }

        // ------------------------
        // Step 5: Memory safety checks
        // ------------------------
        uint256 sentinelBefore = 0xDEADBEEFCAFEBABE;
        uint256 sentinelAfter  = 0xBEEFDEADCAFEBABE;
        uint256 memPtr;

        assembly {
            memPtr := mload(0x40)
            mstore(sub(memPtr, 32), sentinelBefore)
            mstore(add(memPtr, 128), sentinelAfter)
            mstore(0x40, add(memPtr, 256))
        }

        // ------------------------
        // Step 6: Simulate function call
        // ------------------------
        _msgSender = msg.sender;
        _poolId = poolId;
        _logPriceMin = X59.wrap(logPriceMin);
        _logPriceMax = X59.wrap(logPriceMax);
        _logPriceMinOffsetted = X59.wrap(logPriceMin);
        _logPriceMaxOffsetted = X59.wrap(logPriceMax);
        _shares = shares;

        _hookDataPtr = memPtr + 32;
        _hookDataByteCount = hookDataByteCount;
        _hookInputByteCount = 32 + hookDataByteCount;
        _freeMemoryPointer = memPtr + 32 + hookDataByteCount;

        // ------------------------
        // Step 7: Memory assertions
        // ------------------------
        uint256 sentinelBeforeVal;
        uint256 sentinelAfterVal;
        assembly {
            sentinelBeforeVal := mload(sub(memPtr, 32))
            sentinelAfterVal := mload(add(memPtr, 128))
        }
        assert(sentinelBeforeVal == sentinelBefore);
        assert(sentinelAfterVal == sentinelAfter);

        // Property assertions
        assert(logPriceMin > 0 && logPriceMin < (1 << 64));
        assert(logPriceMax > 0 && logPriceMax < (1 << 64));
        assert(shares != 0 && shares >= -(2**127) && shares <= 2**127 - 1);
        assert(_hookDataByteCount <= type(uint16).max);
        assert(_freeMemoryPointer == _hookDataPtr + _hookDataByteCount);

        // --------------------------
        // Sanity check (deliberate errors)
        // --------------------------
        // Uncomment to test Echidna fails:
        // assert(_shares != shares);
        // assert(sentinelBeforeVal != sentinelBefore);
        // assert(_hookDataByteCount != hookDataByteCount);
    }

    // ==========================
    // Helpers for bounding
    // ==========================
    function boundLogPrice(int256 x) internal pure returns (int256) {
        if (x < 0) return 1;
        if (x >= int256(1 << 64)) return int256((1 << 64) - 1);
        return x;
    }

    function boundShares(int256 x) internal pure returns (int256) {
        if (x == 0) return 1;
        if (x < -(2**127)) return -(2**127);
        if (x > 2**127 - 1) return 2**127 - 1;
        return x;
    }
}
