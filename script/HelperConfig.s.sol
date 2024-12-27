//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    // since we need to write configuration repeatedly for all networks we can use a struct
    struct NetworkConfig {
        uint256 enteranceFee; 
        uint256 interval;
        address vrfCoordinator; 
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;                    // added later for fundSubscription    // address of smart contract that manages the 'LINK token' (native cryptocurrency of chainlink network) on a specific blockchain
        uint256 deployerKey;            // added more later to solve issue 1 of testing on forked network.
    }

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;           // automatic convert from hex to uint256
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {            // changed from pure to view bcoz of key
        // get all these chaindependent values from the chainlink docs
        return NetworkConfig({
            enteranceFee : 0.01 ether,        // meri mrzi
            interval: 30,                     // meri mrzi
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,                          // https://docs.chain.link/vrf/v2/subscription/supported-networks
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,        // gas lane  = key hash     //https://docs.chain.link/vrf/v2/subscription/supported-networks
            subscriptionId: 1893,             // will update this with our subId    //1893 is patrick's id
            callbackGasLimit: 500000,         // meri mrzi 
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,                               // https://docs.chain.link/resources/link-token-contracts
            deployerKey : vm.envUint("PRIVATE_KEY")     //using our private key as deployerKey   // cheatcode: vm.envUint() is a cheatcode that allows you to get the value of an environment variable as a uint256
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
        LinkToken link = new LinkToken();       //added later       // using this below to create mock link token
        vm.stopBroadcast();
        // 2. will use this new contract address in below constructor


        return NetworkConfig({
            enteranceFee: 0.01 ether,        // meri mrzi
            interval: 30,                    // meri mrzi 
            vrfCoordinator: address(mockVRFCoordinator), 
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,        // gas lane for mock doesn't matter so we can leave it like this i.e., same as in above function
            subscriptionId: 0,               //our script will add this 
            callbackGasLimit: 500000,         // meri mrzi
            link: address(link),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }

}