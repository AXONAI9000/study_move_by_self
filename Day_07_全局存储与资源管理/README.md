# Day 07: 全局存储与资源管理模式

## 📚 学习目标

今天你将学习：
- 掌握 Move 全局存储的核心操作
- 深入理解 `move_to`、`borrow_global`、`move_from` 的使用
- 学会资源生命周期管理
- 理解 `acquires` 关键字的作用和使用场景
- 掌握常见的资源管理模式

## 🎯 为什么重要

全局存储是 Move 最独特的特性之一：
- **账户模型**：每个地址可以存储多个不同类型的资源
- **类型安全**：编译期就能确保资源访问的安全性
- **所有权清晰**：资源归属明确，避免状态混乱
- 在 DeFi 开发中，几乎所有用户数据都存储在全局存储中

## 📖 今日课程安排

1. **理论学习**（1.5 小时）
   - 阅读 `01_理论学习/核心概念.md`
   - 研究 `01_理论学习/代码示例.move`
   
2. **实践任务**（3 小时）
   - 完成 `02_实践任务/任务说明.md` 中的三个任务
   
3. **每日考试**（1 小时）
   - 完成选择题和编程题
   - 自我评分（答案在 `03_每日考试/答案解析.md`）

4. **复习总结**（0.5 小时）
   - 整理笔记
   - 思考资源管理的最佳实践

## 🎓 学习资源

- [Move Book - Global Storage](https://move-language.github.io/move/global-storage-operators.html)
- [Aptos Framework - Account Module](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/framework/aptos-framework/sources)
- [Move Patterns - Resource Management](https://www.movepatterns.com/)

## ✅ 完成标准

- [ ] 理解全局存储的四个核心操作
- [ ] 掌握 acquires 关键字的使用规则
- [ ] 能够设计合理的资源结构
- [ ] 完成所有实践任务
- [ ] 考试成绩达到 70 分以上

## 💡 学习建议

1. 对比传统数据库的 CRUD 操作，理解 Move 的资源操作
2. 画出资源的生命周期图，理解从创建到销毁的全过程
3. 思考：为什么 Move 不允许覆盖已存在的资源？
4. 注意 `borrow_global` 和 `borrow_global_mut` 的区别

## ⚠️ 常见陷阱

1. **忘记添加 acquires 声明**：编译器会报错
2. **重复 move_to**：会导致 RESOURCE_ALREADY_EXISTS 错误
3. **访问不存在的资源**：会导致 RESOURCE_NOT_FOUND 错误
4. **借用冲突**：不能同时有可变和不可变借用

---

**预计学习时间**：6 小时  
**难度等级**：⭐⭐⭐⭐☆

掌握全局存储是成为 Move 高级开发者的关键一步！💪
