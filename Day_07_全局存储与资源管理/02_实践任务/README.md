# Day 07 实践任务 - 参考答案

## 📁 项目结构

```
02_实践任务/
├── Move.toml                           # 项目配置文件
├── README.md                           # 本文件
├── sources/                            # 源代码目录
│   ├── task1_user_account.move        # 任务1：用户账户系统
│   ├── task2_registry.move            # 任务2：资源注册表
│   └── task3_multisig_wallet.move     # 任务3：多重签名钱包
└── scripts/                            # 测试脚本
    └── test_all.sh                     # 运行所有测试
```

## 🚀 快速开始

### 1. 安装依赖

确保已安装 Aptos CLI：
```bash
# 检查版本
aptos --version

# 如果未安装，请访问：https://aptos.dev/tools/aptos-cli/install-cli/
```

### 2. 运行测试

#### 测试所有任务
```bash
cd Day_07_全局存储与资源管理/02_实践任务
aptos move test
```

#### 测试单个任务
```bash
# 任务1：用户账户系统
aptos move test --filter user_account

# 任务2：资源注册表
aptos move test --filter registry

# 任务3：多重签名钱包
aptos move test --filter multisig_wallet
```

#### 查看详细输出
```bash
aptos move test --filter user_account -v
```

## 📝 任务说明

### 任务1：用户账户系统（35分）

**功能实现**：
- ✅ 用户注册和账户创建
- ✅ 用户资料更新
- ✅ 余额管理（存款、取款）
- ✅ 账户间转账
- ✅ 账户删除（需余额为0）

**关键技术点**：
- `move_to` 创建资源
- `borrow_global_mut` 修改资源
- 作用域分离避免借用冲突
- 所有权验证和错误处理

**测试覆盖**：
- ✅ 基本账户操作
- ✅ 资料更新
- ✅ 重复注册检测
- ✅ 余额不足检测
- ✅ 自我转账防护
- ✅ 账户删除验证

### 任务2：资源注册表（35分）

**功能实现**：
- ✅ 中心化注册表初始化
- ✅ 数据项注册和ID管理
- ✅ 数据项查询、更新、删除
- ✅ 用户项目列表管理
- ✅ 统计信息查询

**关键技术点**：
- `Table` 数据结构使用
- 集中式资源管理模式
- 所有权验证机制
- 多用户数据隔离

**测试覆盖**：
- ✅ 完整的CRUD操作
- ✅ 重复初始化检测
- ✅ 非所有者操作防护
- ✅ 多项目管理

### 任务3：多重签名钱包（30分）

**功能实现**：
- ✅ 多所有者钱包创建
- ✅ 存款功能
- ✅ 交易提交和ID管理
- ✅ 多方确认机制
- ✅ 交易执行和状态管理

**关键技术点**：
- 多方协作逻辑
- 确认数阈值验证
- 防重复确认
- 防重复执行
- 余额检查

**测试覆盖**：
- ✅ 完整交易流程
- ✅ 所有者验证
- ✅ 确认数不足防护
- ✅ 重复确认防护
- ✅ 余额不足防护
- ✅ 重复执行防护

## 🎯 评分标准

### 任务1（35分）
| 评分项 | 分数 | 说明 |
|--------|------|------|
| 功能完整性 | 15 | 所有函数正确实现 |
| acquires声明 | 10 | 正确使用acquires |
| 安全检查 | 10 | 完善的权限和余额验证 |

### 任务2（35分）
| 评分项 | 分数 | 说明 |
|--------|------|------|
| 注册表设计 | 15 | Table使用和数据结构设计 |
| 功能实现 | 15 | CRUD操作完整性 |
| 权限控制 | 5 | 所有者验证机制 |

### 任务3（30分）
| 评分项 | 分数 | 说明 |
|--------|------|------|
| 多签逻辑 | 15 | 确认和执行机制 |
| 安全验证 | 10 | 各类防护检查 |
| 测试通过 | 5 | 所有测试用例通过 |

## 💡 学习要点

