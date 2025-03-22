#!/bin/bash


# 这是将out中的合约转换成abi的脚本
# 第一步，给这个脚本添加执行权限 chmod +x scripts/extract_abis_one.sh
# 第二步，运行脚本 ./scripts/extract_abis_one.sh
# 创建 abi 目录
mkdir -p src/abi

# 提取所有需要的合约 ABI
contracts=(
    "CourseLessonManagerV1",
    "CourseLessonV1"
)

for contract in "${contracts[@]}"
do
    echo "Extracting ABI for $contract..."
    jq .abi "out/${contract}.sol/${contract}.json" > "src/abi/${contract}.json"
done

echo "ABI extraction completed!"