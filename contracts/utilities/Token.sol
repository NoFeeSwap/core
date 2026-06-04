// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {IERC1155} from "@openzeppelin/interfaces/IERC1155.sol";
import {IERC6909} from "@openzeppelin/interfaces/draft-IERC6909.sol";
import {BalanceOverflow} from "./Errors.sol";

/// @dev This library allows transferring native, ERC-20, ERC-1155 and
/// ERC-6909 tokens from 'address(this)'.
library TokenLibrary {
  /// @notice Transfers an 'amount' of native or ERC-20 with address 'token'
  // from 'address(this)' to 'to'. Implementation is from
  // https://github.com/transmissions11/solmate/blob/
  // e8f96f25d48fe702117ce76c79228ca4f20206cb/src/utils/SafeTransferLib.sol
  function transfer(
    address token,
    address to,
    uint256 amount
  ) internal {
    if (token == address(0)) {
      assembly {
        // Transfers ETH and relays the reason if reverted.
        // The output of 'call' is zero if and only if the call is reverted.
        if iszero(
          call(gas(), to, amount, 0, 0, 0, 0)
        ) {
          // Return data is copied to memory and relayed as a revert message.
          returndatacopy(0, 0, returndatasize())
          revert(0, returndatasize())
        }
      }
    } else {
      // The appropriate selector for ERC20's 'transfer' method.
      bytes4 selector = IERC20.transfer.selector;
      assembly {
        // Cache the free memory pointer so that the third memory slot can be
        // used for the external call.
        let freeMemoryPointer := mload(0x40)

        // Write the abi-encoded calldata into memory, beginning with the 
        // function selector.
        //
        //    'IERC20(token).transfer(to, amount)'
        //
        // To this end, the following 68 bytes of calldata are written in
        // memory.
        //
        //    0                          4    36       68
        //    |                          |    |        |
        //    +--------------------------+----+--------+
        //    | IERC20.transfer.selector | to | amount |
        //    +--------------------------+----+--------+
        //
        // First, the 4 byte selector is placed in memory. Notice that the most
        // significant 4 bytes of selector contain the desired value.
        mstore(0, selector)
        mstore(4, to) // Append 'to'.
        mstore(36, amount) // Append 'amount'.

        // Invokes 'IERC20(token).transfer' and relays the reason if reverted.
        // The transfer is deemed successful if the output of 'call' is 'true'
        // and if the return data is either nonexistent or starts with a slot
        // containing exactly '1'.
        if iszero(
          and(
            or(
              // If return data is nonexistent, then we only rely on the output
              // of 'call' to determine whether the transfer is successful.
              iszero(returndatasize()),
              and(
                // The first 32 bytes of return data are copied to the first
                // slot of memory. Here, we check whether it is exactly '1'.
                eq(mload(0), 1),
                // Here we check whether the size of the return data is at
                // least '32'.
                gt(returndatasize(), 31)
              )
            ),
            // We use 68 because the length of our calldata totals up to:
            // '4 + 32 + 32'. We use 0 and 32 to copy up to 32 bytes of return
            // data into the scratch space.
            call(gas(), token, 0, 0, 68, 0, 32)
          )
        ) {
          // Return data is copied to memory and relayed as a revert message.
          returndatacopy(0, 0, returndatasize())
          revert(0, returndatasize())
        }

        // Restore the free memory pointer.
        mstore(0x40, freeMemoryPointer)
      }
    }
  }

  /// @notice Transfers an 'amount' of '(token, id)' ERC-1155 tokens from 
  /// 'address(this)' to 'to'.
  function transfer(
    address token, 
    uint256 id, 
    address to, 
    uint256 amount,
    bytes calldata transferData
  ) internal {
    // The appropriate selector for ERC1155's 'safeTransferFrom' method.
    bytes4 selector = IERC1155.safeTransferFrom.selector;
    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the 
      // function selector.
      //
      //    'IERC1155(token).safeTransferFrom(
      //        address(this),
      //        to,
      //        id,
      //        amount,
      //        data
      //     )'
      //
      // To this end, the following 68 bytes of calldata are written in
      // memory.
      //
      //    0                                    4               36   68  100
      //    |                                    |               |    |    |
      //    +------------------------------------+---------------+----+----+
      //    | IERC1155.safeTransferFrom.selector | address(this) | to | id |
      //    +------------------------------------+---------------+----+----+
      //
      //   100      132    164             196
      //    |        |      |               |
      //    +--------+------+---------------+------+
      //    | amount | 0xA0 | dataByteCount | data |
      //    +--------+------+---------------+------+
      //
      // First, the 4 byte selector is placed in memory. Notice that the most
      // significant 4 bytes of selector contain the desired value.
      mstore(freeMemoryPointer, selector)
      mstore(add(freeMemoryPointer, 4), address()) // Append 'from'.
      mstore(add(freeMemoryPointer, 36), to) // Append 'to'.
      mstore(add(freeMemoryPointer, 68), id) // Append 'id'.
      mstore(add(freeMemoryPointer, 100), amount) // Append 'amount'.
      mstore(add(freeMemoryPointer, 132), 160) // Append the header for 'data'.
      // The offset of 'transferData' is subtracted by '32' to point to the
      // 'length' slot.
      let offset := sub(transferData.offset, 32)
      // The byte count of 'transferData' is loaded.
      let length := calldataload(offset)
      // 'transferData' with its length slot are copied from calldata to
      // to memory.
      calldatacopy(
        add(freeMemoryPointer, 164),
        // The beginning of the length slot. 
        offset,
        // '32' is added to the byte count of 'transferData' to account for the
        // length slot as well.
        add(32, length)
      ) // Append 'data'.

      // Invokes 'IERC1155(token).safeTransferFrom' and relays the reason if
      // reverted.
      // The transfer is deemed successful if the output of 'call' is 'true'.
      if iszero(
        // The byte count of our calldata is equal to:
        // '196 + length = 4 (selector) + 32 (to) + 32 (id) + 32 (amount) + 
        //  32 (header) + 32 (length slot) + length (byte count of data)'.
        call(gas(), token, 0, freeMemoryPointer, add(196, length), 0, 0)
      ) {
        // Return data is copied to memory and relayed as a revert message.
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
    }
  }

  /// @notice Transfers an 'amount' of '(token, id)' ERC6909 tokens from 
  /// 'address(this)' to 'to'.
  function transfer(
    address token, 
    uint256 id, 
    address to, 
    uint256 amount
  ) internal {
    // The appropriate selector for ERC6909's 'transfer' method.
    bytes4 selector = IERC6909.transfer.selector;
    assembly {
      // Get a pointer to some free memory.
      let freeMemoryPointer := mload(0x40)

      // Write the abi-encoded calldata into memory, beginning with the 
      // function selector.
      //
      //    'IERC6909(token).transfer(to, id, amount)'
      //
      // To this end, the following 68 bytes of calldata are written in
      // memory.
      //
      //    0                            4    36   68      100
      //    |                            |    |    |        |
      //    +----------------------------+----+----+--------+
      //    | IERC6909.transfer.selector | to | id | amount |
      //    +----------------------------+----+----+--------+
      //
      // First, the 4 byte selector is placed in memory. Notice that the most
      // significant 4 bytes of selector contain the desired value.
      mstore(freeMemoryPointer, selector)
      mstore(add(freeMemoryPointer, 4), to) // Append 'to'.
      mstore(add(freeMemoryPointer, 36), id) // Append 'id'.
      mstore(add(freeMemoryPointer, 68), amount) // Append 'amount'.

      // Invokes 'IERC6909(token).transfer' and relays the reason if reverted.
      // The transfer is deemed successful if the output of 'call' is 'true'
      // and if the return data is exactly:
      // '0x0000000000000000000000000000000000000000000000000000000000000001'
      if iszero(
        and(
          and(
            // The first 32 bytes of return data are copied to the first slot
            // of memory. Here, we check whether it is exactly '1'.
            eq(mload(0), 1),
            // Here we check whether the size of the return data is exactly
            // '32' bytes.
            eq(returndatasize(), 32)
          ),
          // We use 100 because the length of our calldata totals up to:
          // '4 + 32 + 32 + 32'. We use 0 and 32 to copy up to 32 bytes of
          // return data into the scratch space.
          call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
        )
      ) {
        // Return data is copied to memory and relayed as a revert message.
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
    }
  }

  /// @notice Returns balance of 'address(this)' ERC-20 tokens.
  function balanceOfSelf(
    address token
  ) internal view returns (
    uint256 value
  ) {
    // The appropriate selector for ERC20's 'balanceOf' method.
    bytes4 selector = IERC20.balanceOf.selector;
    assembly {
      // First, the 4 byte selector is placed in memory. Notice that the most
      // significant 4 bytes of selector contain the desired value.
      //
      //    'IERC20(token).balanceOf(address(this))'
      //
      // To this end, the following 68 bytes of calldata are written in
      // memory.
      //
      //    0                           4               36
      //    |                           |               |
      //    +---------------------------+---------------+
      //    | IERC20.balanceOf.selector | address(this) |
      //    +---------------------------+---------------+
      //
      mstore(0, selector)
      mstore(4, address()) // Append 'address(this)'.
      // Invokes 'IERC20(token).balanceOf' and relays the reason if reverted.
      // The staticcall is deemed successful if the output of 'staticcall' is
      // 'true' and if the length of return data is exactly '32'.
      if iszero(
        and(
          // Here, we check if the length of return data is exactly '32' bytes.
          eq(returndatasize(), 32),
          // We use 36 because the length of our calldata totals up to:
          // '4 + 32'. We use 0 and 32 to copy up to 32 bytes of return data
          // into the scratch space.
          staticcall(gas(), token, 0, 0, 36, 0, 32)
        )
      ) {
        // Return data is copied to memory and relayed as a revert message.
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
      // If the call is successful the return data is read from memory.
      value := mload(0)
    }
    // If the balance of protocol in any token exceeds 'type(uint128).max' the
    // balance may not be synced.
    require(value <= type(uint128).max, BalanceOverflow(value));
  }

  /// @notice Returns balance of 'address(this)' for ERC1155 and ERC6909.
  function balanceOfSelf(
    address token, 
    uint256 id
  ) internal view returns (
    uint256 value
  ) {
    // The appropriate selector for method 'balanceOf' which is the same in
    // both ERC1155 and ERC6909.
    bytes4 selector = IERC1155.balanceOf.selector;
    assembly {
      // Cache the free memory pointer so that the third memory slot can be
      // used for the external call.
      let freeMemoryPointer := mload(0x40)
      
      // First, the 4 byte selector is placed in memory. Notice that the most
      // significant 4 bytes of selector contain the desired value.
      //
      //    'IERC6909(token).balanceOf(address(this), id)'
      //    'IERC1155(token).balanceOf(address(this), id)'
      //
      // To this end, the following 68 bytes of calldata are written in
      // memory.
      //
      //    0          4               36   68
      //    |          |               |    |
      //    +----------+---------------+----+
      //    | selector | address(this) | id |
      //    +----------+---------------+----+
      //
      mstore(0, selector)
      mstore(4, address()) // Append 'address(this)'.
      mstore(36, id) // Append 'id'.

      // Invokes 'IERC6909(token).balanceOf' or equivalently 
      // 'IERC1155(token).balanceOf' and relays the reason if reverted.
      // The staticcall is deemed successful if the output of 'staticcall' is
      // 'true' and if the length of return data is exactly '32'.
      if iszero(
        and(
          // Here, we check if the length of return data is exactly '32' bytes.
          eq(returndatasize(), 32),
          // We use 68 because the length of our calldata totals up to:
          // '4 + 32 + 32'. We use 0 and 32 to copy up to 32 bytes of return
          // data into the scratch space.
          staticcall(gas(), token, 0, 0, 68, 0, 32)
        )
      ) {
        // Return data is copied to memory and relayed as a revert message.
        returndatacopy(0, 0, returndatasize())
        revert(0, returndatasize())
      }
      // Restore the free memory pointer.
      mstore(0x40, freeMemoryPointer)
      // If the call is successful the return data is read from memory.
      value := mload(0)
    }
    // If the balance of protocol in any token exceeds 'type(uint128).max' the
    // balance may not be synced.
    require(value <= type(uint128).max, BalanceOverflow(value));
  }
}