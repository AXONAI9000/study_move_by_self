#!/bin/bash

# Day 34 Gas 优化 - 部署脚本
# 用于部署和测试 Gas 优化模块

set -e

echo "================================"
echo "Day 34 - Gas 优化部署脚本"
echo "================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 检查 Aptos CLI
echo -e "${YELLOW}检查 Aptos CLI...${NC}"
if ! command -v aptos &> /dev/null; then
    echo -e "${RED}错误: Aptos CLI 未安装${NC}"
    echo "请访问 https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli"
    exit 1
fi

echo -e "${GREEN}✓ Aptos CLI 已安装${NC}"
aptos --version
echo ""

# 清理之前的构建
echo -e "${YELLOW}清理之前的构建...${NC}"
aptos move clean
echo -e "${GREEN}✓ 清理完成${NC}"
echo ""

# 编译项目
echo -e "${YELLOW}编译 Move 项目...${NC}"
if aptos move compile; then
    echo -e "${GREEN}✓ 编译成功${NC}"
else
    echo -e "${RED}✗ 编译失败${NC}"
    exit 1
fi
echo ""

# 运行测试
echo -e "${YELLOW}运行测试...${NC}"
if aptos move test; then
    echo -e "${GREEN}✓ 所有测试通过${NC}"
else
    echo -e "${RED}✗ 测试失败${NC}"
    exit 1
fi
echo ""

# 运行 Gas Profiler
echo -e "${YELLOW}运行 Gas Profiler...${NC}"
echo "生成 Gas 报告..."
aptos move test --gas-profiler > gas_report.txt
echo -e "${GREEN}✓ Gas 报告已生成: gas_report.txt${NC}"
echo ""

# 显示 Gas 报告摘要
echo -e "${YELLOW}Gas 报告摘要:${NC}"
head -n 30 gas_report.txt
echo ""
echo "完整报告请查看: gas_report.txt"
echo ""

# 可选：部署到测试网
read -p "是否部署到测试网? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}部署到测试网...${NC}"
    
    # 检查配置文件
    if [ ! -f .aptos/config.yaml ]; then
        echo -e "${YELLOW}初始化 Aptos 配置...${NC}"
        aptos init --network testnet
    fi
    
    # 发布模块
    echo -e "${YELLOW}发布模块...${NC}"
    if aptos move publish --assume-yes; then
        echo -e "${GREEN}✓ 部署成功${NC}"
    else
        echo -e "${RED}✗ 部署失败${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}部署完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "下一步："
echo "1. 查看 gas_report.txt 了解 Gas 消耗详情"
echo "2. 运行 'aptos move test --gas-profiler' 重新生成报告"
echo "3. 使用 TypeScript 脚本进行更详细的分析"
echo ""
