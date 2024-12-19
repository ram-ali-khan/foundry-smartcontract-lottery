//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";       // a lot of the input parameters of the constructor of Raffle depend on the chain so we will use helper configuration script

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
        uint32 callbackGasLimit) = helperConfig.activeNetworkConfig();                              


        // now deploying the contract:
        vm.startBroadcast();
        Raffle raffle = new Raffle(enteranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit);
        vm.stopBroadcast();
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