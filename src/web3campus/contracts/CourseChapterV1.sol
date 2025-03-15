// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./CourseV1.sol";

contract CourseChapterV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 课程合约地址
    CourseV1 public courseContract;
    
    // 章节结构
    struct Chapter {
        bytes32 chapterHash;   // 内容哈希
        uint256 createTime;    // 创建时间戳
        string title;          // 章节标题
    }
    
    // 课程ID => 章节哈希数组
    mapping(uint256 => bytes32[]) private courseChapterHashes;
    
    // 章节哈希 => 章节信息
    mapping(bytes32 => Chapter) private chapters;
    
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
    
    // 添加章节
    function addChapter(
        uint256 _courseId,
        string memory _title,
        bytes32 _chapterHash
    ) public {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        require(courseContract.isTeacherOfCourse(_courseId, msg.sender), "Only teacher can add chapter");
        require(!courseContract.isCourseLocked(_courseId), "Course is locked");
        require(chapters[_chapterHash].createTime == 0, "Chapter hash already exists");
        
        // 创建新章节
        Chapter storage newChapter = chapters[_chapterHash];
        newChapter.chapterHash = _chapterHash;
        newChapter.createTime = block.timestamp;
        newChapter.title = _title;
        
        // 将章节哈希添加到课程中
        courseChapterHashes[_courseId].push(_chapterHash);
        
        emit ChapterAdded(_courseId, _chapterHash, _title);
    }
    
    // 更新章节信息
    function updateChapter(
        uint256 _courseId,
        bytes32 _chapterHash,
        string memory _title
    ) public {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        require(courseContract.isTeacherOfCourse(_courseId, msg.sender), "Only teacher can update chapter");
        require(!courseContract.isCourseLocked(_courseId), "Course is locked");
        require(chapters[_chapterHash].createTime > 0, "Chapter does not exist");
        
        // 确认章节属于该课程
        bool chapterFound = false;
        bytes32[] storage hashes = courseChapterHashes[_courseId];
        for (uint i = 0; i < hashes.length; i++) {
            if (hashes[i] == _chapterHash) {
                chapterFound = true;
                break;
            }
        }
        require(chapterFound, "Chapter not found in this course");
        
        // 更新章节信息
        chapters[_chapterHash].title = _title;
        
        emit ChapterUpdated(_courseId, _chapterHash, _title);
    }
    
    // 删除章节
    function removeChapter(uint256 _courseId, bytes32 _chapterHash) public {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        require(courseContract.isTeacherOfCourse(_courseId, msg.sender), "Only teacher can remove chapter");
        require(!courseContract.isCourseLocked(_courseId), "Course is locked");
        
        // 确认章节属于该课程并删除
        bytes32[] storage hashes = courseChapterHashes[_courseId];
        bool chapterFound = false;
        for (uint i = 0; i < hashes.length; i++) {
            if (hashes[i] == _chapterHash) {
                // 将最后一个元素移到当前位置，然后删除最后一个元素
                hashes[i] = hashes[hashes.length - 1];
                hashes.pop();
                chapterFound = true;
                break;
            }
        }
        require(chapterFound, "Chapter not found in this course");
        
        emit ChapterRemoved(_courseId, _chapterHash);
    }
    
    // 获取课程章节列表
    function getCourseChapters(uint256 _courseId) public view returns (
        bytes32[] memory chapterHashes,
        string[] memory titles
    ) {
        require(courseContract.courseExists(_courseId), "Course does not exist");
        bytes32[] storage hashes = courseChapterHashes[_courseId];
        
        chapterHashes = new bytes32[](hashes.length);
        titles = new string[](hashes.length);
        
        for (uint i = 0; i < hashes.length; i++) {
            chapterHashes[i] = hashes[i];
            titles[i] = chapters[hashes[i]].title;
        }
        
        return (chapterHashes, titles);
    }
    
    // 获取章节详情
    function getChapterDetails(bytes32 _chapterHash) public view returns (
        string memory title,
        uint256 createTime
    ) {
        require(chapters[_chapterHash].createTime > 0, "Chapter does not exist");
        Chapter storage chapter = chapters[_chapterHash];
        
        return (
            chapter.title,
            chapter.createTime
        );
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ==================== 事件 ====================
    event ChapterAdded(uint256 indexed courseId, bytes32 indexed chapterHash, string title);
    event ChapterUpdated(uint256 indexed courseId, bytes32 indexed chapterHash, string title);
    event ChapterRemoved(uint256 indexed courseId, bytes32 indexed chapterHash);
}