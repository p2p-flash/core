// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// Import the ERC20 contract interface
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// Interface for the FlashLoanReceiver contract
interface IFlashLoanReceiver {

    function executeOp() external;

}

abstract contract FlashLoanReceiver is IFlashLoanReceiver {

    P2PFlash public p2pFlash;

    constructor(P2PFlash _p2pFlash) {
        p2pFlash = _p2pFlash;
    }

    function approveLiquidityReturn(address asset, uint256 amount) external {
        IERC20(asset).approve(address(p2pFlash), amount);
    }

}

contract P2PFlash {

    using Math for uint16;
    using Math for uint256;

    error INVALID_LIQUIDITY_TRANSFERRED();
    
    // Mapping to store the deposited ERC20 balance of each address
    mapping(address => mapping(address => uint16)) public lendersFees; // Asset => (liquidityPocket => fees) fees in bips between 0.000% and 100.00%

    // Max loan that can be borrowed from a liquidity pocket
    mapping(address => mapping(address => uint256)) public maxLoans; // Asset => (liquidityPocket => maxLoan) 
    mapping(address => mapping(address => bool)) public areMaxLoansSet; // Asset => (liquidityPocket => isMaxLoanSet) 
    
    // Function to set the fees for an asset as a lender
    function setLiquidityFees(address asset, uint16 feePercentage) external {
        lendersFees[asset][msg.sender] = feePercentage;
    }

    // Function to set the maximum loan available for an asset
    function setMaxLoan(address asset, uint256 maxLoan) external {
        maxLoans[asset][msg.sender] = maxLoan;
        areMaxLoansSet[asset][msg.sender] = true;
    }

    function getLenderAvailableLiquidity(address asset, address lender) public view returns (uint256) {
        uint256 allowance = IERC20(asset).allowance(lender, address(this));
        uint256 balance = IERC20(asset).balanceOf(lender);
        uint256 maxLoan = maxLoans[asset][lender];
        if (areMaxLoansSet[asset][lender])
            return allowance > balance ?
                balance.min(maxLoan)
                : allowance.min(maxLoan);
        return allowance.min(balance);
    }
    
    // Function to allow anyone to perform a flash loan from the contract
    function performMultiFlash(address asset, uint256 amount, address receiver, address[] memory liquidityPockets) external {
        uint256 totalAmountTransferred;
        uint256 totalFees;
        uint256[] memory amountsTransferred = new uint256[](liquidityPockets.length);

        uint256 liquidityPocketIndex;
        for (liquidityPocketIndex; totalAmountTransferred != amount && liquidityPocketIndex < liquidityPockets.length; liquidityPocketIndex++) {
            uint256 availableLiquidity = getLenderAvailableLiquidity(asset, liquidityPockets[liquidityPocketIndex]);
            uint256 remainingAmount = amount - totalAmountTransferred;
            totalAmountTransferred += amountsTransferred[liquidityPocketIndex] = availableLiquidity < remainingAmount ? availableLiquidity : remainingAmount;
            uint16 lenderFee = lendersFees[asset][liquidityPockets[liquidityPocketIndex]];
            totalFees += lenderFee > 0 ? lenderFee.mulDiv(amountsTransferred[liquidityPocketIndex], 100000) : 0;
            IERC20(asset).transferFrom(liquidityPockets[liquidityPocketIndex], receiver, amountsTransferred[liquidityPocketIndex]);
        }

        if (totalAmountTransferred != amount) revert INVALID_LIQUIDITY_TRANSFERRED();

        FlashLoanReceiver(receiver).executeOp();

        FlashLoanReceiver(receiver).approveLiquidityReturn(asset, amount + totalFees);

        for (liquidityPocketIndex = 0; liquidityPocketIndex < liquidityPockets.length; liquidityPocketIndex++) {
            uint16 lenderFee = lendersFees[asset][liquidityPockets[liquidityPocketIndex]];
            IERC20(asset).transferFrom(receiver, liquidityPockets[liquidityPocketIndex], amountsTransferred[liquidityPocketIndex] + (lenderFee > 0 ? lenderFee.mulDiv(amountsTransferred[liquidityPocketIndex], 100000) : 0));
        }
    }

    function performSingleFlash(address asset, uint256 amount, address receiver, address liquidityPocket) external {
        uint256 fees = lendersFees[asset][liquidityPocket].mulDiv(amount, 100000);
        IERC20(asset).transferFrom(liquidityPocket, receiver, amount);
        FlashLoanReceiver(receiver).executeOp();
        FlashLoanReceiver(receiver).approveLiquidityReturn(asset, amount + fees);
        IERC20(asset).transferFrom(receiver, liquidityPocket, amount + fees);
    }

}
