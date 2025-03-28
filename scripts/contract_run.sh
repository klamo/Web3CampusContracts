// 直接调用合约的方法

// 查询我创建的所有学校
cast call 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "getSchoolsByPage(address,uint256,uint256)((uint256,address,uint256,uint256,string,string,string,uint256,uint256,uint8,string)[])" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 0 10


// 冻结学校
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "updateSchoolStatus(uint256,uint8,string)" 1 1 "学校暂时冻结" --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

// 解冻学校
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "updateSchoolStatus(uint256,uint8,string)" 2 0 "学校解除冻结" --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

// CommonUserV3 获取用户信息
cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "getUserInfo(address)((string,string,address,string[],bytes10,bytes4))" 0x90F79bf6EB2c4f870365E785982E1f101E93b906

// SchoolTeacher 获取学校老师申请列表
cast call 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853 "getSchoolApplications(uint256)(address[],string[],uint256[],string[],uint8[],address[],uint256[],string[])" 1
cast call 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853 "getSchoolApplications(uint256)(address[],string[],uint256[],string[],uint8[],address[],uint256[],string[])" 1 | cast --abi-decode "getSchoolApplications(uint256)(address[],string[],uint256[],string[],uint8[],address[],uint256[],string[])" -


// getCourseLessonDetails 获取课程的完整章节和课时详细信息
cast call 0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE "getCourseLessonDetails"


// queryCourses 查询课程列表
cast call 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82 \
  "queryCourses(uint8,uint256,string,address,address,uint8,uint8,uint256,uint256,uint256[])((uint256,string,string,string,uint256,uint256,address,address,uint256,uint256,uint8,uint8,uint256)[],uint256)" \
  0 \
  1 \
  '' \
  0x0000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000 \
  0 \
  255 \
  1 \
  1 \
  "[]"