// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../src/ServiceNFT_A.sol";
import "forge-std/Script.sol";

// If you need to deploy the EchoEcho contract, go to EchoEcho_Script.sol. In this case, deploy the ServiceNFT_A contract separately
contract ServiceNFT_A_Script is Script {
    function run() public {
        vm.startBroadcast();
        ServiceNFT_A serviceNFT_A = new ServiceNFT_A("ServiceNFT_A", "SNFTA");
        vm.stopBroadcast();

        console.log("ServiceNFT_A deployed at:", address(serviceNFT_A));
    }
}