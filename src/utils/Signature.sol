// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library Signature {
    error InvalidSignature();

    // 将签名拆分为v, r, s
    function toVRS(
        bytes memory signature
    ) internal pure returns (
        uint8 v,
        bytes32 r,
        bytes32 s
    ) {
        if (signature.length == 65) {
            assembly {
                r := mload(add(signature, 32))
                s := mload(add(signature, 64))
                v := byte(0, mload(add(signature, 96)))
            }
        } else {
            revert InvalidSignature();
        }
    }

    // 将v, r, s合并为签名
    function fromVRS(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(r, s, v);
    }
}