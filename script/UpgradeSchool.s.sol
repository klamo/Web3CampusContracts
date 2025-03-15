// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/web3campus/contracts/SchoolV1.sol";
import "../src/web3campus/contracts/CollegeV1.sol";
import "../src/web3campus/contracts/CourseV1.sol";
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
        CourseV1 newImplementation = new CourseV1();

        // SchoolUserV1的代理合约
        //UUPSUpgradeable proxy = UUPSUpgradeable(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
        // SchoolTeacher的代理合约
        UUPSUpgradeable proxy = UUPSUpgradeable(0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82);
        proxy.upgradeTo(address(newImplementation));
        vm.stopBroadcast();
        console.log("New implementation deployed to:", address(newImplementation));
        console.log("Proxy upgraded successfully");
    }
}