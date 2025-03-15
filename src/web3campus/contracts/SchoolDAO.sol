// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./SchoolV1.sol";

contract SchoolDAO is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 提案状态枚举
    enum ProposalStatus {
        Pending,
        Approved,
        Rejected
    }
    
    // 提案日志结构
    struct ProposalLog {
        bytes32 proposalHash;
        uint256 timestamp;
        address proposer;
        string description;
        ProposalStatus status;
    }
    
    // 学校提案结构
    struct SchoolProposals {
        mapping(bytes32 => ProposalStatus) proposalMapping;
        ProposalLog[] proposalHistory;
    }
    
    // 学校ID => 提案信息
    mapping(uint256 => SchoolProposals) private schoolProposals;
    
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
    
    // 提交提案
    function submitProposal(uint256 _schoolId, string memory _description, bytes32 _proposalHash) public {
        require(school.schoolExists(_schoolId), "School does not exist");
        require(school.hasPermission(_schoolId, msg.sender, 0x10), "No permission to submit proposals");
        require(schoolProposals[_schoolId].proposalMapping[_proposalHash] == ProposalStatus.Pending, "Proposal already exists");
        
        SchoolProposals storage proposals = schoolProposals[_schoolId];
        
        // 创建提案
        proposals.proposalMapping[_proposalHash] = ProposalStatus.Pending;
        
        // 记录提案历史
        ProposalLog memory log = ProposalLog({
            proposalHash: _proposalHash,
            timestamp: block.timestamp,
            proposer: msg.sender,
            description: _description,
            status: ProposalStatus.Pending
        });
        proposals.proposalHistory.push(log);
        
        emit ProposalSubmitted(_schoolId, msg.sender, _proposalHash, _description);
    }
    
    // 投票处理提案
    function voteOnProposal(uint256 _schoolId, bytes32 _proposalHash, bool _approve) public {
        require(school.schoolExists(_schoolId), "School does not exist");
        require(school.hasPermission(_schoolId, msg.sender, 0x20), "No permission to vote");
        
        SchoolProposals storage proposals = schoolProposals[_schoolId];
        require(proposals.proposalMapping[_proposalHash] == ProposalStatus.Pending, "Proposal is not pending");
        
        // 更新提案状态
        ProposalStatus newStatus = _approve ? ProposalStatus.Approved : ProposalStatus.Rejected;
        proposals.proposalMapping[_proposalHash] = newStatus;
        
        // 更新提案历史
        for (uint i = 0; i < proposals.proposalHistory.length; i++) {
            if (proposals.proposalHistory[i].proposalHash == _proposalHash) {
                proposals.proposalHistory[i].status = newStatus;
                break;
            }
        }
        
        emit ProposalVoted(_schoolId, msg.sender, _proposalHash, _approve);
    }
    
    // 获取提案状态
    function getProposalStatus(uint256 _schoolId, bytes32 _proposalHash) public view returns (uint8) {
        require(school.schoolExists(_schoolId), "School does not exist");
        return uint8(schoolProposals[_schoolId].proposalMapping[_proposalHash]);
    }
    
    // 获取提案历史
    function getProposalHistory(uint256 _schoolId) public view returns (
        bytes32[] memory proposalHashes,
        uint256[] memory timestamps,
        address[] memory proposers,
        string[] memory descriptions,
        uint8[] memory statuses
    ) {
        require(school.schoolExists(_schoolId), "School does not exist");
        
        ProposalLog[] storage logs = schoolProposals[_schoolId].proposalHistory;
        uint256 logsCount = logs.length;
        
        proposalHashes = new bytes32[](logsCount);
        timestamps = new uint256[](logsCount);
        proposers = new address[](logsCount);
        descriptions = new string[](logsCount);
        statuses = new uint8[](logsCount);
        
        for (uint i = 0; i < logsCount; i++) {
            proposalHashes[i] = logs[i].proposalHash;
            timestamps[i] = logs[i].timestamp;
            proposers[i] = logs[i].proposer;
            descriptions[i] = logs[i].description;
            statuses[i] = uint8(logs[i].status);
        }
        
        return (proposalHashes, timestamps, proposers, descriptions, statuses);
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ==================== 事件 ====================
    event ProposalSubmitted(uint256 indexed schoolId, address indexed proposer, bytes32 proposalHash, string description);
    event ProposalVoted(uint256 indexed schoolId, address indexed voter, bytes32 proposalHash, bool approved);
}