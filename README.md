# NFT Contract Template

## Contract: ServiceNFT_A
- **Free Mint Mechanism**: Any user can freely mint NFTs under the following contracts to create a unique TokenId for each service. Users can also specify a unique URI containing vital information such as service details and provider profiles.

- **Service Categories**: EchoEcho offers several specialized service types:
    - **Health**: Covers all services related to physical and mental health, where users can directly book private fitness training, psychological counseling, etc., within the contract.
    - **Education**: Services include academic tutoring, vocational training, arts, and music education, among others.
    - **Entertainment and Experience**: For providing entertainment and unique experiences such as cultural tour guides and experience day activities.
    - **Personalized Services**: Service providers can create unique personalized services based on their expertise.

- **Frontend Search Bar**: One of the four types of contracts -> Service Type -> Language (Chinese, English, Hindi)

- Example: Alice is an American who enjoys global travel and is also a personal fitness trainer. She can mint an NFT in the `Health Contract` with the following `uri`:
```json
{
    "title": "Personal fitness trainer",
    "description": "Meet Alice, a seasoned personal fitness trainer with over 10 years of professional experience, dedicated to helping individuals achieve their peak physical condition. Having served over 2,000 clients across various continents, Alice brings a wealth of practical knowledge and motivational skills to her training sessions. Not only is she fluent in English, but her expertise has also been recognized with several awards, including the 'International Fitness Professional of the Year'. Whether you're at home or traveling, Alice can tailor her training programs to fit your lifestyle and help you reach your health and fitness goals.",
    "image": "https://violet-electric-mockingbird-261.mypinata.cloud/ipfs/IPFS_CID",
    "attributes": [
        {
            "type": "Broad category",
            "value": "Health"
        },
        {
            "trait_type": "Service type",
            "value": "Personal Fitness Trainer"
        },
        {
            "trait_type": "Language",
            "value": "English"
        },
        {
            ...
        }
    ]
}
```

- Override `transferFrom()` and `safeTransferFrom()` to make NFTs minted from ServiceNFT_A soulbound, i.e., non-transferable.

## Contract: ServiceNFT_B【TBD】
- A template for some organizations or institutions;
- Allows batch minting, but no more than 5 tokenIds at a time to avoid excessive gas usage. The `baseURI` must be specified when creating the contract.

- Future considerations include implementing leasing standards such as `ERC4907`, `ERC5058`, and `ERC6147` to refine `ServiceNFT_B`.

# Contract: EchoEcho
## Listing
- Service providers can list their services using the `list()` function, which saves the service information `ServiceInfo` in `lists`;
- Services can also be listed by signing the service information in the frontend.

## Delisting
- Services listed through `list()` can be delisted using `cancelList()` or `cancelListWithSign()`;
- Services listed by signature must use `cancelListWithSign()` to delist.

## Purchasing Services
- Service provider: Alice, Buyer: Bob
- Bob clicks 'I want this' (i.e., calls `consumerWantBuy()`), and the frontend sends a zk proof to Alice;
- After Alice knows the distance between them, she can choose whether to accept the order; if Alice accepts the order (i.e., calls `providerCanService()`);
- Then Bob can choose to chat with Alice or directly purchase (call `buy()`);

- Order status (`PreOrderStatus`):  
    - I Want: 1
    - Alice Accepts the Order: 2
    - Purchase: 3  

1% of the user's payment goes to `feeTo`.
- Users can use `buy()` to purchase services listed with `list()`;
- They can also use `buyWithSign()` to purchase services listed by signature.

## Terminating Services Midway
Users can cancel the service within the trial duration using `cancelOrder()`, and the refund amount is based on the fees, i.e., `99% * _price * _trialPriceBP`.

## Service Provider Withdrawals
Service providers can only withdraw funds when no services are being provided (`serviceWithdraw()`), to avoid discrepancies if a user terminates the service midway.

## Modifier canService()
`canService()` is used to determine if the current service can be purchased, preventing purchase if the service has been delisted or is currently being provided.