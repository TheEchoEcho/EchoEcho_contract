// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../src/ServiceNFT_A.sol";
import "../src/EchoEcho.sol";
import "forge-std/Script.sol";

contract OnlyEchoEcho_Script is Script {
    function run() public {
        address _serviceNFT_A_address = 0x153745F7FDc3BC2cF3E64FBFcCcE04A2f1B89554;
        vm.startBroadcast();
        EchoEcho echoecho = new EchoEcho(_serviceNFT_A_address);
        vm.stopBroadcast();

        console.log("EchoEcho deployed at:", address(echoecho));
        console.log("EchoEcho owner:", echoecho.owner());
        console.log("EchoEcho ServiceNFT_A address:", address(echoecho.serviceNFT_A()));
    }
}