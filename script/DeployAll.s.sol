// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// 导入所有需要部署的合约
import "web3common/contracts/CommonUserV3.sol";
import "../src/web3campus/contracts/SchoolV1.sol";
import "../src/web3campus/contracts/SchoolCustomFieldV1.sol";
import "../src/web3campus/contracts/SchoolUserV1.sol";
import "../src/web3campus/contracts/SchoolTeacher.sol";
import "../src/web3campus/contracts/SchoolFundsV1.sol";
import "../src/web3campus/contracts/SchoolDAO.sol";
import "../src/web3campus/contracts/CourseV1.sol";
import "../src/web3campus/contracts/CourseTeacherV1.sol";
import "../src/web3campus/contracts/CourseLessonV1.sol";
import "../src/web3campus/contracts/CourseLessonManagerV1.sol";
import "../src/web3campus/contracts/CourseChapterV1.sol";
import "../src/web3campus/contracts/CollegeV1.sol";
import "../src/web3campus/contracts/CollegeDAOV1.sol";

// 导入代理合约
import "web3common/contracts/CommonUserProxy.sol";
import "../src/web3campus/contracts/SchoolProxy.sol";
import "../src/web3campus/contracts/SchoolCustomFieldProxy.sol";
import "../src/web3campus/contracts/SchoolUserProxy.sol";
import "../src/web3campus/contracts/SchoolTeacherProxy.sol";
import "../src/web3campus/contracts/SchoolFundsProxy.sol";
import "../src/web3campus/contracts/SchoolDAOProxy.sol";
import "../src/web3campus/contracts/CourseProxy.sol";
import "../src/web3campus/contracts/CourseTeacherProxy.sol";
import "../src/web3campus/contracts/CourseLessonProxy.sol";
import "../src/web3campus/contracts/CourseLessonManagerProxy.sol";
import "../src/web3campus/contracts/CourseChapterProxy.sol";
import "../src/web3campus/contracts/CollegeProxy.sol";
import "../src/web3campus/contracts/CollegeDAOProxy.sol";


/**
 * @title 部署所有合约
 * @notice 运行方法 forge script script/DeployAll.s.sol:DeployAll --rpc-url http://localhost:8545 --broadcast -vvvv
 */
