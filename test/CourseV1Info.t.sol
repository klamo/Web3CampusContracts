// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/web3campus/contracts/CourseV1.sol";

/**
 * forge test --match-path /Users/klamo/Documents/code/dapp/web3campus/web3campus/test/CourseV1Info.t.sol -vvvv
 */
contract CourseV1InfoTest is Test {
    CourseV1 public courseV1;
    address public teacher;
    
    function setUp() public {
        // 设置 RPC URL
        vm.createSelectFork("http://localhost:8545");
        
        // 设置测试账号
        teacher = vm.addr(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6);
        
        // 连接到已部署的合约
        courseV1 = CourseV1(0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82);
        
        // 切换到教师账号
        vm.startPrank(teacher);
    }
    
    function testGetCourseInfo() public {
        
    }
}