#!/bin/bash

# 测试闪电贷套利功能

echo "🧪 测试闪电贷套利..."

# 运行特定测试
echo "1️⃣ 测试基础闪电贷..."
aptos move test --filter basic_pool

echo ""
echo "2️⃣ 测试套利计算..."
aptos move test --filter arbitrage

echo ""
echo "3️⃣ 测试聚合器..."
aptos move test --filter aggregator

echo ""
echo "✅ 所有测试完成"
