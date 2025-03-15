// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./CourseV1.sol";

contract CourseTeacherV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 课程合约引用
    CourseV1 public courseContract;
    
    // 课程ID => 教师地址数组
    mapping(uint256 => address[]) private courseTeachers;
    
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
    
    // ==================== 教师管理 ====================
    
    // 添加教师
    function addTeacher(uint256 _courseId, address _teacher) public {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        require(isTeacherOfCourse(_courseId, msg.sender), "Only teacher can add another teacher");
        require(!courseContract.isCourseLocked(_courseId), "Course is locked");
        
        // 检查教师是否已存在
        address[] storage teachers = courseTeachers[_courseId];
        for (uint i = 0; i < teachers.length; i++) {
            if (teachers[i] == _teacher) {
                revert("Teacher already exists");
            }
        }
        
        teachers.push(_teacher);
        
        emit CourseTeacherAdded(_courseId, _teacher);
    }
    
    // 移除教师
    function removeTeacher(uint256 _courseId, address _teacher) public {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        require(isTeacherOfCourse(_courseId, msg.sender), "Only teacher can remove another teacher");
        require(!courseContract.isCourseLocked(_courseId), "Course is locked");
        
        address[] storage teachers = courseTeachers[_courseId];
        require(teachers.length > 1, "Cannot remove the last teacher");
        
        // 获取课程管理者，管理者不能被移除
        address manager = courseContract.getCourseManager(_courseId);
        require(_teacher != manager, "Cannot remove the manager");
        
        bool found = false;
        for (uint i = 0; i < teachers.length; i++) {
            if (teachers[i] == _teacher) {
                // 将最后一个元素移到当前位置，然后删除最后一个元素
                teachers[i] = teachers[teachers.length - 1];
                teachers.pop();
                found = true;
                break;
            }
        }
        
        require(found, "Teacher not found");
        
        emit CourseTeacherRemoved(_courseId, _teacher);
    }
    
    // 获取课程教师列表
    function getCourseTeachers(uint256 _courseId) public view returns (address[] memory) {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        return courseTeachers[_courseId];
    }
    
    // 检查用户是否为课程教师
    function isTeacherOfCourse(uint256 _courseId, address _teacher) public view returns (bool) {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        
        address[] storage teachers = courseTeachers[_courseId];
        for (uint i = 0; i < teachers.length; i++) {
            if (teachers[i] == _teacher) {
                return true;
            }
        }
        
        return false;
    }
    
    // 初始化课程教师
    function initializeCourseTeacher(uint256 _courseId, address _teacher) public {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        require(msg.sender == address(courseContract), "Only course contract can initialize");
        require(courseTeachers[_courseId].length == 0, "Teachers already initialized");
        
        courseTeachers[_courseId].push(_teacher);
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ==================== 事件 ====================
    event CourseTeacherAdded(uint256 indexed courseId, address indexed teacher);
    event CourseTeacherRemoved(uint256 indexed courseId, address indexed teacher);
}