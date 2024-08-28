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

        // vm.expectEmit(true, true, true, true);
        // emit IERC721.Transfer(address(0), provider_1, 0);
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

    // cancelList
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

    function test_fail_cancelList() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_list();

        vm.expectRevert();
        vm.prank(consumer_1);
        echoecho.cancelList(serviceInfo_);
    }

    // buy
    function test_newBuy() public returns (IEchoEcho.ServiceInfo memory) {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_list();

        vm.deal(consumer_1, 100);
        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_1,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            1
        );
        vm.prank(consumer_1);
        echoecho.consumerWantBuy(serviceInfo_);

        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_1,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            2
        );
        vm.prank(provider_1);
        echoecho.providerCanService(consumer_1, serviceInfo_);

        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_1,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            3
        );
        vm.prank(consumer_1);
        echoecho.buy{value: 100}(serviceInfo_);

        bytes32 serviceInfoHash_ = echoecho.serviceInfoHash(serviceInfo_);
        assertEq(echoecho.getServiceOrder(serviceInfoHash_).consumer, consumer_1, "Buy failed");
        assertEq(echoechoOwner.balance, 1, "fee failed");

        return serviceInfo_;
    }

    // 服务正在进行中，不能选择我想要
    function test_fail1_buy() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_newBuy();

        vm.warp(100);

        vm.expectRevert();
        vm.prank(consumer_2);
        echoecho.consumerWantBuy(serviceInfo_);
    }

    // 当两个用户同时选择我想要时，服务提供者都可以接单
    function test_ProviderDouble() public returns(IEchoEcho.ServiceInfo memory) {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_list();

        vm.deal(consumer_1, 100);
        vm.deal(consumer_2, 100);
        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_1,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            1
        );
        vm.prank(consumer_1);
        echoecho.consumerWantBuy(serviceInfo_);

        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_2,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            1
        );
        vm.prank(consumer_2);
        echoecho.consumerWantBuy(serviceInfo_);

        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_1,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            2
        );
        vm.prank(provider_1);
        echoecho.providerCanService(consumer_1, serviceInfo_);

        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_2,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            2
        );
        vm.prank(provider_1);
        echoecho.providerCanService(consumer_2, serviceInfo_);

        return serviceInfo_;
    }

    // 两个用户同时选择我想要，服务提供者接consumer_1的单后，consumer_1 买了，服务提供者不能再接单
    function test_fail_buy_noProvider() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_list();

        vm.deal(consumer_1, 100);
        vm.deal(consumer_2, 100);
        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_1,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            1
        );
        vm.prank(consumer_1);
        echoecho.consumerWantBuy(serviceInfo_);

        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_2,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            1
        );
        vm.prank(consumer_2);
        echoecho.consumerWantBuy(serviceInfo_);

        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_1,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            2
        );
        vm.prank(provider_1);
        echoecho.providerCanService(consumer_1, serviceInfo_);

        vm.prank(consumer_1);
        echoecho.buy{value: 100}(serviceInfo_);

        vm.expectRevert();
        vm.prank(provider_1);
        echoecho.providerCanService(consumer_2, serviceInfo_);
    }

    // 但是当一个用户买了后，另一个用户不能再买
    function test_fail2_buy() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_ProviderDouble();

        vm.expectEmit(true, true, true, true);
        emit IEchoEcho.PreBuyOrderStatus(
            consumer_1,
            provider_1,
            echoecho.serviceInfoHash(serviceInfo_),
            block.timestamp,
            3
        );
        vm.prank(consumer_1);
        echoecho.buy{value: 100}(serviceInfo_);

        vm.expectRevert();
        vm.prank(consumer_2);
        echoecho.buy{value: 100}(serviceInfo_);
    }

    // cancelOrder
    function test_cancelOrder() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_newBuy();

        vm.warp(100);

        vm.prank(consumer_1);
        echoecho.cancelOrder(serviceInfo_);
        console.log("consumer_1 balance:", consumer_1.balance);

        vm.prank(provider_1);
        echoecho.serviceWithdraw(serviceInfo_);
        console.log("provider_1 balance:", provider_1.balance);
    }

    
    // 不是当前用户取消订单
    function test_fail1_cancelOrder() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_newBuy();

        vm.warp(100);

        vm.expectRevert();
        vm.prank(provider_1);
        echoecho.cancelOrder(serviceInfo_);
    }

    // 超时取消订单
    function test_fail2_cancelOrder() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_newBuy();
        bytes32 serviceInfoHash_ = echoecho.serviceInfoHash(serviceInfo_);
        uint256 start_time = echoecho.getServiceOrder(serviceInfoHash_).start_time;
        uint256 time = serviceInfo_.max_duration * serviceInfo_.trialDurationBP / 10000 + start_time;
        vm.warp(time);

        vm.expectRevert();
        vm.prank(consumer_1);
        echoecho.cancelOrder(serviceInfo_);
    }

    // consumer_2 wantbuy
    // 最近一次服务结束时间还没有到，购买失败
    function test_fail_buy_consumer2() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_newBuy();

        vm.warp(3600);
        vm.expectRevert();
        vm.prank(consumer_2);
        echoecho.consumerWantBuy(serviceInfo_);
    }

    // 上一笔订单服务结束，可以选择我想要
    function test_buy_consumer2() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_newBuy();

        vm.warp(3600 + 1);
        vm.deal(consumer_2, 100);
        vm.prank(consumer_2);
        echoecho.consumerWantBuy;
    }

    // 在服务期间，服务提供者不能取款
    function test_fail_serviceWithdraw() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_newBuy();

        vm.warp(100);
        vm.expectRevert();
        vm.prank(provider_1);
        echoecho.serviceWithdraw(serviceInfo_);
    }

    // 服务结束后，服务提供者可以取款
    function test_serviceWithdraw() public {
        IEchoEcho.ServiceInfo memory serviceInfo_ = test_newBuy();

        vm.warp(3600+1);
        vm.prank(provider_1);
        echoecho.serviceWithdraw(serviceInfo_);
        console.log("provider_1 balance:", provider_1.balance);
    }

    // function test_buyWithSign() public returns (IEchoEcho.ServiceInfo memory) {
    //     IEchoEcho.ServiceInfo memory serviceInfo_ = test_list();
    //     bytes memory signatureWithList_ = signList(serviceInfo_);

    //     vm.deal(consumer_1, 100);
    //     vm.prank(consumer_1);
    //     echoecho.buyWithSign{value: 100}(serviceInfo_, signatureWithList_);

    //     bytes32 serviceInfoHash_ = echoecho.serviceInfoHash(serviceInfo_);
    //     assertEq(echoecho.getServiceOrder(serviceInfoHash_).consumer, consumer_1, "Buy with sign failed");

    //     assertEq(echoechoOwner.balance, 1, "fee failed");

    //     return serviceInfo_;
    // }

    // function test_cancelOrder_ListSign() public {
    //     IEchoEcho.ServiceInfo memory serviceInfo_ = test_buyWithSign();
    //     vm.warp(2);

    //     vm.prank(consumer_1);
    //     echoecho.cancelOrder(serviceInfo_);
    //     console.log("consumer_1 balance:", consumer_1.balance);

    //     vm.prank(provider_1);
    //     echoecho.serviceWithdraw(serviceInfo_);
    //     console.log("provider_1 balance:", provider_1.balance);
    // }

}