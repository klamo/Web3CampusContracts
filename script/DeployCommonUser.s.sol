// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "web3common/contracts/CommonUserV3.sol";
import "web3common/contracts/CommonUserProxy.sol";
import "web3campus/contracts/SchoolV1.sol";


/**
 * @title 单独的部署脚本
 * @notice forge script script/DeployCommonUser.s.sol:DeployCommonUser --rpc-url http://localhost:8545 --broadcast -vvvv
 */
contract DeployCommonUser is Script {
    function run() external {
        // 直接使用私钥
        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

        // 部署实现合约
        SchoolV1 implementation = new SchoolV1();
        
        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            SchoolV1.initialize.selector
        );

        // 部署代理合约
        // CommonUserProxy proxy = new CommonUserProxy(
        //     address(implementation),
        //     initData
        // );

        vm.stopBroadcast();

        console.log("Implementation deployed to:", address(implementation));
        //console.log("Proxy deployed to:", address(proxy));
    }
}