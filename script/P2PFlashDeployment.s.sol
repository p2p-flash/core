   // SPDX-License-Identifier: UNLICENSED
   pragma solidity 0.8.21;
   import "forge-std/Script.sol";
   import "forge-std/Test.sol";
   import "../src/P2PFlash.sol";
   import "../src/sample.sol";
   contract P2PFlashScript is Script {
       function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        P2PFlash p2p = new P2PFlash();
        FlashMarketSampleFlashLoanTesting flashMarketContract = new FlashMarketSampleFlashLoanTesting(address(p2p));
        console.log("FlashMarketSampleFlashLoanTesting contract address: ", address(flashMarketContract));
        vm.stopBroadcast();
       }
   }
