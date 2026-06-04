// Copyright 2025, NoFeeSwap LLC - All rights reserved.
pragma solidity ^0.8.28;

import "../utilities/Token.sol";
import {
  IERC1155Receiver
} from "@openzeppelin/token/ERC1155/IERC1155Receiver.sol";

/// @title This contract exposes the internal functions of 'Token.sol' for
/// testing purposes.
contract TokenWrapper {
  error CannotBe101();

  bytes public storedData;

  receive() external payable {
    bytes4 selector = CannotBe101.selector;
    assembly {
      if eq(callvalue(), 101) {
        mstore(0, selector)
        revert(0, 4)
      }
    }
  }

  function onERC1155Received(
    address , 
    address , 
    uint256 , 
    uint256 , 
    bytes calldata data
  ) external returns (bytes4) {
    storedData = data;
    return IERC1155Receiver.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address , 
    address , 
    uint256[] calldata , 
    uint256[] calldata , 
    bytes calldata
  ) external pure returns (bytes4) {
    return IERC1155Receiver.onERC1155BatchReceived.selector;
  }

  function transfer(
    address tokenAddress, 
    address to, 
    uint256 amount
  ) public {
    TokenLibrary.transfer(
      tokenAddress, 
      to, 
      amount
    );
  }

  function balanceOfSelf(
    address tokenAddress
  ) public view returns (
    uint256 result
  ) {
    result = TokenLibrary.balanceOfSelf(
      tokenAddress
    );
  }

  function transfer(
    address tokenAddress, 
    uint256 id, 
    address to, 
    uint256 amount,
    bytes calldata transferData
  ) public {
    TokenLibrary.transfer(
      tokenAddress, 
      id, 
      to, 
      amount,
      transferData
    );
  }

  function transfer(
    address tokenAddress, 
    uint256 id, 
    address to, 
    uint256 amount
  ) public {
    TokenLibrary.transfer(
      tokenAddress, 
      id, 
      to, 
      amount
    );
  }

  function balanceOfSelf(
    address tokenAddress,
    uint256 id
  ) public view returns (
    uint256 result
  ) {
    result = TokenLibrary.balanceOfSelf(
      tokenAddress,
      id
    );
  }
}