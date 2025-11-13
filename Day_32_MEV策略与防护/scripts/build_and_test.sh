#!/bin/bash

# Day 32 - MEV策略与防护
# 部署和测试脚本 (Linux/Mac)

echo "=== 编译 Move 项目 ==="
aptos move compile --save-metadata

if [ $? -ne 0 ]; then
    echo "编译失败！"
    exit 1
fi

echo "编译成功！"

echo ""
echo "=== 运行测试 ==="
aptos move test

if [ $? -ne 0 ]; then
    echo "测试失败！"
    exit 1
fi

echo "所有测试通过！"

echo ""
echo "=== 项目统计 ==="
move_files=$(find sources -name "*.move" | wc -l)
echo "Move 文件数量: $move_files"

total_lines=0
for file in sources/*.move; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file")
        total_lines=$((total_lines + lines))
        echo "  - $(basename $file): $lines 行"
    fi
done

echo "总代码行数: $total_lines"

echo ""
echo "=== 完成！==="
echo "你现在可以开始实践任务了！"
