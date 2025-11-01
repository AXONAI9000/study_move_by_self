#!/bin/bash

# Day 07 实践任务 - 测试脚本
# 用于运行所有测试并生成测试报告

echo "=========================================="
echo "  Day 07 全局存储与资源管理 - 测试套件"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 统计变量
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 测试函数
run_test() {
    local test_name=$1
    local filter=$2
    
    echo "----------------------------------------"
    echo "测试: $test_name"
    echo "----------------------------------------"
    
    if aptos move test --filter "$filter" 2>&1 | tee /tmp/test_output.txt; then
        echo -e "${GREEN}✓ $test_name 通过${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ $test_name 失败${NC}"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
    echo ""
}

# 开始时间
START_TIME=$(date +%s)

echo "开始运行测试..."
echo ""

# 任务1测试
echo "=========================================="
echo "  任务1：用户账户系统"
echo "=========================================="
echo ""
run_test "用户账户系统 - 基本功能" "test_account_system"
run_test "用户账户系统 - 更新资料" "test_update_profile"
run_test "用户账户系统 - 重复注册检测" "test_duplicate_register"
run_test "用户账户系统 - 余额不足检测" "test_insufficient_balance"
run_test "用户账户系统 - 自我转账防护" "test_self_transfer"
run_test "用户账户系统 - 账户删除" "test_delete_account"
run_test "用户账户系统 - 非零余额删除" "test_delete_account_with_balance"

# 任务2测试
echo "=========================================="
echo "  任务2：资源注册表"
echo "=========================================="
echo ""
run_test "资源注册表 - 基本功能" "test_registry"
run_test "资源注册表 - 重复初始化" "test_duplicate_init"
run_test "资源注册表 - 非所有者更新" "test_update_not_owner"
run_test "资源注册表 - 非所有者删除" "test_delete_not_owner"
run_test "资源注册表 - 多项目管理" "test_multiple_items_per_user"

# 任务3测试
echo "=========================================="
echo "  任务3：多重签名钱包"
echo "=========================================="
echo ""
run_test "多重签名钱包 - 基本功能" "test_multisig_wallet"
run_test "多重签名钱包 - 所有者检查" "test_is_owner"
run_test "多重签名钱包 - 确认数不足" "test_insufficient_confirmations"
run_test "多重签名钱包 - 重复确认" "test_double_confirmation"
run_test "多重签名钱包 - 余额不足" "test_insufficient_balance"
run_test "多重签名钱包 - 重复执行" "test_double_execution"

# 结束时间
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# 输出测试报告
echo "=========================================="
echo "  测试报告"
echo "=========================================="
echo ""
echo "总测试数: $TOTAL_TESTS"
echo -e "${GREEN}通过: $PASSED_TESTS${NC}"
echo -e "${RED}失败: $FAILED_TESTS${NC}"
echo "耗时: ${DURATION}秒"
echo ""

# 计算通过率
if [ $TOTAL_TESTS -gt 0 ]; then
    PASS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo "通过率: ${PASS_RATE}%"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}=========================================="
        echo "  🎉 恭喜！所有测试通过！"
        echo "==========================================${NC}"
        exit 0
    else
        echo -e "${YELLOW}=========================================="
        echo "  ⚠️  部分测试失败，请检查代码"
        echo "==========================================${NC}"
        exit 1
    fi
else
    echo -e "${RED}未运行任何测试${NC}"
    exit 1
fi
