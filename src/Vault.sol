//SPDX-License-Identifier:MIT

pragma solidity ^0.8.23;
import {IRebaseToken} from "./interfaces/iRebaseToken.sol";

// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Vault {
    //pass token address to constructor
    //create a deposit function that mints tokens to the user
    // create a redeem function that burns tokens from the user and sends the user eth
    // create a way to add rewards to the vault
    IRebaseToken private immutable I_REBASETOKEN;
    /* Errors */
    error Vault__RedeemFailed();

    /* Events */
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        I_REBASETOKEN = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Allows users to deposit Eth into the vault and mint the right amount of tokens to the user
     * @dev This function will mint the right amount of tokens to the user
     */
    function deposit() external payable {
        // 1. use the amount of ETH to mint the right amount of tokens to the user
        uint256 interestRate = I_REBASETOKEN.getUserInterestRate(msg.sender);
        I_REBASETOKEN.mint(msg.sender, msg.value, interestRate);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem tokens from the vault and send the user eth
     * @dev This function will burn the tokens from the user and send the user eth
     * @param _amount This is the amount of tokens that the user wants to redeem
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = I_REBASETOKEN.balanceOf(msg.sender);
        }
        //1. burn the tokens from the user
        I_REBASETOKEN.burn(msg.sender, _amount);

        // 2. we need to send the user ETh
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice This function returns the address of the rebase token contract
     * @return the address of the rebase token contract
     */
    function getRebaseTokenAddress() public view returns (address) {
        return address(I_REBASETOKEN);
    }
}
