//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
    // since we need to write configuration repeatedly for all networks we can use a struct
    struct NetworkConfig {
        uint256 enteranceFee; 
        uint256 interval;
        address vrfCoordinator; 
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {             // pure bcoz neither it changes state nor it looks into storage
        // get all these chaindependent values from the chainlink docs
        return NetworkConfig({
            enteranceFee : 0.01 ether,        // meri mrzi
            interval: 30,                     // meri mrzi
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,                          // https://docs.chain.link/vrf/v2/subscription/supported-networks
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,        // gas lane  = key hash     //https://docs.chain.link/vrf/v2/subscription/supported-networks
            subscriptionId: 0,                // will update this with our subId
            callbackGasLimit: 500000          // meri mrzi 
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {            // not pure/view because we are sending a txn.
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        //VRFCoordinator address using mocks
        //1. deploy mocks (real contracts but we own and control them)
        //2. use address of mocks

        // 1.lets deploy our own VRFCoordinator contract
        uint96 baseFee = 0.25 ether;  // basically 0.25 LINK
        uint96 gasPricelink = 1e9;   // 1 gwei LINK
        
        vm.startBroadcast();
        VRFCoordinatorV2Mock mockVRFCoordinator = new VRFCoordinatorV2Mock(baseFee, gasPricelink);       // the two inputs for VRFCoordinatorV2Mock are: _baseFee (flat fee it takes) and _gasPriceLink (fees for every gas used in form of LINK tokens)
        vm.stopBroadcast();
        // 2. will use this new contract address in below constructor


        return NetworkConfig({
            enteranceFee: 0.01 ether,        // meri mrzi
            interval: 30,                    // meri mrzi 
            vrfCoordinator: address(mockVRFCoordinator),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,        // gas lane for mock doesn't matter so we can leave it like this i.e., same as in above function
            subscriptionId: 0,               //our script will add this 
            callbackGasLimit: 500000         // meri mrzi
        });
    }

}