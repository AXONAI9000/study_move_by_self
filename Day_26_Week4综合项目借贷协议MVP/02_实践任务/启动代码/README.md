# 启动代码说明

## 📁 文件说明

本文件夹包含借贷协议 MVP 的启动代码模板，帮助你快速开始实现。

### 文件列表

- `lending_pool_template.move` - 借贷池核心逻辑模板
- `README.md` - 本文件

## 🚀 快速开始

### 1. 复制模板到你的答案文件夹

```bash
# Windows PowerShell
Copy-Item -Path ".\启动代码\lending_pool_template.move" -Destination ".\你的答案\lending_pool.move"
```

### 2. 开始实现

打开 `你的答案/lending_pool.move`，查找所有 `TODO` 标记并实现相应功能。

### 3. 推荐实现顺序

#### 阶段 1：基础结构（30分钟）
1. ✅ 实现 `initialize` 函数
2. ✅ 实现 `add_reserve` 函数
3. ✅ 编写初始化测试

#### 阶段 2：存取款（1.5小时）
4. ✅ 实现 `deposit` 函数
5. ✅ 实现 `withdraw` 函数（如果时间允许）
6. ✅ 编写存取款测试

#### 阶段 3：利率模型（1小时）
7. ✅ 实现 `calculate_utilization_rate`
8. ✅ 实现 `calculate_borrow_rate`
9. ✅ 实现 `calculate_supply_rate`
10. ✅ 实现 `calculate_linear_index`
11. ✅ 实现 `update_interest_rates`
12. ✅ 编写利率测试

#### 阶段 4：借还款（1.5小时）
13. ✅ 实现 `calculate_borrowing_power`
14. ✅ 实现 `calculate_health_factor_internal`
15. ✅ 实现 `borrow` 函数
16. ✅ 实现 `calculate_current_debt`
17. ✅ 实现 `repay` 函数
18. ✅ 编写借还款测试

#### 阶段 5：清算（1小时）
19. ✅ 实现 `liquidate` 函数
20. ✅ 编写清算测试

#### 阶段 6：查询函数（30分钟）
21. ✅ 实现 `get_reserve_data`
22. ✅ 实现 `get_user_health_factor`
23. ✅ 添加其他有用的查询函数

## 💡 实现提示

### 初始化

```move
public entry fun initialize(admin: &signer) {
    let admin_addr = signer::address_of(admin);
    
    // 检查未初始化
    assert!(!exists<LendingPool>(admin_addr), E_POOL_ALREADY_INITIALIZED);
    
    // 创建并移动资源
    move_to(admin, LendingPool {
        reserves: table::new(),
        user_data: table::new(),
        supported_assets: vector::empty(),
        admin: admin_addr,
        deposit_events: account::new_event_handle<DepositEvent>(admin),
        // ... 其他事件句柄
    });
}
```

### 存款

```move
public entry fun deposit(user: &signer, asset: String, amount: u64) acquires LendingPool {
    // 1. 基本验证
    assert!(amount > 0, E_AMOUNT_ZERO);
    
    // 2. 获取池和用户地址
    let user_addr = signer::address_of(user);
    let pool = borrow_global_mut<LendingPool>(@lending_protocol);
    
    // 3. 验证资产
    assert!(table::contains(&pool.reserves, &asset), E_ASSET_NOT_SUPPORTED);
    
    // 4. 更新利率
    update_interest_rates(&asset);
    
    // 5. 更新储备金
    let reserve = table::borrow_mut(&mut pool.reserves, &asset);
    reserve.total_deposits = reserve.total_deposits + amount;
    reserve.available_liquidity = reserve.available_liquidity + amount;
    
    // 6. 初始化或更新用户账户
    if (!table::contains(&pool.user_data, &user_addr)) {
        // 创建新账户
    };
    
    // 7. 更新用户抵押品
    // 8. 发射事件
}
```

### 利率计算

```move
fun calculate_borrow_rate(
    utilization_rate: u64,
    base_rate: u64,
    slope1: u64,
    slope2: u64,
    optimal_utilization: u64
): u64 {
    if (utilization_rate <= optimal_utilization) {
        // 第一段：线性增长
        let rate_increase = (utilization_rate as u128) * (slope1 as u128) / 
                           (optimal_utilization as u128);
        base_rate + (rate_increase as u64)
    } else {
        // 第二段：快速增长
        let excess = utilization_rate - optimal_utilization;
        let capacity = 10000 - optimal_utilization;
        let rate_increase = (excess as u128) * (slope2 as u128) / (capacity as u128);
        base_rate + slope1 + (rate_increase as u64)
    }
}
```

