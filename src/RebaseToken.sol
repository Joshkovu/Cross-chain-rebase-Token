//SPDX-License-Identifier:MIT

pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken contract
 * @author Joash Kuteesa
 * @notice This is a cross-chain rebase token that incentives/encourages users to deposit into a vault and gives rewards
 * @notice The interest rate in the smart contracts can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    /////////////////////////
    // Errors //
    ///////////////////////
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 oldInterestRate,
        uint256 newInterestRate
    );

    /////////////////////////
    // State variables //
    ///////////////////////
    uint256 private sInterestRate = 5e10;
    mapping(address to => uint256 amount) private sUserInterestRate;
    mapping(address => uint256) private sUserLastUpdatedTimestamp;
    bytes32 private constant MINT_AND_BURN_ROLE =
        keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant LINEAR_PRECISION = 1e18;

    //////////
    // Events //
    ///////////

    event InterestRateSet(uint256 interestRate);

    /////////////////////////
    // Constructor functions //
    ///////////////////////
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    /////////////////////////////
    // Public and view functions //
    //////////////////////////////
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * Calculate the balance of the user including the interest that has been accumulated since the last update (principal balance + interest)
     * @param _user The user to calculate the balance for
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the number of tokens that have actually been left after minting)
        // multiply the principle balance by the interest rate
        return
            (super.balanceOf(_user) *
                _calculateUserAccumulatedInterestSinceLastUpdate(_user)) /
            LINEAR_PRECISION;
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @dev This function will mint interest to the recipient before transferring the tokens
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            sUserInterestRate[_recipient] = sUserInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            sUserInterestRate[_recipient] = sUserInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    //////////////////////////////////
    // Internal and view functions//
    ////////////////////////////////
    /**
     * Calculate the interest that has been accumulated since the last update
     * @param _user  The user to calculate the interest for
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256 linearInterest) {
        // calculate the interests accumulated since the last update
        //This is going to be linear growth with time
        // 1. calculate the time since last update
        // 2. calculate the amount of linear growth
        // (principal amount) +(1 +(user_interest_rate *time_elapsed))
        uint256 timeElapsed = block.timestamp -
            sUserLastUpdatedTimestamp[_user];
        uint256 linearInterestNow = LINEAR_PRECISION +
            (sUserInterestRate[_user] * timeElapsed);
        return linearInterestNow;
    }

    /////////////////////////
    // Internal functions //
    ///////////////////////
    /**
     * This contract mints interest to the user since the last time they interacted with the protocol eg mint, burn transfer
     *
     * @param _user The user to mint the accrued interest to
     */
    function _mintAccruedInterest(address _user) internal {
        //find the current balance of rebase tokens that have been minted to the user
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        // calculate their current balance including any interest
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that need to be minted to the user
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;

        // set the users last updated timestamp

        sUserLastUpdatedTimestamp[_user] = block.timestamp;
        // mint the tokens to the user
        _mint(_user, balanceIncrease);

        //call _mint to mint the tokens to the user
    }

    /////////////////////////
    // External functions //
    ///////////////////////
    /**
     * @notice This function sets the interest rate in the contract
     * @param _newInterestRate The new Interest rate set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate < sInterestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                sInterestRate,
                _newInterestRate
            );
        }
        sInterestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Get the principle balance of the user , This is the number of tokens that have been minted to the user not including any interest that has been accrued since the last time the user interacted with the protocol
     * @param _user The user to get the principal balance for
     * @return the principle balance of the user
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mint the user tokens when the deposit into the vault
     * @param _to The user to mint the tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(
        address _to,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        sUserInterestRate[_to] = sInterestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the user tokens when they withdraw from the vault
     * @param _from The user to burn the tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(
        address _from,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice get interest rate for the contract that is currently set for the contract , any future depositors will receive this interest rate
     */
    function getInterestRate() external view returns (uint256) {
        return sInterestRate;
    }

    /**
     * @notice This function returns the user's interest rate
     * @param _user this is the user whose interest rate is being returned to
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return sUserInterestRate[_user];
    }
}
