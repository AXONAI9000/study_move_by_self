#!/bin/bash

# Day 31 闪电贷实现 - 部署脚本

echo "🚀 开始部署闪电贷协议..."

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 编译项目
echo -e "${YELLOW}📦 编译 Move 项目...${NC}"
aptos move compile

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo -e "${GREEN}✅ 编译成功${NC}"

# 2. 运行测试
echo -e "${YELLOW}🧪 运行测试...${NC}"
aptos move test

if [ $? -ne 0 ]; then
    echo "❌ 测试失败"
    exit 1
fi

echo -e "${GREEN}✅ 测试通过${NC}"

# 3. 部署到测试网（可选）
echo -e "${YELLOW}🌐 是否部署到测试网? (y/n)${NC}"
read -r deploy

if [ "$deploy" = "y" ]; then
    echo "📡 部署到 testnet..."
    aptos move publish --profile testnet
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 部署成功${NC}"
    else
        echo "❌ 部署失败"
        exit 1
    fi
fi

echo "🎉 完成！"
