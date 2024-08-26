// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../src/ServiceNFT_A.sol";
import "forge-std/Script.sol";

// 如果需要部署EchoEcho合约直接去EchoEcho_Script.sol，这里是单独部署ServiceNFT_A合约
contract ServiceNFT_A_Script is Script {
    function run() public {
        vm.startBroadcast();
        ServiceNFT_A serviceNFT_A = new ServiceNFT_A("ServiceNFT_A", "SNFTA");
        vm.stopBroadcast();

        console.log("ServiceNFT_A deployed at:", address(serviceNFT_A));
    }
}