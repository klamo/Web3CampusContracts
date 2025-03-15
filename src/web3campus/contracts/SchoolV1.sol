// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/utils/CountersUpgradeable.sol";
import "./SchoolUserV1.sol";
import "./SchoolTeacher.sol";


contract SchoolV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // 学校用户合约地址
    SchoolUserV1 public schoolUser;

    // 学校ID计数器
    CountersUpgradeable.Counter private _schoolIdCounter;
    
    // 学校状态枚举
    enum SchoolStatus {
        Active,
        Frozen,
        Closed
    }
    
    // 权限位定义
    uint32 constant CREATE_COLLEGE = 0x1;     // bit0: 创建学院
    uint32 constant MANAGE_FUNDS = 0x2;       // bit1: 管理资金
    uint32 constant UPDATE_INFO = 0x4;        // bit2: 修改信息
    uint32 constant MANAGE_TEACHERS = 0x8;    // bit3: 管理教师
    uint32 constant SUBMIT_PROPOSALS = 0x10;  // bit4: 提交提案
    uint32 constant DAO_VOTE = 0x20;          // bit5: DAO投票
    
    // 学校结构
    struct School {
        uint256 schoolId;
        address payable creator;
        uint256 createdAt;
        uint256 updatedAt;
        string name;
        string desc;
        string logo;
        mapping(string => string) customFields;
        string[] customFieldKeys;
        uint256 reputation;
        uint256 maxColleges;
        address[] permissionAdmins;
        SchoolStatus status;
        string statusReason;
    }
    
    // 学校ID => 学校信息
    mapping(uint256 => School) private schools;
    
    // 学校名称 => 学校ID (用于检查名称唯一性)
    mapping(string => uint256) private schoolNameToId;
    
    // 用户地址 => 创建的学校ID数组
    mapping(address => uint256[]) private userCreatedSchools;
    
    // 学校总数
    uint256 public totalSchools;
    
    // 默认最大学院数
    uint256 public defaultMaxColleges;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    // 添加 SchoolTeacher 合约变量
    SchoolTeacher public schoolTeacher;
    
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        defaultMaxColleges = 10;
    }
    
    // 添加设置 schoolUser 的函数
    function setSchoolUser(address _schoolUserAddress) public onlyOwner {
        require(_schoolUserAddress != address(0), "Invalid address");
        schoolUser = SchoolUserV1(_schoolUserAddress);
        emit SchoolUserUpdated(_schoolUserAddress);
    }

    // 在事件部分添加新事件
    event SchoolUserUpdated(address indexed newUserContract);
    
    // 添加设置 schoolTeacher 的函数，允许多次更新
    function setSchoolTeacher(address _schoolTeacherAddress) public onlyOwner {
        require(_schoolTeacherAddress != address(0), "Invalid address");
        schoolTeacher = SchoolTeacher(_schoolTeacherAddress);
        emit SchoolTeacherUpdated(_schoolTeacherAddress);
    }

    // 添加事件
    event SchoolTeacherUpdated(address indexed newTeacherContract);
    
    // ==================== 学校管理 ====================

    // 创建学校
    function createSchool(
        string memory _name,
        string memory _desc,
        string memory _logo
    ) public returns (uint256) {
        require(schoolUser.isRegistered(msg.sender), "User not registered");
        require(bytes(_name).length > 0, "School name cannot be empty");
        require(bytes(_desc).length > 0, "School description cannot be empty");
        require(bytes(_logo).length > 0, "School logo cannot be empty");
        require(schoolNameToId[_name] == 0, "School name already exists");
        
        _schoolIdCounter.increment();
        uint256 newSchoolId = _schoolIdCounter.current();
        
        School storage newSchool = schools[newSchoolId];
        newSchool.schoolId = newSchoolId;
        newSchool.creator = payable(msg.sender);
        newSchool.createdAt = block.timestamp;
        newSchool.updatedAt = block.timestamp;
        newSchool.name = _name;
        newSchool.desc = _desc;
        newSchool.logo = _logo;
        newSchool.customFieldKeys = new string[](0);
        newSchool.reputation = 0;
        newSchool.maxColleges = defaultMaxColleges;
        newSchool.status = SchoolStatus.Active;
        // 添加创建者为权限管理员
        newSchool.permissionAdmins.push(msg.sender);
        // 更新映射关系
        schoolNameToId[_name] = newSchoolId;
        userCreatedSchools[msg.sender].push(newSchoolId);
        totalSchools++;
        
        emit SchoolCreated(newSchoolId, msg.sender, _name);
        return newSchoolId;
    }
    
    // 更新学校信息
    function updateSchoolInfo(
        uint256 _schoolId,
        string memory _name,
        string memory _desc,
        string memory _logo
    ) public {
        require(schoolExists(_schoolId), "School does not exist");
        require(_hasPermission(_schoolId, msg.sender, UPDATE_INFO), "No permission to update info");
        School storage school = schools[_schoolId];
        // 如果名称变更，需要检查唯一性
        if (keccak256(bytes(school.name)) != keccak256(bytes(_name))) {
            require(schoolNameToId[_name] == 0, "School name already exists");
            // 删除旧名称映射
            delete schoolNameToId[school.name];
            // 添加新名称映射
            schoolNameToId[_name] = _schoolId;
        }
        school.name = _name;
        school.desc = _desc;
        school.logo = _logo;
        school.updatedAt = block.timestamp;
        emit SchoolInfoUpdated(_schoolId, msg.sender, _name);
    }
    
    // 获取学校基本信息
    function getSchoolInfo(uint256 _schoolId) public view returns (
        string memory name,
        string memory desc,
        string memory logo,
        address creator,
        uint256 createdAt,
        uint256 updatedAt,
        uint256 reputation,
        uint8 status
    ) {
        require(schoolExists(_schoolId), "School does not exist");
        School storage school = schools[_schoolId];
        
        return (
            school.name,
            school.desc,
            school.logo,
            school.creator,
            school.createdAt,
            school.updatedAt,
            school.reputation,
            uint8(school.status)
        );
    }
    
    // 获取学校状态原因
    function getSchoolStatusReason(uint256 _schoolId) public view returns (string memory) {
        require(schoolExists(_schoolId), "School does not exist");
        return schools[_schoolId].statusReason;
    }
    
    // 更新学校状态
    function updateSchoolStatus(uint256 _schoolId, SchoolStatus _status, string memory _reason) public {
        require(schoolExists(_schoolId), "School does not exist");
        School storage school = schools[_schoolId];
        
        // 检查权限：合约所有者、学校创建者或有权限的用户
        require(
            owner() == msg.sender || 
            school.creator == msg.sender || 
            _hasPermission(_schoolId, msg.sender, UPDATE_INFO),
            "No permission to update status"
        );
        
        school.status = _status;
        school.statusReason = _reason;
        school.updatedAt = block.timestamp;
        
        emit SchoolStatusUpdated(_schoolId, uint8(_status), _reason);
    }

    // ==================== 自定义字段管理 ====================
    
    // 添加或更新学校自定义字段
    function setSchoolCustomField(uint256 _schoolId, string memory _key, string memory _value) public {
        require(schoolExists(_schoolId), "School does not exist");
        require(_hasPermission(_schoolId, msg.sender, UPDATE_INFO), "No permission to update info");
        
        School storage school = schools[_schoolId];
        require(school.customFieldKeys.length < 100, "Too many custom fields");
        
        if (bytes(school.customFields[_key]).length == 0) {
            school.customFieldKeys.push(_key);
        }
        school.customFields[_key] = _value;
        school.updatedAt = block.timestamp;
        
        emit SchoolCustomFieldUpdated(_schoolId, _key, _value);
    }
    
    // 获取学校自定义字段值
    function getSchoolCustomField(uint256 _schoolId, string memory _key) public view returns (string memory) {
        require(schoolExists(_schoolId), "School does not exist");
        return schools[_schoolId].customFields[_key];
    }
    
    // 获取学校所有自定义字段键
    function getSchoolCustomFieldKeys(uint256 _schoolId) public view returns (string[] memory) {
        require(schoolExists(_schoolId), "School does not exist");
        return schools[_schoolId].customFieldKeys;
    }
    
    // 删除学校自定义字段
    function removeSchoolCustomField(uint256 _schoolId, string memory _key) public {
        require(schoolExists(_schoolId), "School does not exist");
        require(_hasPermission(_schoolId, msg.sender, UPDATE_INFO), "No permission to update info");
        
        School storage school = schools[_schoolId];
        require(bytes(school.customFields[_key]).length > 0, "Field not found");
        
        // 删除当前记录
        delete school.customFields[_key];
        for (uint i = 0; i < school.customFieldKeys.length; i++) {
            if (keccak256(bytes(school.customFieldKeys[i])) == keccak256(bytes(_key))) {
                school.customFieldKeys[i] = school.customFieldKeys[school.customFieldKeys.length - 1];
                school.customFieldKeys.pop();
                break;
            }
        }
        school.updatedAt = block.timestamp;
        
        emit SchoolCustomFieldRemoved(_schoolId, _key);
    }

    // ==================== 声誉管理 ====================
    
    // 更新学校声誉值
    function updateSchoolReputation(uint256 _schoolId, uint256 _value) public onlyOwner {
        require(schoolExists(_schoolId), "School does not exist");
        
        School storage school = schools[_schoolId];
        school.reputation = _value;
        school.updatedAt = block.timestamp;
        
        emit SchoolReputationUpdated(_schoolId, _value);
    }

    // ==================== 权限管理 ====================
    
    // 添加权限管理员
    function addPermissionAdmin(uint256 _schoolId, address _admin) public {
        require(schoolExists(_schoolId), "School does not exist");
        require(msg.sender == schools[_schoolId].creator, "Only creator can add permission admins");
        
        School storage school = schools[_schoolId];
        
        // 检查是否已经是管理员
        bool isAdmin = false;
        for (uint i = 0; i < school.permissionAdmins.length; i++) {
            if (school.permissionAdmins[i] == _admin) {
                isAdmin = true;
                break;
            }
        }
        
        if (!isAdmin) {
            school.permissionAdmins.push(_admin);
            emit PermissionAdminAdded(_schoolId, _admin);
        }
    }
    
    // 移除权限管理员
    function removePermissionAdmin(uint256 _schoolId, address _admin) public {
        require(schoolExists(_schoolId), "School does not exist");
        require(msg.sender == schools[_schoolId].creator, "Only creator can remove permission admins");
        require(_admin != schools[_schoolId].creator, "Cannot remove creator as admin");
        
        School storage school = schools[_schoolId];
        
        for (uint i = 0; i < school.permissionAdmins.length; i++) {
            if (school.permissionAdmins[i] == _admin) {
                school.permissionAdmins[i] = school.permissionAdmins[school.permissionAdmins.length - 1];
                school.permissionAdmins.pop();
                emit PermissionAdminRemoved(_schoolId, _admin);
                break;
            }
        }
    }
    
    // 获取所有权限管理员
    function getPermissionAdmins(uint256 _schoolId) public view returns (address[] memory) {
        require(schoolExists(_schoolId), "School does not exist");
        return schools[_schoolId].permissionAdmins;
    }
    
    // 检查用户是否有特定权限
    function hasPermission(uint256 _schoolId, address _user, uint32 _permission) public view returns (bool) {
        require(schoolExists(_schoolId), "School does not exist");
        return _hasPermission(_schoolId, _user, _permission);
    }

    // ==================== 学院管理 ====================
    
    // 设置最大学院数
    function setMaxColleges(uint256 _schoolId, uint256 _maxColleges) public {
        require(schoolExists(_schoolId), "School does not exist");
        require(msg.sender == schools[_schoolId].creator, "Only creator can set max colleges");
        
        schools[_schoolId].maxColleges = _maxColleges;
        schools[_schoolId].updatedAt = block.timestamp;
        
        emit MaxCollegesUpdated(_schoolId, _maxColleges);
    }
    
    // 获取最大学院数
    function getMaxColleges(uint256 _schoolId) public view returns (uint256) {
        require(schoolExists(_schoolId), "School does not exist");
        return schools[_schoolId].maxColleges;
    }

    // ==================== 查询功能 ====================
    
    // 获取用户创建的所有学校
    function getUserCreatedSchools(address _user) public view returns (uint256[] memory) {
        return userCreatedSchools[_user];
    }
    
    // 定义返回用的学校信息结构体
    struct SchoolInfo {
        uint256 schoolId;
        address creator;
        uint256 createdAt;
        uint256 updatedAt;
        string name;
        string desc;
        string logo;
        uint256 reputation;
        uint256 maxColleges;
        SchoolStatus status;
        string statusReason;
    }
    
    // 将学校数据转换为 SchoolInfo
    function _toSchoolInfo(School storage schoolData) internal view returns (SchoolInfo memory) {
        return SchoolInfo({
            schoolId: schoolData.schoolId,
            creator: schoolData.creator,
            createdAt: schoolData.createdAt,
            updatedAt: schoolData.updatedAt,
            name: schoolData.name,
            desc: schoolData.desc,
            logo: schoolData.logo,
            reputation: schoolData.reputation,
            maxColleges: schoolData.maxColleges,
            status: schoolData.status,
            statusReason: schoolData.statusReason
        });
    }

    // 分页获取学校列表
    function getSchoolsByPage(
        address _user,
        uint256 _page,
        uint256 _size,
        uint8 isNotDelete    // 0-未删除学校，1-已删除学校，2-所有学校
    ) public view returns (SchoolInfo[] memory schoolList) {
        require(_size > 0, "Page size must be greater than 0");
        
        // 权限检查：只有合约拥有者可以查询已删除和所有学校
        if (isNotDelete > 0) {
            if (owner() != msg.sender) {
                // 如果不是合约拥有者，强制查询未删除的学校
                isNotDelete = 0;
            }
        }

        uint256 total;
        uint256[] memory ids;
        
        if (_user != address(0)) {
            ids = userCreatedSchools[_user];
            total = ids.length;
        } else {
            total = totalSchools;
        }
        
        uint256 start = _page * _size;
        if (start >= total) return new SchoolInfo[](0);
        
        uint256 end = (start + _size) > total ? total : (start + _size);
        schoolList = new SchoolInfo[](end - start);
        
        if (_user != address(0)) {
            uint256 validCount = 0;
            for (uint256 i = 0; i < end - start; i++) {
                SchoolInfo memory info = _toSchoolInfo(schools[ids[start + i]]);
                // 根据删除状态筛选
                if ((isNotDelete == 0 && info.status != SchoolStatus.Closed) ||
                    (isNotDelete == 1 && info.status == SchoolStatus.Closed) ||
                    isNotDelete == 2) {
                    schoolList[validCount] = info;
                    validCount++;
                }
            }
            // 如果筛选后数量减少，调整数组大小
            if (validCount < schoolList.length) {
                assembly {
                    mstore(schoolList, validCount)
                }
            }
        } else {
            uint256 idx;
            uint256 validCount = 0;
            for (uint256 i = 1; i <= _schoolIdCounter.current() && validCount < schoolList.length; i++) {
                if (!schoolExists(i)) continue;
                SchoolInfo memory info = _toSchoolInfo(schools[i]);
                // 根据删除状态筛选
                if ((isNotDelete == 0 && info.status != SchoolStatus.Closed) ||
                    (isNotDelete == 1 && info.status == SchoolStatus.Closed) ||
                    isNotDelete == 2) {
                    if (idx >= start) {
                        schoolList[validCount] = info;
                        validCount++;
                    }
                    idx++;
                }
            }
            // 如果筛选后数量减少，调整数组大小
            if (validCount < schoolList.length) {
                assembly {
                    mstore(schoolList, validCount)
                }
            }
        }
        
        return schoolList;
    }

    // ==================== 辅助函数 ====================
    
    // 把这个辅助函数移到合约的前面
    // 检查学校是否存在
    function schoolExists(uint256 _schoolId) public view returns (bool) {
        return _schoolId > 0 && _schoolId <= _schoolIdCounter.current() && schools[_schoolId].createdAt > 0;
    }

    // 检查用户是否有特定权限
    function _hasPermission(uint256 _schoolId, address _user, uint32 _permission) internal view returns (bool) {
        // 创建者拥有所有权限
        if (_user == schools[_schoolId].creator) {
            return true;
        }
        
        // 从 SchoolTeacher 合约获取权限
        uint32 userPerms = schoolTeacher.getTeacherPermissions(_schoolId, _user);
        return (userPerms & _permission) == _permission;
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ==================== 事件 ====================
    event SchoolCreated(uint256 indexed schoolId, address indexed creator, string name);
    event SchoolInfoUpdated(uint256 indexed schoolId, address indexed updater, string name);
    event SchoolStatusUpdated(uint256 indexed schoolId, uint8 status, string reason);
    event SchoolCustomFieldUpdated(uint256 indexed schoolId, string key, string value);
    event SchoolCustomFieldRemoved(uint256 indexed schoolId, string key);
    event SchoolReputationUpdated(uint256 indexed schoolId, uint256 value);
    event PermissionAdminAdded(uint256 indexed schoolId, address indexed admin);
    event PermissionAdminRemoved(uint256 indexed schoolId, address indexed admin);
    event MaxCollegesUpdated(uint256 indexed schoolId, uint256 maxColleges);
}