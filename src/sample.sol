// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "./P2PFlash.sol";

contract FlashMarketSampleFlashLoanTesting is FlashLoanReceiver {

    address asset;
    uint256 public lastBalanceFlashBorrowed;

    constructor(address p2pFlash) FlashLoanReceiver(P2PFlash(p2pFlash)) {
        asset = 0x9FD21bE27A2B059a288229361E2fA632D8D2d074;
    }

    function performMultiFlash(uint256 amount, address[] memory liquidityPockets) external {
        p2pFlash.performMultiFlash(asset, amount, address(this), liquidityPockets);
    }

    function performSingleFlash(uint256 amount, address liquidityPocket) external {
        p2pFlash.performSingleFlash(asset, amount, address(this), liquidityPocket);
    }

    function executeOp() external {
        lastBalanceFlashBorrowed = IERC20(asset).balanceOf(address(this));
    }
}

// What you need to do to do a flash loan from Flash Market