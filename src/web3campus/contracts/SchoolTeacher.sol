// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./SchoolUserV1.sol";
import "./SchoolV1.sol";  // 添加这行导入语句
import "@openzeppelin/contracts/utils/Strings.sol";

contract SchoolTeacher is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 学校用户合约地址
    SchoolUserV1 public schoolUser;

    // 公共用户合约地址
    CommonUserV3 public commonUser;
    
    // 权限日志结构
    struct PermissionLog {
        uint256 timestamp;
        address operator;
        uint32 oldPerms;
        uint32 newPerms;
    }
    
    // 教师信息结构
    struct TeacherInfo {
        address[] teacherIds;
        mapping(address => uint32) userPermissions;
        mapping(address => PermissionLog[]) permissionLogs;
    }
    
    // 学校ID => 教师信息
    mapping(uint256 => TeacherInfo) private teacherInfos;
    
    // 用户地址 => 作为教师的学校ID数组
    mapping(address => uint256[]) private userTeacherSchools;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // 添加 SchoolV1 合约引用
    SchoolV1 public school;
    
    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }
    
    // 添加设置 schoolUser 的函数
    function setSchoolUser(address _schoolUserAddress) public onlyOwner {
        require(_schoolUserAddress != address(0), "Invalid address");
        schoolUser = SchoolUserV1(_schoolUserAddress);
        emit SchoolUserUpdated(_schoolUserAddress);
    }
    
    // 添加设置 school 的函数
    function setSchool(address _schoolAddress) public onlyOwner {
        require(_schoolAddress != address(0), "Invalid address");
        school = SchoolV1(_schoolAddress);
        emit SchoolUpdated(_schoolAddress);
    }

    // 添加设置 commonUser 的函数
    function setCommonUser(address _commonUserAddress) public onlyOwner {
        require(_commonUserAddress != address(0), "Invalid address");
        commonUser = CommonUserV3(_commonUserAddress);
        emit CommonUserUpdated(_commonUserAddress);
    }

    // 在事件部分添加新事件
    event CommonUserUpdated(address indexed newCommonUserContract);

    // 在事件部分添加新事件
    event SchoolUserUpdated(address indexed newUserContract);
    event SchoolUpdated(address indexed newSchoolContract);
    
    // 在每个教师相关函数中添加学校存在性检查
    // 修改 modifier 使用 public 函数
    modifier schoolExists(uint256 _schoolId) {
        require(school.schoolExists(_schoolId), "School does not exist");
        _;
    }
    
    // 修改所有函数添加 schoolExists 修饰符
    function addTeacher(uint256 _schoolId, address _teacher, uint32 _permissions) 
        public 
        schoolExists(_schoolId) 
    {
        require(schoolUser.isRegistered(_teacher), "Teacher not registered");
        
        TeacherInfo storage info = teacherInfos[_schoolId];
        
        // 检查教师是否已存在
        bool teacherExists = false;
        for (uint i = 0; i < info.teacherIds.length; i++) {
            if (info.teacherIds[i] == _teacher) {
                teacherExists = true;
                break;
            }
        }
        
        if (!teacherExists) {
            info.teacherIds.push(_teacher);
            userTeacherSchools[_teacher].push(_schoolId);
            
            // 如果用户之前不是教师，更新 SchoolUserV1 中的 isTeacherTime
            if (schoolUser.getTeacherTime(_teacher) == 0) {
                // 调用 SchoolUserV1 合约的 setAsTeacher 方法
                // 注意：这里假设 SchoolTeacher 合约有权限调用 setAsTeacher
                // 如果没有权限，需要修改 SchoolUserV1 合约的权限设置
                schoolUser.setAsTeacher(_teacher);
            }
        }
        
        // 更新权限
        uint32 oldPerms = info.userPermissions[_teacher];
        info.userPermissions[_teacher] = _permissions;
        
        // 记录权限日志
        PermissionLog memory log = PermissionLog({
            timestamp: block.timestamp,
            operator: msg.sender,
            oldPerms: oldPerms,
            newPerms: _permissions
        });
        info.permissionLogs[_teacher].push(log);
        
        emit TeacherAdded(_schoolId, _teacher, _permissions);
    }
    
    // 移除教师
    function removeTeacher(uint256 _schoolId, address _teacher) public {
        TeacherInfo storage info = teacherInfos[_schoolId];
        
        // 从教师列表中移除
        for (uint i = 0; i < info.teacherIds.length; i++) {
            if (info.teacherIds[i] == _teacher) {
                info.teacherIds[i] = info.teacherIds[info.teacherIds.length - 1];
                info.teacherIds.pop();
                break;
            }
        }
        
        // 从用户的教师学校列表中移除
        for (uint i = 0; i < userTeacherSchools[_teacher].length; i++) {
            if (userTeacherSchools[_teacher][i] == _schoolId) {
                userTeacherSchools[_teacher][i] = userTeacherSchools[_teacher][userTeacherSchools[_teacher].length - 1];
                userTeacherSchools[_teacher].pop();
                break;
            }
        }
        
        // 记录权限日志
        uint32 oldPerms = info.userPermissions[_teacher];
        PermissionLog memory log = PermissionLog({
            timestamp: block.timestamp,
            operator: msg.sender,
            oldPerms: oldPerms,
            newPerms: 0
        });
        info.permissionLogs[_teacher].push(log);
        
        // 清除权限
        delete info.userPermissions[_teacher];
        
        emit TeacherRemoved(_schoolId, _teacher);
    }
    
    // 获取学校所有教师
    function getSchoolTeachers(uint256 _schoolId) public view returns (address[] memory) {
        return teacherInfos[_schoolId].teacherIds;
    }
    
    // 获取教师权限
    function getTeacherPermissions(uint256 _schoolId, address _teacher) public view returns (uint32) {
        return teacherInfos[_schoolId].userPermissions[_teacher];
    }
    
    // 获取教师权限日志
    function getTeacherPermissionLogs(uint256 _schoolId, address _teacher) public view returns (
        uint256[] memory timestamps,
        address[] memory operators,
        uint32[] memory oldPerms,
        uint32[] memory newPerms
    ) {
        PermissionLog[] storage logs = teacherInfos[_schoolId].permissionLogs[_teacher];
        uint256 logsCount = logs.length;
        
        timestamps = new uint256[](logsCount);
        operators = new address[](logsCount);
        oldPerms = new uint32[](logsCount);
        newPerms = new uint32[](logsCount);
        
        for (uint i = 0; i < logsCount; i++) {
            timestamps[i] = logs[i].timestamp;
            operators[i] = logs[i].operator;
            oldPerms[i] = logs[i].oldPerms;
            newPerms[i] = logs[i].newPerms;
        }
        
        return (timestamps, operators, oldPerms, newPerms);
    }
    
    // 获取用户作为教师的所有学校
    function getUserTeacherSchools(address _user) public view returns (uint256[] memory) {
        return userTeacherSchools[_user];
    }

    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 事件
    event TeacherAdded(uint256 indexed schoolId, address indexed teacher, uint32 permissions);
    event TeacherRemoved(uint256 indexed schoolId, address indexed teacher);
    
    // 教师申请状态枚举
    enum ApplicationStatus {
        Pending,    // 待审核
        Approved,   // 已通过
        Rejected    // 已拒绝
    }
    
    // 教师申请结构
    struct TeacherApplication {
        address teacher;            // 教师地址
        uint256 timestamp;          // 申请时间
        string reason;              // 申请理由
        ApplicationStatus status;   // 申请状态
        address reviewer;           // 审核人
        uint256 reviewTime;         // 审核时间
        string reviewComment;       // 审核意见
    }
    
    // 学校ID => 教师申请列表
    mapping(uint256 => TeacherApplication[]) private schoolTeacherApplications;
    
    // 学校ID => 教师地址 => 是否有待处理的申请
    mapping(uint256 => mapping(address => bool)) private hasPendingApplication;
    
    // 1. 老师申请加入学校
    function applyToSchool(uint256 _schoolId, string memory _reason) 
        public 
        schoolExists(_schoolId) 
    {
        require(schoolUser.isRegistered(msg.sender), "User not registered");
        require(!hasPendingApplication[_schoolId][msg.sender], "Already has pending application");
        
        // 检查是否已经是该学校的教师
        TeacherInfo storage info = teacherInfos[_schoolId];
        for (uint i = 0; i < info.teacherIds.length; i++) {
            if (info.teacherIds[i] == msg.sender) {
                revert("Already a teacher in this school");
            }
        }
        
        // 创建新申请
        TeacherApplication memory application = TeacherApplication({
            teacher: msg.sender,
            timestamp: block.timestamp,
            reason: _reason,
            status: ApplicationStatus.Pending,
            reviewer: address(0),
            reviewTime: 0,
            reviewComment: ""
        });
        
        schoolTeacherApplications[_schoolId].push(application);
        hasPendingApplication[_schoolId][msg.sender] = true;
        
        emit TeacherApplicationSubmitted(_schoolId, msg.sender, schoolTeacherApplications[_schoolId].length - 1);
    }
    
    // 2. 管理者根据学校id查询申请加入学校的老师
    function getSchoolApplications(uint256 _schoolId) 
        public 
        view 
        schoolExists(_schoolId) 
        returns (
            address[] memory teachers,
            string[] memory teacherNames,  // 新增教师姓名返回值
            uint256[] memory timestamps,
            string[] memory reasons,
            uint8[] memory statuses,
            address[] memory reviewers,
            uint256[] memory reviewTimes,
            string[] memory reviewComments
        ) 
    {
        // 检查权限：只有学校管理员或合约拥有者可以查看
        (,,,address schoolCreator,,,, ) = school.getSchoolInfo(_schoolId);
        require(
            msg.sender == owner() || 
            msg.sender == schoolCreator ||
            school.hasPermission(_schoolId, msg.sender, 0x8), 
            // string(abi.encodePacked(
            //     "No permission to view applications. "
            // ))
            string(abi.encodePacked(
                "No permission to view applications. ",
                "Caller: ", Strings.toHexString(msg.sender),
                ", Owner: ", Strings.toHexString(owner()),
                ", Creator: ", Strings.toHexString(schoolCreator),
                ", HasPermission: ", school.hasPermission(_schoolId, msg.sender, 0x8) ? "true" : "false"
            ))
        );
        
        TeacherApplication[] storage applications = schoolTeacherApplications[_schoolId];
        uint256 count = applications.length;
        
        teachers = new address[](count);
        teacherNames = new string[](count);  // 初始化教师姓名数组
        timestamps = new uint256[](count);
        reasons = new string[](count);
        statuses = new uint8[](count);
        reviewers = new address[](count);
        reviewTimes = new uint256[](count);
        reviewComments = new string[](count);
        
        for (uint256 i = 0; i < count; i++) {
            teachers[i] = applications[i].teacher;
            CommonUserV3.UserBasicInfo memory basicInfo = commonUser.getUserInfo(applications[i].teacher);
            teacherNames[i] = basicInfo.username;
            timestamps[i] = applications[i].timestamp;
            reasons[i] = applications[i].reason;
            statuses[i] = uint8(applications[i].status);
            reviewers[i] = applications[i].reviewer;
            reviewTimes[i] = applications[i].reviewTime;
            reviewComments[i] = applications[i].reviewComment;
        }
        
        return (teachers, teacherNames, timestamps, reasons, statuses, reviewers, reviewTimes, reviewComments);
    }
    
    // 3. 审核老师申请加入学校
    function reviewTeacherApplication(
        uint256 _schoolId, 
        uint256 _applicationIndex, 
        bool _approved, 
        string memory _comment,
        uint32 _permissions
    ) 
        public 
        schoolExists(_schoolId) 
    {
        (,,,address schoolCreator,,,, ) = school.getSchoolInfo(_schoolId);
        // 检查权限：只有学校管理员或合约拥有者可以审核
        require(
            msg.sender == owner() || 
            msg.sender == schoolCreator ||
            school.hasPermission(_schoolId, msg.sender, 0x8), 
            "No permission to review applications"
        );
        
        TeacherApplication[] storage applications = schoolTeacherApplications[_schoolId];
        require(_applicationIndex < applications.length, "Application does not exist");
        
        TeacherApplication storage application = applications[_applicationIndex];
        require(application.status == ApplicationStatus.Pending, "Application already reviewed");
        
        // 更新申请状态
        application.status = _approved ? ApplicationStatus.Approved : ApplicationStatus.Rejected;
        application.reviewer = msg.sender;
        application.reviewTime = block.timestamp;
        application.reviewComment = _comment;
        
        // 清除待处理标记
        hasPendingApplication[_schoolId][application.teacher] = false;
        
        // 如果通过，添加为教师
        if (_approved) {
            addTeacher(_schoolId, application.teacher, _permissions);
        }
        
        emit TeacherApplicationReviewed(
            _schoolId, 
            application.teacher, 
            _applicationIndex, 
            uint8(application.status), 
            msg.sender
        );
    }
    
    // 检查用户是否有待处理的申请
    function hasPendingApplicationToSchool(uint256 _schoolId, address _teacher) 
        public 
        view 
        returns (bool) 
    {
        return hasPendingApplication[_schoolId][_teacher];
    }
    
    // 获取用户在特定学校的申请状态
    function getTeacherApplicationStatus(uint256 _schoolId, address _teacher) 
        public 
        view 
        returns (uint8, uint256) 
    {
        TeacherApplication[] storage applications = schoolTeacherApplications[_schoolId];
        
        // 从最新的申请开始查找
        for (uint256 i = applications.length; i > 0; i--) {
            if (applications[i-1].teacher == _teacher) {
                return (uint8(applications[i-1].status), i-1);
            }
        }
        
        // 没有找到申请
        return (99, 0);
    }
    
    // 事件
    event TeacherApplicationSubmitted(uint256 indexed schoolId, address indexed teacher, uint256 applicationIndex);
    event TeacherApplicationReviewed(uint256 indexed schoolId, address indexed teacher, uint256 applicationIndex, uint8 status, address reviewer);
}