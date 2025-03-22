// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./CourseV1.sol";
import "./CourseLessonV1.sol";

contract CourseLessonManagerV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 课程合约地址
    CourseV1 public courseContract;
    // 课时合约地址
    CourseLessonV1 public lessonContract;
    
    // 完成记录结构
    struct CompletionRecord {
        uint8 progress;         // 完成百分比
        uint64 lastAccess;      // 最后访问时间
        uint16 score;           // 考核分数
        address studentAddress; // 学员地址
    }
    
    // 完成记录映射：课时ID => 学员地址 => 完成记录
    mapping(uint256 => mapping(address => CompletionRecord)) private completionRecords;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    // 添加设置 courseContract 的函数
    function setCourseContract(address _courseAddress) public onlyOwner {
        require(_courseAddress != address(0), "Invalid address");
        courseContract = CourseV1(_courseAddress);
        emit CourseContractUpdated(_courseAddress);
    }

    // 在事件部分添加新事件
    event CourseContractUpdated(address indexed newCourseContract);

    // 添加设置 courseContract 的函数
    function setLessonContract(address _lessonAddress) public onlyOwner {
        require(_lessonAddress != address(0), "Invalid address");
        lessonContract = CourseLessonV1(_lessonAddress);
        emit LessonContractUpdated(_lessonAddress);
    }

    // 在事件部分添加新事件
    event LessonContractUpdated(address indexed newLessonContract);
    
    // 更新学习进度
    function updateLearningProgress(
        uint256 _lessonId,
        uint256 _courseId,
        address _student,
        uint8 _progress
    ) public {
        require(lessonContract.lessonExists(_lessonId), "Lesson does not exist");
        
        // 只有课程教师或合约拥有者可以更新学习进度
        require(
            courseContract.isTeacherOfCourse(_courseId, msg.sender) || 
            msg.sender == owner(),
            "Only teacher or owner can update learning progress"
        );
        require(_progress <= 100, "Progress cannot exceed 100%");
        
        CompletionRecord storage record = completionRecords[_lessonId][_student];
        record.progress = _progress;
        record.lastAccess = uint64(block.timestamp);
        record.studentAddress = _student;
        
        emit LearningProgressUpdated(_lessonId, _student, _progress);
    }
    
    // 更新考核分数
    function updateLearningScore(
        uint256 _lessonId,
        uint256 _courseId,
        address _student,
        uint16 _score
    ) public {
        require(lessonContract.lessonExists(_lessonId), "Lesson does not exist");
        
        // 只有课程教师或合约拥有者可以更新考核分数
        require(
            courseContract.isTeacherOfCourse(_courseId, msg.sender) || 
            msg.sender == owner(),
            "Only teacher or owner can update learning score"
        );
        require(_score <= 10000, "Score cannot exceed 10000"); // 允许百分比的100倍精度
        
        CompletionRecord storage record = completionRecords[_lessonId][_student];
        record.score = _score;
        record.lastAccess = uint64(block.timestamp);
        record.studentAddress = _student;
        
        emit LearningScoreUpdated(_lessonId, _student, _score);
    }
    
    // 批量更新学习记录
    function batchUpdateLearningRecords(
        uint256 _lessonId,
        uint256 _courseId,
        address[] memory _students,
        uint8[] memory _progresses,
        uint16[] memory _scores
    ) public {
        require(lessonContract.lessonExists(_lessonId), "Lesson does not exist");
        
        // 只有课程教师或合约拥有者可以批量更新学习记录
        require(
            courseContract.isTeacherOfCourse(_courseId, msg.sender) || 
            msg.sender == owner(),
            "Only teacher or owner can batch update learning records"
        );
        require(_students.length == _progresses.length && _students.length == _scores.length, "Array lengths must match");
        
        for (uint i = 0; i < _students.length; i++) {
            CompletionRecord storage record = completionRecords[_lessonId][_students[i]];
            record.progress = _progresses[i];
            record.score = _scores[i];
            record.lastAccess = uint64(block.timestamp);
            record.studentAddress = _students[i];
        }
        
        emit BatchLearningRecordsUpdated(_lessonId, _students.length);
    }
    
    // 获取学习完成记录
    function getLearningRecord(uint256 _lessonId, address _student) public view returns (
        uint8 progress,
        uint64 lastAccess,
        uint16 score
    ) {
        CompletionRecord storage record = completionRecords[_lessonId][_student];
        
        return (
            record.progress,
            record.lastAccess,
            record.score
        );
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ==================== 事件 ====================
    event LearningProgressUpdated(uint256 indexed lessonId, address indexed student, uint8 progress);
    event LearningScoreUpdated(uint256 indexed lessonId, address indexed student, uint16 score);
    event BatchLearningRecordsUpdated(uint256 indexed lessonId, uint256 studentsCount);
}