contract DeployAll is Script {
    function run() external {
        // 直接使用私钥
        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

        // 1. 部署 CommonUserV3 及其代理
        console.log(unicode"1、开始部署 CommonUserV3...");
        CommonUserV3 commonUserImplementation = new CommonUserV3();
        
        bytes memory commonUserInitData = abi.encodeWithSelector(
            CommonUserV3.initialize.selector
        );
        
        CommonUserProxy commonUserProxy = new CommonUserProxy(
            address(commonUserImplementation),
            commonUserInitData
        );
        
        console.log(unicode"2、CommonUserV3 实现合约部署成功:", address(commonUserImplementation));
        console.log(unicode"3、CommonUserV3 代理合约部署成功:", address(commonUserProxy));

        // 2. 部署 SchoolV1 及其代理
        console.log(unicode"4、开始部署 SchoolV1...");
        SchoolV1 schoolImplementation = new SchoolV1();
        
        bytes memory schoolInitData = abi.encodeWithSelector(
            SchoolV1.initialize.selector
        );
        
        SchoolProxy schoolProxy = new SchoolProxy(
            address(schoolImplementation),
            schoolInitData
        );
        
        console.log(unicode"5、SchoolV1 实现合约部署成功:", address(schoolImplementation));
        console.log(unicode"6、SchoolV1 代理合约部署成功:", address(schoolProxy));

        // 3. 部署 SchoolUserV1 及其代理
        console.log(unicode"7、开始部署 SchoolUserV1...");
        SchoolUserV1 schoolUserImplementation = new SchoolUserV1();
        
        bytes memory schoolUserInitData = abi.encodeWithSelector(
            SchoolUserV1.initialize.selector
        );
        
        SchoolUserProxy schoolUserProxy = new SchoolUserProxy(
            address(schoolUserImplementation),
            schoolUserInitData
        );
        
        console.log(unicode"8、SchoolUserV1 实现合约部署成功:", address(schoolUserImplementation));
        console.log(unicode"9、SchoolUserV1 代理合约部署成功:", address(schoolUserProxy));

        // 4. 部署 SchoolTeacher 及其代理
        console.log(unicode"10、开始部署 SchoolTeacher...");
        SchoolTeacher schoolTeacherImplementation = new SchoolTeacher();
        
        bytes memory schoolTeacherInitData = abi.encodeWithSelector(
            SchoolTeacher.initialize.selector
        );
        
        SchoolTeacherProxy schoolTeacherProxy = new SchoolTeacherProxy(
            address(schoolTeacherImplementation),
            schoolTeacherInitData
        );
        
        console.log(unicode"11、SchoolTeacher 实现合约部署成功:", address(schoolTeacherImplementation));
        console.log(unicode"12、SchoolTeacher 代理合约部署成功:", address(schoolTeacherProxy));

        // 5. 部署 SchoolFundsV1 及其代理
        console.log(unicode"13、开始部署 SchoolFundsV1...");
        SchoolFundsV1 schoolFundsImplementation = new SchoolFundsV1();
        
        bytes memory schoolFundsInitData = abi.encodeWithSelector(
            SchoolFundsV1.initialize.selector
        );
        
        SchoolFundsProxy schoolFundsProxy = new SchoolFundsProxy(
            address(schoolFundsImplementation),
            schoolFundsInitData
        );
        
        console.log(unicode"14、SchoolFundsV1 实现合约部署成功:", address(schoolFundsImplementation));
        console.log(unicode"15、SchoolFundsV1 代理合约部署成功:", address(schoolFundsProxy));

        // 6. 部署 SchoolDAO 及其代理
        console.log(unicode"16、开始部署 SchoolDAO...");
        SchoolDAO schoolDAOImplementation = new SchoolDAO();
        
        bytes memory schoolDAOInitData = abi.encodeWithSelector(
            SchoolDAO.initialize.selector
        );
        
        SchoolDAOProxy schoolDAOProxy = new SchoolDAOProxy(
            address(schoolDAOImplementation),
            schoolDAOInitData
        );
        
        console.log(unicode"17、SchoolDAO 实现合约部署成功:", address(schoolDAOImplementation));
        console.log(unicode"18、SchoolDAO 代理合约部署成功:", address(schoolDAOProxy));

        // 7. 部署 CourseV1 及其代理
        console.log(unicode"19、开始部署 CourseV1...");
        CourseV1 courseImplementation = new CourseV1();
        
        bytes memory courseInitData = abi.encodeWithSelector(
            CourseV1.initialize.selector
        );
        
        CourseProxy courseProxy = new CourseProxy(
            address(courseImplementation),
            courseInitData
        );
        
        console.log(unicode"20、CourseV1 实现合约部署成功:", address(courseImplementation));
        console.log(unicode"21、CourseV1 代理合约部署成功:", address(courseProxy));

        // 8. 部署 CourseTeacherV1 及其代理
        console.log(unicode"22、开始部署 CourseTeacherV1...");
        CourseTeacherV1 courseTeacherImplementation = new CourseTeacherV1();
        
        bytes memory courseTeacherInitData = abi.encodeWithSelector(
            CourseTeacherV1.initialize.selector
        );
        
        CourseTeacherProxy courseTeacherProxy = new CourseTeacherProxy(
            address(courseTeacherImplementation),
            courseTeacherInitData
        );
        
        console.log(unicode"23、CourseTeacherV1 实现合约部署成功:", address(courseTeacherImplementation));
        console.log(unicode"24、CourseTeacherV1 代理合约部署成功:", address(courseTeacherProxy));

        // 9. 部署 CourseLessonV1 及其代理
        console.log(unicode"25、开始部署 CourseLessonV1...");
        CourseLessonV1 courseLessonImplementation = new CourseLessonV1();
        
        bytes memory courseLessonInitData = abi.encodeWithSelector(
            CourseLessonV1.initialize.selector
        );
        
        CourseLessonProxy courseLessonProxy = new CourseLessonProxy(
            address(courseLessonImplementation),
            courseLessonInitData
        );
        
        console.log(unicode"26、CourseLessonV1 实现合约部署成功:", address(courseLessonImplementation));
        console.log(unicode"27、CourseLessonV1 代理合约部署成功:", address(courseLessonProxy));

        // 10. 部署 CourseLessonManagerV1 及其代理
        console.log(unicode"28、开始部署 CourseLessonManagerV1...");
        CourseLessonManagerV1 courseLessonManagerImplementation = new CourseLessonManagerV1();
        
        bytes memory courseLessonManagerInitData = abi.encodeWithSelector(
            CourseLessonManagerV1.initialize.selector
        );
        
        CourseLessonManagerProxy courseLessonManagerProxy = new CourseLessonManagerProxy(
            address(courseLessonManagerImplementation),
            courseLessonManagerInitData
        );
        
        console.log(unicode"29、CourseLessonManagerV1 实现合约部署成功:", address(courseLessonManagerImplementation));
        console.log(unicode"30、CourseLessonManagerV1 代理合约部署成功:", address(courseLessonManagerProxy));

        // 11. 部署 CourseChapterV1 及其代理
        console.log(unicode"31、开始部署 CourseChapterV1...");
        CourseChapterV1 courseChapterImplementation = new CourseChapterV1();
        
        bytes memory courseChapterInitData = abi.encodeWithSelector(
            CourseChapterV1.initialize.selector
        );
        
        CourseChapterProxy courseChapterProxy = new CourseChapterProxy(
            address(courseChapterImplementation),
            courseChapterInitData
        );
        
        console.log(unicode"32、CourseChapterV1 实现合约部署成功:", address(courseChapterImplementation));
        console.log(unicode"33、CourseChapterV1 代理合约部署成功:", address(courseChapterProxy));

        // 12. 部署 CollegeV1 及其代理
        console.log(unicode"34、开始部署 CollegeV1...");
        CollegeV1 collegeImplementation = new CollegeV1();
        
        bytes memory collegeInitData = abi.encodeWithSelector(
            CollegeV1.initialize.selector
        );
        
        CollegeProxy collegeProxy = new CollegeProxy(
            address(collegeImplementation),
            collegeInitData
        );
        
        console.log(unicode"35、CollegeV1 实现合约部署成功:", address(collegeImplementation));
        console.log(unicode"36、CollegeV1 代理合约部署成功:", address(collegeProxy));

        // 13. 部署 CollegeDAOV1 及其代理
        console.log(unicode"37、开始部署 CollegeDAOV1...");
        CollegeDAOV1 collegeDAOImplementation = new CollegeDAOV1();
        
        bytes memory collegeDAOInitData = abi.encodeWithSelector(
            CollegeDAOV1.initialize.selector
        );
        
        CollegeDAOProxy collegeDAOProxy = new CollegeDAOProxy(
            address(collegeDAOImplementation),
            collegeDAOInitData
        );

        console.log(unicode"38、CollegeDAOV1 实现合约部署成功:", address(collegeDAOImplementation));
        console.log(unicode"39、CollegeDAOV1 代理合约部署成功:", address(collegeDAOProxy));


        // 14. 部署 SchoolCustomFieldV1 及其代理
        console.log(unicode"40、开始部署 SchoolCustomFieldV1...");
        SchoolCustomFieldV1 schoolCustomFieldImplementation = new SchoolCustomFieldV1();
        
        bytes memory schoolCustomFieldInitData = abi.encodeWithSelector(
            SchoolCustomFieldV1.initialize.selector
        );
        
        SchoolCustomFieldProxy schoolCustomFieldProxy = new SchoolCustomFieldProxy(
            address(schoolCustomFieldImplementation),
            schoolCustomFieldInitData
        );
        
        console.log(unicode"41、SchoolCustomFieldV1 实现合约部署成功:", address(schoolCustomFieldImplementation));
        console.log(unicode"42、SchoolCustomFieldV1 代理合约部署成功:", address(schoolCustomFieldProxy));


        


        // 设置 SchoolUser 的 CommonUser 地址
        SchoolUserV1(address(schoolUserProxy)).setCommonUser(address(commonUserProxy));
        console.log(unicode"40、SchoolUserV1 设置 setCommonUser 地址成功");

        // 设置 SchoolTeacher 的外部合约地址
        SchoolTeacher(address(schoolTeacherProxy)).setSchoolUser(address(schoolUserProxy));
        console.log(unicode"41、SchoolTeacher 设置 setSchoolUser 地址成功");
        SchoolTeacher(address(schoolTeacherProxy)).setSchool(address(schoolProxy));
        console.log(unicode"42、SchoolTeacher 设置 setSchool 地址成功");
        SchoolTeacher(address(schoolTeacherProxy)).setCommonUser(address(commonUserProxy));
        console.log(unicode"42、SchoolTeacher 设置 setCommonUser 地址成功");

        // 设置 School 的外部合约地址
        SchoolV1(address(schoolProxy)).setSchoolUser(address(schoolUserProxy));
        console.log(unicode"43、SchoolV1 设置 setSchoolUser 地址成功");
        SchoolV1(address(schoolProxy)).setSchoolTeacher(address(schoolTeacherProxy));
        console.log(unicode"44、SchoolV1 设置 setSchoolTeacher 地址成功");
        SchoolV1(address(schoolProxy)).setCustomField(address(schoolCustomFieldProxy));
        console.log(unicode"45、SchoolV1 设置 setCustomField 地址成功");

        // 设置 SchoolFunds 的外部合约地址
        SchoolFundsV1(address(schoolFundsProxy)).setSchool(address(schoolProxy));
        console.log(unicode"45、SchoolFundsV1 设置 setSchool 地址成功");

        // 设置 SchoolDAO 的外部合约地址
        SchoolDAO(address(schoolDAOProxy)).setSchool(address(schoolProxy));
        console.log(unicode"46、SchoolDAO 设置 setSchool 地址成功");

        // 设置 CourseV1 的外部合约地址
        CourseV1(address(courseProxy)).setCollegeContract(address(collegeProxy));
        console.log(unicode"47、CourseV1 设置 setCollegeContract 地址成功");
        CourseV1(address(courseProxy)).setTeacherContract(address(courseTeacherProxy));
        console.log(unicode"48、CourseV1 设置 setTeacherContract 地址成功");

        // 设置 CourseTeacherV1 的外部合约地址
        CourseTeacherV1(address(courseTeacherProxy)).setCourseContract(address(courseProxy));
        console.log(unicode"49、CourseTeacherV1 设置 setCourseContract 地址成功");

        // 设置 CourseLessonV1 的外部合约地址
        CourseLessonV1(address(courseLessonProxy)).setCourseContract(address(courseProxy));
        console.log(unicode"50、CourseLessonV1 设置 setCourseContract 地址成功");

        // 设置 CourseLessonManagerV1 的外部合约地址
        CourseLessonManagerV1(address(courseLessonManagerProxy)).setCourseContract(address(courseProxy));
        console.log(unicode"51、CourseLessonManagerV1 设置 setCourseContract 地址成功");
        CourseLessonManagerV1(address(courseLessonManagerProxy)).setLessonContract(address(courseLessonProxy));
        console.log(unicode"52、CourseLessonManagerV1 设置 setLessonContract 地址成功");

        // 设置 CourseChapterV1 的外部合约地址
        CourseChapterV1(address(courseChapterProxy)).setCourseContract(address(courseProxy));
        console.log(unicode"53、CourseChapterV1 设置 setCourseContract 地址成功");

        // 设置 CollegeV1 的外部合约地址
        CollegeV1(address(collegeProxy)).setSchool(address(schoolProxy));
        console.log(unicode"54、CollegeV1 设置 setSchool 地址成功");
        CollegeV1(address(collegeProxy)).setSchoolTeacher(address(schoolTeacherProxy));
        console.log(unicode"55、CollegeV1 设置 setSchoolTeacher 地址成功");

        // 设置 CollegeDAOV1 的外部合约地址
        CollegeDAOV1(address(collegeDAOProxy)).setSchool(address(schoolProxy));
        console.log(unicode"56、CollegeDAOV1 设置 setSchool 地址成功");
        CollegeDAOV1(address(collegeDAOProxy)).setCollege(address(collegeProxy));
        console.log(unicode"57、CollegeDAOV1 设置 setCollege 地址成功");


        // 设置 SchoolCustomField 的外部合约地址
        SchoolCustomFieldV1(address(schoolCustomFieldProxy)).setSchool(address(schoolProxy));
        console.log(unicode"46、SchoolCustomFieldV1 设置 setSchool 地址成功");



        vm.stopBroadcast();

        // 输出所有部署的合约地址汇总
        console.log(unicode"\n58、========== 部署完成 ==========");
        console.log(unicode"59、CommonUserV3 实现合约:", address(commonUserImplementation));
        console.log(unicode"60、CommonUserV3 代理合约:", address(commonUserProxy));
        console.log(unicode"61、SchoolV1 实现合约:", address(schoolImplementation));
        console.log(unicode"62、SchoolV1 代理合约:", address(schoolProxy));
        console.log(unicode"63、SchoolUserV1 实现合约:", address(schoolUserImplementation));
        console.log(unicode"64、SchoolUserV1 代理合约:", address(schoolUserProxy));
        console.log(unicode"65、SchoolTeacher 实现合约:", address(schoolTeacherImplementation));
        console.log(unicode"66、SchoolTeacher 代理合约:", address(schoolTeacherProxy));
        console.log(unicode"67、SchoolFundsV1 实现合约:", address(schoolFundsImplementation));
        console.log(unicode"68、SchoolFundsV1 代理合约:", address(schoolFundsProxy));
        console.log(unicode"69、SchoolDAO 实现合约:", address(schoolDAOImplementation));
        console.log(unicode"70、SchoolDAO 代理合约:", address(schoolDAOProxy));
        console.log(unicode"71、CourseV1 实现合约:", address(courseImplementation));
        console.log(unicode"72、CourseV1 代理合约:", address(courseProxy));
        console.log(unicode"73、CourseTeacherV1 实现合约:", address(courseTeacherImplementation));
        console.log(unicode"74、CourseTeacherV1 代理合约:", address(courseTeacherProxy));
        console.log(unicode"75、CourseLessonV1 实现合约:", address(courseLessonImplementation));
        console.log(unicode"76、CourseLessonV1 代理合约:", address(courseLessonProxy));
        console.log(unicode"77、CourseLessonManagerV1 实现合约:", address(courseLessonManagerImplementation));
        console.log(unicode"78、CourseLessonManagerV1 代理合约:", address(courseLessonManagerProxy));
        console.log(unicode"79、CourseChapterV1 实现合约:", address(courseChapterImplementation));
        console.log(unicode"80、CourseChapterV1 代理合约:", address(courseChapterProxy));
        console.log(unicode"81、CollegeV1 实现合约:", address(collegeImplementation));
        console.log(unicode"82、CollegeV1 代理合约:", address(collegeProxy));
        console.log(unicode"83、CollegeDAOV1 实现合约:", address(collegeDAOImplementation));
        console.log(unicode"84、CollegeDAOV1 代理合约:", address(collegeDAOProxy));
        console.log(unicode"85、SchoolCustomFieldV1 实现合约:", address(schoolCustomFieldImplementation));
        console.log(unicode"86、SchoolCustomFieldV1 代理合约:", address(schoolCustomFieldProxy));
    }
}