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
    
    // 章节结构体
    struct Chapter {
        uint256 chapterId;          // 章节ID
        uint256 courseId;           // 所属课程ID
        string title;               // 章节标题
        string description;         // 章节描述
        uint256 orderIndex;         // 排序索引
        uint256 createdAt;          // 创建时间
        uint256 updatedAt;          // 更新时间
        address creator;            // 创建者
        bool isActive;              // 是否激活
        bool isVirtual;             // 是否为虚拟章节
    }
    
    // 资源包结构
    struct ResourcePack {
        string mainURI;         // 主资源地址
        string backupURI;       // 备用资源地址
        bytes32 ipfsCID;        // IPFS内容标识
        bytes storageProof;     // 去中心化存储证明
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
    
    // 章节ID计数器
    CountersUpgradeable.Counter private _chapterIdCounter;
    
    // 章节ID => 章节信息
    mapping(uint256 => Chapter) private chapters;
    
    // 课程ID => 章节ID数组
    mapping(uint256 => uint256[]) private courseChapterIds;
    
    // 章节ID => 课时ID数组
    mapping(uint256 => uint256[]) private chapterLessonIds;
    
    // 课时ID => 章节ID (如果课时属于章节)
    mapping(uint256 => uint256) private lessonChapterIds;
    
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
    
    // 创建课时
    function createLesson(
        uint256 _courseId,
        uint256 _chapterId,
        string memory _title,
        string memory _description,
        LessonType _lessonType,
        uint32 _duration,
        uint8 _complexity,
        ResourcePack memory _resourcePack,
        bytes32 _contentHash
    ) public returns (uint256) {
        require(bytes(_title).length > 0, "Lesson title empty");
        require(_complexity > 0 && _complexity <= 100, "Complexity between 1-100");
        require(_chapterId != 0, "Chapter zero");
        
        // 添加更详细的错误信息
        // 将长错误消息替换为更简短的版本
        require(chapterExists(_chapterId), "Chapter not found");
        require(chapters[_chapterId].courseId == _courseId, "Chapter not in course");
        
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
        chapterLessonIds[_chapterId].push(newLessonId);
        lessonChapterIds[newLessonId] = _chapterId;
        
        // 默认将创建者添加为编辑者，拥有所有权限
        approvedEditors[newLessonId][msg.sender] = type(uint256).max;
        
        totalLessons++;
        
        emit LessonCreated(newLessonId, _courseId, msg.sender, _title);
        return newLessonId;
    }
    
    // 创建章节
    function createChapter(
        uint256 _courseId,
        string memory _title,
        string memory _description,
        uint256 _orderIndex,
        bool _isVirtual
    ) public returns (uint256) {
        require(bytes(_title).length > 0, "Chapter title empty");
        
        _chapterIdCounter.increment();
        uint256 newChapterId = _chapterIdCounter.current();
        
        Chapter storage newChapter = chapters[newChapterId];
        newChapter.chapterId = newChapterId;
        newChapter.courseId = _courseId;
        newChapter.title = _title;
        newChapter.description = _description;
        newChapter.orderIndex = _orderIndex;
        newChapter.isVirtual = _isVirtual;
        newChapter.createdAt = block.timestamp;
        newChapter.updatedAt = block.timestamp;
        newChapter.creator = msg.sender;
        newChapter.isActive = true;
        
        // 更新映射关系
        courseChapterIds[_courseId].push(newChapterId);
        
        emit ChapterCreated(newChapterId, _courseId, msg.sender, _title);
        return newChapterId;
    }
    
    // 批量创建课程章节和课时体系
    struct ChapterInput {
        string title;
        string description;
        uint256 orderIndex;
        bool isVirtual;             // 是否为虚拟章节
        LessonInput[] lessons;
    }
    
    struct LessonInput {
        string title;
        string description;
        LessonType lessonType;
        uint32 duration;
        uint8 complexity;
        ResourcePack resourcePack;
        bytes32 contentHash;
    }
    
    // 修改批量创建/更新课程章节和课时体系方法
    function createCourseLessonSystem(
        uint256 _courseId,
        ChapterInput[] memory _chapters
    ) public returns (uint256[] memory chapterIds, uint256[] memory lessonIds) {
        require(courseContract.courseExists(_courseId), "Course not exist");
        require(courseContract.isTeacherOfCourse(_courseId, msg.sender), "Only teacher create");
        require(!courseContract.isCourseLocked(_courseId), "Course locked");
        return processChapterStructure(_courseId, _chapters);
    }
    
    // 处理章节结构的课程
    function processChapterStructure(
        uint256 _courseId, 
        ChapterInput[] memory _chapters
    ) private returns (uint256[] memory chapterIds, uint256[] memory lessonIds) {
        // 获取现有章节
        uint256[] memory existingChapterIds = courseChapterIds[_courseId];
        bool[] memory processedChapters = new bool[](existingChapterIds.length);
        
        // 计算总课时数量
        uint256 totalLessonsCount = 0;
        for (uint256 i = 0; i < _chapters.length; i++) {
            totalLessonsCount += _chapters[i].lessons.length;
        }
        
        uint256[] memory newChapterIds = new uint256[](_chapters.length);
        uint256[] memory newLessonIds = new uint256[](totalLessonsCount);
        uint256 lessonIndex = 0;
        
        // 处理章节和章节下的课时
        for (uint256 i = 0; i < _chapters.length; i++) {
            uint256 chapterId = 0;
            bool chapterFound = false;
            
            // 尝试查找匹配的现有章节
            for (uint256 j = 0; j < existingChapterIds.length; j++) {
                if (processedChapters[j]) continue;
                
                Chapter storage existingChapter = chapters[existingChapterIds[j]];
                // 只匹配活跃的章节
                if (existingChapter.isActive && keccak256(bytes(existingChapter.title)) == keccak256(bytes(_chapters[i].title))) {
                    // 找到匹配的章节，检查是否需要更新
                    chapterId = existingChapterIds[j];
                    
                    // 检查章节内容是否有变化
                    bool needUpdate = false;
                    if (
                        keccak256(bytes(existingChapter.description)) != keccak256(bytes(_chapters[i].description)) ||
                        existingChapter.orderIndex != _chapters[i].orderIndex ||
                        existingChapter.isVirtual != _chapters[i].isVirtual
                    ) {
                        needUpdate = true;
                    }
                    
                    // 如果需要更新，则更新章节信息
                    if (needUpdate) {
                        existingChapter.description = _chapters[i].description;
                        existingChapter.orderIndex = _chapters[i].orderIndex;
                        existingChapter.isVirtual = _chapters[i].isVirtual;
                        existingChapter.updatedAt = block.timestamp;
                        
                        emit ChapterUpdated(chapterId, msg.sender);
                    }
                    
                    processedChapters[j] = true;
                    chapterFound = true;
                    break;
                }
            }
            
            // 如果没有找到匹配的章节，创建新章节
            if (!chapterFound) {
                chapterId = createChapter(
                    _courseId,
                    _chapters[i].title,
                    _chapters[i].description,
                    _chapters[i].orderIndex,
                    _chapters[i].isVirtual
                );
                
                // 添加验证，确保章节创建成功
                require(chapterExists(chapterId), "Failed to create chapter");
            }
            
            newChapterIds[i] = chapterId;
            
            // 处理章节下的课时
            uint256[] memory chapterLessonResult = processChapterLessons(
                _courseId,
                chapterId,
                _chapters[i].lessons
            );
            
            // 将章节下的课时ID添加到结果数组
            for (uint256 j = 0; j < chapterLessonResult.length; j++) {
                newLessonIds[lessonIndex] = chapterLessonResult[j];
                lessonIndex++;
            }
        }
        
        // 处理未使用的章节
        handleUnusedChapters(existingChapterIds, processedChapters);
        
        return (newChapterIds, newLessonIds);
    }
    
    // 处理章节下的课时
    function processChapterLessons(
        uint256 _courseId,
        uint256 _chapterId,
        LessonInput[] memory _lessons
    ) private returns (uint256[] memory) {
        // 获取章节下现有的课时
        uint256[] memory existingLessonIds = chapterLessonIds[_chapterId];
        bool[] memory processedLessons = new bool[](existingLessonIds.length);
        
        uint256[] memory newLessonIds = new uint256[](_lessons.length);
        
        // 处理章节下的课时
        for (uint256 i = 0; i < _lessons.length; i++) {
            uint256 lessonId = 0;
            bool lessonFound = false;
            
            // 尝试查找匹配的现有课时
            for (uint256 j = 0; j < existingLessonIds.length; j++) {
                if (processedLessons[j]) continue;
                
                Lesson storage existingLesson = lessons[existingLessonIds[j]];
                if (keccak256(bytes(existingLesson.title)) == keccak256(bytes(_lessons[i].title))) {
                    // 找到匹配的课时，检查是否需要更新
                    lessonId = existingLessonIds[j];
                    
                    // 检查课时内容是否有变化
                    bool needInfoUpdate = isLessonInfoChanged(existingLesson, _lessons[i]);
                    bool needResourceUpdate = isResourceChanged(existingLesson.resourcePack, _lessons[i].resourcePack);
                    
                    // 如果需要更新，则更新课时信息
                    if (needInfoUpdate) {
                        updateLessonInfo(existingLesson, _lessons[i]);
                        emit LessonInfoUpdated(lessonId, msg.sender);
                    }
                    
                    // 如果需要更新资源包，则更新资源包
                    if (needResourceUpdate) {
                        existingLesson.resourcePack = _lessons[i].resourcePack;
                        existingLesson.resourceNonce += 1;
                        existingLesson.updatedAt = block.timestamp;
                        
                        emit LessonResourceUpdated(lessonId, msg.sender, existingLesson.resourceNonce);
                    }
                    
                    processedLessons[j] = true;
                    lessonFound = true;
                    break;
                }
            }
            
            // 如果没有找到匹配的课时，创建新课时
            if (!lessonFound) {
                lessonId = createLesson(
                    _courseId,
                    _chapterId,
                    _lessons[i].title,
                    _lessons[i].description,
                    _lessons[i].lessonType,
                    _lessons[i].duration,
                    _lessons[i].complexity,
                    _lessons[i].resourcePack,
                    _lessons[i].contentHash
                );
            }
            
            newLessonIds[i] = lessonId;
        }
        
        // 处理未使用的课时
        handleUnusedLessons(existingLessonIds, processedLessons);
        
        return newLessonIds;
    }
    
    // 处理未使用的章节
    function handleUnusedChapters(uint256[] memory _chapterIds, bool[] memory _processed) private {
        for (uint256 i = 0; i < _chapterIds.length; i++) {
            if (!_processed[i]) {
                // 将章节设置为非活跃
                chapters[_chapterIds[i]].isActive = false;
                emit ChapterDeleted(_chapterIds[i], msg.sender);
                
                // 将该章节下的所有课时状态设置为已归档
                uint256[] memory chapterLessons = chapterLessonIds[_chapterIds[i]];
                for (uint256 j = 0; j < chapterLessons.length; j++) {
                    lessons[chapterLessons[j]].status = LessonStatus.Archived;
                    emit LessonStatusUpdated(chapterLessons[j], uint8(LessonStatus.Archived));
                }
            }
        }
    }
    
    // 处理未使用的课时
    function handleUnusedLessons(uint256[] memory _lessonIds, bool[] memory _processed) private {
        for (uint256 i = 0; i < _lessonIds.length; i++) {
            if (!_processed[i]) {
                // 将课时状态设置为已归档
                lessons[_lessonIds[i]].status = LessonStatus.Archived;
                emit LessonStatusUpdated(_lessonIds[i], uint8(LessonStatus.Archived));
            }
        }
    }
    
    // 检查课时信息是否有变化
    function isLessonInfoChanged(Lesson storage _existingLesson, LessonInput memory _newLesson) private view returns (bool) {
        return (
            keccak256(bytes(_existingLesson.description)) != keccak256(bytes(_newLesson.description)) ||
            _existingLesson.ltype != _newLesson.lessonType ||
            _existingLesson.duration != _newLesson.duration ||
            _existingLesson.complexity != _newLesson.complexity ||
            _existingLesson.contentHash != _newLesson.contentHash
        );
    }
    
    // 检查资源包是否有变化
    function isResourceChanged(ResourcePack storage _existingResource, ResourcePack memory _newResource) private view returns (bool) {
        return (
            keccak256(bytes(_existingResource.mainURI)) != keccak256(bytes(_newResource.mainURI)) ||
            keccak256(bytes(_existingResource.backupURI)) != keccak256(bytes(_newResource.backupURI)) ||
            _existingResource.ipfsCID != _newResource.ipfsCID
        );
    }
    
    // 更新课时信息
    function updateLessonInfo(Lesson storage _lesson, LessonInput memory _input) private {
        _lesson.description = _input.description;
        _lesson.ltype = _input.lessonType;
        _lesson.duration = _input.duration;
        _lesson.complexity = _input.complexity;
        _lesson.contentHash = _input.contentHash;
        _lesson.updatedAt = block.timestamp;
    }
    
    // 检查章节是否存在
    function chapterExists(uint256 _chapterId) public view returns (bool) {
        return _chapterId > 0 && _chapterId <= _chapterIdCounter.current() && chapters[_chapterId].createdAt > 0;
    }
    
    // 获取课程的完整章节和课时详细信息
    function getCourseLessonDetails(uint256 _courseId) public view returns (
        // 章节信息数组
        Chapter[] memory chapterList,  // 修改变量名，避免与全局变量冲突
        // 每个章节下的课时详细信息
        Lesson[][] memory chapterLessons
    ) {
        require(courseContract.courseExists(_courseId), "Course not exist");
        
        // 获取课程下的所有章节ID
        uint256[] memory chapterIds = courseChapterIds[_courseId];
        uint256 activeChapterCount = 0;
        
        // 计算活跃章节数量
        for (uint256 i = 0; i < chapterIds.length; i++) {
            if (chapters[chapterIds[i]].isActive) {
                activeChapterCount++;
            }
        }
        
        // 初始化返回数组
        chapterList = new Chapter[](activeChapterCount);  // 使用修改后的变量名
        chapterLessons = new Lesson[][](activeChapterCount);
        
        // 填充章节信息和章节下的课时详细信息
        uint256 chapterIndex = 0;
        for (uint256 i = 0; i < chapterIds.length; i++) {
            if (chapters[chapterIds[i]].isActive) {
                chapterList[chapterIndex] = chapters[chapterIds[i]];  // 使用修改后的变量名
                
                // 获取章节下的课时ID
                uint256[] memory lessonIds = chapterLessonIds[chapterIds[i]];
                uint256 activeLessonCount = 0;
                
                // 计算活跃课时数量
                for (uint256 j = 0; j < lessonIds.length; j++) {
                    if (lessons[lessonIds[j]].status != LessonStatus.Archived) {
                        activeLessonCount++;
                    }
                }
                
                chapterLessons[chapterIndex] = new Lesson[](activeLessonCount);
                
                // 填充课时详细信息（只包含非归档状态的课时）
                uint256 activeLessonIndex = 0;
                for (uint256 j = 0; j < lessonIds.length; j++) {
                    if (lessons[lessonIds[j]].status != LessonStatus.Archived) {
                        chapterLessons[chapterIndex][activeLessonIndex] = lessons[lessonIds[j]];
                        activeLessonIndex++;
                    }
                }
                
                chapterIndex++;
            }
        }
        
        return (chapterList, chapterLessons);  // 使用修改后的变量名
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
    
    
    event ChapterCreated(uint256 indexed chapterId, uint256 indexed courseId, address indexed creator, string title);
    event ChapterUpdated(uint256 indexed chapterId, address indexed updater);
    event ChapterDeleted(uint256 indexed chapterId, address indexed deleter);
    event LessonCreated(uint256 indexed lessonId, uint256 indexed courseId, address indexed creator, string title);
    event LessonInfoUpdated(uint256 indexed lessonId, address indexed updater);
    event LessonResourceUpdated(uint256 indexed lessonId, address indexed updater, uint256 resourceNonce);
    event LessonStatusUpdated(uint256 indexed lessonId, uint8 status);
}
