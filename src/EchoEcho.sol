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
    
    mapping (bytes32 => ServiceInfo) public lists; // Listed services
    mapping (bytes32 => ServiceOrder) public orders; // Most recent service order
    mapping (bytes32 => bool) public canceledOrders; // Canceled orders
    mapping (bytes32 => uint256) public serviceIncome; // Earned revenue
    mapping (address => mapping (bytes32 => PreOrderStatus)) public preBuyStatuses; // Order statuses before purchasing the service (consumer => serviceInfoHash => PreOrderStatus)
    mapping (uint256 => Longitude_Latitude) public tokenLocation; // NFT tokenId => latitude and longitude
    mapping (uint256 => ServiceInfo) public tokenId_ServiceInfo; // NFT tokenId => service information

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
        // Check if the token_id owner is the current user
        if (serviceNFT_A.ownerOf(_token_id) != msg.sender) {
            revert OnlyOwnerCanList();
        }

        // check if the listing end time is greater than the current time
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
        tokenId_ServiceInfo[_token_id] = _list;
        emit List(_list.provider, _serviceInfoHash);
        emit TokenIdListed(_token_id, _serviceInfoHash);
    }

    function cancelList(
        ServiceInfo calldata _list
    ) public {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);
        // Check if the service provider is the current user
        if (lists[_serviceInfoHash].provider != msg.sender) {
            revert OnlyProviderCancelList(msg.sender, lists[_serviceInfoHash].provider);
        }

        _cancelList(_serviceInfoHash);
    }

    function cancelListWithSign(
        ServiceInfo calldata _list,
        bytes calldata _providerSignature
    ) external {
        // Check if the service provider is the current user
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

    // User clicks "I Want," after checking if the service is purchasable, a structure is generated, and the status is set to 1
    function consumerWantBuy(
        ServiceInfo calldata _list
    ) external canService(_list) {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        // Only when the status is 0 or 3 can "I Want" be clicked
        if (preBuyStatuses[msg.sender][_serviceInfoHash].status != 0 && preBuyStatuses[msg.sender][_serviceInfoHash].status != 3) {
            revert ListWantBuyStatusError(_serviceInfoHash, preBuyStatuses[msg.sender][_serviceInfoHash].status);
        }

        IEchoEcho.PreOrderStatus memory _preOrderStatus = IEchoEcho.PreOrderStatus({
            consumer: msg.sender,
            provider: _list.provider,
            serviceInfo: _list,
            status: 1
        });
        preBuyStatuses[msg.sender][_serviceInfoHash] = _preOrderStatus;

        emit PreBuyOrderStatus(msg.sender, _list.provider, _serviceInfoHash, block.timestamp, 1);
    }

    // Service provider clicks "Can Provide," after checking if the service is purchasable, a structure is generated, and the status is set to 2
    function providerCanService(
        address _consumer,
        ServiceInfo calldata _list
    ) external canService(_list) {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        // Check if the order status is 1
        if (preBuyStatuses[_consumer][_serviceInfoHash].status != 1) {
            revert OrderWantBuyStatusError(_serviceInfoHash, preBuyStatuses[_consumer][_serviceInfoHash].status);
        }

        // Check if the service provider is the current user
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

        // Check if the service is listed
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
        // Check if the order status is 2
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

        // Transfer funds
        uint256 fee = msg.value * feeBP / 10000;
        uint256 amount = msg.value - fee;
        payable(feeTo).transfer(fee);
        serviceIncome[_serviceInfoHash] += amount;

        emit ServiceBought(msg.sender, _list.provider, _serviceInfoHash, block.timestamp);
    }

    // User cancels the order within the trial period
    function cancelOrder(
        ServiceInfo calldata _list
    ) external {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        // Check if the order's consumer is the current user
        if (orders[_serviceInfoHash].consumer != msg.sender) {
            revert OnlyConsumerCancelOrder(msg.sender, orders[_serviceInfoHash].consumer);
        }

        // Check if the order has already been canceled
        if (orders[_serviceInfoHash].cancelOrder) {
            revert OrderHasBeenCancelled();
        }

        // Check if the order is within the trial period
        uint256 max_trial_duration = orders[_serviceInfoHash].start_time + _list.trialDurationBP * _list.max_duration / 10000;
        if (block.timestamp >= max_trial_duration) {
            revert TrialDurationExpired();
        }

        orders[_serviceInfoHash].cancelOrder = true;

        // Calculate the refund amount
        // First, calculate the amount after deducting the fee
        uint256 fee = _list.price * feeBP / 10000;
        uint256 amount = _list.price - fee;
        // Calculate the amount during the trial period
        uint256 trialAmount = _list.trialPriceBP * amount / 10000;
        // Refund
        uint256 refundAmount = amount - trialAmount;
        payable(msg.sender).transfer(refundAmount);
        serviceIncome[_serviceInfoHash] -= refundAmount;

        emit OrderCancelled(msg.sender, _list.provider, _serviceInfoHash, refundAmount);
    }

    // Service provider withdraws earnings from a service
    function serviceWithdraw(
        ServiceInfo calldata _list
    ) external canService(_list) {
        // Check if the withdrawer is the service provider
        if (msg.sender != _list.provider) {
            revert OnlyProviderWithdraw(msg.sender, _list.provider);
        }

        // Check if the service provider has earnings
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
        // Generate an order
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

        // Check if the order has been canceled
        if (canceledOrders[_serviceInfoHash]) {
            revert ListAlreadyCancelled(_serviceInfoHash);
        }

        // Check if the end_time is greater than the current time 
        if (lists[_serviceInfoHash].list_endtime < block.timestamp) {
            revert ListEndTimeExpired(_serviceInfoHash);
        }

        // Check if the provider is currently providing the service
        if (_isService(_list)) {
            revert ServicesBeingProvided(_serviceInfoHash);
        }

        _;
    }

    // Check if the provider is currently providing the service, true indicates the service is being provided, false indicates free
    function _isService(
        ServiceInfo calldata _list
        ) internal view returns (bool) {
        bytes32 _serviceInfoHash = this.serviceInfoHash(_list);

        if (orders[_serviceInfoHash].consumer != address(0)) {
            ServiceOrder memory _lastOrder = orders[_serviceInfoHash];
            uint256 endTime = _lastOrder.start_time + _list.max_duration;
            // From the last order to the end time, i.e., the user did not cancel (cancelOrder=false), free
            // From the last order to the end time and the user canceled (cancelOrder=true), free
            // From the last order has not reached the end time, but the user canceled (cancelOrder=true), free
            // The last order has not reached the end time, and the user did not cancel (cancelOrder=false), the service is being provided
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

    // Latitude: 22.3658801
    // Longitude: 113.5939815
    // The frontend needs to multiply the latitude and longitude by 1e4, then round up to make it an integer
    // Example: 22.3658801 => 223659
    // Example: 113.5939815 => 113594
    function upgradeLocation(uint256 _tokenId, int256 _latitude, int256 _longitude) external {
        // Check if the token_id owner is the current user
        if (serviceNFT_A.ownerOf(_tokenId) != msg.sender) {
            revert OnlyOwnerCanUpgradeLocation();
        }
        tokenLocation[_tokenId] = Longitude_Latitude(_latitude, _longitude);

        emit LocationUpgraded(_tokenId, _latitude, _longitude);
    }
}