// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./SchoolV1.sol";
import "./CollegeV1.sol";

contract CollegeDAOV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 学校合约地址
    SchoolV1 public school;
    
    // 学院合约地址
    CollegeV1 public college;
    
    // 学院DAO结构
    struct CollegeDAO {
        mapping(string => string) daoMap;  // DAO提案map
        string[] daoKeys;                  // DAO提案键列表
    }
    
    // 学院ID => 学院DAO信息
    mapping(uint256 => CollegeDAO) private collegeDAOs;

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

    function setCollege(address _collegeAddress) public onlyOwner {
        require(_collegeAddress != address(0), "Invalid address");
        college = CollegeV1(_collegeAddress);
        emit CollegeUpdated(_collegeAddress);
    }

    event CollegeUpdated(address indexed newCollegeContract);
    
    // ==================== DAO管理 ====================
    
    // 添加或更新DAO提案
    function setCollegeDAO(uint256 _collegeId, string memory _key, string memory _value) public {
        require(college.collegeExists(_collegeId), "College does not exist");
        (,,,uint256 schoolId,,,,,) = college.getCollegeInfo(_collegeId);
        require(school.hasPermission(schoolId, msg.sender, 0x20), "No permission for DAO operations");
        
        CollegeDAO storage dao = collegeDAOs[_collegeId];
        if (bytes(dao.daoMap[_key]).length == 0) {
            dao.daoKeys.push(_key);
        }
        dao.daoMap[_key] = _value;
        
        emit CollegeDAOUpdated(_collegeId, _key, _value);
    }
    
    // 获取DAO提案值
    function getCollegeDAO(uint256 _collegeId, string memory _key) public view returns (string memory) {
        require(college.collegeExists(_collegeId), "College does not exist");
        return collegeDAOs[_collegeId].daoMap[_key];
    }
    
    // 获取所有DAO提案键
    function getCollegeDAOKeys(uint256 _collegeId) public view returns (string[] memory) {
        require(college.collegeExists(_collegeId), "College does not exist");
        return collegeDAOs[_collegeId].daoKeys;
    }
    
    // 删除DAO提案
    function removeCollegeDAO(uint256 _collegeId, string memory _key) public {
        require(college.collegeExists(_collegeId), "College does not exist");
        (,,,uint256 schoolId,,,,,) = college.getCollegeInfo(_collegeId);
        require(school.hasPermission(schoolId, msg.sender, 0x20), "No permission for DAO operations");
        
        CollegeDAO storage dao = collegeDAOs[_collegeId];
        require(bytes(dao.daoMap[_key]).length > 0, "DAO key not found");
        
        delete dao.daoMap[_key];
        for (uint i = 0; i < dao.daoKeys.length; i++) {
            if (keccak256(bytes(dao.daoKeys[i])) == keccak256(bytes(_key))) {
                dao.daoKeys[i] = dao.daoKeys[dao.daoKeys.length - 1];
                dao.daoKeys.pop();
                break;
            }
        }
        
        emit CollegeDAORemoved(_collegeId, _key);
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ==================== 事件 ====================
    event CollegeDAOUpdated(uint256 indexed collegeId, string key, string value);
    event CollegeDAORemoved(uint256 indexed collegeId, string key);
}