// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../src/ServiceNFT_A.sol";
import "../src/EchoEcho.sol";
import "forge-std/Script.sol";

contract EchoEcho_Script is Script {
    function run() public {
        vm.startBroadcast();
        ServiceNFT_A serviceNFT_A = new ServiceNFT_A("ServiceNFT_A", "SNFTA");
        EchoEcho echoecho = new EchoEcho(address(serviceNFT_A));
        vm.stopBroadcast();

        console.log("ServiceNFT_A deployed at:", address(serviceNFT_A));
        console.log("EchoEcho deployed at:", address(echoecho));
        console.log("ServiceNFT_A owner:", serviceNFT_A.owner());
        console.log("EchoEcho owner:", echoecho.owner());
        console.log("EchoEcho ServiceNFT_A address:", address(echoecho.serviceNFT_A()));
    }
}