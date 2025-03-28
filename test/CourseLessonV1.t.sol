// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/web3campus/contracts/CourseLessonV1.sol";
import "../src/web3campus/contracts/CourseV1.sol";


/**
 * forge test --match-path /Users/klamo/Documents/code/dapp/web3campus/web3campus/test/CourseLessonV1.t.sol -vvvv
 */
contract CourseLessonV1Test is Test {
    CourseLessonV1 public courseLessonV1;
    CourseV1 public courseV1;
    address public teacher;
    
    function setUp() public {
        // 设置 RPC URL（使用本地测试网络或其他测试网络）
        vm.createSelectFork("http://localhost:8545");
        
        // 设置测试账号
        teacher = vm.addr(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6);
        
        // 连接到已部署的合约
        courseV1 = CourseV1(0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82);
        courseLessonV1 = CourseLessonV1(0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE);
        
        // 切换到教师账号
        vm.startPrank(teacher);
        
        // 打印合约状态信息
        console.log("Teacher address:", teacher);
        console.log("CourseV1 address:", address(courseV1));
        console.log("CourseLessonV1 proxy address:", address(courseLessonV1));
        
        // 检查课程合约状态
        bool isCourseExists = courseV1.courseExists(1);
        bool isTeacher = courseV1.isTeacherOfCourse(1, teacher);
        console.log("Course exists:", isCourseExists);
        console.log("Is teacher:", isTeacher);
    }
    
    function testCreateCourseLessonSystem() public {
        
    }
}