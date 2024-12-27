//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test{
    //COLLECTING THE RAW MATERIAL FOR TESTING:

    //redefining the event:  ( why? >> beacause events are not types like structs, enums, etc. which are imported by default )
    event EnteredRaffle(address indexed player);

    // nakli player bana diya:
    address public PLAYER = makeAddr("player");            //cheatcode that will assign a fake address to the name "player"
    uint256 public constant STARTING_USER_BALANCE = 10 ether; 



    // to get the deployed Raffle contract and helperconfig (basically all chain dependent values):
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 enteranceFee; 
    uint256 interval;
    address vrfCoordinator; 
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    uint256 deployerKey;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (enteranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit, link, deployerKey) = helperConfig.activeNetworkConfig();
    
    
        vm.deal(PLAYER , STARTING_USER_BALANCE);            // why did we write it inside setup fn ??  bcoz we want to give player money before every test. It ensures that all tests start from a clean, predefined state.
    
    }
    

    //TESTING >>

    function testRaffleInitializesInOpenState() public view{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);      //wierd: to acess value of enum >> Raffle.RaffleState.OPEN
    }



    ////////////////////////////////////////
    ////// enter raffle ////////////////////
    ////////////////////////////////////////

    function testRaffleRevertWhenYouDontPayEnoughEth() public{
        //Arrange
        vm.prank(PLAYER);       // cheatcode vm.prank() is used to change the msg.sender for the next call to simulate calls coming from a different address. 
                                // The next call after vm.prank() will have its msg.sender set to the provided address.
                                // In a testing environment, you often need to test how contracts behave when interacting with different addresses (e.g., owner vs. non-owner).
        //Act  /Assert
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);      // (cheatcode) : this means next line should revert. if reverts then the test will pass. this cheatcode works in foundry only (for more details search in foundry book)
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public{
        vm.prank(PLAYER);    

        raffle.enterRaffle{value: enteranceFee}();
        address playerRecorded = raffle.getPlayer(0);

        assert(playerRecorded == PLAYER);
        
    }

    function testEmitsEventsOnEnterance() public{
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));        // (cheatcode) : expects the 'event in next line' to be emited when the transaction in 'next to next line' happens
        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: enteranceFee}();
    }

    function testCannotEnterRaffleWhenItIsCalculating() public{
        //Arrange    
        // to test, we need to put the raffle in calculating state i.e. run the performupkeep i.e. make all the parameters of checkupkeep true.

        vm.prank(PLAYER);
        raffle.enterRaffle{value:enteranceFee}();      // entered raffle in open state
        vm.warp(block.timestamp + interval + 1);       // making the paramter of checkupkeep true                  // cheatcode: warp() is a cheatcode that allows you to warp the blockchain to a specific timestamp.
        vm.roll(block.number + 1);                     // making the paramter of checkupkeep true                  // cheatcode: roll() is a cheatcode that allows you to advance the blockchain to a specific block.
        raffle.performUpKeep("");                      // putting rafffle in closed state
        

        //Act  /Assert
        vm.expectRevert(Raffle.Raffle_NotOpen.selector);   
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();     // trying to enter in calculating state. should revert. test will pass
    }

    // earlier this test failed due to subscriptionID issues (why? error said raffle not added as a consumer to subscription)
    // now passes. 



    //////////////////////////////////////////////////////////////////
    ////////////////////// checkUpKeep  //////////////////////////////
    //////////////////////////////////////////////////////////////////
    

    function testCheckUpkeepReturnsFalseIfIthasnoBalance() public {
        //Arrange  
        // make all the paramter true except balance so test it 
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);                      // made timepassed variable true

        //Act 
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");

        //Assert
        assert(!upKeepNeeded);

    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public  {
        //arrange
        // make all the paramter true except openstate so test it 
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();      // now it has players and balance
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);                      // now enoughtimehas passed
        raffle.performUpKeep("");                      // but made the state closed (only this parameter is false)

        //Act 
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");

        //assert
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasnotpassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();      // now it has players and balance and open state
        vm.warp(block.timestamp + interval - 1);        // now enoughtimehas not passed

        //Act
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");

        //Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenparametersaregood()  public{
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();      // now it has players and balance and open state
        vm.warp(block.timestamp + interval + 1);       
        vm.roll(block.number + 1);                      // now enoughtimehas passed

        //Act
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");

        //Assert
        assert(upKeepNeeded);
    }




    ///////////////////////////////////////////////////////////
    //////////// perfom up keep //////////////////////////////
    ///////////////////////////////////////////////////////////


    function testperformUpKeepCanOnlyRunifCheckUpkeepIsTrue() public {
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();      // now it has players and balance and open state
        vm.warp(block.timestamp + interval + 1);       
        vm.roll(block.number + 1);                      // now enoughtimehas passed

        //Act /Assert
        raffle.performUpKeep("");          // *******  this is equivalent to:  dont expect revert      ********

    }

    function testperformUpKeepRevertsifCheckUpkeepIsFalse() public {
        // at this moment the raffle is deployed but no player has entered i.e. checkUpkeep is false
        
        /*   method 1 to write this test:

        vm.expectRevert(Raffle.Raffle_upKeepNotNeeded.selector);             
        raffle.performUpKeep("");
        */
        
        // **** better method: revert with parameters value

        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState =0; 

        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_upKeepNotNeeded.selector, currentBalance, numPlayers, raffleState));
        raffle.performUpKeep("");
    }

    modifier upKeepParametersMadeTrue{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();      // now it has players and balance and open state
        vm.warp(block.timestamp + interval + 1);       
        vm.roll(block.number + 1);                      // now enoughtimehas passed
        _;
    }

    // what if I need to test using the output of an event ??  >> recordLogs
    function testPerformUpkeepEmitsRequestId() public upKeepParametersMadeTrue{
        // act
        vm.recordLogs();                                        // cheatcode : tells the vm to start recording all the emitted events
        raffle.performUpKeep("");               // here emitting events 
        Vm.Log[] memory entries  = vm.getRecordedLogs();        // cheatcode : get the recorded events
        bytes32 requestId = entries[1].topics[1];               // many logs are stored in the entries array // many ways to find out our wanted log // here we just know it is 2nd log 
                                                                // topics inside the event start from index 1 bcoz at index 0 is the event itself
        
        //assert
        assert( uint256(requestId) > 0 );

    }
    
    function testPerformUpkeepUpdatesRaffleState() public upKeepParametersMadeTrue{
        //act
        raffle.performUpKeep("");
        Raffle.RaffleState rState = raffle.getRaffleState();

        //assert
        assert(uint256(rState) == 1);
    }




    //this below modifier when added to below tests it will skip those tests when tested on real environment
    modifier skipInCaseOfFork{
        if (block.chainid != 31337){                // if not the anvil chain then skip the test
            return;
        }
        _;
    }
    ////////////////////////////////////////////////////////////////////
    ///////////// fullfill random words ////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ////////   fulfillRandomWords is called by the VRF coordinator in real environment as told during automation.   //////////
    ////////   but for testing on local chain, we will ourself become vrfcoordinator using the vrfcoordinatormock   //////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    /************************************************************************************
    
    function testFulfilRandomWordsCanOnlyRunIfPerformUpkeepIsTrue() public upKeepParametersMadeTrue{
        
        expectRevert("nonexistent request"); 
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(0, address(raffle));

        expectRevert("nonexistent request"); 
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(1, address(raffle));

        expectRevert("nonexistent request"); 
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(2, address(raffle));

    }
   
    *****************************************************************************
       FUZZ TEST : rather than testing for all requestId we can write a FUZZ test where foundry itself tests by giving random values to requestId
    *********************************************************************************/

    function testFulfilRandomWordsCanOnlyRunIfPerformUpkeepIsTrue(uint256 randomRequestId) public upKeepParametersMadeTrue skipInCaseOfFork{
        
        vm.expectRevert("nonexistent request"); 
        // now performipkeep is not ran so now if vrfcoordinator tries to run the fullfillrandomwords it will revert
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));                      // this fulfillRandomWords function is inside the vrfcoordinator contract
    }


    //testing almost complete fulfillRandomWords function in one test:
    function testfulfillRandomWordsPicksAwinnerResetsAndSendsMoney() public skipInCaseOfFork{
        
        //Arrange players
        uint256 totalEntrants = 5;
        uint256 startingIndex = 0;
        for(uint256 i = startingIndex; i < totalEntrants; i++){
            address player = address(uint160(i + 1));                                                       // i+1 bcoz we want all address be non zero         
            hoax(player, STARTING_USER_BALANCE);              // cheatcode for prank + deal
            raffle.enterRaffle{value: enteranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = 5*enteranceFee;


        //Act : just running the fulfillRandomWords function
        vm.warp(block.timestamp + interval + 1);       
        vm.roll(block.number + 1);                      // upkeep done 

        vm.recordLogs();
        raffle.performUpKeep("");                           
        Vm.Log[] memory entries  = vm.getRecordedLogs();    
        bytes32 requestId = entries[1].topics[1];                 //performupkeep done
        
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords (uint256(requestId), address(raffle));        //fulfillrandomwords done


        //Assert  : checking if fulfillRandomWords function does the tasks assigned in it
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getNumberOfPlayers() == 0);
        assert(raffle.getLastTimeStamp() > startingTimeStamp);
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE - enteranceFee + prize);
    
    }


}