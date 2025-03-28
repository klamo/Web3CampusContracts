// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/web3campus/contracts/SchoolV1.sol";
import "../src/web3campus/contracts/CollegeV1.sol";
import "../src/web3campus/contracts/CourseV1.sol";
import "../src/web3campus/contracts/CourseLessonV1.sol";
import "../src/web3campus/contracts/CourseLessonManagerV1.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title 合约升级脚本
 * @notice 升级 SchoolV1 合约的实现
 * 运行方法 forge script script/UpgradeSchool.s.sol:UpgradeSchool --rpc-url http://localhost:8545 --broadcast -vvvv
 */
contract UpgradeSchool is Script {
    function run() external {
        // 使用默认私钥
        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

        // 部署新的实现合约
        //SchoolUserV1 newImplementation = new SchoolUserV1();
        //CourseLessonV1 newImplementation = new CourseLessonV1();
        //SchoolTeacher newImplementation = new SchoolTeacher();
        CourseLessonManagerV1 newImplementation = new CourseLessonManagerV1();

        // SchoolUserV1的代理合约
        //UUPSUpgradeable proxy = UUPSUpgradeable(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
        // SchoolTeacher的代理合约
        //UUPSUpgradeable proxy = UUPSUpgradeable(0xa513E6E4b8f2a923D98304ec87F64353C4D5C853);
        // CourseV1的代理合约
        UUPSUpgradeable proxy = UUPSUpgradeable(0x3Aa5ebB10DC797CAC828524e59A333d0A371443c);
        proxy.upgradeTo(address(newImplementation));
        vm.stopBroadcast();
        console.log("New implementation deployed to:", address(newImplementation));
        console.log("Proxy upgraded successfully");
    }
}