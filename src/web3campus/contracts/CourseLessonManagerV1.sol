// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./CourseV1.sol";
import "./CourseLessonV1.sol";

contract CourseLessonManagerV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // 课程合约地址
    CourseV1 public courseContract;
    // 课时合约地址
    CourseLessonV1 public lessonContract;
    
    // 退款状态枚举
    enum RefundStatus {
        None,        // 未申请退款
        Requested,   // 已申请退款
        Approved,    // 已批准退款
        Rejected,    // 已拒绝退款
        Processed    // 已处理退款
    }
    
    // 完成记录结构
    struct CompletionRecord {
        uint8 progress;         // 完成百分比
        uint64 lastAccess;      // 最后访问时间
        uint16 score;           // 考核分数
        address studentAddress; // 学员地址
        uint256 courseId;       // 课程ID
        uint256 lessonId;       // 课时ID
    }
    
    // 学生购买课程记录结构
    struct EnrollmentRecord {
        uint256 enrollmentTime;   // 购买/加入时间
        uint256 expiryTime;       // 到期时间（订阅制模式使用）
        uint256 amountPaid;       // 支付金额
        address paymentToken;     // 支付代币
        bool isActive;            // 是否有效
        RefundStatus refundStatus; // 退款状态
        string studentRefundReason; // 学生申请的退款原因
        string teacherRejectReason; // 教师拒绝原因
    }
    
    // 完成记录映射：学员地址 => 课时ID => 完成记录
    mapping(address => mapping(uint256 => CompletionRecord)) private completionRecords;
    
    // 记录学生完成过的课时ID列表：学生地址 => 课程ID => 课时ID数组
    mapping(address => mapping(uint256 => uint256[])) private studentLessonIds;
    
    // 课程购买记录映射：课程ID => 学员地址 => 购买记录
    mapping(uint256 => mapping(address => EnrollmentRecord)) private enrollmentRecords;
    
    // 课程学生列表映射：课程ID => 学生地址数组
    mapping(uint256 => address[]) private courseStudents;
    
    // 新增映射：学生地址 => 课程ID数组
    mapping(address => uint256[]) private studentCourses;
    
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

    // 添加设置 courseContract 的函数
    function setLessonContract(address _lessonAddress) public onlyOwner {
        require(_lessonAddress != address(0), "Invalid address");
        lessonContract = CourseLessonV1(_lessonAddress);
        emit LessonContractUpdated(_lessonAddress);
    }

    // 在事件部分添加新事件
    event LessonContractUpdated(address indexed newLessonContract);
    
    // 购买课程/加入课程
    function joinCourse(uint256 _courseId) public payable {
        // 验证课程是否存在
        require(courseContract.courseExists(_courseId), "Course does not exist");
        
        // 获取课程价格信息
        (uint8 priceModel, uint256 basePrice, uint256 discountRate, address paymentToken) = courseContract.getCoursePricing(_courseId);
        
        // 验证课程未被锁定
        require(!courseContract.isCourseLocked(_courseId), "Course is locked");
        
        // 验证学生未购买过此课程或已过期
        EnrollmentRecord storage record = enrollmentRecords[_courseId][msg.sender];
        require(!record.isActive || (record.expiryTime > 0 && record.expiryTime < block.timestamp), "Already enrolled in this course");
        
        // 计算实际支付金额
        uint256 actualPrice = basePrice;
        if (discountRate > 0) {
            actualPrice = basePrice * (100 - discountRate) / 100;
        }
        
        // 处理支付逻辑
        if (paymentToken == address(0)) {
            // 使用原生代币支付
            require(msg.value >= actualPrice, "Insufficient payment");
            
            // 转账给课程管理者
            address courseManager = courseContract.getCourseManager(_courseId);
            (bool success, ) = courseManager.call{value: msg.value}("");
            require(success, "Payment transfer failed");
        } else {
            // 对于代币支付，需要单独处理（此处简化处理）
            // 实际应用中应使用ERC20接口处理代币转账
            revert("Token payment not implemented");
        }
        
        // 记录购买信息
        uint256 expiryTime = 0; // 默认不过期
        if (PriceModel(priceModel) == PriceModel.Subscription) {
            // 如果是订阅制，设置30天的有效期（可以根据需要调整）
            expiryTime = block.timestamp + 30 days;
        }
        
        // 更新购买记录
        record.enrollmentTime = block.timestamp;
        record.expiryTime = expiryTime;
        record.amountPaid = msg.value;
        record.paymentToken = paymentToken;
        record.isActive = true;
        
        // 将学生添加到课程学生列表（如果尚未添加）
        bool studentExists = false;
        address[] storage students = courseStudents[_courseId];
        for (uint i = 0; i < students.length; i++) {
            if (students[i] == msg.sender) {
                studentExists = true;
                break;
            }
        }
        
        if (!studentExists) {
            courseStudents[_courseId].push(msg.sender);
            studentCourses[msg.sender].push(_courseId); // 新增：添加到学生课程列表
        }
        
        // 触发加入课程事件
        emit CourseEnrollment(_courseId, msg.sender, msg.value, block.timestamp);
    }
    
    // 检查学生是否已加入课程
    function isEnrolledInCourse(uint256 _courseId, address _student) public view returns (bool) {
        EnrollmentRecord storage record = enrollmentRecords[_courseId][_student];
        
        // 检查是否有效，以及是否在有效期内
        if (!record.isActive) {
            return false;
        }
        
        // 如果设置了到期时间，检查是否已过期
        if (record.expiryTime > 0 && block.timestamp > record.expiryTime) {
            return false;
        }
        
        return true;
    }
    
    // 获取课程学生列表
    function getCourseStudents(uint256 _courseId) public view returns (address[] memory) {
        return courseStudents[_courseId];
    }
    
    // 获取学生的课程购买记录
    function getEnrollmentRecord(uint256 _courseId, address _student) public view returns (
        uint256 enrollmentTime,
        uint256 expiryTime,
        uint256 amountPaid,
        address paymentToken,
        bool isActive,
        RefundStatus refundStatus,
        string memory studentRefundReason,
        string memory teacherRejectReason
    ) {
        EnrollmentRecord storage record = enrollmentRecords[_courseId][_student];
        
        return (
            record.enrollmentTime,
            record.expiryTime,
            record.amountPaid,
            record.paymentToken,
            record.isActive,
            record.refundStatus,
            record.studentRefundReason,
            record.teacherRejectReason
        );
    }
    
    // 更新学习进度
    function updateLearningProgress(
        uint256 _lessonId,
        uint256 _courseId,
        address _student,
        uint8 _progress
    ) public {
        require(lessonContract.lessonExists(_lessonId), "Lesson does not exist");
        
        // 只有课程教师或合约拥有者可以更新学习进度
        require(
            courseContract.isTeacherOfCourse(_courseId, msg.sender) || 
            msg.sender == owner(),
            "Only teacher or owner can update learning progress"
        );
        require(_progress <= 100, "Progress cannot exceed 100%");
        
        CompletionRecord storage record = completionRecords[_student][_lessonId];
        record.progress = _progress;
        record.lastAccess = uint64(block.timestamp);
        record.studentAddress = _student;
        record.courseId = _courseId;
        record.lessonId = _lessonId;
        
        // 如果这是学生第一次学习这个课时，将课时ID添加到学生的课时列表中
        _addLessonToStudentList(_student, _courseId, _lessonId);
        
        emit LearningProgressUpdated(_lessonId, _student, _progress);
    }
    
    // 内部函数：将课时添加到学生的课时列表中（如果尚未添加）
    function _addLessonToStudentList(address _student, uint256 _courseId, uint256 _lessonId) private {
        uint256[] storage lessonIds = studentLessonIds[_student][_courseId];
        bool lessonExists = false;
        
        // 检查课时是否已经在列表中
        for(uint256 i = 0; i < lessonIds.length; i++) {
            if(lessonIds[i] == _lessonId) {
                lessonExists = true;
                break;
            }
        }
        
        // 如果课时不在列表中，则添加
        if(!lessonExists) {
            studentLessonIds[_student][_courseId].push(_lessonId);
        }
    }
    
    // 更新考核分数
    function updateLearningScore(
        uint256 _lessonId,
        uint256 _courseId,
        address _student,
        uint16 _score
    ) public {
        require(lessonContract.lessonExists(_lessonId), "Lesson does not exist");
        
        // 只有课程教师或合约拥有者可以更新考核分数
        require(
            courseContract.isTeacherOfCourse(_courseId, msg.sender) || 
            msg.sender == owner(),
            "Only teacher or owner can update learning score"
        );
        require(_score <= 10000, "Score cannot exceed 10000"); // 允许百分比的100倍精度
        
        CompletionRecord storage record = completionRecords[_student][_lessonId];
        record.score = _score;
        record.lastAccess = uint64(block.timestamp);
        record.studentAddress = _student;
        record.courseId = _courseId;
        record.lessonId = _lessonId;
        
        // 如果这是学生第一次获得这个课时的分数，将课时ID添加到学生的课时列表中
        _addLessonToStudentList(_student, _courseId, _lessonId);
        
        emit LearningScoreUpdated(_lessonId, _student, _score);
    }
    
    // 批量更新学习记录
    function batchUpdateLearningRecords(
        uint256 _lessonId,
        uint256 _courseId,
        address[] memory _students,
        uint8[] memory _progresses,
        uint16[] memory _scores
    ) public {
        require(lessonContract.lessonExists(_lessonId), "Lesson does not exist");
        
        // 只有课程教师或合约拥有者可以批量更新学习记录
        require(
            courseContract.isTeacherOfCourse(_courseId, msg.sender) || 
            msg.sender == owner(),
            "Only teacher or owner can batch update learning records"
        );
        require(_students.length == _progresses.length && _students.length == _scores.length, "Array lengths must match");
        
        for (uint i = 0; i < _students.length; i++) {
            CompletionRecord storage record = completionRecords[_students[i]][_lessonId];
            record.progress = _progresses[i];
            record.score = _scores[i];
            record.lastAccess = uint64(block.timestamp);
            record.studentAddress = _students[i];
            record.courseId = _courseId;
            record.lessonId = _lessonId;
            
            // 为每个学生添加课时到列表
            _addLessonToStudentList(_students[i], _courseId, _lessonId);
        }
        
        emit BatchLearningRecordsUpdated(_lessonId, _students.length);
    }
    
    // 获取学习完成记录
    function getLearningRecord(uint256 _lessonId, address _student) public view returns (
        uint8 progress,
        uint64 lastAccess,
        uint16 score
    ) {
        CompletionRecord storage record = completionRecords[_student][_lessonId];
        
        return (
            record.progress,
            record.lastAccess,
            record.score
        );
    }
    
    // 根据课程ID获取学生的所有课时完成记录
    struct LessonCompletionRecord {
        uint256 lessonId;       // 课时ID
        uint8 progress;         // 完成百分比
        uint64 lastAccess;      // 最后访问时间
        uint16 score;           // 考核分数
        address studentAddress; // 学员地址
    }
    
    function getStudentLessonRecordsByCourse(uint256 _courseId, address _student) public view returns (LessonCompletionRecord[] memory) {
        // 验证课程是否存在
        require(courseContract.courseExists(_courseId), "Course does not exist");
        
        // 直接从学生的课时列表获取课时ID
        uint256[] storage lessonIds = studentLessonIds[_student][_courseId];
        
        // 创建结果数组
        LessonCompletionRecord[] memory results = new LessonCompletionRecord[](lessonIds.length);
        
        // 遍历所有课时ID，获取完成记录
        for (uint256 i = 0; i < lessonIds.length; i++) {
            uint256 lessonId = lessonIds[i];
            CompletionRecord storage record = completionRecords[_student][lessonId];
            
            results[i] = LessonCompletionRecord({
                lessonId: lessonId,
                progress: record.progress,
                lastAccess: record.lastAccess,
                score: record.score,
                studentAddress: record.studentAddress
            });
        }
        
        return results;
    }
    
    // 必需的函数，用于控制合约升级权限
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // 用于支持订阅模式的价格模型枚举
    enum PriceModel {
        Fixed,        // 固定价格
        Subscription, // 订阅制
        Dynamic       // 动态定价
    }
    
    // ==================== 事件 ====================
    event LearningProgressUpdated(uint256 indexed lessonId, address indexed student, uint8 progress);
    event LearningScoreUpdated(uint256 indexed lessonId, address indexed student, uint16 score);
    event BatchLearningRecordsUpdated(uint256 indexed lessonId, uint256 studentsCount);
    event CourseEnrollment(uint256 indexed courseId, address indexed student, uint256 amount, uint256 timestamp);

    // 申请退款
    function requestRefund(uint256 _courseId, string memory _reason) public {
        EnrollmentRecord storage record = enrollmentRecords[_courseId][msg.sender];
        require(record.isActive, "No active enrollment");
        require(record.refundStatus == RefundStatus.None, "Refund already requested");
        require(bytes(_reason).length > 0, "Refund reason cannot be empty");
        
        record.refundStatus = RefundStatus.Requested;
        record.studentRefundReason = _reason;
        emit RefundRequested(_courseId, msg.sender, _reason);
    }

    // 审核退款申请
    function processRefund(
        uint256 _courseId,
        address _student,
        bool _approve,
        string memory _rejectReason
    ) public {
        require(courseContract.isTeacherOfCourse(_courseId, msg.sender), "Only teacher can process refund");
        
        EnrollmentRecord storage record = enrollmentRecords[_courseId][_student];
        require(record.refundStatus == RefundStatus.Requested, "No refund request");
        
        if (_approve) {
            record.refundStatus = RefundStatus.Approved;
            // 执行退款逻辑
            if (record.paymentToken == address(0)) {
                (bool success, ) = _student.call{value: record.amountPaid}("");
                require(success, "Refund transfer failed");
                record.refundStatus = RefundStatus.Processed;
                record.isActive = false;
            } else {
                revert("Token refund not implemented");
            }
        } else {
            require(bytes(_rejectReason).length > 0, "Reject reason cannot be empty");
            record.refundStatus = RefundStatus.Rejected;
            record.teacherRejectReason = _rejectReason;
        }
        
        emit RefundProcessed(_courseId, _student, _approve, _approve ? "" : _rejectReason);
    }

    // 在事件部分添加新事件
    event RefundRequested(uint256 indexed courseId, address indexed student, string reason);
    event RefundProcessed(uint256 indexed courseId, address indexed student, bool approved, string reason);

    // 优化后的获取学生课程列表方法
    function getStudentEnrollments(address _student) public view returns (EnrollmentRecord[] memory) {
        uint256[] storage courseIds = studentCourses[_student];
        EnrollmentRecord[] memory result = new EnrollmentRecord[](courseIds.length);
        
        for (uint256 i = 0; i < courseIds.length; i++) {
            uint256 courseId = courseIds[i];
            if (enrollmentRecords[courseId][_student].isActive) {
                result[i] = enrollmentRecords[courseId][_student];
            }
        }
        
        return result;
    }

    // 新增：获取学生加入的所有课程ID
    function getStudentCourseIds(address _student) public view returns (uint256[] memory) {
        return studentCourses[_student];
    }
}