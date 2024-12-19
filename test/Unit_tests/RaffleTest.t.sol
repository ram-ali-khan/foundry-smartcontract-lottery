//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";

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

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();

        (enteranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit) = helperConfig.activeNetworkConfig();
    
    
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

        vm.expectEmit(true, false, false, false, address(raffle));        // (cheatcode) : expects the event in 'next line' to be emited when the transaction in 'next to next line' happens
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
        raffle.performUpKeep;                          // putting rafffle in closed state


        //Act  /Assert
        vm.expectRevert(Raffle.Raffle_NotOpen.selector);   
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();     // trying to enter in calculating state. should revert. test will pass
    }


    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // the above test failed at this point due to subId issues. commintted code in this codition , later made the subId changes//
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}