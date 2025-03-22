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
        // 准备测试数据
        uint256 courseId = 3;
        
        // 先查询课程信息
        CourseV1.CourseInfoView memory courseInfo = courseV1.getCourseInfo(courseId);
        console.log("Course Info:");
        console.log("- Name:", courseInfo.name);
        console.log("- Creator:", courseInfo.creator);
        console.log("- Manager:", courseInfo.manager);
        console.log("- Status:", courseInfo.courseStatus);
        
        // 检查当前账号是否为课程教师
        bool isTeacher = courseV1.isTeacherOfCourse(courseId, teacher);
        console.log("Is current account teacher:", isTeacher);
        
        CourseLessonV1.ChapterInput[] memory chapters = new CourseLessonV1.ChapterInput[](1);
        
        // 创建课时资源包
        CourseLessonV1.ResourcePack memory resourcePack = CourseLessonV1.ResourcePack({
            mainURI: "ipfs://QmfZiFNbuCZfcyKVfvDoMPT8Fs2UhBurVz4gjiGizD6oFX",
            backupURI: "",
            ipfsCID: bytes32(hex"6c201b2965c14e4a37789c13bdf2af191cbd6adbf4a2417436fd653dab28cf18"),
            storageProof: hex""
        });
        
        // 创建课时输入数组
        CourseLessonV1.LessonInput[] memory lessons = new CourseLessonV1.LessonInput[](1);
        lessons[0] = CourseLessonV1.LessonInput({
            title: unicode"章节一下的课时1",
            description: unicode"111",
            lessonType: CourseLessonV1.LessonType.Recorded,
            duration: 10,
            complexity: 1,
            resourcePack: resourcePack,
            contentHash: bytes32(hex"d4c37ca19df8091d8eccd9ae95c6a0e167d10fbe27a9073dcd400257d11ce459")
        });
        
        // 创建章节输入
        chapters[0] = CourseLessonV1.ChapterInput({
            title: unicode"章节一",
            description: unicode"123",
            orderIndex: 0,
            isVirtual: false,
            lessons: lessons
        });
        
        // 调用合约方法
        (uint256[] memory chapterIds, uint256[] memory lessonIds) = courseLessonV1.createCourseLessonSystem(courseId, chapters);
        
        // 验证返回结果
        assertEq(chapterIds.length, 1, "Should create one chapter");
        assertEq(lessonIds.length, 1, "Should create one lesson");
        
        // 获取创建的章节和课时信息
        (CourseLessonV1.Chapter[] memory chapterList, CourseLessonV1.Lesson[][] memory chapterLessons) = 
            courseLessonV1.getCourseLessonDetails(courseId);
        
        // 验证章节信息
        assertEq(chapterList.length, 1, "Should have one chapter");
        assertEq(chapterList[0].title, unicode"章节一", "Chapter title should match");
        assertEq(chapterList[0].description, unicode"123", "Chapter description should match");
        assertEq(chapterList[0].orderIndex, 0, "Chapter order index should match");
        assertEq(chapterList[0].isVirtual, false, "Chapter virtual flag should match");
        
        // 验证课时信息
        assertEq(chapterLessons[0].length, 1, "Should have one lesson in chapter");
        assertEq(chapterLessons[0][0].title, unicode"章节一下的课时1", "Lesson title should match");
        assertEq(chapterLessons[0][0].description, unicode"111", "Lesson description should match");
        assertEq(uint(chapterLessons[0][0].ltype), uint(CourseLessonV1.LessonType.Recorded), "Lesson type should match");
        assertEq(chapterLessons[0][0].duration, 10, "Lesson duration should match");
        assertEq(chapterLessons[0][0].complexity, 1, "Lesson complexity should match");
        assertEq(
            chapterLessons[0][0].resourcePack.mainURI, 
            "ipfs://QmfZiFNbuCZfcyKVfvDoMPT8Fs2UhBurVz4gjiGizD6oFX",
            "Lesson resource URI should match"
        );
    }
}