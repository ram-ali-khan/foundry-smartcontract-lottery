// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations / enums   
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

//  SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";          // import for accessing the vrf contract to which we will send the request for generating random number      //iski remapping kar dena bcoz hum net se nhi local directory se access krna chahte hai 
import {VRFConsumerBaseV2}from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
/**
 * @title Raffle
 * @author Nitin Dhaka
 * @notice this contract is for creating a sample raffle
 * @dev Implemensts chianlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2{

    //custom errors:        (get a habbit of naming the errors with contract name so that later we can know from which contract the erorr is coming)
    error Raffle_NotEnoughEthSent();      // if player pays less fees than entry fee      
    error Raffle_TransferFailed();       // if money not sent to the winner
    error Raffle_NotOpen();              // if raffle is not open 
        //error with parameteres:
    error Raffle_upKeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);    //if upKeepNeeded is false and trying to run the performUpKeep



    //enums:
    enum RaffleState {
        OPEN,  //0                     
        CALCULATING  //1                         // when  in the process of calculating winner
    }



    uint256 private immutable i_enteranceFee;       //get a habbit of making almost all state variables private and make their getter function
    
    //what data structures should be used to keep track of all players? array/ mapping / single
    // array bcoz easy to pick a random player
    address payable[] private s_players;        //addresses payable because one will win and get money.
    address private s_recentWinner;

    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;
 
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;       // this address varies from chain to chain so need to take this as input in constructor     //instead of address declared it as VRFCoordinatorV2Interface
    bytes32 private immutable i_gasLane;                   // also chain dependent. its value can be getted from chainlink docs
    uint64 private immutable i_subscriptionId;               // our id , ye bhi input lenge 
    uint16 private constant REQUEST_CONFIRMATIONS = 3;      // seekh rhe hai to constant bana diya , vrna ye bhi input le sakte hai depending on chain 
    uint32 private immutable i_callbackGasLimit;            // ye bhi input lelenge
    uint32 private constant NUMBER_WORDS = 1;
    
    RaffleState private s_raffleState;



    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);



    constructor(
        uint256 enteranceFee, 
        uint256 interval, 
        address vrfCoordinator, 
        bytes32 gasLane, 
        uint64 subscriptionId, 
        uint32 callbackGasLimit
    )VRFConsumerBaseV2(vrfCoordinator) {                     // to use the constructor of the parent interface VRFConsumerBaseV2 contract
        i_enteranceFee = enteranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);           //typecasting address to VRFCoordinatorV2Interface
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;                   // by default keep it open
    }
    


    function enterRaffle() external payable {
        // require(msg.value >= i_enteranceFee, "Not enough ETH sent");
        if (msg.value < i_enteranceFee) {
            revert Raffle_NotEnoughEthSent();
        }

        if(s_raffleState != RaffleState.OPEN) {
            revert Raffle_NotOpen();
        }

        s_players.push(payable(msg.sender)); //whenever we make a storage update, we should omit a event    //becasue these events are easy to track for front end devlopers    //good habit to do so 
        emit EnteredRaffle(msg.sender);
    }

    
    // 1. get a random no.   -> 2 parts : request and fulfill       - chainlink VRF
    // 2. use the random no. to pick the winner      - us
    // 3. pickwinner should be automatically called after some time  -  chainlink automationn

    // before automation ->  pickwinner
    // after automation ->  checkUpKeep, performUpkeep(made from pickwinner)
    
    /**
     * @dev chainlink nodes(oracle neetwwork) run upkeep function offchian (thats why it is view) to check if performupkeep is needed??
     * all these conditon need to be satisfied then return true
     * 1. enough time has passed
     * 2. raffle is in OPEN state
     * 3. contract has ETH (aka, players) 
     * 4. (implicit) the subscription is funded with enough ETH. **** badme chainlink nodes hi performupkeep function ko onchain run krwate hai. and pay the gas fees themselves. for that only they are asking for LINK. wo apna performupkeep fn run krwate rehte hai jab tak paise khatatm na ho.
     */
    function checkUpKeep ( bytes memory /* checkData */) public view returns (bool upKeepNeeded, bytes memory /* performData */) {
        bool enoughTimePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool openState = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;

        upKeepNeeded = enoughTimePassed && openState && hasPlayers && hasBalance;           //upkeepNeeded will only be true if all the above contidition are true
        // since the upkeepneeded was defined in the returns() of this function only, it will automatically be returned without using the return statenent. but to be explicit we will use return statenent 
        return (upKeepNeeded, "0x0");        // 0x0 formality bcoz returns() has two outputs

    }
    // (for cahinlink nodes to recognise this fuction we need input parameters (these parameters are used for customization) but we don't need it so commented) ->
    // bytes memory /* checkData */       >>> for flexibility, efficiency and standardization
        // checkData is input data passed by the Chainlink Automation system to the checkUpkeep function. It allows you to send specific data to tailor the checkUpkeep logic for different conditions.
    // bytes memory /* performData */     >>> for flexibility, efficiency and standardization
        // performData is output data returned by checkUpkeep and passed to performUpkeep. It allows checkUpkeep to provide additional context or parameters to performUpkeep for executing the action.



    function performUpKeep(bytes calldata /* performData */) external {
        
        // even though this function would be called by the chainlink nodes, when upKeepNeeded is true but still when this function gets called by them, we want another check. so:
        (bool upKeepNeeded, ) = checkUpKeep("");

        if(!upKeepNeeded){
            revert Raffle_upKeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)                                    //since enum can directly be converted to integers
            );
        }

        /*
        ************   raw form of the code that we copied from the chainlink vrf website(for requesting random number) ************
        **************************************************************************************************************************************
        ***********   we are using the function named requestRandomWords on our vrf coordinator address to generate requestId  ****************
        ***************************************************************************************************************************************

        requestId = COORDINATOR.requestRandomWords(
            keyHash,          //gasLane
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        *********************************************************************************
        */
        
        s_raffleState = RaffleState.CALCULATING;

        // Request randomness
        uint256 requestId = i_vrfCoordinator.requestRandomWords(                      //jabtak vrf import nhi karenge tab tak code ko lagega ki i_vrfCoordinator ek simple address hai and wo ek contract ka address nhi hai to wo  .requestRandomWords function ko access nhi kar paega    //also address import krke usse typecast krna padega VRFCoordinatorV2Interface me 
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUMBER_WORDS
        );
        
        // quiz....is this redundant? if yes then why this event ??
        // yes it is redundant bcoz this requestId has already been emitted to logs in vrfcoordinator contract in the event named RandomWordsRequested.  (In actual chainlink works on basis of these events or logs only)
        emit RequestedRaffleWinner(requestId);
    }


    /************************************** function to get back the generated random no. ***************************************************************
        
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    ***********************************************************************************************/



    // Callback function to handle the randomness
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override{
        //now since we have got the random no., we will play with that to pick winner. 
        //best option in this condition is to use mod operator
        uint256 indexOfWinner = _randomWords[0] % s_players.length;             
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner; 

        //formalities for next round of lottery to begin:
        s_raffleState = RaffleState.OPEN;        // done with the process of calculating now new players can enter raffle
        s_lastTimeStamp = block.timestamp;    
        s_players = new address payable[](0);             //reset the s_players array. old players removed, new players can enter raffle. 
        emit WinnerPicked(recentWinner);

        //send money to the winner
        (bool success, ) = recentWinner.call{value: address(this).balance}("");          // Attempts to send the entire balance of the contract to the recentWinner using the .call method. The call method is a low-level function that can transfer ETH and execute code. It returns a boolean success value indicating whether the operation succeeded.
            // require(success, "Transfer failed");
        if (!success) {
            revert Raffle_TransferFailed();
        }
    }




    /****************** getter functions *****************/

    // for telling enterance fee to players
    function getEnteranceFee() external view returns (uint256) {
        return i_enteranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
