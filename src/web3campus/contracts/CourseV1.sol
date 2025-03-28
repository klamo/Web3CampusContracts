// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/utils/CountersUpgradeable.sol";
import "./CollegeV1.sol";
import "./CourseTeacherV1.sol";

contract CourseV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // 学院合约地址
    CollegeV1 public college;
    
    // 教师管理合约地址
    CourseTeacherV1 public teacherContract;
    
    // 课程ID计数器
    CountersUpgradeable.Counter private _courseIdCounter;

    // 课程状态枚举
    enum CourseStatus {
        NotStarted,  // 未开始
        Ongoing,     // 进行中
        Completed,   // 已结束
        Archived     // 已归档
    }
    
    // 课程类型枚举
    enum CourseType {
        Live,       // 直播
        Recorded,   // 录播
        Offline,    // 线下
        VR          // 虚拟现实
    }
    
    // 价格模型枚举
    enum PriceModel {
        Fixed,        // 固定价格
        Subscription, // 订阅制
        Dynamic       // 动态定价
    }
    
    // AI助教配置结构
    struct AIAssistantConfig {
        bytes32 configHash;    // 配置哈希
        address validator;     // API验证合约
        uint256 updateNonce;   // 更新计数器
    }
    
    // 定价策略结构
    struct Pricing {
        PriceModel model;         // 价格模型
        uint256 basePrice;        // 基础价格(wei)
        uint256 discountRate;     // 声誉折扣率(百分比)
        address paymentToken;     // 支付代币地址
    }
    
    // 章节结构
    struct Chapter {
        bytes32 chapterHash;   // 内容哈希
        uint256 createTime;    // 创建时间戳
        string title;          // 章节标题
    }
    
    // 移除 Chapter 结构体
    
    // 课程结构
    struct Course {
        // 核心字段
        uint256 courseId;           // 课程唯一ID
        CourseStatus courseStatus;  // 课程状态
        CourseType ctype;           // 课程类型
        uint256 collegeId;          // 所属学院ID (0=独立课程)
        uint256 schoolId;           // 所属学校ID
        uint256 reputation;         // 动态声誉值
        
        // 教学配置
        AIAssistantConfig assistantConfig; // AI助教配置
        
        // 价格模型
        Pricing pricing;            // 定价策略
        
        // 章节存储
        // bytes32[] _chapterHashes;   // 章节哈希索引
        
        // 元数据
        bytes32 contentHash;        // 课程内容哈希
        uint256 createdAt;          // 创建时间戳
        uint256 updatedAt;          // 最后更新时间
        uint256 version;            // 数据版本号
        
        // 安全字段
        bool _emergencyLock;        // 紧急锁定开关
        
        // 基本信息
        string name;                // 课程名称
        string description;         // 课程描述
        string coverImage;          // 封面图片
        address creator;            // 创建者（不可变）
        address manager;            // 课程管理者（可变）
    }
    
    // 课程基本信息结构体（用于返回值）
    struct CourseInfoView {
        uint256 courseId;      // 课程ID字段
        string name;
        string description;
        string coverImage;
        uint256 collegeId;
        uint256 schoolId;      // 添加学校ID字段
        address creator;
        address manager;
        uint256 createdAt;
        uint256 updatedAt;
        uint8 courseStatus;
        uint8 courseType;
        uint256 reputation;
        
        // 添加Pricing结构体的字段
        uint8 priceModel;         // 价格模型
        uint256 basePrice;        // 基础价格(wei)
        uint256 discountRate;     // 声誉折扣率(百分比)
        address paymentToken;     // 支付代币地址
        
        // 添加AIAssistantConfig结构体的字段
        bytes32 aiConfigHash;     // AI配置哈希
        address aiValidator;      // API验证合约
        uint256 aiUpdateNonce;    // 更新计数器
        
        // 添加其他Course结构体中的字段
        bytes32 contentHash;      // 课程内容哈希
        uint256 version;          // 数据版本号
        bool emergencyLock;       // 紧急锁定开关
    }
    
    // 课程ID => 课程信息
    mapping(uint256 => Course) private courses;
    
    // 学院ID => 课程ID数组
    mapping(uint256 => uint256[]) private collegeCoursesIds;
    
    // 学校ID => 课程ID数组
    mapping(uint256 => uint256[]) private schoolCoursesIds;
    
    // 课程总数
    uint256 public totalCourses;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    // 修改 initialize 函数，移除外部合约地址参数
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }
    
    // 添加设置学院合约地址的函数
    function setCollegeContract(address _collegeAddress) public onlyOwner {
        require(_collegeAddress != address(0), "College address cannot be zero");
        college = CollegeV1(_collegeAddress);
        emit CollegeContractUpdated(_collegeAddress);
    }
    
    // 添加设置教师合约地址的函数
    function setTeacherContract(address _teacherAddress) public onlyOwner {
        require(_teacherAddress != address(0), "Teacher address cannot be zero");
        teacherContract = CourseTeacherV1(_teacherAddress);
        emit TeacherContractUpdated(_teacherAddress);
    }

    // 在事件部分添加新的事件
    event CollegeContractUpdated(address indexed newCollegeContract);
    event TeacherContractUpdated(address indexed newTeacherContract);
    
    // ==================== 课程管理 ====================
    
    // 创建课程
    function createCourse(
        uint256 _collegeId,
        uint256 _schoolId,
        string memory _name,
        string memory _description,
        string memory _coverImage,
        CourseType _courseType,
        Pricing memory _pricing,
        bytes32 _contentHash
    ) public returns (uint256) {
        // 如果指定了学院ID，则验证学院是否存在
        if (_collegeId > 0) {
            require(college.collegeExists(_collegeId), "College does not exist");
            // 验证创建者是否为学院教师
            require(college.isTeacherInCollege(_collegeId, msg.sender), "Creator must be a teacher in the college");
        }
        
        require(bytes(_name).length > 0, "Course name cannot be empty");
        require(bytes(_description).length > 0, "Course description cannot be empty");
        require(bytes(_coverImage).length > 0, "Cover image cannot be empty");
        
        _courseIdCounter.increment();
        uint256 newCourseId = _courseIdCounter.current();
        
        Course storage newCourse = courses[newCourseId];
        newCourse.courseId = newCourseId;
        newCourse.courseStatus = CourseStatus.NotStarted;
        newCourse.ctype = _courseType;
        newCourse.collegeId = _collegeId;
        newCourse.schoolId = _schoolId;    // 设置学校ID
        newCourse.reputation = 0;
        
        // 设置AI助教默认配置
        newCourse.assistantConfig = AIAssistantConfig({
            configHash: bytes32(0),
            validator: address(0),
            updateNonce: 0
        });
        
        // 设置价格模型
        newCourse.pricing = _pricing;
        
        // 设置元数据
        newCourse.contentHash = _contentHash;
        newCourse.createdAt = block.timestamp;
        newCourse.updatedAt = block.timestamp;
        newCourse.version = 1;
        
        // 设置安全字段
        newCourse._emergencyLock = false;
        
        // 设置基本信息
        newCourse.name = _name;
        newCourse.description = _description;
        newCourse.coverImage = _coverImage;
        newCourse.creator = msg.sender;
        newCourse.manager = msg.sender;  // 初始时创建者同时也是管理者
        
        // 更新映射关系
        if (_collegeId > 0) {
            collegeCoursesIds[_collegeId].push(newCourseId);
        }
        
        // 更新学校映射关系
        if (_schoolId > 0) {
            schoolCoursesIds[_schoolId].push(newCourseId);
        }
        
        // 初始化教师
        if (address(teacherContract) != address(0)) {
            teacherContract.initializeCourseTeacher(newCourseId, msg.sender);
        }
        
        totalCourses++;
        
        emit CourseCreated(newCourseId, _collegeId, msg.sender, _name);
        return newCourseId;
    }

    // 更新课程管理者
    function updateCourseManager(uint256 _courseId, address _newManager) public {
        require(courseExists(_courseId), "Course does not exist");
        Course storage course = courses[_courseId];
        
        // 只有当前管理者或创建者可以更新管理者
        require(
            msg.sender == course.manager || 
            msg.sender == course.creator, 
            "Only current manager or creator can update manager"
        );
        require(!course._emergencyLock, "Course is locked");
        require(_newManager != address(0), "New manager cannot be zero address");
        
        // 更新管理者
        course.manager = _newManager;
        course.updatedAt = block.timestamp;
        
        emit CourseManagerUpdated(_courseId, _newManager);
    }
    
    // 更新课程基本信息
    function updateCourseInfo(
        uint256 _courseId,
        string memory _name,
        string memory _description,
        string memory _coverImage,
        bytes32 _contentHash
    ) public {
        require(courseExists(_courseId), "Course does not exist");
        Course storage course = courses[_courseId];
        
        // 修改权限检查，允许管理者更新
        require(
            isTeacherOfCourse(_courseId, msg.sender) || 
            msg.sender == course.manager,
            "Only teacher or manager can update course info"
        );
        require(!course._emergencyLock, "Course is locked");
        
        course.name = _name;
        course.description = _description;
        course.coverImage = _coverImage;
        course.contentHash = _contentHash;
        course.updatedAt = block.timestamp;
        course.version += 1;
        
        emit CourseInfoUpdated(_courseId, msg.sender);
    }
    
    // 更新课程状态
    function updateCourseStatus(uint256 _courseId, CourseStatus _status) public {
        require(courseExists(_courseId), "Course does not exist");
        Course storage course = courses[_courseId];
        require(isTeacherOfCourse(_courseId, msg.sender), "Only teacher can update course status");
        require(!course._emergencyLock, "Course is locked");
        
        course.courseStatus = _status;
        course.updatedAt = block.timestamp;
        
        emit CourseStatusUpdated(_courseId, uint8(_status));
    }
    
    // 更新课程价格模型
    function updateCoursePricing(uint256 _courseId, Pricing memory _pricing) public {
        require(courseExists(_courseId), "Course does not exist");
        Course storage course = courses[_courseId];
        require(isTeacherOfCourse(_courseId, msg.sender), "Only teacher can update pricing");
        require(!course._emergencyLock, "Course is locked");
        
        course.pricing = _pricing;
        course.updatedAt = block.timestamp;
        
        emit CoursePricingUpdated(_courseId, uint8(_pricing.model), _pricing.basePrice);
    }
    
    // 更新课程声誉值
    function updateCourseReputation(uint256 _courseId, uint256 _value) public {
        require(courseExists(_courseId), "Course does not exist");
        Course storage course = courses[_courseId];
        
        // 只有合约拥有者可以更新课程声誉
        require(msg.sender == owner(), "Only owner can update reputation");
        
        course.reputation = _value;
        course.updatedAt = block.timestamp;
        
        emit CourseReputationUpdated(_courseId, _value);
    }
    
    // 紧急锁定/解锁课程
    function toggleEmergencyLock(uint256 _courseId) public onlyOwner {
        require(courseExists(_courseId), "Course does not exist");
        Course storage course = courses[_courseId];
        
        course._emergencyLock = !course._emergencyLock;
        course.updatedAt = block.timestamp;
        
        emit CourseEmergencyLockToggled(_courseId, course._emergencyLock);
    }
    
    // ==================== AI助教管理 ====================
    
    // 更新AI助教配置
    function updateAIAssistant(
        uint256 _courseId,
        bytes32 _configHash,
        address _validator
    ) public {
        require(courseExists(_courseId), "Course does not exist");
        Course storage course = courses[_courseId];
        require(isTeacherOfCourse(_courseId, msg.sender), "Only teacher can update AI assistant");
        require(!course._emergencyLock, "Course is locked");
        
        course.assistantConfig.configHash = _configHash;
        course.assistantConfig.validator = _validator;
        course.assistantConfig.updateNonce += 1;
        course.updatedAt = block.timestamp;
        
        emit CourseAIAssistantUpdated(_courseId, _configHash, _validator);
    }
    
    // ==================== 查询功能 ====================
    
    // 获取课程基本信息
    // function getCourseInfo(uint256 _courseId) public view returns (CourseInfoView memory) {
    //     require(courseExists(_courseId), "Course does not exist");
    //     Course storage course = courses[_courseId];
    //     return CourseInfoView({
    //         courseId: _courseId,
    //         name: course.name,
    //         description: course.description,
    //         coverImage: course.coverImage,
    //         collegeId: course.collegeId,
    //         schoolId: course.schoolId,    // 返回学校ID
    //         creator: course.creator,
    //         manager: course.manager,
    //         createdAt: course.createdAt,
    //         updatedAt: course.updatedAt,
    //         courseStatus: uint8(course.courseStatus),
    //         courseType: uint8(course.ctype),
    //         reputation: course.reputation,
    //         priceModel: uint8(course.pricing.model),
    //         basePrice: course.pricing.basePrice,
    //         discountRate: course.pricing.discountRate,
    //         paymentToken: course.pricing.paymentToken,
    //         aiConfigHash: course.assistantConfig.configHash,
    //         aiValidator: course.assistantConfig.validator,
    //         aiUpdateNonce: course.assistantConfig.updateNonce,
    //         contentHash: course.contentHash,
    //         version: course.version,
    //         emergencyLock: course._emergencyLock
    //     });
    // }
    
    //获取课程价格信息
    function getCoursePricing(uint256 _courseId) public view returns (
        uint8 model,
        uint256 basePrice,
        uint256 discountRate,
        address paymentToken
    ) {
        require(courseExists(_courseId), "Course does not exist");
        Pricing storage pricing = courses[_courseId].pricing;
        
        return (
            uint8(pricing.model),
            pricing.basePrice,
            pricing.discountRate,
            pricing.paymentToken
        );
    }
    
    // 获取课程AI助教配置
    // function getCourseAIAssistant(uint256 _courseId) public view returns (
    //     bytes32 configHash,
    //     address validator,
    //     uint256 updateNonce
    // ) {
    //     require(courseExists(_courseId), "Course does not exist");
    //     AIAssistantConfig storage config = courses[_courseId].assistantConfig;
        
    //     return (
    //         config.configHash,
    //         config.validator,
    //         config.updateNonce
    //     );
    // }
    
    // 查询课程列表（通用查询方法）
    function queryCourses(
        uint8 source,           // 0-学校；1-学院
        uint256 sourceId,       // 学校ID或学院ID
        string memory name,     // 课程名称（可选）
        address manager,        // 课程管理者（可选）
        address creator,        // 课程创建者（可选）
        uint8 courseStatus,     // 课程状态（可选，255表示不过滤）
        uint8 sort,             // 排序规则（预留）
        uint256 pageSize,       // 每页数量
        uint256 pageNumber,     // 页码（从0开始）
        uint256[] memory courseIds  // 课程ID数组（可选）
    ) public view returns (CourseInfoView[] memory, uint256) {
        // 获取初始课程ID列表
        uint256[] memory initialCourseIds;
        
        // 如果指定了课程ID数组，直接使用它
        if (courseIds.length > 0) {
            initialCourseIds = courseIds;
        }
        // 否则按原有逻辑获取课程列表
        else if (sourceId > 0) {
            if (source == 0) {
                // 从学校获取课程
                initialCourseIds = schoolCoursesIds[sourceId];
            } else if (source == 1) {
                // 从学院获取课程
                require(college.collegeExists(sourceId), "College does not exist");
                initialCourseIds = collegeCoursesIds[sourceId];
            } else {
                revert("Invalid source type");
            }
        } else {
            // 如果没有指定sourceId，则创建一个包含所有课程ID的数组
            initialCourseIds = new uint256[](totalCourses);
            for (uint256 i = 1; i <= totalCourses; i++) {
                if (courseExists(i)) {
                    initialCourseIds[i-1] = i;
                }
            }
        }
        
        // 如果初始课程ID列表为空，直接返回空结果
        if (initialCourseIds.length == 0) {
            return (new CourseInfoView[](0), 0);
        }
        
        // 计算符合条件的课程数量和索引
        uint256[] memory matchedIndices = new uint256[](initialCourseIds.length);
        uint256 matchCount = 0;
        
        for (uint256 i = 0; i < initialCourseIds.length; i++) {
            uint256 courseId = initialCourseIds[i];
            if (courseId == 0 || !courseExists(courseId)) continue; // 跳过无效ID
            
            Course storage course = courses[courseId];
            
            // 应用过滤条件
            bool nameMatch = bytes(name).length == 0 || 
                             _containsSubstring(course.name, name);
            // 修改比较逻辑，使用正确的方式判断零地址
            bool managerMatch = manager == address(0) || course.manager == manager;
            bool creatorMatch = creator == address(0) || course.creator == creator;
            // 修改过滤条件
            bool statusMatch = courseStatus == type(uint8).max || uint8(course.courseStatus) == courseStatus;
            
            if (nameMatch && managerMatch && creatorMatch && statusMatch) {
                matchedIndices[matchCount] = i;
                matchCount++;
            }
        }
        
        // 计算分页参数
        uint256 startIndex = 0;
        uint256 endIndex = matchCount;
        uint256 totalPages = 1;
        
        if (pageSize > 0) {
            totalPages = (matchCount + pageSize - 1) / pageSize; // 向上取整
            
            if (pageNumber >= totalPages && matchCount > 0) {
                pageNumber = totalPages - 1; // 页码从0开始，所以最大页码是总页数-1
            }
            
            startIndex = pageNumber * pageSize;
            endIndex = startIndex + pageSize;
            
            if (endIndex > matchCount) {
                endIndex = matchCount;
            }
        }
        
        // 创建结果数组
        uint256 resultSize = endIndex > startIndex ? endIndex - startIndex : 0;
        CourseInfoView[] memory result = new CourseInfoView[](resultSize);
        
        // 填充结果数组
        for (uint256 i = 0; i < resultSize; i++) {
            uint256 originalIndex = matchedIndices[startIndex + i];
            uint256 _courseId = initialCourseIds[originalIndex];
            
            Course storage course = courses[_courseId];
            result[i] = CourseInfoView({
                courseId: _courseId,     // 添加课程ID
                name: course.name,
                description: course.description,
                coverImage: course.coverImage,
                collegeId: course.collegeId,
                schoolId: course.schoolId,    // 添加学校ID
                creator: course.creator,
                manager: course.manager,
                createdAt: course.createdAt,
                updatedAt: course.updatedAt,
                courseStatus: uint8(course.courseStatus),
                courseType: uint8(course.ctype),
                reputation: course.reputation,
                priceModel: uint8(course.pricing.model),
                basePrice: course.pricing.basePrice,
                discountRate: course.pricing.discountRate,
                paymentToken: course.pricing.paymentToken,
                aiConfigHash: course.assistantConfig.configHash,
                aiValidator: course.assistantConfig.validator,
                aiUpdateNonce: course.assistantConfig.updateNonce,
                contentHash: course.contentHash,
                version: course.version,
                emergencyLock: course._emergencyLock
            });
        }
        // 注意：排序功能预留，目前未实现
        // 如果需要实现排序，可以在这里添加排序逻辑
        
        return (result, totalPages);
    }
    
    // 辅助函数：检查字符串是否包含子串（简化版，仅用于演示）
    function _containsSubstring(string memory str, string memory substr) private pure returns (bool) {
        // 处理空字符串的特殊情况
        if (bytes(substr).length == 0 || keccak256(bytes(substr)) == keccak256(bytes("0x"))) {
            return true;
        }
        
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);
        
        // 如果子串长度大于字符串长度，则不匹配
        if (substrBytes.length > strBytes.length) return false;
        
        // 简单的字符串匹配（注意：这是一个简化版本，不支持复杂的字符串匹配）
        for (uint i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool isMatched = true;
            for (uint j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    isMatched = false;
                    break;
                }
            }
            if (isMatched) return true;
        }
        
        return false;
    }
    
    // ==================== 辅助函数 ====================
    
    // 检查课程是否存在
    function courseExists(uint256 _courseId) public view returns (bool) {
        return _courseId > 0 && _courseId <= _courseIdCounter.current() && courses[_courseId].createdAt > 0;
    }
    
    // 检查用户是否为课程教师
    function isTeacherOfCourse(uint256 _courseId, address _teacher) public view returns (bool) {
        if (address(teacherContract) == address(0)) {
            return false;
        }
        return teacherContract.isTeacherOfCourse(_courseId, _teacher);
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 获取课程管理者 - 供教师合约调用
    function getCourseManager(uint256 _courseId) public view returns (address) {
        require(courseExists(_courseId), "Course does not exist");
        return courses[_courseId].manager;
    }
    
    // 检查课程是否被锁定 - 供教师合约调用
    function isCourseLocked(uint256 _courseId) public view returns (bool) {
        require(courseExists(_courseId), "Course does not exist");
        return courses[_courseId]._emergencyLock;
    }
    
    // ==================== 事件 ====================
    event CourseCreated(uint256 indexed courseId, uint256 indexed collegeId, address indexed creator, string name);
    event CourseInfoUpdated(uint256 indexed courseId, address indexed updater);
    event CourseStatusUpdated(uint256 indexed courseId, uint8 status);
    event CoursePricingUpdated(uint256 indexed courseId, uint8 model, uint256 basePrice);
    event CourseReputationUpdated(uint256 indexed courseId, uint256 value);
    event CourseEmergencyLockToggled(uint256 indexed courseId, bool locked);
    event CourseAIAssistantUpdated(uint256 indexed courseId, bytes32 configHash, address validator);
    event CourseManagerUpdated(uint256 indexed courseId, address indexed newManager);
}