### 1. 全局存储操作
```move
// 创建资源
move_to(account, Resource { ... });

// 读取资源
let resource = borrow_global<Resource>(addr);

// 修改资源
let resource = borrow_global_mut<Resource>(addr);

// 删除资源
let Resource { ... } = move_from<Resource>(addr);

// 检查存在
exists<Resource>(addr)
```

### 2. acquires 声明规则
```move
// 需要 acquires
public fun read(addr: address): u64 acquires Account {
    borrow_global<Account>(addr).balance
}

// 需要 acquires
public fun modify(account: &signer) acquires Account {
    let acc = borrow_global_mut<Account>(signer::address_of(account));
    acc.balance = acc.balance + 100;
}

// 不需要 acquires
public fun check(addr: address): bool {
    exists<Account>(addr)
}

// 不需要 acquires
public fun create(account: &signer) {
    move_to(account, Account { balance: 0 });
}
```

### 3. 避免借用冲突
```move
// ❌ 错误：可能产生借用冲突
public fun transfer(from: &signer, to: address, amount: u64) acquires Account {
    let from_acc = borrow_global_mut<Account>(signer::address_of(from));
    let to_acc = borrow_global_mut<Account>(to);  // 如果 from == to，冲突！
    // ...
}

// ✅ 正确：使用作用域分离
public fun transfer(from: &signer, to: address, amount: u64) acquires Account {
    let from_addr = signer::address_of(from);
    assert!(from_addr != to, E_SELF_TRANSFER);
    
    {
        let from_acc = borrow_global_mut<Account>(from_addr);
        from_acc.balance = from_acc.balance - amount;
    };
    
    {
        let to_acc = borrow_global_mut<Account>(to);
        to_acc.balance = to_acc.balance + amount;
    };
}
```

### 4. 错误处理最佳实践
```move
// 定义清晰的错误码
const E_ACCOUNT_NOT_FOUND: u64 = 1;
const E_INSUFFICIENT_BALANCE: u64 = 2;
const E_NOT_OWNER: u64 = 3;

// 使用 error 模块的标准函数
assert!(!exists<Account>(addr), error::already_exists(E_ACCOUNT_EXISTS));
assert!(balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
assert!(owner == addr, error::permission_denied(E_NOT_OWNER));
```

### 5. Table 数据结构使用
```move
use aptos_std::table::{Self, Table};

// 创建表
let items: Table<u64, Item> = table::new();

// 添加元素
table::add(&mut items, key, value);

// 检查存在
if (table::contains(&items, key)) { ... }

// 获取元素
let item = table::borrow(&items, key);

// 修改元素
let item = table::borrow_mut(&mut items, key);

// 删除元素
table::remove(&mut items, key);
```

## 🔍 常见错误排查

### 错误1：忘记 acquires 声明
```
error[E04005]: missing acquires annotation
```
**解决方案**：在函数签名中添加 `acquires ResourceType`

### 错误2：借用冲突
```
error[E04003]: borrowing rule violation
```
**解决方案**：使用作用域分离读写操作

### 错误3：资源已存在
```
runtime error: RESOURCE_ALREADY_EXISTS
```
**解决方案**：使用 `exists<T>()` 检查后再 `move_to`

### 错误4：资源不存在
```
runtime error: RESOURCE_NOT_FOUND
```
**解决方案**：使用 `exists<T>()` 检查或使用 `assert!`

## 📚 参考资源

- [Move Book - Global Storage](https://move-language.github.io/move/global-storage-operators.html)
- [Aptos Framework Documentation](https://aptos.dev/move/move-on-aptos)
- [Move Prover Guide](https://github.com/move-language/move/tree/main/language/move-prover)

## 🎉 完成标准

- [ ] 所有测试用例通过
- [ ] 代码符合 Move 编码规范
- [ ] 正确使用 acquires 声明
- [ ] 完善的错误处理
- [ ] 安全的权限验证

## 💪 进阶挑战

完成基础任务后，可以尝试：

1. **任务1扩展**：添加账户锁定/解锁功能
2. **任务2扩展**：实现分页查询功能
3. **任务3扩展**：添加交易取消和超时机制

---

**预计完成时间**：3-4 小时  
**难度等级**：⭐⭐⭐⭐☆

祝学习顺利！🚀