### 健康因子

```move
fun calculate_health_factor_internal(user_addr: address): u128 acquires LendingPool {
    let pool = borrow_global<LendingPool>(@lending_protocol);
    let user = table::borrow(&pool.user_data, &user_addr);
    
    // 没有借款则返回最大值
    if (simple_map::length(&user.borrows) == 0) {
        return MAX_U128
    };
    
    let total_collateral_value = 0u128;
    let total_borrow_value = 0u128;
    
    // 遍历抵押品
    // 遍历借款
    
    // 计算并返回
    if (total_borrow_value == 0) {
        MAX_U128
    } else {
        (total_collateral_value * PRECISION) / total_borrow_value
    }
}
```

## ⚠️ 注意事项

### 1. 精度处理

- 利率使用 RAY (10^27)
- 价格使用统一精度
- 避免整数除法精度损失

```move
// ✅ 正确
let result = (a as u128) * (b as u128) / (c as u128);

// ❌ 错误（可能溢出或精度损失）
let result = a * b / c;
```

### 2. 类型转换

```move
// u64 -> u128
let big_num = (small_num as u128);

// u128 -> u64（确保不溢出）
assert!(big_num <= (MAX_U64 as u128), E_OVERFLOW);
let small_num = (big_num as u64);
```

### 3. 除零保护

```move
// 始终检查除数
if (denominator == 0) {
    return 0;
};
let result = numerator / denominator;
```

### 4. 简化价格获取

由于我们是 MVP，可以使用固定价格或简化的价格函数：

```move
// 简化版价格获取
fun get_asset_price(asset: &String): u64 {
    if (asset == &string::utf8(b"APT")) {
        10_00000000 // $10
    } else if (asset == &string::utf8(b"USDC")) {
        1_00000000  // $1
    } else {
        1_00000000  // 默认
    }
}
```

## 🧪 测试建议

### 单元测试模板

```move
#[test_only]
module lending_protocol::lending_pool_tests {
    use lending_protocol::lending_pool;
    use std::string;
    
    #[test(admin = @0x123)]
    fun test_initialize(admin: &signer) {
        lending_pool::initialize(admin);
        // 验证初始化成功
    }
    
    #[test(admin = @0x123, user = @0x456)]
    fun test_deposit(admin: &signer, user: &signer) {
        // 1. 初始化
        lending_pool::initialize(admin);
        
        // 2. 添加资产
        lending_pool::add_reserve(
            admin,
            string::utf8(b"APT"),
            7500,  // LTV 75%
            8500,  // 清算阈值 85%
            500,   // 清算奖励 5%
            1000,  // 储备金因子 10%
            0,     // base_rate
            400,   // slope1
            7500,  // slope2
            8000   // optimal_utilization
        );
        
        // 3. 用户存款
        lending_pool::deposit(user, string::utf8(b"APT"), 100);
        
        // 4. 验证
        let (total_deposits, _, _) = lending_pool::get_reserve_data(string::utf8(b"APT"));
        assert!(total_deposits == 100, 0);
    }
}
```

## 📚 参考资源

### 需要时查看

1. **核心概念** - `../01_理论学习/核心概念.md`
2. **代码示例** - `../01_理论学习/代码示例.move`
3. **任务说明** - `../任务说明.md`

### Aptos 标准库文档

- [Table](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/table.move)
- [SimpleMap](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/sources/simple_map.move)
- [Event](https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/event.move)

## 🎯 完成标准

### 最小可行版本（MVP）

- [x] 初始化借贷池
- [x] 添加资产储备
- [x] 存款功能
- [x] 借款功能
- [x] 还款功能
- [x] 利率计算
- [x] 健康因子计算

### 扩展功能（可选）

- [ ] 取款功能
- [ ] 清算功能
- [ ] 价格预言机集成
- [ ] 闪电贷

## 💪 你可以做到的！

记住：
- 一步一步来
- 先让基础功能工作
- 逐步添加复杂性
- 经常测试

**开始编码吧！🚀**
