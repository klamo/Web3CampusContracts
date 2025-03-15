// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./SchoolV1.sol";

contract SchoolFundsV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 资金池结构
    struct FundPool {
        uint256 totalDeposits;
        uint256 lockedFunds;
        mapping(address => uint256[]) withdrawHistory;
    }
    
    // 学校ID => 资金池
    mapping(uint256 => FundPool) private fundPools;
    
    // SchoolV1 合约地址
    SchoolV1 public school;
    
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
    
    // 向学校资金池存款
    function depositToSchool(uint256 _schoolId) public payable {
        require(school.schoolExists(_schoolId), "School does not exist");
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        // 获取学校信息并检查状态
        (,,,,,,,uint8 status) = school.getSchoolInfo(_schoolId);
        require(status == 0, "School is not active");
        
        fundPools[_schoolId].totalDeposits += msg.value;
        
        emit FundsDeposited(_schoolId, msg.sender, msg.value);
    }
    
    // 从学校资金池提款
    function withdrawFromSchool(uint256 _schoolId, uint256 _amount) public {
        require(school.schoolExists(_schoolId), "School does not exist");
        require(_amount > 0, "Withdraw amount must be greater than 0");
        
        // 获取学校信息并检查创建者
        (,,,address creator,,,,) = school.getSchoolInfo(_schoolId);
        require(msg.sender == creator, "Only school creator can withdraw funds");
        
        FundPool storage fundPool = fundPools[_schoolId];
        uint256 availableFunds = fundPool.totalDeposits - fundPool.lockedFunds;
        require(availableFunds >= _amount, "Insufficient available funds");
        
        // 更新资金池
        fundPool.totalDeposits -= _amount;
        
        // 记录提款历史
        fundPool.withdrawHistory[msg.sender].push(_amount);
        
        // 转账
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transfer failed");
        
        emit FundsWithdrawn(_schoolId, msg.sender, _amount);
    }
    
    // 锁定资金
    function lockFunds(uint256 _schoolId, uint256 _amount) public {
        require(school.schoolExists(_schoolId), "School does not exist");
        require(school.hasPermission(_schoolId, msg.sender, 0x2), "No permission to manage funds");
        
        FundPool storage fundPool = fundPools[_schoolId];
        require(fundPool.totalDeposits - fundPool.lockedFunds >= _amount, "Insufficient available funds");
        
        fundPool.lockedFunds += _amount;
        
        emit FundsLocked(_schoolId, msg.sender, _amount);
    }
    
    // 解锁资金
    function unlockFunds(uint256 _schoolId, uint256 _amount) public {
        require(school.schoolExists(_schoolId), "School does not exist");
        require(school.hasPermission(_schoolId, msg.sender, 0x2), "No permission to manage funds");
        
        FundPool storage fundPool = fundPools[_schoolId];
        require(fundPool.lockedFunds >= _amount, "Insufficient locked funds");
        
        fundPool.lockedFunds -= _amount;
        
        emit FundsUnlocked(_schoolId, msg.sender, _amount);
    }
    
    // 获取资金池信息
    function getFundPoolInfo(uint256 _schoolId) public view returns (
        uint256 totalDeposits,
        uint256 lockedFunds,
        uint256 availableFunds
    ) {
        require(school.schoolExists(_schoolId), "School does not exist");
        
        FundPool storage fundPool = fundPools[_schoolId];
        totalDeposits = fundPool.totalDeposits;
        lockedFunds = fundPool.lockedFunds;
        availableFunds = totalDeposits - lockedFunds;
        
        return (totalDeposits, lockedFunds, availableFunds);
    }
    
    // 获取提款历史
    function getWithdrawHistory(uint256 _schoolId, address _user) public view returns (uint256[] memory) {
        require(school.schoolExists(_schoolId), "School does not exist");
        return fundPools[_schoolId].withdrawHistory[_user];
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ==================== 事件 ====================
    event FundsDeposited(uint256 indexed schoolId, address indexed depositor, uint256 amount);
    event FundsWithdrawn(uint256 indexed schoolId, address indexed withdrawer, uint256 amount);
    event FundsLocked(uint256 indexed schoolId, address indexed locker, uint256 amount);
    event FundsUnlocked(uint256 indexed schoolId, address indexed unlocker, uint256 amount);
}