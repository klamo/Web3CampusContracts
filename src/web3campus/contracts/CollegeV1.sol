// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/utils/CountersUpgradeable.sol";
import "./SchoolV1.sol";
import "./SchoolTeacher.sol";

contract CollegeV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // 学校合约地址
    SchoolV1 public school;
    
    // 教师合约地址
    SchoolTeacher public schoolTeacher;
    
    // 学院ID计数器
    CountersUpgradeable.Counter private _collegeIdCounter;
    
    // 学院状态枚举
    enum CollegeStatus {
        Active,
        Frozen,
        Closed
    }
    
    // 学院结构
    // 修改学院结构，移除 DAO 相关字段
    struct College {
        uint256 collegeId;          // 学院ID
        uint256 schoolId;           // 所属学校ID
        string name;                // 学院名称
        string desc;                // 学院简介
        string logo;                // 学院图标
        uint256 reputation;         // 学院声誉值
        address[] teachers;         // 教师地址列表
        uint256 createdAt;          // 创建时间
        uint256 updatedAt;          // 更新时间
        address creator;            // 创建者
        CollegeStatus status;       // 学院状态
    }
    
    // 学院ID => 学院信息
    mapping(uint256 => College) private colleges;
    
    // 学校ID => 学院ID数组
    mapping(uint256 => uint256[]) private schoolColleges;
    
    // 学校ID和学院名称 => 学院ID (用于检查名称唯一性)
    mapping(uint256 => mapping(string => uint256)) private schoolCollegeNameToId;
    
    // 学院总数
    uint256 public totalColleges;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    // 添加设置 school 的函数
    function setSchool(address _schoolAddress) public onlyOwner {
        require(_schoolAddress != address(0), "Invalid address");
        school = SchoolV1(_schoolAddress);
        emit SchoolUpdated(_schoolAddress);
    }

    event SchoolUpdated(address indexed newSchoolContract);

    // 添加设置 school 的函数
    function setSchoolTeacher(address _schoolTeacherAddress) public onlyOwner {
        require(_schoolTeacherAddress != address(0), "Invalid address");
        schoolTeacher = SchoolTeacher(_schoolTeacherAddress);
        emit SchoolTeacherUpdated(_schoolTeacherAddress);
    }

    event SchoolTeacherUpdated(address indexed newSchoolTeacherContract);

    
    // ==================== 学院管理 ====================

    // 创建学院
    function createCollege(
        uint256 _schoolId,
        string memory _name,
        string memory _desc,
        string memory _logo
    ) public returns (uint256) {
        require(school.schoolExists(_schoolId), "School does not exist");
        require(school.hasPermission(_schoolId, msg.sender, 0x1), "No permission to create college");
        require(bytes(_name).length > 0, "College name cannot be empty");
        require(bytes(_desc).length > 0, "College description cannot be empty");
        require(bytes(_logo).length > 0, "College logo cannot be empty");
        require(schoolCollegeNameToId[_schoolId][_name] == 0, "College name already exists in this school");
        
        // 检查学院数量是否超过限制
        require(schoolColleges[_schoolId].length < school.getMaxColleges(_schoolId), "Max colleges limit reached");
        
        _collegeIdCounter.increment();
        uint256 newCollegeId = _collegeIdCounter.current();
        
        College storage newCollege = colleges[newCollegeId];
        newCollege.collegeId = newCollegeId;
        newCollege.schoolId = _schoolId;
        newCollege.name = _name;
        newCollege.desc = _desc;
        newCollege.logo = _logo;
        newCollege.reputation = 0;
        newCollege.createdAt = block.timestamp;
        newCollege.updatedAt = block.timestamp;
        newCollege.creator = msg.sender;
        newCollege.status = CollegeStatus.Active;
        
        // 更新映射关系
        schoolCollegeNameToId[_schoolId][_name] = newCollegeId;
        schoolColleges[_schoolId].push(newCollegeId);
        totalColleges++;
        
        emit CollegeCreated(newCollegeId, _schoolId, msg.sender, _name);
        return newCollegeId;
    }
    
    // 更新学院信息
    function updateCollegeInfo(
        uint256 _collegeId,
        string memory _name,
        string memory _desc,
        string memory _logo
    ) public {
        require(collegeExists(_collegeId), "College does not exist");
        College storage college = colleges[_collegeId];
        require(school.hasPermission(college.schoolId, msg.sender, 0x4), "No permission to update info");
        
        // 如果名称变更，需要检查唯一性
        if (keccak256(bytes(college.name)) != keccak256(bytes(_name))) {
            require(schoolCollegeNameToId[college.schoolId][_name] == 0, "College name already exists in this school");
            // 删除旧名称映射
            delete schoolCollegeNameToId[college.schoolId][college.name];
            // 添加新名称映射
            schoolCollegeNameToId[college.schoolId][_name] = _collegeId;
        }
        
        college.name = _name;
        college.desc = _desc;
        college.logo = _logo;
        college.updatedAt = block.timestamp;
        
        emit CollegeInfoUpdated(_collegeId, msg.sender, _name);
    }
    
    // 获取学院基本信息
    function getCollegeInfo(uint256 _collegeId) public view returns (
        string memory name,
        string memory desc,
        string memory logo,
        uint256 schoolId,
        address creator,
        uint256 createdAt,
        uint256 updatedAt,
        uint256 reputation,
        uint8 status
    ) {
        require(collegeExists(_collegeId), "College does not exist");
        College storage college = colleges[_collegeId];
        
        return (
            college.name,
            college.desc,
            college.logo,
            college.schoolId,
            college.creator,
            college.createdAt,
            college.updatedAt,
            college.reputation,
            uint8(college.status)
        );
    }
    
    // 更新学院状态
    function updateCollegeStatus(uint256 _collegeId, CollegeStatus _status) public {
        require(collegeExists(_collegeId), "College does not exist");
        College storage college = colleges[_collegeId];
        
        // 只有学校创建者或合约拥有者可以更新学院状态
        // 修复：正确获取学校创建者地址
        (,,,address schoolCreator,,,, ) = school.getSchoolInfo(college.schoolId);
        require(
            msg.sender == owner() || 
            msg.sender == schoolCreator,
            "No permission to update status"
        );
        
        college.status = _status;
        college.updatedAt = block.timestamp;
        
        emit CollegeStatusUpdated(_collegeId, uint8(_status));
    }

    // ==================== 教师管理 ====================
    
    // 添加教师
    function addTeacher(uint256 _collegeId, address _teacher) public {
        require(collegeExists(_collegeId), "College does not exist");
        College storage college = colleges[_collegeId];
        require(school.hasPermission(college.schoolId, msg.sender, 0x8), "No permission to manage teachers");
        
        // 检查教师是否已存在
        bool exists = false;
        for (uint i = 0; i < college.teachers.length; i++) {
            if (college.teachers[i] == _teacher) {
                exists = true;
                break;
            }
        }
        
        require(!exists, "Teacher already exists in this college");
        
        college.teachers.push(_teacher);
        college.updatedAt = block.timestamp;
        
        emit TeacherAdded(_collegeId, _teacher);
    }
    
    // 移除教师
    function removeTeacher(uint256 _collegeId, address _teacher) public {
        require(collegeExists(_collegeId), "College does not exist");
        College storage college = colleges[_collegeId];
        require(school.hasPermission(college.schoolId, msg.sender, 0x8), "No permission to manage teachers");
        
        for (uint i = 0; i < college.teachers.length; i++) {
            if (college.teachers[i] == _teacher) {
                college.teachers[i] = college.teachers[college.teachers.length - 1];
                college.teachers.pop();
                college.updatedAt = block.timestamp;
                
                emit TeacherRemoved(_collegeId, _teacher);
                break;
            }
        }
    }
    
    // 获取学院所有教师
    function getCollegeTeachers(uint256 _collegeId) public view returns (address[] memory) {
        require(collegeExists(_collegeId), "College does not exist");
        return colleges[_collegeId].teachers;
    }

    // ==================== 声誉管理 ====================
    
    // 更新学院声誉值
    function updateCollegeReputation(uint256 _collegeId, uint256 _value) public {
        require(collegeExists(_collegeId), "College does not exist");
        College storage college = colleges[_collegeId];
        
        // 只有学校创建者或合约拥有者可以更新学院声誉
        // 修复：正确获取学校创建者地址
        (,,,address schoolCreator,,,, ) = school.getSchoolInfo(college.schoolId);
        require(
            msg.sender == owner() || 
            msg.sender == schoolCreator,
            "No permission to update reputation"
        );
        
        college.reputation = _value;
        college.updatedAt = block.timestamp;
        
        emit CollegeReputationUpdated(_collegeId, _value);
    }

    // ==================== 查询功能 ====================
    
    // 获取学校的所有学院
    function getSchoolColleges(uint256 _schoolId) public view returns (uint256[] memory) {
        require(school.schoolExists(_schoolId), "School does not exist");
        return schoolColleges[_schoolId];
    }
    
    // 定义返回用的学院信息结构体
    struct CollegeInfo {
        uint256 collegeId;
        uint256 schoolId;
        string name;
        string desc;
        string logo;
        uint256 reputation;
        uint256 createdAt;
        uint256 updatedAt;
        address creator;
        CollegeStatus status;
    }
    
    // 修改分页获取学校的学院方法
    function getSchoolCollegesByPage(
        uint256 _schoolId,
        uint256 _page,
        uint256 _size
    ) public view returns (
        CollegeInfo[] memory collegeList,
        uint256 totalReputation
    ) {
        require(school.schoolExists(_schoolId), "School does not exist");
        require(_size > 0, "Page size must be greater than 0");
        
        uint256[] memory allColleges = schoolColleges[_schoolId];
        uint256[] memory filteredColleges = new uint256[](allColleges.length);
        uint256 filteredCount = 0;
        
        // 过滤符合条件的学院
        for (uint256 i = 0; i < allColleges.length; i++) {
            College storage college = colleges[allColleges[i]];
            if (msg.sender == owner() || uint8(college.status) <= 1) {
                filteredColleges[filteredCount] = allColleges[i];
                filteredCount++;
            }
        }
        
        uint256 start = _page * _size;
        uint256 end = start + _size;
        
        if (start >= filteredCount) {
            return (new CollegeInfo[](0), 0);
        }
        
        if (end > filteredCount) {
            end = filteredCount;
        }
        
        uint256 resultSize = end - start;
        collegeList = new CollegeInfo[](resultSize);
        totalReputation = 0;
        
        for (uint256 i = start; i < end; i++) {
            uint256 collegeId = filteredColleges[i];
            College storage college = colleges[collegeId];
            
            collegeList[i - start] = CollegeInfo({
                collegeId: college.collegeId,
                schoolId: college.schoolId,
                name: college.name,
                desc: college.desc,
                logo: college.logo,
                reputation: college.reputation,
                createdAt: college.createdAt,
                updatedAt: college.updatedAt,
                creator: college.creator,
                status: college.status
            });
            
            totalReputation += college.reputation;
        }
        
        return (collegeList, totalReputation);
    }
    
    // 检查教师是否属于学院
    function isTeacherInCollege(uint256 _collegeId, address _teacher) public view returns (bool) {
        require(collegeExists(_collegeId), "College does not exist");
        
        College storage college = colleges[_collegeId];
        for (uint i = 0; i < college.teachers.length; i++) {
            if (college.teachers[i] == _teacher) {
                return true;
            }
        }
        
        return false;
    }
    
    // ==================== 辅助函数 ====================
    
    // 检查学院是否存在
    function collegeExists(uint256 _collegeId) public view returns (bool) {
        return _collegeId > 0 && _collegeId <= _collegeIdCounter.current() && colleges[_collegeId].createdAt > 0;
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ==================== 事件 ====================
    event CollegeCreated(uint256 indexed collegeId, uint256 indexed schoolId, address indexed creator, string name);
    event CollegeInfoUpdated(uint256 indexed collegeId, address indexed updater, string name);
    event CollegeStatusUpdated(uint256 indexed collegeId, uint8 status);
    event CollegeReputationUpdated(uint256 indexed collegeId, uint256 value);
    event TeacherAdded(uint256 indexed collegeId, address indexed teacher);
    event TeacherRemoved(uint256 indexed collegeId, address indexed teacher);
}