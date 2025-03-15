// 直接调用合约的方法

// 查询我创建的所有学校
cast call 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "getSchoolsByPage(address,uint256,uint256)((uint256,address,uint256,uint256,string,string,string,uint256,uint256,uint8,string)[])" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 0 10


// 冻结学校
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "updateSchoolStatus(uint256,uint8,string)" 1 1 "学校暂时冻结" --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

// 解冻学校
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "updateSchoolStatus(uint256,uint8,string)" 2 0 "学校解除冻结" --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

// CommonUserV3 获取用户信息
cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "getUserInfo(address)((string,string,address,string[],bytes10,bytes4))" 0x90F79bf6EB2c4f870365E785982E1f101E93b906