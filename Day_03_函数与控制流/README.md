# Day 03 - 函数与控制流

## 📚 学习目标
- 掌握函数的定义、调用与可见性控制
- 理解参数传递方式与多返回值
- 学习条件语句与循环结构的使用
- 掌握表达式与语句的区别
- 学习错误处理的最佳实践

## 📖 核心内容

### 1. 函数基础
- **函数定义**：`fun`关键字、参数、返回类型
- **参数传递**：按值、不可变引用`&T`、可变引用`&mut T`
- **返回值**：单返回值、多返回值（元组）、表达式返回

### 2. 函数可见性
- **私有函数**（默认）：模块内可见
- **公开函数**（`public`）：所有模块可见
- **友元函数**（`public(friend)`）：友元模块可见
- **入口函数**（`public entry`）：交易入口点

### 3. 条件控制
- **if表达式**：Move中的if是表达式，有返回值
- **if-else链**：多重条件判断
- **类型一致性**：两个分支必须返回相同类型

### 4. 循环结构
- **while循环**：条件循环
- **loop循环**：无限循环，需要break退出
- **break**：跳出循环
- **continue**：跳过当前迭代

### 5. 提前退出
- **return语句**：提前返回函数
- **abort语句**：终止整个交易
- **assert!宏**：条件检查，常用的错误处理方式

### 6. 表达式与语句
- **表达式**：有值，可以赋值给变量
- **语句**：无值（值为`()`）
- **分号作用**：将表达式转换为语句

## 🎯 为什么重要？

函数是组织代码的基本单元，控制流决定了程序的执行逻辑。掌握这些知识是编写任何有意义程序的必备基础：

- **函数**让我们能够复用代码、抽象逻辑
- **控制流**让程序能够做决策和重复操作
- **错误处理**保证程序的健壮性和安全性

## 📂 目录结构

```
Day_03_函数与控制流/
├── Move.toml                      # 项目配置
├── README.md                      # 本文件
├── 01_理论学习/
│   ├── 核心概念.md               # 详细的理论知识
│   └── 代码示例.move             # 完整的代码示例
├── 02_实践任务/
│   └── 任务说明.md               # 三个递进式编程任务
├── 03_每日考试/
│   ├── 选择题.md                 # 55道选择题（75分）
│   ├── 编程题.md                 # 3道编程题（50分）
│   └── 答案解析.md               # 完整答案和解析
└── sources/
    └── control_flow.move         # 可编译的示例代码
```

## 🚀 快速开始

### 1. 学习理论知识
```bash
# 阅读核心概念
cat 01_理论学习/核心概念.md
```

### 2. 查看代码示例
```bash
# 查看完整示例
cat 01_理论学习/代码示例.move
```

### 3. 编译和测试
```bash
# 编译项目
aptos move compile

# 运行所有测试
aptos move test

# 运行特定测试
aptos move test test_add
```

### 4. 完成实践任务
```bash
# 阅读任务要求
cat 02_实践任务/任务说明.md

# 创建你的解决方案
# 按照任务说明实现三个任务
```

### 5. 参加每日考试
```bash
# 做选择题和编程题
cat 03_每日考试/选择题.md
cat 03_每日考试/编程题.md

# 完成后查看答案
cat 03_每日考试/答案解析.md
```

## 💡 关键知识点

### 函数定义模板
```move
public fun function_name(param: Type): ReturnType {
    // 函数体
    return_value  // 最后一个表达式（无分号）自动返回
}
```

### 参数传递方式
```move
// 按值传递（Copy类型）
public fun by_value(x: u64): u64 { x + 1 }

// 不可变引用（只读）
public fun by_ref(x: &u64): u64 { *x + 1 }

// 可变引用（可修改）
public fun by_mut_ref(x: &mut u64) { *x = *x + 1 }
```

### if表达式
```move
// if是表达式，有返回值
let max = if (a > b) { a } else { b };

// 两个分支类型必须相同
let result = if (condition) {
    10
} else {
    20
};
```

### 循环结构
```move
// while循环
while (i < 10) {
    i = i + 1;
}

// loop循环（无限循环）
loop {
    if (condition) break;
}
```

### 错误处理
```move
// 定义错误码
const E_INSUFFICIENT_BALANCE: u64 = 1;

// 使用assert!检查
assert!(balance >= amount, E_INSUFFICIENT_BALANCE);

// 使用abort终止
if (invalid) abort E_ERROR;
```

## 📊 学习路径

```
第1天：函数基础
├── 函数定义与调用
├── 参数和返回值
└── 函数可见性

第2天：控制流
├── if条件表达式
├── while和loop循环
└── break和continue

第3天：综合应用
├── 错误处理
├── 常见算法模式
└── 最佳实践
```

## 🎓 实践任务

### 任务1：数学工具库（30分）
实现基础运算、质数检测、数字操作等函数。

### 任务2：向量操作库（35分）
实现统计、查找、转换、判断等向量操作。

### 任务3：游戏逻辑实现（35分）
实现猜数字游戏和井字棋判定逻辑。

## 📝 每日考试

- **选择题**：55道，每题5分（适当扩展），共75分
- **编程题**：3道，共50分
  - 递归函数（15分）
  - 控制流应用（20分）
  - 实用算法（15分）

## 🔑 核心代码片段

### 累加器模式
```move
public fun sum_to_n(n: u64): u64 {
    let mut sum = 0;
    let mut i = 0;
    while (i <= n) {
        sum = sum + i;
        i = i + 1;
    };
    sum
}
```

### 查找模式
```move
public fun find_in_range(start: u64, end: u64, target: u64): bool {
    let mut i = start;
    while (i <= end) {
        if (i == target) return true;
        i = i + 1;
    };
    false
}
```

### 守卫模式
```move
public fun transfer(from: &signer, amount: u64) {
    // 前置条件检查
    assert!(amount > 0, E_INVALID_AMOUNT);
    assert!(balance >= amount, E_INSUFFICIENT_BALANCE);
    
    // 执行核心逻辑
    // ...
}
```

## 🎯 学习建议

1. **先理论后实践**：仔细阅读核心概念，理解每个特性
2. **多写代码**：通过代码示例加深理解
3. **完成任务**：三个实践任务循序渐进
4. **参加考试**：检验学习效果
5. **反复练习**：多写、多改、多思考

## 🔗 相关资源

- [Move Book - Functions](https://move-language.github.io/move/functions.html)
- [Aptos Move Tutorial](https://aptos.dev/guides/move-guides/)
- Day 02：基本数据类型与变量
- Day 04：结构体与资源概念

## ✨ 下一步

完成Day 03的学习后，你将能够：
- ✅ 熟练定义和使用函数
- ✅ 掌握各种控制流结构
- ✅ 实现常见算法模式
- ✅ 进行有效的错误处理

准备好学习 **Day 04：结构体与资源概念** 了吗？

继续加油！💪
