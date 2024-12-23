//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import{HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";      //for CreateSubscription
import {LinkToken} from "../test/mocks/LinkToken.sol";
// import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";


contract CreateSubscription is Script{
    
    function run() external returns(uint64) {
        return createSubscriptionUsingConfig();
    }
    
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        ( , ,address vrfCoordinator, , , , ) = helperConfig.activeNetworkConfig();        //1        

        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint64){
        
        console.log("creating subscription on chainid: ", block.chainid );

        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();         //2          
        vm.stopBroadcast();

        console.log("subscription created with id: ", subId);
        return subId;
    }

}


// there has to be a single run function but we divided it into three functions and deviated path from one to another.


/*  explainiation:

    basically work is being done in only two lines : 
    1. getting our chain specific vrfcoordinator address in createSubscriptionUsingConfig
    2. using the VRFCoordinatorV2Mock(vrfCoordinator).createSubscription() to get subId

*/

/*  another explaination:

    also this whole script is code version of ui method (to create subscription)
    check the VRFCoordinatorV2Mock.sol once to understand(in real ui subscription also the same fuction is called when we check in hex of metamask)
*/


// Que. why we created this using mock only and not the real vrfcoordinator?
// Ans. bcoz we are making this whoele script just for testing purpose


contract FundSubscription is Script{

    uint96 public constant FUND_AMOUNT = 3 ether;


    function run() external{
        fundSubscriptionUsingConfig(); 
    }


    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        ( , ,address vrfCoordinator, , uint64 subId, , address link) = helperConfig.activeNetworkConfig();        //1

        fundSubscription(vrfCoordinator, subId, link);
    }


    function fundSubscription(address vrfCoordinator, uint64 subId, address link) public {
        console.log("funding subscription :" , subId);
        console.log("using vrfCoordinaator:" , vrfCoordinator);
        console.log("on chainId:" , block.chainid);

        if(block.chainid == 31337){ //we are on anvil chain
            vm.startBroadcast();
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);              //2.1
            vm.stopBroadcast();
        }
        else{            //on real chain
            vm.startBroadcast(); 
            LinkToken(link).transferAndCall( vrfCoordinator, FUND_AMOUNT, abi.encode(subId));        //2.2
            vm.startBroadcast();
        }
    }


}


// there has to be a single run function but we divided it into three functions and deviated path from one to another.


/*  explainiation:

    basically work is being done in only two lines : 
    1. getting our vrfcoordinator address, subId, link token address in createSubscriptionUsingConfig using helperconfig
    2.1 (for local anvil chain)    using the         VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT)         to fund 
    2.2 (for seplia testnet chain) using the         LinkToken(link).transferAndCall( vrfCoordinator, FUND_AMOUNT, abi.encode(subId))          to fund

*/


contract AddConsumer is Script{
    
    // here we will make our raffle contract a consumer of the subscription. (and with this our last test namely testCannotEnterRaffleWhenItIsCalculating will pass where the main problem of subscription started)
    // we will deploy our raffle contract in DeployScipt but it will be added as a consumer HERE.
    // so to get the latest deployed contract here, we will use devops
   
    function run() external{
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);         //0
        addConsumerUsingConfig(raffle);
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        ( , ,address vrfCoordinator, , uint64 subId, , ) = helperConfig.activeNetworkConfig();        //1

        addConsumer(raffle, vrfCoordinator, subId);
    }

    function addConsumer(address raffle, address vrfCoordinator, uint64 subId) public {
        console.log("adding consumer contract:" , raffle);
        console.log("using vrfCoordinaator:" , vrfCoordinator);
        console.log("on chainId:" , block.chainid);

        vm.startBroadcast(); 
        //this add consumer is defined in VRFCoordinatorV2Mock 
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);             //2
        vm.stopBroadcast();
    
    }
}


// there has to be a single run function but we divided it into three functions and deviated path from one to another.


/*  explainiation:

    basically work is being done in only three lines : 
    0. getting the latest deployed raffle contract using devops. 
    1. getting our chain specific vrfcoordinator address and subId in createSubscriptionUsingConfig
    2. using the VRFCoordinatorV2Mock(vrfCoordinator).addConsumer() to add consumer finally

*/
