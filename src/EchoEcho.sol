// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IServiceNFT_A} from "./interface/IServiceNFT_A.sol";
import {IEchoEcho} from "./interface/IEchoEcho.sol";
import {Signature} from "./utils/Signature.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EchoEcho is IEchoEcho, EIP712("EchoEcho", "1"), Ownable(msg.sender) {
    using ECDSA for bytes32;

    uint256 public constant feeBP = 100; // 100 Basis Points = 1%
    address public feeTo;

    IServiceNFT_A public serviceNFT_A;
    
    mapping (bytes32 => ServiceInfo) public lists; // 已上架服务
    mapping (bytes32 => ServiceOrder) public orders; // 最近一次服务订单
    mapping (bytes32 => bool) public canceledOrders; // 已取消订单
    mapping (bytes32 => uint256) public serviceIncome; // 获得的收益
    mapping (address => mapping (bytes32 => PreOrderStatus)) public preBuyStatuses; // 在购买服务前，订单的状态(consumer => serviceInfoHash => PreOrderStatus)
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256(
            "ServiceInfo(address provider,address nft_ca,uint256 token_id,uint256 price,uint256 trialPriceBP,uint256 trialDurationBP,uint256 max_duration,uint256 list_endtime)"
        );
    bytes32 private constant _CANCELLIST_TYPEHASH = 
        keccak256(
            "CancelList(address provider,bytes32 serviceInfoHash)"
        );

    constructor(address _serviceNFT_A) {
        serviceNFT_A = IServiceNFT_A(_serviceNFT_A);
        feeTo = msg.sender;
    }

    function list (
        uint256 _token_id,
        uint256 _price,
        uint256 _trialPriceBP,
        uint256 _trialDurationBP,
        uint256 _max_duration,
        uint256 _list_endtime
    ) external {
        // 检查token_id的owner是否是当前用户
        if (serviceNFT_A.ownerOf(_token_id) != msg.sender) {
            revert OnlyOwnerCanList();
        }

        // 检查挂单结束时间是否大于当前时间
        if (_list_endtime < block.timestamp) {
            revert ErrorListEndTime();
        }

        ServiceInfo memory _list = ServiceInfo({
            provider: msg.sender,
            nft_ca: address(serviceNFT_A),
            token_id: _token_id,
            price: _price,
            trialPriceBP: _trialPriceBP,
            trialDurationBP: _trialDurationBP,
            max_duration: _max_duration,
            list_endtime: _list_endtime
        });

        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        if (lists[_serviceInfoHash].provider != address(0)) {
            revert ServicesAlreadyListed(_serviceInfoHash);
        }

        lists[_serviceInfoHash] = _list;
        emit List(_list.provider, _serviceInfoHash);
    }

    function cancelList(
        ServiceInfo calldata _list
    ) public {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);
        // 检查服务提供者是否是当前用户
        if (lists[_serviceInfoHash].provider != msg.sender) {
            revert OnlyProviderCancelList(msg.sender, lists[_serviceInfoHash].provider);
        }

        _cancelList(_serviceInfoHash);
    }

    function cancelListWithSign(
        ServiceInfo calldata _list,
        bytes calldata _providerSignature
    ) external {
        // 检查服务提供者是否是当前用户
        if (_list.provider != msg.sender) {
            revert OnlyProviderCancelList(msg.sender, _list.provider);
        }

        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);
        _verifyCancelList(_serviceInfoHash, _providerSignature);
        _cancelList(_serviceInfoHash);
    }

    function _cancelList(
        bytes32 _serviceInfoHash
    ) internal {
        if (canceledOrders[_serviceInfoHash]) {
            revert ListAlreadyCancelled(_serviceInfoHash);
        }
        
        canceledOrders[_serviceInfoHash] = true;
        emit ListCanceled(_serviceInfoHash);
    }

    // 用户点击“想要”，判断该服务是否可以购买后，会生成结构体，状态变为1
    function consumerWantBuy(
        ServiceInfo calldata _list
    ) external canService(_list) {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        IEchoEcho.PreOrderStatus memory _preOrderStatus = IEchoEcho.PreOrderStatus({
            consumer: msg.sender,
            provider: _list.provider,
            serviceInfo: _list,
            status: 1
        });
        preBuyStatuses[msg.sender][_serviceInfoHash] = _preOrderStatus;

        emit PreBuyOrderStatus(msg.sender, _list.provider, _serviceInfoHash, block.timestamp, 1);
    }

    // 服务提供者点击“提供”，判断该服务是否可以购买后，会生成结构体，状态变为2
    function providerCanService(
        address _consumer,
        ServiceInfo calldata _list
    ) external canService(_list) {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        // 检查订单的状态是否为1
        if (preBuyStatuses[_consumer][_serviceInfoHash].status != 1) {
            revert OrderWantBuyStatusError(_serviceInfoHash, preBuyStatuses[_consumer][_serviceInfoHash].status);
        }

        // 检查服务提供者是否是当前用户
        if (preBuyStatuses[_consumer][_serviceInfoHash].provider != msg.sender) {
            revert OnlyProviderCanService(msg.sender, preBuyStatuses[_consumer][_serviceInfoHash].provider);
        }

        IEchoEcho.PreOrderStatus memory _preOrderStatus = IEchoEcho.PreOrderStatus({
            consumer: _consumer,
            provider: msg.sender,
            serviceInfo: _list,
            status: 2
        });
        preBuyStatuses[_consumer][_serviceInfoHash] = _preOrderStatus;

        emit PreBuyOrderStatus(_consumer, msg.sender, _serviceInfoHash, block.timestamp, 2);
    }

    function buy(
        ServiceInfo calldata _list
    ) external canService(_list) payable {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        // 检查服务是否上架
        if (lists[_serviceInfoHash].provider == address(0)) {
            revert ErrorServiceNotListed(_serviceInfoHash);
        }

        _buy(_list);
    }

    function buyWithSign(
        ServiceInfo calldata _list,
        bytes calldata _providerSignature
    ) external canService(_list) payable {
        _verifyList(_list, _providerSignature);
        _buy(_list);
    }

    function _buy(
        ServiceInfo calldata _list
    ) internal {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);
        // 检查订单的状态是否为2
        if (preBuyStatuses[msg.sender][_serviceInfoHash].status != 2) {
            revert OrderCanServiceStatusError(_serviceInfoHash, preBuyStatuses[msg.sender][_serviceInfoHash].status);
        }
        if (msg.value < _list.price) {
            revert ErrorMoneyNotEnough(msg.value, _list.price);
        }

        IEchoEcho.PreOrderStatus memory _preOrderStatus = IEchoEcho.PreOrderStatus({
            consumer: msg.sender,
            provider: preBuyStatuses[msg.sender][_serviceInfoHash].provider,
            serviceInfo: _list,
            status: 3
        });
        preBuyStatuses[msg.sender][_serviceInfoHash] = _preOrderStatus;
        emit PreBuyOrderStatus(msg.sender, preBuyStatuses[msg.sender][_serviceInfoHash].provider, _serviceInfoHash, block.timestamp, 3);

        _GenerateOrder(_serviceInfoHash, _list);

        // 转账
        uint256 fee = msg.value * feeBP / 10000;
        uint256 amount = msg.value - fee;
        payable(feeTo).transfer(fee);
        serviceIncome[_serviceInfoHash] += amount;

        emit ServiceBought(msg.sender, _list.provider, _serviceInfoHash, block.timestamp);
    }

    // 用户在试用期内取消订单
    function cancelOrder(
        ServiceInfo calldata _list
    ) external {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        // 检查订单的消费者是否是当前用户
        if (orders[_serviceInfoHash].consumer != msg.sender) {
            revert OnlyConsumerCancelOrder(msg.sender, orders[_serviceInfoHash].consumer);
        }

        // 检查订单是否已经取消过了
        if (orders[_serviceInfoHash].cancelOrder) {
            revert OrderHasBeenCancelled();
        }

        // 检查订单是否在试用期内
        uint256 max_trial_duration = orders[_serviceInfoHash].start_time + _list.trialDurationBP * _list.max_duration / 10000;
        if (block.timestamp >= max_trial_duration) {
            revert TrialDurationExpired();
        }

        orders[_serviceInfoHash].cancelOrder = true;

        // 计算退款金额
        // 先计算扣除手续费后的金额
        uint256 fee = _list.price * feeBP / 10000;
        uint256 amount = _list.price - fee;
        // 计算试用期内的金额
        uint256 trialAmount = _list.trialPriceBP * amount / 10000;
        // 退款
        uint256 refundAmount = amount - trialAmount;
        payable(msg.sender).transfer(refundAmount);
        serviceIncome[_serviceInfoHash] -= refundAmount;

        emit OrderCancelled(msg.sender, _list.provider, _serviceInfoHash, refundAmount);
    }

    // 服务提供者提取某个服务的收益
    function serviceWithdraw(
        ServiceInfo calldata _list
    ) external canService(_list) {
        // 检查取款人是否是服务提供者
        if (msg.sender != _list.provider) {
            revert OnlyProviderWithdraw(msg.sender, _list.provider);
        }

        // 检查服务提供者是否有收益
        if (serviceIncome[this.serviceInfoHash(_list)] == 0) {
            revert NoIncome();
        }

        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);
        uint256 amount = serviceIncome[_serviceInfoHash];
        serviceIncome[_serviceInfoHash] = 0;
        payable(msg.sender).transfer(amount);

        emit ServiceWithdrawn(msg.sender, _serviceInfoHash, amount);
    }

    function _verifyList(
        ServiceInfo calldata _list,
        bytes calldata _providerSignature
    ) internal view {
        bytes32 hashStruct = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                _list.provider,
                _list.nft_ca,
                _list.token_id,
                _list.price,
                _list.trialPriceBP,
                _list.trialDurationBP,
                _list.max_duration,
                _list.list_endtime
            )
        );

        bytes32 _hash = keccak256(
            abi.encodePacked("\x19\x01", _domainSeparatorV4(), hashStruct)
        );

        (uint8 v, bytes32 r, bytes32 s) = Signature.toVRS(_providerSignature);

        address _signer = ECDSA.recover(_hash, v, r, s);

        if (_signer != _list.provider || _signer == address(0)) {
            revert ErrorListSigner();
        }
    }

    function _verifyCancelList(
        bytes32 _serviceInfoHash,
        bytes calldata _providerSignature
    ) internal view {
        bytes32 hashStruct = keccak256(
            abi.encode(
                _CANCELLIST_TYPEHASH,
                msg.sender,
                _serviceInfoHash
            )
        );

        bytes32 _hash = keccak256(
            abi.encodePacked("\x19\x01", _domainSeparatorV4(), hashStruct)
        );

        (uint8 v, bytes32 r, bytes32 s) = Signature.toVRS(_providerSignature);

        address _signer = ECDSA.recover(_hash, v, r, s);

        if (_signer != msg.sender) {
            revert ErrorCancelListSigner();
        }
    }

    function _GenerateOrder(
        bytes32 _serviceInfoHash,
        ServiceInfo calldata _list
    ) internal {
        // 生成订单
        ServiceOrder memory _order = ServiceOrder({
            consumer: msg.sender,
            start_time: block.timestamp,
            serviceInfo: _list,
            cancelOrder: false
        });

        orders[_serviceInfoHash] = _order;
    }

    modifier canService(ServiceInfo calldata _list) {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        // 检查订单是否已取消
        if (canceledOrders[_serviceInfoHash]) {
            revert ListAlreadyCancelled(_serviceInfoHash);
        }

        // 检查end_time是否大于当前时间 
        if (lists[_serviceInfoHash].list_endtime < block.timestamp) {
            revert ListEndTimeExpired(_serviceInfoHash);
        }

        // 检查服务者是否正在提供服务
        if (_isService(_list)) {
            revert ServicesBeingProvided(_serviceInfoHash);
        }

        _;
    }

    // 检查服务者是否正在提供服务, true表示正在提供服务, false表示空闲
    function _isService(
        ServiceInfo calldata _list
        ) internal view returns (bool) {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        if (orders[_serviceInfoHash].consumer != address(0)) {
            ServiceOrder memory _lastOrder = orders[_serviceInfoHash];
            uint256 endTime = _lastOrder.start_time + _list.max_duration;
            // 上一次订单到结束时间，即用户没有取消(callcelOrder=false) 空闲
            // 上一次订单到结束时间 且 用户取消了(callcelOrder=true) 空闲
            // 上一次订单没有到结束时间，但是用户取消了(callcelOrder=true) ，空闲
            // 上一次订单没有到结束时间，同时用户没有取消(callcelOrder=false)，正在提供服务
            if (block.timestamp < endTime && !_lastOrder.cancelOrder) {
                return true;
            }
        }
        return false;
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        if (_feeTo == address(0)) {
            revert FeeToZeroAddress();
        }

        if (feeTo == _feeTo) {
            revert FeeToSameAddress();
        } 

        feeTo = _feeTo;
        emit FeeToChanged(feeTo);
    }

    function setServiceNFT_A(address _serviceNFT_A) external onlyOwner {
        serviceNFT_A = IServiceNFT_A(_serviceNFT_A);
    }

    function serviceInfoHash(
        ServiceInfo calldata _list
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                _list.provider,
                _list.nft_ca,
                _list.token_id,
                _list.price,
                _list.trialPriceBP,
                _list.trialDurationBP,
                _list.max_duration,
                _list.list_endtime
            )
        );
    }

    function getServiceInfo(bytes32 key) public view returns (ServiceInfo memory) {
        return lists[key];
    }

    function getServiceOrder(bytes32 key) public view returns (ServiceOrder memory) {
        return orders[key];
    }

    // public domain separator
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}