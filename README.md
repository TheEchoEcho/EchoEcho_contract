# NFT Contract template
- ServiceNFT_A：每个TokenId都需要mint一次，可以指定不同的URI。
- ServiceNFT_B：可以批量mint，但是每次不能超过5个tokenId，防止超gas，baseURI需要在创建合约的时候指定。