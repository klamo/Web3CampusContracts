// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract CommonUserV3 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 用户信息结构体
    struct UserInfo {
        // 身份系统
        string username;
        string avatar;
        address wallet;
        mapping(string => string) customFields;
        string[] customFieldKeys;
        
        // 动态属性模块 - 系统预设字段
        bytes10 geohash;
        bytes4 timeZone;
        
        // 声誉引擎 - 领域声誉值
        uint256 educationRep;
        uint256 workRep;
        uint256 communityRep;
        
        // 声誉引擎 - 声誉证明
        mapping(address => bytes32) thirdPartyAttestations;
        
        // 用户创建的内容
        uint256[] createdSchools;
        uint256[] createdCourses;
        
    }

    // 用户地址 => 用户信息
    mapping(address => UserInfo) private users;
    
    // 已注册用户数量
    uint256 public userCount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    // ==================== 用户身份管理 ====================

    // 注册新用户
    function register(string memory _username, string memory _avatar) public {
        require(bytes(users[msg.sender].username).length == 0, "User already registered");
        
        UserInfo storage newUser = users[msg.sender];
        newUser.username = _username;
        newUser.avatar = _avatar;
        newUser.wallet = msg.sender;
        userCount++;
        
        emit UserRegistered(msg.sender, _username);
    }

    // 更新用户名
    function updateUsername(string memory _newUsername) public {
        require(bytes(users[msg.sender].username).length > 0, "User not registered");
        users[msg.sender].username = _newUsername;
        
        emit UsernameUpdated(msg.sender, _newUsername);
    }

    // 更新头像
    function updateAvatar(string memory _newAvatar) public {
        require(bytes(users[msg.sender].username).length > 0, "User not registered");
        users[msg.sender].avatar = _newAvatar;
        
        emit AvatarUpdated(msg.sender, _newAvatar);
    }

    // 添加或更新自定义字段
    function setCustomField(string memory _key, string memory _value) public {
        require(bytes(users[msg.sender].username).length > 0, "User not registered");
        require(users[msg.sender].customFieldKeys.length < 100, "Too many custom fields");
        
        UserInfo storage user = users[msg.sender];
        if (bytes(user.customFields[_key]).length == 0) {
            user.customFieldKeys.push(_key);
        }
        user.customFields[_key] = _value;
        
        emit CustomFieldUpdated(msg.sender, _key, _value);
    }

    // 用户基本信息结构体
    struct UserBasicInfo {
        string username;
        string avatar;
        address wallet;
        string[] customFieldKeys;
        bytes10 geohash;
        bytes4 timeZone;
    }

    // 获取用户信息
    function getUserInfo(address _user) public view returns (UserBasicInfo memory) {
        return UserBasicInfo({
            username: users[_user].username,
            avatar: users[_user].avatar,
            wallet: users[_user].wallet,
            customFieldKeys: users[_user].customFieldKeys,
            geohash: users[_user].geohash,
            timeZone: users[_user].timeZone
        });
    }

    // 批量获取用户信息
    function getUserInfoBatch(address[] memory _users) public view returns (UserBasicInfo[] memory) {
        UserBasicInfo[] memory result = new UserBasicInfo[](_users.length);
        for(uint i = 0; i < _users.length; i++) {
            result[i] = getUserInfo(_users[i]);
        }
        return result;
    }

    // 获取用户自定义字段值
    function getCustomField(address _user, string memory _key) public view returns (string memory) {
        return users[_user].customFields[_key];
    }

    // 检查用户是否已注册
    function isRegistered(address _user) public view returns (bool) {
        return bytes(users[_user].username).length > 0;
    }
    
    // ==================== 动态属性模块 - 系统预设字段 ====================
    
    // 更新地理位置信息和时区
    function updateGeoData(bytes10 _geohash, bytes4 _timeZone) public {
        require(bytes(users[msg.sender].username).length > 0, "User not registered");
        
        users[msg.sender].geohash = _geohash;
        users[msg.sender].timeZone = _timeZone;
        
        emit GeoDataUpdated(msg.sender, _geohash, _timeZone);
    }
    
    // 获取地理位置信息和时区
    function getGeoData(address _user) public view returns (bytes10 geohash, bytes4 timeZone) {
        return (users[_user].geohash, users[_user].timeZone);
    }
    
    // ==================== 声誉引擎 - 领域声誉值 ====================
    
    // 获取声誉值
    function getReputationScores(address _user) public view returns (
        uint256 educationRep,
        uint256 workRep,
        uint256 communityRep
    ) {
        return (
            users[_user].educationRep,
            users[_user].workRep,
            users[_user].communityRep
        );
    }
    
    // 更新声誉值（仅限所有者）
    function updateReputationScores(
        address _user,
        uint256 _educationRep,
        uint256 _workRep,
        uint256 _communityRep
    ) public onlyOwner {
        require(bytes(users[_user].username).length > 0, "User not registered");
        
        users[_user].educationRep = _educationRep;
        users[_user].workRep = _workRep;
        users[_user].communityRep = _communityRep;
        
        emit ReputationUpdated(_user, _educationRep, _workRep, _communityRep);
    }
    
    // ==================== 声誉引擎 - 声誉证明 ====================
    
    // 添加第三方证明
    function addAttestation(address _user, bytes32 _attestation) public {
        require(bytes(users[_user].username).length > 0, "User not registered");
        
        users[_user].thirdPartyAttestations[msg.sender] = _attestation;
        
        emit AttestationAdded(_user, msg.sender, _attestation);
    }
    
    // 获取第三方证明
    function getAttestation(address _user, address _attestor) public view returns (bytes32) {
        return users[_user].thirdPartyAttestations[_attestor];
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ==================== 事件 ====================
    event UserRegistered(address indexed user, string username);
    event UsernameUpdated(address indexed user, string newUsername);
    event AvatarUpdated(address indexed user, string newAvatar);
    event CustomFieldUpdated(address indexed user, string key, string value);
    event GeoDataUpdated(address indexed user, bytes10 geohash, bytes4 timeZone);
    event ReputationUpdated(address indexed user, uint256 educationRep, uint256 workRep, uint256 communityRep);
    event AttestationAdded(address indexed user, address indexed attestor, bytes32 attestation);
}