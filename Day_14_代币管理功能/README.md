# Day 14: 代币管理功能

## 📚 学习目标

今天你将学习：
- 掌握代币的铸造（Mint）和销毁（Burn）机制
- 理解账户冻结（Freeze）功能的实现和应用
- 学习权限管理系统（MintCapability, BurnCapability, FreezeCapability）
- 实现代币供应量控制策略
- 掌握多签名和时间锁机制
- 了解代币升级和迁移方案

## 🎯 为什么重要

**代币管理功能**是构建专业级代币系统的关键：

- **供应量控制**：通过铸造/销毁实现经济模型
- **合规要求**：冻结功能满足监管需求（如 USDC）
- **安全管理**：权限分离降低风险
- **经济激励**：灵活的供应策略驱动生态发展

**真实案例**：
- **USDC**：使用冻结功能满足监管要求
- **APT**：通过定期销毁控制通胀
- **DeFi 协议**：铸造奖励代币激励用户
- **DAO**：使用多签管理铸造权限

## 💰 变现机会

掌握代币管理后，你可以：
1. **代币经济设计**：为项目设计代币模型（$2000-$5000/项目）
2. **合规代币开发**：开发符合监管要求的代币（$5000+）
3. **DeFi 协议开发**：构建复杂的激励机制
4. **审计服务**：审查代币管理安全性（$3000+/项目）

## 📖 今日课程安排

### 1. 理论学习（2 小时）
- 阅读 `01_理论学习/核心概念.md`
- 理解三大权限系统
- 学习供应量控制策略
- 研究 `01_理论学习/代码示例.move`

### 2. 实践任务（3.5 小时）
完成 `02_实践任务/任务说明.md` 中的任务：
- 任务 1：实现完整的权限管理系统
- 任务 2：构建通缩代币（Deflationary Token）
- 任务 3：开发多签名代币管理系统

### 3. 每日考试（1 小时）
- 完成选择题（30 题）
- 完成编程题（3 题）
- 对照答案自我评分

### 4. 复习总结（0.5 小时）
- 整理代币管理最佳实践
- 记录安全检查清单
- 准备明天的 AMM 学习

## 📋 核心知识点预览

### 三大权限能力

```
权限系统
├── MintCapability<CoinType>      // 铸造权限
│   ├── 创建新代币
│   ├── 控制供应量增长
│   └── 实现奖励分发
├── BurnCapability<CoinType>      // 销毁权限
│   ├── 永久移除代币
│   ├── 实现通缩机制
│   └── 回收代币
└── FreezeCapability<CoinType>    // 冻结权限
    ├── 冻结账户
    ├── 解冻账户
    └── 合规管理
```

### 核心操作

```move
// 铸造代币
coin::mint<MyCoin>(amount, &mint_cap)

// 销毁代币
coin::burn<MyCoin>(coin, &burn_cap)

// 冻结账户
coin::freeze_coin_store<MyCoin>(addr, &freeze_cap)

// 解冻账户
coin::unfreeze_coin_store<MyCoin>(addr, &freeze_cap)

// 转移权限
// 将 capability 从一个账户转移到另一个账户
```

### 供应量管理策略

```
固定供应：
- 初始铸造全部代币
- 销毁 MintCapability
- 总量不变

通胀模型：
- 保留 MintCapability
- 定期铸造新代币
- 实现奖励分发

通缩模型：
- 使用 BurnCapability
- 交易手续费销毁
- 定期回购销毁

混合模型：
- 同时使用铸造和销毁
- 动态调节供应量
- 维持价格稳定
```

## 🔑 关键概念

### 1. 权限分离原则

```move
// ❌ 不好：所有权限集中在一个账户
struct AllCapabilities has key {
    mint_cap: MintCapability<MyCoin>,
    burn_cap: BurnCapability<MyCoin>,
    freeze_cap: FreezeCapability<MyCoin>,
}

// ✓ 好：权限分离到不同账户/角色
struct MintManager has key {
    mint_cap: MintCapability<MyCoin>,
}

struct ComplianceManager has key {
    freeze_cap: FreezeCapability<MyCoin>,
}
```

### 2. 时间锁机制

```move
struct TimeLock has key {
    unlock_time: u64,
    mint_cap: MintCapability<MyCoin>,
}

// 只有在 unlock_time 之后才能使用权限
```

### 3. 多签名控制

```move
struct MultiSigMint has key {
    required_signatures: u64,
    signers: vector<address>,
    mint_cap: MintCapability<MyCoin>,
}

// 需要多个签名才能执行铸造
```

## 📚 学习资源

