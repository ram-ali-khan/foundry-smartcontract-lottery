//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";       // a lot of the input parameters of the constructor of Raffle depend on the chain so we will use helper configuration script

import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol"; 


contract DeployRaffle is Script{
    function run() external returns(Raffle, HelperConfig) {


        //using helperconfig to get values corresponding to chain we are deploying to (Helper config gives us flexibility with respect to chain)>>>   

        HelperConfig helperConfig = new HelperConfig();                                                               
        //this new helperConfig will have values corresponding to chain                                 
        //accessing the values (using bracket and commas bcoz struct hai)  >>                         
        (uint256 enteranceFee,                                                                       
        uint256 interval,                                                                               
        address vrfCoordinator,                                                                         
        bytes32 gasLane,                                                                                
        uint64 subscriptionId,                                                                        
        uint32 callbackGasLimit,
        address link) = helperConfig.activeNetworkConfig();    


        // (need only for testing) ye wale part me hum subscription create karenge:
        if(subscriptionId == 0 ){
            
            // 1. creating a subscription:
            CreateSubscription createSubscription = new CreateSubscription();
            // subscriptionId = createSubscription.run();                                        //method1: using the helperconfig in interaction script to get vrfCoordinator
            subscriptionId = createSubscription.createSubscription(vrfCoordinator);              //method2: using the vrfCoordinator from above helperconfig                      //
        

            // 2. funding the subscription:
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link);


            // adding consumer: ye kaam niche kiya hai bcoz it would be done after the raffle is deployed
        
        }                           


        // now deploying the contract:
        vm.startBroadcast();
        Raffle raffle = new Raffle(enteranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit);
        vm.stopBroadcast();


        // 3. adding the deployed contract as consumer in our subscription:
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), vrfCoordinator, subscriptionId);           // here we have directly used the addConsumer function of the AddConsumer script (bcoz we have got all its required inputs here. yes we have got the latest deployed raffle contract here and dont need the devops ki bakchodi)
        
        
        return (raffle, helperConfig);

    }
}



/* 
*
* this should be the actual form of above contract (in above contract we are also returning the helperconfig because we need those chain values while testing) where we return only the raffle contract:
* 
*

contract DeployRaffle is Script{
    function run() external returns(Raffle) {


        //using helperconfig to get values corresponding to chain we are deploying to (Helper config gives us flexibility with respect to chain)>>>   

        HelperConfig helperConfig = new HelperConfig();                                                               
        //this new helperConfig will have values corresponding to chain                                 
        //accessing the values (using bracket and commas bcoz struct hai)  >>                         
        (uint256 enteranceFee,                                                                       
        uint256 interval,                                                                               
        address vrfCoordinator,                                                                         
        bytes32 gasLane,                                                                                
        uint64 subscriptionId,                                                                        
        uint32 callbackGasLimit) = helperConfig.activeNetworkConfig();                              


        // now deploying the contract:
        vm.startBroadcast();
        Raffle raffle = new Raffle(enteranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit);
        vm.stopBroadcast();
        return raffle;

    }
}

*/