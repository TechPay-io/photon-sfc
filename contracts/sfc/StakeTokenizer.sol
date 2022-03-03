pragma solidity ^0.5.0;

import "./SFC.sol";
import "../erc20/base/ERC20Burnable.sol";
import "../erc20/base/ERC20Mintable.sol";
import "../common/Initializable.sol";

contract Spacer {
    address private _owner;
}

contract StakeTokenizer is Spacer, Initializable {
    SFC internal sfc;

    mapping(address => mapping(uint256 => uint256)) public outstandingSTPC;

    address public sTPCTokenAddress;

    function initialize(address _sfc, address _sTPCTokenAddress) public initializer {
        sfc = SFC(_sfc);
        sTPCTokenAddress = _sTPCTokenAddress;
    }

    function mintSTPC(uint256 toValidatorID) external {
        address delegator = msg.sender;
        uint256 lockedStake = sfc.getLockedStake(delegator, toValidatorID);
        require(lockedStake > 0, "delegation isn't locked up");
        require(lockedStake > outstandingSTPC[delegator][toValidatorID], "sTPC is already minted");

        uint256 diff = lockedStake - outstandingSTPC[delegator][toValidatorID];
        outstandingSTPC[delegator][toValidatorID] = lockedStake;

        // It's important that we mint after updating outstandingSTPC (protection against Re-Entrancy)
        require(ERC20Mintable(sTPCTokenAddress).mint(delegator, diff), "failed to mint sTPC");
    }

    function redeemSTPC(uint256 validatorID, uint256 amount) external {
        require(outstandingSTPC[msg.sender][validatorID] >= amount, "low outstanding sTPC balance");
        require(IERC20(sTPCTokenAddress).allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        outstandingSTPC[msg.sender][validatorID] -= amount;

        // It's important that we burn after updating outstandingSTPC (protection against Re-Entrancy)
        ERC20Burnable(sTPCTokenAddress).burnFrom(msg.sender, amount);
    }

    function allowedToWithdrawStake(address sender, uint256 validatorID) public view returns(bool) {
        return outstandingSTPC[sender][validatorID] == 0;
    }
}
