// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/utils/CountersUpgradeable.sol";
import "./CourseV1.sol";

contract CourseLessonV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // 课程合约地址
    CourseV1 public courseContract;
    
    // 课时ID计数器
    CountersUpgradeable.Counter private _lessonIdCounter;
    
    // 课时类型枚举
    enum LessonType {
        Live,       // 直播
        Recorded,   // 录播
        Offline,    // 线下
        VR          // 虚拟现实
    }
    
    // 课时状态枚举
    enum LessonStatus {
        Draft,      // 草稿
        Published,  // 已发布
        Archived,   // 已归档
        Suspended   // 已暂停
    }
    
    // 资源包结构
    struct ResourcePack {
        string mainURI;         // 主资源地址
        string backupURI;       // 备用资源地址
        bytes32 ipfsCID;        // IPFS内容标识
        bytes storageProof;     // 去中心化存储证明
    }
    
    // 完成记录结构
    struct CompletionRecord {
        uint8 progress;         // 完成百分比
        uint64 lastAccess;      // 最后访问时间
        uint16 score;           // 考核分数
        address studentAddress; // 学员地址
    }
        
    // 课时结构
    struct Lesson {
        // 元数据核心字段
        uint256 lessonId;           // 课时全局唯一ID
        bytes32 contentHash;        // 课时内容哈希（防篡改校验）
        uint256 linkedCourseId;     // 所属课程ID
        
        // 教学属性配置
        LessonType ltype;           // 课时类型
        uint32 duration;            // 单位秒（MAX=1193小时）
        uint8 complexity;           // 难度系数1-100
        
        // 资源存储结构
        ResourcePack resourcePack;  // 资源包
        uint256 resourceNonce;      // 资源更新计数器
        
        // 权限管理
        uint256 accessFlags;        // 权限位掩码
        
        // 状态监控
        LessonStatus status;        // 课时状态
        
        // 可扩展设计
        bytes32 extensionSlot;      // 扩展存储槽（EIP-1967标准）
        uint256 featureFlags;       // 功能特性开关
        
        // 基本信息
        string title;               // 课时标题
        string description;         // 课时描述
        uint256 createdAt;          // 创建时间戳
        uint256 updatedAt;          // 最后更新时间
        address creator;            // 创建者
    }
    
    // 课时ID => 课时信息
    mapping(uint256 => Lesson) private lessons;
    
    // 课程ID => 课时ID数组
    mapping(uint256 => uint256[]) private courseLessonIds;
    
    // 授权编辑者映射：课时ID => 地址 => 权限标志
    mapping(uint256 => mapping(address => uint256)) private approvedEditors;
    
    // 课时总数
    uint256 public totalLessons;
    
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
    
    // ==================== 课时管理 ====================
    
    // 创建课时
    function createLesson(
        uint256 _courseId,
        string memory _title,
        string memory _description,
        LessonType _lessonType,
        uint32 _duration,
        uint8 _complexity,
        ResourcePack memory _resourcePack,
        bytes32 _contentHash
    ) public returns (uint256) {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        require(courseContract.isTeacherOfCourse(_courseId, msg.sender), "Only teacher can create lesson");
        require(!courseContract.isCourseLocked(_courseId), "Course is locked");
        require(bytes(_title).length > 0, "Lesson title cannot be empty");
        require(_complexity > 0 && _complexity <= 100, "Complexity must be between 1 and 100");
        
        _lessonIdCounter.increment();
        uint256 newLessonId = _lessonIdCounter.current();
        
        Lesson storage newLesson = lessons[newLessonId];
        newLesson.lessonId = newLessonId;
        newLesson.contentHash = _contentHash;
        newLesson.linkedCourseId = _courseId;
        
        newLesson.ltype = _lessonType;
        newLesson.duration = _duration;
        newLesson.complexity = _complexity;
        
        newLesson.resourcePack = _resourcePack;
        newLesson.resourceNonce = 1;
        
        newLesson.accessFlags = 7; // 默认启用前三个权限位
        
        newLesson.status = LessonStatus.Draft;
        
        
        newLesson.extensionSlot = bytes32(0);
        newLesson.featureFlags = 0;
        
        newLesson.title = _title;
        newLesson.description = _description;
        newLesson.createdAt = block.timestamp;
        newLesson.updatedAt = block.timestamp;
        newLesson.creator = msg.sender;
        
        // 更新映射关系
        courseLessonIds[_courseId].push(newLessonId);
        
        // 默认将创建者添加为编辑者，拥有所有权限
        approvedEditors[newLessonId][msg.sender] = type(uint256).max;
        
        totalLessons++;
        
        emit LessonCreated(newLessonId, _courseId, msg.sender, _title);
        return newLessonId;
    }
    
    // 更新课时基本信息
    function updateLessonInfo(
        uint256 _lessonId,
        string memory _title,
        string memory _description,
        bytes32 _contentHash
    ) public {
        require(lessonExists(_lessonId), "Lesson does not exist");
        Lesson storage lesson = lessons[_lessonId];
        
        // 检查权限
        require(
            hasEditPermission(_lessonId, msg.sender, 0), // 检查元数据修改权限
            "No permission to update lesson info"
        );
        require(!courseContract.isCourseLocked(lesson.linkedCourseId), "Course is locked");
        
        lesson.title = _title;
        lesson.description = _description;
        lesson.contentHash = _contentHash;
        lesson.updatedAt = block.timestamp;
        
        emit LessonInfoUpdated(_lessonId, msg.sender);
    }
    
    // 更新课时资源
    function updateLessonResource(
        uint256 _lessonId,
        ResourcePack memory _resourcePack
    ) public {
        require(lessonExists(_lessonId), "Lesson does not exist");
        Lesson storage lesson = lessons[_lessonId];
        
        // 检查权限
        require(
            hasEditPermission(_lessonId, msg.sender, 1), // 检查资源更新权限
            "No permission to update lesson resource"
        );
        require(!courseContract.isCourseLocked(lesson.linkedCourseId), "Course is locked");
        
        lesson.resourcePack = _resourcePack;
        lesson.resourceNonce += 1;
        lesson.updatedAt = block.timestamp;
        
        emit LessonResourceUpdated(_lessonId, msg.sender, lesson.resourceNonce);
    }
    
    // 更新课时状态
    function updateLessonStatus(uint256 _lessonId, LessonStatus _status) public {
        require(lessonExists(_lessonId), "Lesson does not exist");
        Lesson storage lesson = lessons[_lessonId];
        
        // 检查权限
        require(
            hasEditPermission(_lessonId, msg.sender, 2), // 检查状态变更权限
            "No permission to update lesson status"
        );
        require(!courseContract.isCourseLocked(lesson.linkedCourseId), "Course is locked");
        
        lesson.status = _status;
        lesson.updatedAt = block.timestamp;
        
        emit LessonStatusUpdated(_lessonId, uint8(_status));
    }
    
    // ==================== 权限管理 ====================
    
    // 授权编辑者
    function approveEditor(
        uint256 _lessonId,
        address _editor,
        uint256 _permissions
    ) public {
        require(lessonExists(_lessonId), "Lesson does not exist");
        Lesson storage lesson = lessons[_lessonId];
        
        // 只有课程教师或课时创建者可以授权编辑者
        require(
            courseContract.isTeacherOfCourse(lesson.linkedCourseId, msg.sender) || 
            msg.sender == lesson.creator,
            "Only teacher or creator can approve editors"
        );
        require(!courseContract.isCourseLocked(lesson.linkedCourseId), "Course is locked");
        
        approvedEditors[_lessonId][_editor] = _permissions;
        
        emit EditorApproved(_lessonId, _editor, _permissions);
    }
    
    // 撤销编辑者权限
    function revokeEditor(uint256 _lessonId, address _editor) public {
        require(lessonExists(_lessonId), "Lesson does not exist");
        Lesson storage lesson = lessons[_lessonId];
        
        // 只有课程教师或课时创建者可以撤销编辑者
        require(
            courseContract.isTeacherOfCourse(lesson.linkedCourseId, msg.sender) || 
            msg.sender == lesson.creator,
            "Only teacher or creator can revoke editors"
        );
        require(!courseContract.isCourseLocked(lesson.linkedCourseId), "Course is locked");
        
        delete approvedEditors[_lessonId][_editor];
        
        emit EditorRevoked(_lessonId, _editor);
    }
    
    // ==================== 学习记录管理 ====================
    
    // ==================== 扩展功能 ====================
    
    // 更新功能特性开关
    function updateFeatureFlags(uint256 _lessonId, uint256 _featureFlags) public {
        require(lessonExists(_lessonId), "Lesson does not exist");
        Lesson storage lesson = lessons[_lessonId];
        
        // 只有课程教师或课时创建者可以更新功能特性开关
        require(
            courseContract.isTeacherOfCourse(lesson.linkedCourseId, msg.sender) || 
            msg.sender == lesson.creator,
            "Only teacher or creator can update feature flags"
        );
        require(!courseContract.isCourseLocked(lesson.linkedCourseId), "Course is locked");
        
        lesson.featureFlags = _featureFlags;
        lesson.updatedAt = block.timestamp;
        
        emit FeatureFlagsUpdated(_lessonId, _featureFlags);
    }
    
    // 更新扩展存储槽
    function updateExtensionSlot(uint256 _lessonId, bytes32 _extensionSlot) public {
        require(lessonExists(_lessonId), "Lesson does not exist");
        Lesson storage lesson = lessons[_lessonId];
        
        // 只有课程教师或课时创建者可以更新扩展存储槽
        require(
            courseContract.isTeacherOfCourse(lesson.linkedCourseId, msg.sender) || 
            msg.sender == lesson.creator,
            "Only teacher or creator can update extension slot"
        );
        require(!courseContract.isCourseLocked(lesson.linkedCourseId), "Course is locked");
        
        lesson.extensionSlot = _extensionSlot;
        lesson.updatedAt = block.timestamp;
        
        emit ExtensionSlotUpdated(_lessonId, _extensionSlot);
    }
    
    // ==================== 查询功能 ====================
    
    // 获取课时基本信息
    function getLessonInfo(uint256 _lessonId) public view returns (
        string memory title,
        string memory description,
        uint256 linkedCourseId,
        address creator,
        uint256 createdAt,
        uint256 updatedAt,
        uint8 lessonType,
        uint8 status,
        uint32 duration,
        uint8 complexity
    ) {
        require(lessonExists(_lessonId), "Lesson does not exist");
        Lesson storage lesson = lessons[_lessonId];
        
        return (
            lesson.title,
            lesson.description,
            lesson.linkedCourseId,
            lesson.creator,
            lesson.createdAt,
            lesson.updatedAt,
            uint8(lesson.ltype),
            uint8(lesson.status),
            lesson.duration,
            lesson.complexity
        );
    }
    
    // 获取课时资源信息
    function getLessonResource(uint256 _lessonId) public view returns (
        string memory mainURI,
        string memory backupURI,
        bytes32 ipfsCID,
        uint256 resourceNonce
    ) {
        require(lessonExists(_lessonId), "Lesson does not exist");
        Lesson storage lesson = lessons[_lessonId];
        
        return (
            lesson.resourcePack.mainURI,
            lesson.resourcePack.backupURI,
            lesson.resourcePack.ipfsCID,
            lesson.resourceNonce
        );
    }
    
    // 获取课程的所有课时
    function getCourseLessons(uint256 _courseId) public view returns (uint256[] memory) {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        
        return courseLessonIds[_courseId];
    }
    
    // 获取编辑者权限
    function getEditorPermissions(uint256 _lessonId, address _editor) public view returns (uint256) {
        return approvedEditors[_lessonId][_editor];
    }
    
    // ==================== 辅助函数 ====================
    
    // 检查课时是否存在
    function lessonExists(uint256 _lessonId) public view returns (bool) {
        return _lessonId > 0 && _lessonId <= _lessonIdCounter.current() && lessons[_lessonId].createdAt > 0;
    }
    
    // 检查是否有编辑权限
    function hasEditPermission(uint256 _lessonId, address _editor, uint8 _permissionBit) internal view returns (bool) {
        // 课程教师或课时创建者始终拥有所有权限
        if (
            courseContract.isTeacherOfCourse(lessons[_lessonId].linkedCourseId, _editor) || 
            _editor == lessons[_lessonId].creator
        ) {
            return true;
        }
        
        // 检查特定权限位
        return (approvedEditors[_lessonId][_editor] & (1 << _permissionBit)) != 0;
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ==================== 事件 ====================
    
    // 在事件列表中移除：
    event LessonCreated(uint256 indexed lessonId, uint256 indexed courseId, address indexed creator, string title);
    event LessonInfoUpdated(uint256 indexed lessonId, address indexed updater);
    event LessonResourceUpdated(uint256 indexed lessonId, address indexed updater, uint256 resourceNonce);
    event LessonStatusUpdated(uint256 indexed lessonId, uint8 status);
    event EditorApproved(uint256 indexed lessonId, address indexed editor, uint256 permissions);
    event EditorRevoked(uint256 indexed lessonId, address indexed editor);
    event FeatureFlagsUpdated(uint256 indexed lessonId, uint256 featureFlags);
    event ExtensionSlotUpdated(uint256 indexed lessonId, bytes32 extensionSlot);
}