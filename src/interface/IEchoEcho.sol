// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IEchoEcho {

    // 服务信息
    struct ServiceInfo {
        address provider; // 服务提供者
        address nft_ca; // NFT合约地址
        uint256 token_id; // NFT tokenId
        uint256 price; // 价格
        uint256 trialPriceBP; // 试用价格， 5000 trial price besis points = 50% of the (price - fee)
        uint256 trialDurationBP; // 使用时长，5000 trial duration besis points = 50% of the max duration
        uint256 max_duration; // 最大时长
        uint256 list_endtime; // 挂单结束时间
    }

    // 服务订单
    struct ServiceOrder {
        address consumer; // 服务消费者
        uint256 start_time; // 服务开始时间
        ServiceInfo serviceInfo; // 服务信息
        bool cancelOrder; // 是否取消订单
    }

    // 在购买服务前，订单的状态
    // status: 0: 初始状态， 1: 用户“想要”；2: 服务提供者“提供”；3: 用户“购买”
    struct PreOrderStatus {
        address consumer; // 服务消费者
        address provider; // 服务提供者
        ServiceInfo serviceInfo; // 服务信息
        uint8 status; // 订单状态
    }

    function list(
        uint256 _token_id,
        uint256 _price,
        uint256 _trialPriceBP,
        uint256 _trialDurationBP,
        uint256 _max_duration,
        uint256 _list_endtime
    ) external;

    function cancelList(ServiceInfo calldata _list) external;
    function cancelListWithSign(
        ServiceInfo calldata _list,
        bytes calldata _providerSignature
    ) external;
    function buy(ServiceInfo calldata _serviceInfo) external payable;
    function buyWithSign(
        ServiceInfo calldata _list,
        bytes calldata _consumerSignature
    ) external payable;
    function cancelOrder(ServiceInfo calldata _list) external;
    function serviceWithdraw(ServiceInfo calldata _list) external;
    function setFeeTo(address _feeTo) external;
    function setServiceNFT_A(address _serviceNFT_A) external;
    function serviceInfoHash(ServiceInfo calldata _list) external pure returns (bytes32);

    event FeeToChanged(address indexed feeTo);
    event List(
        address indexed provider,
        bytes32 indexed serviceInfoHash
    );
    event ListCanceled(bytes32 indexed serviceInfoHash);
    event ServiceBought(
        address indexed consumer,
        address indexed provider,
        bytes32 indexed serviceInfoHash,
        uint256 start_time
    );
    event OrderCancelled(
        address indexed consumer,
        address indexed provider,
        bytes32 indexed serviceInfoHash,
        uint256 refundAmount
    );
    event ServiceWithdrawn(
        address indexed provider,
        bytes32 indexed serviceInfoHash,
        uint256 amount
    );
    event ConsumerWantBuy(
        address indexed consumer,
        address indexed provider,
        bytes32 indexed serviceInfoHash,
        uint256 time,
        uint8 status
    );
    event ProviderCanService(
        address indexed consumer,
        address indexed provider,
        bytes32 indexed serviceInfoHash,
        uint256 time,
        uint8 status
    );
    event PreOrderFinished(
        address indexed consumer,
        address indexed provider,
        bytes32 indexed serviceInfoHash,
        uint256 time,
        uint8 status
    );

    error OnlyOwnerCanList();
    error ErrorListEndTime();
    error ServicesAlreadyListed(bytes32 serviceInfoHash);
    error FeeToZeroAddress();
    error FeeToSameAddress();
    error ErrorServiceNotListed(bytes32 serviceInfoHash);
    error ListAlreadyCancelled(bytes32 serviceInfoHash);
    error ServicesBeingProvided(bytes32 serviceInfoHash);
    error ErrorMoneyNotEnough(uint256 money, uint256 price);
    error ErrorListSigner();
    error ErrorCancelListSigner();
    error OnlyProviderWithdraw(address sender, address provider);
    error OnlyConsumerCancelOrder(address sender, address consumer);
    error OrderHasBeenCancelled();
    error TrialDurationExpired();
    error ListEndTimeExpired(bytes32 serviceInfoHash);
    error OnlyProviderCancelList(address sender, address provider);
    error NoIncome();
    error OnlyProviderCanService(address sender, address provider);
    error OrderWantBuyStatusError(bytes32 serviceInfoHash, uint8 status);
    error OrderCanServiceStatusError(bytes32 serviceInfoHash, uint8 status);
    
}