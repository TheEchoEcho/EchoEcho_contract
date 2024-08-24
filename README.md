# NFT Contract template
## ServiceNFT_A
- **自由Mint机制**：任何用户都可以在下面的几个合约中自由地mint NFT，为每种服务创建一个独一无二的TokenId。并且用户可以为其服务指定一个独特的URI，其中包含服务详情、提供者资料等重要信息。

- **服务分类**：EchoEcho提供几个专门的服务类型：
    - **健康(Health)**：覆盖所有与身体和心理健康相关的服务，用户可以直接在合约中预约私人健身训练、心理咨询等。
    - **教育(Education)**：服务包括学术辅导、职业培训、艺术和音乐教育等。
    - **娱乐与体验(Entertainment and Experience)**：为提供娱乐和独特体验的服务，如文化旅游导游和体验日活动等。
    - **个性化服务(Personalized Services)**：服务提供者可以基于自己的特长创建独特的个性化服务。

- **前端搜索栏**：上述的四种合约之一 -> 服务类型 -> 语言（汉语、英语、印地语）

- 例子：Alice是一位美国人，他喜欢全球旅游，同时也是一名私人健身教练，那么他可以在`Health Contract`中铸造一个NFT，其中`uri`可以这样写：
```json
{
    "title": "Personal fitness trainer",
    "description": "Meet Alice, a seasoned personal fitness trainer with over 10 years of professional experience, dedicated to helping individuals achieve their peak physical condition.  Having served over 2,000 clients across various continents, Alice brings a wealth of practical knowledge and motivational skills to her training sessions.  Not only is she fluent in English, but her expertise has also been recognized with several awards, including the 'International Fitness Professional of the Year'.  Whether you're at home or traveling, Alice can tailor her training programs to fit your lifestyle and help you reach your health and fitness goals.",
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

## ServiceNFT_B【待定】
- 给一些组织或机构的模版；
- 可以批量mint，但是每次不能超过5个tokenId，防止超gas，baseURI需要在创建合约的时候指定。
