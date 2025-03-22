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
        // 先检查课程是否存在
        uint256 courseId = 3;
        bool exists = courseV1.courseExists(courseId);
        console.log("Course exists:", exists);
        
        // 检查是否为教师
        bool isTeacher = courseV1.isTeacherOfCourse(courseId, teacher);
        console.log("Is teacher:", isTeacher);
        
        // 尝试逐个字段获取课程信息，而不是一次性获取所有字段
        try courseV1.getCourseManager(courseId) returns (address manager) {
            console.log("Course manager:", manager);
        } catch {
            console.log("Failed to get course manager");
        }
        
        // 尝试获取课程价格信息
        try courseV1.getCoursePricing(courseId) returns (
            uint8 model,
            uint256 basePrice,
            uint256 discountRate,
            address paymentToken
        ) {
            console.log("Course pricing model:", model);
            console.log("Course base price:", basePrice);
        } catch {
            console.log("Failed to get course pricing");
        }
        
        // 最后尝试获取完整信息
        try courseV1.getCourseInfo(courseId) returns (CourseV1.CourseInfoView memory info) {
            console.log("Course info retrieved successfully");
            console.log("- Name:", info.name);
            console.log("- Creator:", info.creator);
        } catch Error(string memory reason) {
            console.log("Failed with reason:", reason);
        } catch Panic(uint256 code) {
            console.log("Panic with code:", code);
        } catch {
            console.log("Unknown error in getCourseInfo");
        }
    }
}