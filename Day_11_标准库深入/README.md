# Day 11: 标准库深入

## 📚 学习目标

今天你将学习：
- 掌握 vector 的高级操作和性能优化
- 理解 Table 和 SmartTable 的区别与使用场景
- 学会 option 模块处理可选值
- 掌握 string 模块的字符串操作
- 了解其他常用标准库模块
- 学会选择合适的数据结构

## 🎯 为什么重要

Move 标准库是构建高效 DApp 的基础：
- **高效数据结构**：选对结构能大幅提升性能
- **Gas 优化**：不同数据结构的 Gas 成本差异巨大
- **代码质量**：善用标准库让代码更简洁可靠
- **实战必备**：DeFi、NFT 项目都大量使用这些库

**真实案例**：
- Liquidswap 使用 SmartTable 优化流动性池管理
- Aptos Names 使用 Table 存储域名映射
- 多数 DeFi 项目使用 vector 管理用户列表

## 📖 今日课程安排

1. **理论学习**（2 小时）
   - 阅读 `01_理论学习/核心概念.md`
   - 研究 `01_理论学习/代码示例.move`
   - 对比不同数据结构的性能
   
2. **实践任务**（3.5 小时）
   - 完成 `02_实践任务/任务说明.md` 中的三个任务
   - 任务 1：实现高效的用户管理系统
   - 任务 2：构建商品库存系统
   - 任务 3：开发订单簿（Order Book）
   
3. **每日考试**（1 小时）
   - 完成选择题和编程题
   - 自我评分（答案在 `03_每日考试/答案解析.md`）

4. **复习总结**（0.5 小时）
   - 整理各数据结构的选择标准
   - 建立性能优化清单

## 🎓 学习资源

### 官方文档
- [Move Standard Library](https://github.com/move-language/move/tree/main/language/move-stdlib/docs)
- [Aptos Standard Library](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/framework/aptos-stdlib)
- [Vector Module](https://aptos.dev/reference/move/?branch=mainnet&page=aptos-stdlib/doc/vector.md)
- [Table Module](https://aptos.dev/reference/move/?branch=mainnet&page=aptos-stdlib/doc/table.md)

### 性能基准
- [Gas 成本对比](https://aptos.dev/guides/move-guides/gas-profiling/)
- [数据结构性能分析](https://aptoslabs.medium.com/)

### 开源示例
- [Liquidswap 源码](https://github.com/pontem-network/liquidswap)
- [Aptos Framework 实现](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/framework)

## ✅ 完成标准

- [ ] 理解 vector、Table、SmartTable 的区别
- [ ] 掌握 option 模块的使用场景
- [ ] 能够根据需求选择合适的数据结构
- [ ] 了解各数据结构的 Gas 成本
- [ ] 完成所有实践任务
- [ ] 考试成绩达到 70 分以上

## 💡 学习建议

1. **对比学习**：将 vector、Table、SmartTable 的操作对比着学
2. **性能意识**：关注每个操作的 Gas 成本
3. **实战导向**：思考在 DeFi 项目中如何应用
4. **查阅源码**：阅读 Aptos Framework 的实际使用
5. **记录笔记**：整理各数据结构的适用场景

## ⚠️ 常见陷阱

1. **vector 的大小限制**：vector 不适合存储大量数据
2. **Table 的迭代成本**：Table 无法高效遍历所有元素
3. **SmartTable 的额外开销**：小数据集不需要 SmartTable
4. **string 的不可变性**：字符串操作可能产生新对象
5. **option 的展开错误**：未检查就 extract 会 panic

## 📊 数据结构速查表

| 数据结构 | 适用场景 | 优势 | 劣势 | Gas 成本 |
|---------|---------|------|------|---------|
| **vector** | 小型列表 | 遍历快 | 大小受限 | 低 |
| **Table** | 键值映射 | 随机访问 | 不可迭代 | 中 |
| **SmartTable** | 大型映射 | 可迭代 | 复杂度高 | 高 |
| **option** | 可选值 | 类型安全 | 需手动检查 | 极低 |
| **string** | 文本数据 | UTF-8支持 | 操作有限 | 低 |

## 🎯 性能优化要点

### Vector 优化
```move
// ❌ 避免：频繁在中间插入
vector::insert(&mut v, index, value);

// ✅ 推荐：在末尾添加
vector::push_back(&mut v, value);
```

### Table 优化
```move
// ❌ 避免：重复检查存在性
if (table::contains(&t, key)) {
    let value = table::borrow(&t, key);
}

// ✅ 推荐：使用 borrow_mut_with_default
let value = table::borrow_mut_with_default(&mut t, key, default);
```

### SmartTable 选择
```move
// 小数据集（< 100 项）：使用 Table
// 大数据集（> 100 项）且需要迭代：使用 SmartTable
// 只需随机访问：使用 Table
```

## 🔧 开发环境

确保已安装 Aptos CLI：
```bash
aptos --version
# 应该显示版本号
```

运行示例代码：
```bash
cd Day_11_标准库深入
aptos move compile
aptos move test
```

## 💼 实际应用场景

### 1. DeFi 协议
- **流动性池**：使用 Table 存储用户份额
- **价格预言机**：使用 vector 存储历史价格
- **交易对管理**：使用 SmartTable 管理所有交易对

### 2. NFT 市场
- **NFT 列表**：使用 SmartTable 存储 NFT 元数据
- **拍卖列表**：使用 vector 存储活跃拍卖
- **竞价记录**：使用 Table 按 NFT ID 索引

### 3. 游戏
- **玩家库存**：使用 Table 存储物品
- **排行榜**：使用 vector 存储前 100 名
- **任务系统**：使用 option 处理可选奖励

## 📝 本周回顾

这是 Week 2 的最后一天，本周你学习了：
- ✅ Day 06：泛型编程与能力系统
- ✅ Day 07：全局存储与资源管理
- ✅ Day 08：事件系统与链下索引
- ✅ Day 09：错误处理与断言
- ✅ Day 10：Move Prover 形式化验证
- 🎯 Day 11：标准库深入（今天）

**Week 2 目标**：掌握 Move 高级特性和工具

## 🚀 下一步预告

完成今天的学习后，你将进入 **Week 3：DeFi 核心协议**：
- Day 12：Week 2 综合项目 - 投票系统
- Day 13：Fungible Token 标准（Coin Framework）
- Day 14：代币管理功能
- 开始构建真实的 DeFi 应用！

---

**预计学习时间**：7 小时  
**难度等级**：⭐⭐⭐☆☆  
**重要程度**：⭐⭐⭐⭐⭐

掌握标准库是成为 Move 高手的必经之路！让我们开始吧！💪
