// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./SchoolV1.sol";

contract SchoolCustomFieldV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 学校合约地址
    SchoolV1 public school;
    
    // 学校ID => 自定义字段映射
    mapping(uint256 => mapping(string => string)) private customFields;
    
    // 学校ID => 自定义字段键数组
    mapping(uint256 => string[]) private customFieldKeys;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }
    
    // 设置学校合约地址
    function setSchool(address _schoolAddress) public onlyOwner {
        require(_schoolAddress != address(0), "Invalid address");
        school = SchoolV1(_schoolAddress);
        emit SchoolUpdated(_schoolAddress);
    }
    
    // 添加或更新学校自定义字段
    function setSchoolCustomField(uint256 _schoolId, string memory _key, string memory _value) public {
        require(school.schoolExists(_schoolId), "School does not exist");
        require(school.hasPermission(_schoolId, msg.sender, 0x4), "No permission to update info");
        
        require(customFieldKeys[_schoolId].length < 100, "Too many custom fields");
        
        if (bytes(customFields[_schoolId][_key]).length == 0) {
            customFieldKeys[_schoolId].push(_key);
        }
        customFields[_schoolId][_key] = _value;
        
        emit SchoolCustomFieldUpdated(_schoolId, _key, _value);
    }
    
    // 获取学校自定义字段值
    function getSchoolCustomField(uint256 _schoolId, string memory _key) public view returns (string memory) {
        require(school.schoolExists(_schoolId), "School does not exist");
        return customFields[_schoolId][_key];
    }
    
    // 获取学校所有自定义字段键
    function getSchoolCustomFieldKeys(uint256 _schoolId) public view returns (string[] memory) {
        require(school.schoolExists(_schoolId), "School does not exist");
        return customFieldKeys[_schoolId];
    }
    
    // 删除学校自定义字段
    function removeSchoolCustomField(uint256 _schoolId, string memory _key) public {
        require(school.schoolExists(_schoolId), "School does not exist");
        require(school.hasPermission(_schoolId, msg.sender, 0x4), "No permission to update info");
        
        require(bytes(customFields[_schoolId][_key]).length > 0, "Field not found");
        
        // 删除当前记录
        delete customFields[_schoolId][_key];
        for (uint i = 0; i < customFieldKeys[_schoolId].length; i++) {
            if (keccak256(bytes(customFieldKeys[_schoolId][i])) == keccak256(bytes(_key))) {
                customFieldKeys[_schoolId][i] = customFieldKeys[_schoolId][customFieldKeys[_schoolId].length - 1];
                customFieldKeys[_schoolId].pop();
                break;
            }
        }
        
        emit SchoolCustomFieldRemoved(_schoolId, _key);
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // 事件
    event SchoolUpdated(address indexed newSchoolContract);
    event SchoolCustomFieldUpdated(uint256 indexed schoolId, string key, string value);
    event SchoolCustomFieldRemoved(uint256 indexed schoolId, string key);
}