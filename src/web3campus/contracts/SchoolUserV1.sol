// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "web3common/contracts/CommonUserV3.sol";

contract SchoolUserV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 学校用户信息结构体
    struct SchoolUserInfo {
        // 用户注册时间
        uint256 registerTime;
        // 作为教师的初始时间
        uint256 isTeacherTime;
        // 声誉值 (类型 => 值) 0-在学校中作为老师的声誉;1-学校中作为学生的声誉
        mapping(uint8 => uint256) reputation;
        // 用户自定义字段
        mapping(string => string) customFields;
        // 用户自定义字段key
        string[] customFieldKeys;
    }

    // 公共用户合约地址
    CommonUserV3 public commonUser;
    
    // 用户地址 => 学校用户信息
    mapping(address => SchoolUserInfo) private schoolUsers;
    
    // 已注册学校用户数量
    uint256 public schoolUserCount;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    // 添加设置 commonUser 的函数
    function setCommonUser(address _commonUserAddress) public onlyOwner {
        require(_commonUserAddress != address(0), "Invalid address");
        commonUser = CommonUserV3(_commonUserAddress);
        emit CommonUserUpdated(_commonUserAddress);
    }

    // 在事件部分添加新事件
    event CommonUserUpdated(address indexed newCommonUserContract);

    // ==================== 用户管理 ====================

    // 注册学校用户
    function register() public {
        require(commonUser.isRegistered(msg.sender), "User not registered in CommonUser");
        require(!isRegistered(msg.sender), "School user already registered");
        
        SchoolUserInfo storage newUser = schoolUsers[msg.sender];
        newUser.registerTime = block.timestamp;
        newUser.isTeacherTime = 0;
        newUser.customFieldKeys = new string[](0);
        
        schoolUserCount++;
        
        emit SchoolUserRegistered(msg.sender);
    }

    // 检查用户是否已注册
    function isRegistered(address _user) public view returns (bool) {
        // 使用注册时间来判断用户是否已注册
        return schoolUsers[_user].registerTime > 0;
    }

    // ==================== 教师管理 ====================

    // 设置用户为教师
    function setAsTeacher(address _user) public {
        require(isRegistered(_user), "User not registered");
        
        // 如果用户之前不是教师，设置初始时间
        if (schoolUsers[_user].isTeacherTime == 0) {
            schoolUsers[_user].isTeacherTime = block.timestamp;
            emit TeacherStatusUpdated(_user, true);
        }
    }

    // 检查用户是否为教师
    function isTeacher(address _user) public view returns (bool) {
        return schoolUsers[_user].isTeacherTime > 0;
    }

    // 获取用户成为教师的时间
    function getTeacherTime(address _user) public view returns (uint256) {
        return schoolUsers[_user].isTeacherTime;
    }

    // ==================== 声誉管理 ====================

    // 更新用户声誉值
    function updateReputation(address _user, uint8 _type, uint256 _value) public {
        
        // 检查权限：如果是教师声誉，需要检查用户是否为教师
        if (_type == 0) {
            require(isTeacher(_user), "User is not a teacher");
        }
        
        bool authorized = msg.sender == owner();
        
        require(authorized, "Not authorized");
        
        schoolUsers[_user].reputation[_type] = _value;
        
        emit ReputationUpdated(_user, _type, _value);
    }

    // 获取用户声誉值
    function getReputation(address _user, uint8 _type) public view returns (uint256) {
        require(_type <= 1, "Invalid reputation type");
        return schoolUsers[_user].reputation[_type];
    }

    // ==================== 自定义字段管理 ====================

    // 添加或更新自定义字段
    function setCustomField(string memory _key, string memory _value) public {
        require(isRegistered(msg.sender), "User not registered");
        require(schoolUsers[msg.sender].customFieldKeys.length < 100, "Too many custom fields");
        
        SchoolUserInfo storage user = schoolUsers[msg.sender];
        if (bytes(user.customFields[_key]).length == 0) {
            user.customFieldKeys.push(_key);
        }
        user.customFields[_key] = _value;
        
        emit CustomFieldUpdated(msg.sender, _key, _value);
    }

    // 获取用户自定义字段值
    function getCustomField(address _user, string memory _key) public view returns (string memory) {
        return schoolUsers[_user].customFields[_key];
    }

    // 获取用户所有自定义字段键
    function getCustomFieldKeys(address _user) public view returns (string[] memory) {
        return schoolUsers[_user].customFieldKeys;
    }

    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 删除自定义字段
    function removeCustomField(string memory _key) public {
        require(isRegistered(msg.sender), "User not registered");
        SchoolUserInfo storage user = schoolUsers[msg.sender];
        require(bytes(user.customFields[_key]).length > 0, "Field not found");

        // 删除当前记录
        delete user.customFields[_key];
        for (uint i = 0; i < user.customFieldKeys.length; i++) {
            if (keccak256(bytes(user.customFieldKeys[i])) == keccak256(bytes(_key))) {
                user.customFieldKeys[i] = user.customFieldKeys[user.customFieldKeys.length - 1];
                user.customFieldKeys.pop();
                break;
            }
        }
        emit CustomFieldRemoved(msg.sender, _key);
    }

        // ==================== 事件 ====================
    event SchoolUserRegistered(address indexed user);
    event TeacherStatusUpdated(address indexed user, bool isTeacher);
    event ReputationUpdated(address indexed user, uint8 reputationType, uint256 value);
    event CustomFieldUpdated(address indexed user, string key, string value);
    event CustomFieldRemoved(address indexed user, string key);

    // 获取用户完整信息
    function getUserInfo(address _user) public view returns (
        // SchoolUser信息
        bool isSchoolRegistered,
        uint256 registerTime,
        uint256 isTeacherTime,
        uint256 teacherReputation,
        uint256 studentReputation,
        string[] memory schoolCustomFieldKeys,
        // CommonUser信息
        bool isCommonRegistered,
        string memory username,
        string memory avatar,
        address wallet,
        string[] memory commonCustomFieldKeys,
        bytes10 geohash,
        bytes4 timeZone
    ) {
        // 获取学校用户信息
        isSchoolRegistered = isRegistered(_user);
        if (isSchoolRegistered) {
            SchoolUserInfo storage user = schoolUsers[_user];
            registerTime = user.registerTime;
            isTeacherTime = user.isTeacherTime;
            teacherReputation = user.reputation[0];
            studentReputation = user.reputation[1];
            schoolCustomFieldKeys = user.customFieldKeys;
        }
        
        // 获取公共用户信息
        isCommonRegistered = commonUser.isRegistered(_user);
        if (isCommonRegistered) {
            CommonUserV3.UserBasicInfo memory basicInfo = commonUser.getUserInfo(_user);
            username = basicInfo.username;
            avatar = basicInfo.avatar;
            wallet = basicInfo.wallet;
            commonCustomFieldKeys = basicInfo.customFieldKeys;
            geohash = basicInfo.geohash;
            timeZone = basicInfo.timeZone;
        }
    }
}