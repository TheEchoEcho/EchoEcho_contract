// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IEchoEcho {

    // 服务信息
    struct ServiceInfo {
        address provider; // service provider
        address nft_ca; // NFT contract address
        uint256 token_id; // NFT tokenId
        uint256 price;
        uint256 trialPriceBP; // trial price， 5000 trial price besis points = 50% of the (price - fee)
        uint256 trialDurationBP; // trial duration，5000 trial duration besis points = 50% of the max duration
        uint256 max_duration; // max duration
        uint256 list_endtime; // list end time
    }

    struct Longitude_Latitude {
        int256 latitude;
        int256 longitude;
    }

    struct ServiceOrder {
        address consumer; // service consumer
        uint256 start_time; // service start time
        ServiceInfo serviceInfo; // service information
        bool cancelOrder; // cancel order
    }

    // The status of the order before the purchase of the service
    // status: 0: indicates the initial status. 1: indicates the user "wants". 2: The service provider "provides"; 3: User "purchase"
    struct PreOrderStatus {
        address consumer; // service consumer
        address provider; // service provider
        ServiceInfo serviceInfo; // service information
        uint8 status;
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
    function consumerWantBuy(ServiceInfo calldata _list) external;
    function providerCanService(
        address _consumer,
        ServiceInfo calldata _list
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
    function upgradeLocation(
        uint256 _token_id,
        int256 _latitude,
        int256 _longitude
    ) external;

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
    event PreBuyOrderStatus(
        address indexed consumer,
        address indexed provider,
        bytes32 indexed serviceInfoHash,
        uint256 time,
        uint8 status
    );
    event TokenIdListed(
        uint256 indexed token_id,
        bytes32 indexed serviceInfoHash
    );
    event LocationUpgraded(
        uint256 indexed token_id,
        int256 latitude,
        int256 longitude
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
    error OnlyOwnerCanUpgradeLocation();
    error ListWantBuyStatusError(bytes32 serviceInfoHash, uint8 status);
}