### 官方文档
- [Coin Module](https://aptos.dev/reference/move?branch=mainnet&page=aptos-framework/doc/coin.md)
- [Managed Coin](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/move-examples/managed_coin)
- [Capability Pattern](https://move-book.com/advanced-topics/capability.html)

### 开源项目
- [USDC on Aptos](https://github.com/circlefin/aptos-usdc) - 合规冻结功能
- [LayerZero Bridge](https://github.com/LayerZero-Labs) - 跨链代币管理
- [Thala Token](https://github.com/ThalaLabs) - 复杂的代币经济

### 工具
- [Aptos MultiSig](https://aptos.dev/guides/system-integrators-guide/#multisig-accounts) - 多签账户
- [Timelock Tools](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/move-examples/timelock)

## ✅ 完成标准

今日学习完成后，你应该能够：
- [ ] 理解三大权限能力的作用和风险
- [ ] 实现安全的铸造和销毁机制
- [ ] 掌握账户冻结/解冻功能
- [ ] 设计合理的权限管理架构
- [ ] 实现时间锁和多签控制
- [ ] 了解不同的供应量策略
- [ ] 完成所有实践任务
- [ ] 考试成绩达到 70 分以上

## 💡 学习建议

### 1. 安全第一
代币管理功能直接影响经济安全，务必：
- 仔细设计权限架构
- 多次测试关键功能
- 考虑极端情况
- 进行安全审计

### 2. 参考真实项目
阅读 USDC 和其他成熟项目的代码：
```bash
# Circle USDC 源码
https://github.com/circlefin/aptos-usdc
```

### 3. 权限管理检查清单
- [ ] 谁有铸造权限？
- [ ] 铸造有限额吗？
- [ ] 权限可以转移吗？
- [ ] 权限可以撤销吗？
- [ ] 有紧急暂停机制吗？

## ⚠️ 常见陷阱

### 1. 权限永久丢失

```move
// ❌ 危险：权限被销毁后无法恢复
fun destroy_mint_cap(mint_cap: MintCapability<MyCoin>) {
    let MintCapability {} = mint_cap;  // 永久销毁
}

// ✓ 更好：转移到安全账户
fun transfer_mint_cap(
    mint_cap: MintCapability<MyCoin>,
    to: address
) {
    move_to(&create_signer(to), MintManager { mint_cap });
}
```

### 2. 无限制铸造

```move
// ❌ 危险：没有限额检查
public fun mint(amount: u64, mint_cap: &MintCapability<MyCoin>) {
    coin::mint(amount, mint_cap);  // 可以无限铸造
}

// ✓ 安全：添加限额
const MAX_MINT_PER_DAY: u64 = 1000000 * 100000000;  // 100万个币

public fun mint_with_limit(
    amount: u64,
    mint_cap: &MintCapability<MyCoin>
) acquires MintLimit {
    let limit = borrow_global_mut<MintLimit>(@admin);
    assert!(amount <= MAX_MINT_PER_DAY, ERROR_EXCEED_LIMIT);
    // ... 铸造逻辑
}
```

### 3. 冻结滥用

```move
// ⚠️ 冻结权限需要严格控制
// 不应该由单一个人掌握
// 需要多签或治理流程
```

### 4. 供应量不一致

```move
// ❌ 问题：手动维护总供应量
struct MySupply has key {
    total: u64,  // 可能与实际不同步
}

// ✓ 使用框架提供的供应量追踪
let supply = coin::supply<MyCoin>();
```

## 🎯 实战技巧

### 1. 分阶段铸造

```move
struct VestingSchedule has key {
    total_amount: u64,
    released_amount: u64,
    start_time: u64,
    duration: u64,
    mint_cap: MintCapability<MyCoin>,
}

// 按时间逐步释放代币
public fun release_vested_tokens() acquires VestingSchedule {
    let schedule = borrow_global_mut<VestingSchedule>(@admin);
    let now = timestamp::now_seconds();
    let elapsed = now - schedule.start_time;
    
    let should_release = (schedule.total_amount * elapsed) / schedule.duration;
    let to_release = should_release - schedule.released_amount;
    
    if (to_release > 0) {
        let coins = coin::mint(to_release, &schedule.mint_cap);
        // 分发代币...
        schedule.released_amount = should_release;
    }
}
```

### 2. 紧急暂停

```move
struct EmergencyControl has key {
    paused: bool,
    admin: address,
}

public fun mint_with_pause_check(...) acquires EmergencyControl {
    let control = borrow_global<EmergencyControl>(@admin);
    assert!(!control.paused, ERROR_PAUSED);
    // 继续铸造...
}
```

### 3. 销毁手续费

```move
const BURN_FEE_PERCENTAGE: u64 = 1;  // 1%

public entry fun transfer_with_burn(
    from: &signer,
    to: address,
    amount: u64
) acquires Capabilities {
    let burn_amount = (amount * BURN_FEE_PERCENTAGE) / 100;
    let transfer_amount = amount - burn_amount;
    
    // 提取代币
    let coins = coin::withdraw<MyCoin>(from, amount);
    
    // 分离要销毁的部分
    let burn_coins = coin::extract(&mut coins, burn_amount);
    
    // 销毁手续费
    let caps = borrow_global<Capabilities>(@admin);
    coin::burn(burn_coins, &caps.burn_cap);
    
    // 转账剩余部分
    coin::deposit(to, coins);
}
```

## 📊 代币经济模型对比

| 模型 | 铸造 | 销毁 | 适用场景 | 案例 |
|------|------|------|---------|------|
| 固定供应 | 一次性 | 不支持 | 价值存储 | Bitcoin |
| 通胀模型 | 定期 | 不支持 | 奖励分发 | Ethereum |
| 通缩模型 | 不支持 | 手续费销毁 | 价值增长 | BNB |
| 混合模型 | 灵活 | 灵活 | 稳定币 | USDC |
| 算法稳定 | 动态 | 动态 | 价格稳定 | UST（失败案例） |

## 🔧 开发环境

### 编译项目
```bash
cd Day_14_代币管理功能
aptos move compile
```

### 运行测试
```bash
aptos move test
```

### 部署
```bash
aptos move publish
```

## 🌟 今日目标

完成今天的学习后，你将：
1. ✅ 掌握完整的代币管理体系
2. ✅ 能够设计安全的权限架构
3. ✅ 理解不同经济模型的实现
4. ✅ 为后续 DeFi 开发奠定基础

---

**预计学习时间**：7 小时  
**难度等级**：⭐⭐⭐⭐☆  
**重要程度**：⭐⭐⭐⭐⭐

掌握代币管理是成为 DeFi 专家的必经之路！🚀💎
