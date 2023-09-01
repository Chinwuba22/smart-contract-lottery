// LAYOUT OF A CONTRACT
// licence and solidity-version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title SMART-CONTRACT RAFFLE
 * @author AKWUBA CHRIS
 * @notice This contract is a raffle contract
 * @dev THIS CONTRACT IMPLEMENTS CHAINLINK-VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    //ERROR
    error Raffle_NotEnoughEthEnterred();
    error Raffle__EnoughTimeHasNotPassed();
    error Raffle_SendTxFailed();
    error Raffle_RaffleNotOpened();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /** Type Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**STATE VARIABLES */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vfrCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subsciptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event RaffleEnterred(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vfrCoordinator,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        uint64 subsriptionId
    ) VRFConsumerBaseV2(vfrCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vfrCoordinator = VRFCoordinatorV2Interface(vfrCoordinator);
        i_subsciptionId = subsriptionId;
        i_callbackGasLimit = callbackGasLimit;
        i_gasLane = gasLane;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not Enough Eth Entered");
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthEnterred();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpened();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnterred(msg.sender);
    }

    //** @dev This is the function that the chainLink Automation nodes call to confirm it time to perform an upkeep */
    function checkUpkeep(
        bytes memory /** checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /*performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /*performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vfrCoordinator.requestRandomWords(
            i_gasLane,
            i_subsciptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_SendTxFailed();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpened();
        }
        emit WinnerPicked(winner);
    }

    /**Getters */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
