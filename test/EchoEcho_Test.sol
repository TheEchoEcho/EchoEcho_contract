// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {IEchoEcho} from "../src/interface/IEchoEcho.sol";
import {EchoEcho} from "../src/EchoEcho.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IServiceNFT_A} from "../src/interface/IServiceNFT_A.sol";
import {ServiceNFT_A} from "../src/ServiceNFT_A.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Signature} from "../src/utils/Signature.sol";

contract EchoEcho_Test is Test {
    address echoechoOwner;
    uint256 echoechoOwnerPrivateKey;
    EchoEcho echoecho;
    ServiceNFT_A serviceNFT_A;
    address provider_1;
    uint256 providerPrivateKey_1;
    address consumer_1;
    uint256 consumerPrivateKey_1;
    address consumer_2;
    uint256 consumerPrivateKey_2;

    bytes32 private constant _PERMIT_TYPEHASH =
    keccak256(
        "ServiceInfo(address provider,address nft_ca,uint256 token_id,uint256 price,uint256 trialPriceBP,uint256 trialDurationBP,uint256 max_duration,uint256 list_endtime)"
    );
bytes32 private constant _CANCELLIST_TYPEHASH = 
    keccak256(
        "CancelList(address provider,bytes32 serviceInfoHash)"
    );

    function setUp() public {
        (echoechoOwner, echoechoOwnerPrivateKey) = makeAddrAndKey("echoechoOwner");
        serviceNFT_A = new ServiceNFT_A("ServiceNFT_A", "SNFTA");
        vm.prank(echoechoOwner);
        echoecho = new EchoEcho(address(serviceNFT_A));
        (provider_1, providerPrivateKey_1) = makeAddrAndKey("provider_1");
        (consumer_1, consumerPrivateKey_1) = makeAddrAndKey("consumer_1");
        (consumer_2, consumerPrivateKey_2) = makeAddrAndKey("consumer_2");
    }

    // -----------------------------------------------------------setupTools-------------------------------------------------------
    function _mintNFT() private returns (uint256) {  
        uint256 tokenId_;

        vm.expectEmit(true, true, true, true);
        emit IERC721.Transfer(address(0), provider_1, 0);
        vm.prank(provider_1);
        tokenId_ = serviceNFT_A.mint_A(provider_1, "https://ipfs.io/ipfs/CID1");
        // Check if the NFT was minted with the correct URI
        assertEq(serviceNFT_A.tokenURI(tokenId_), "https://ipfs.io/ipfs/CID1", "URI does not match");
        console.log("Minted NFT with tokenId:", tokenId_);

        return tokenId_;
    }

    function _generateServiceInfo(
        address _provider,
        uint256 _tokenId,
        uint256 _price,
        uint256 _trialPriceBP,
        uint256 _trialDurationBP,
        uint256 _max_duration,
        uint256 _list_endtime
    ) private view returns (IEchoEcho.ServiceInfo memory) {
        return IEchoEcho.ServiceInfo({
            provider: _provider,
            nft_ca: address(serviceNFT_A),
            token_id: _tokenId,
            price: _price,
            trialPriceBP: _trialPriceBP,
            trialDurationBP: _trialDurationBP,
            max_duration: _max_duration,
            list_endtime: _list_endtime
        });
    }

    // list signature
    function signList(
        IEchoEcho.ServiceInfo memory _serviceInfo
    ) private view returns(bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                _serviceInfo.provider,
                _serviceInfo.nft_ca,
                _serviceInfo.token_id,
                _serviceInfo.price,
                _serviceInfo.trialPriceBP,
                _serviceInfo.trialDurationBP,
                _serviceInfo.max_duration,
                _serviceInfo.list_endtime
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                echoecho.getDomainSeparator(),
                structHash
            )
        );

        // Generate Signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(providerPrivateKey_1, digest);
        bytes memory signatureWithList_ = Signature.fromVRS(v, r, s);

        return signatureWithList_;
    }

    // cancelList signature
    function signCancelList(
        IEchoEcho.ServiceInfo memory _serviceInfo
    ) private view returns(bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                _CANCELLIST_TYPEHASH,
                _serviceInfo.provider,
                echoecho.serviceInfoHash(_serviceInfo)
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                echoecho.getDomainSeparator(),
                structHash
            )
        );

        // Generate Signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(providerPrivateKey_1, digest);
        bytes memory signatureWithCancelList_ = Signature.fromVRS(v, r, s);

        return signatureWithCancelList_;
    }

    // -----------------------------------------------------------test-------------------------------------------------------

    // ServiceNFT_A.sol
    function test_fail_NFT_A_transferFrom() public {
        uint256 tokenId_ = _mintNFT();

        vm.expectRevert();
        vm.prank(provider_1);
        serviceNFT_A.transferFrom(provider_1, consumer_1, tokenId_);
    }

    function test_fail_NFT_A_safeTransferFrom() public {
        uint256 tokenId_ = _mintNFT();

        vm.expectRevert();
        vm.prank(provider_1);
        serviceNFT_A.safeTransferFrom(provider_1, consumer_1, tokenId_);
    }

    function test_fail_NFT_A_safeTransferFrom_data() public {
        uint256 tokenId_ = _mintNFT();

        vm.expectRevert();
        vm.prank(provider_1);
        serviceNFT_A.safeTransferFrom(provider_1, consumer_1, tokenId_, "");
    }

    // EchoEcho.sol
    // list
    function test_list() public returns (IEchoEcho.ServiceInfo memory) {
        uint256 tokenId_ = _mintNFT();
        uint256 price_ = 100;
        uint256 trialPriceBP_ = 5000;
        uint256 trialDurationBP_ = 5000;
        uint256 max_duration_ = 3600;
        uint256 list_endtime_ = block.timestamp + 365 days;

        vm.prank(provider_1);
        echoecho.list(
            tokenId_,
            price_,
            trialPriceBP_,
            trialDurationBP_,
            max_duration_,
            list_endtime_
        );

        IEchoEcho.ServiceInfo memory serviceInfo_ = _generateServiceInfo(
            provider_1,
            tokenId_,
            price_,
            trialPriceBP_,
            trialDurationBP_,
            max_duration_,
            list_endtime_
        );

        bytes32 serviceInfoHash_ = echoecho.serviceInfoHash(serviceInfo_);

        assertEq(echoecho.getServiceInfo(serviceInfoHash_).provider, provider_1, "List failed");

        return serviceInfo_;
    }

    function test_fail_list() public {
        uint256 price_ = 100;
        uint256 trialPriceBP_ = 5000;
        uint256 trialDurationBP_ = 5000;
        uint256 max_duration_ = 3600;
        uint256 list_endtime_ = block.timestamp + 365 days;

        vm.expectRevert();
        vm.prank(provider_1);
        echoecho.list(
            0,
            price_,
            trialPriceBP_,
            trialDurationBP_,
            max_duration_,
            list_endtime_
        );
    }

    function test_cancelList() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_list();

        vm.prank(provider_1);
        echoecho.cancelList(serviceInfo_);

        bytes32 serviceInfoHash_ = echoecho.serviceInfoHash(serviceInfo_);
        assertEq(echoecho.canceledOrders(serviceInfoHash_), true, "Cancel list failed");
    }

    function test_cancelListWithSign() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_list();
        bytes memory signatureWithCancelList_ = signCancelList(serviceInfo_);

        vm.prank(provider_1);
        echoecho.cancelListWithSign(serviceInfo_, signatureWithCancelList_);

        bytes32 serviceInfoHash_ = echoecho.serviceInfoHash(serviceInfo_);
        assertEq(echoecho.canceledOrders(serviceInfoHash_), true, "Cancel list with sign failed");
    }
}