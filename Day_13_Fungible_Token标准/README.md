# Day 13: Fungible Token 标准（Coin Framework）

## 📚 学习目标

今天你将学习：
- 深入理解 Aptos Coin Framework 标准
- 掌握 CoinInfo 和 CoinStore 的设计
- 学会创建和管理代币
- 理解代币元数据的重要性
- 掌握代币转账和查询操作
- 了解 Coin 与 Fungible Asset 的区别

## 🎯 为什么重要

**Coin Framework** 是 Aptos 上同质化代币的核心标准，是构建 DeFi 生态的基础：

- **DeFi 基石**：所有 DeFi 协议都基于代币标准
- **标准化**：统一的接口让不同协议可以互操作
- **安全性**：经过审计的框架代码，降低安全风险
- **效率**：优化的实现提供最佳性能

**真实应用**：
- **DEX**：Liquidswap、PancakeSwap 使用 Coin 标准
- **借贷**：Aptin Finance、Aries Markets 基于 Coin 构建
- **稳定币**：USDC、USDT 在 Aptos 上使用 Coin 标准
- **治理代币**：几乎所有 DeFi 项目的治理代币

## 💰 变现机会

掌握 Coin Framework 后，你可以：
1. **发行代币**：为项目创建代币（$500-$2000/项目）
2. **DEX 开发**：构建去中心化交易所
3. **DeFi 协议**：开发借贷、质押等协议
4. **代币工具**：开发代币管理工具（$1000+/月订阅）

## 📖 今日课程安排

### 1. 理论学习（2 小时）
- 阅读 `01_理论学习/核心概念.md`
- 理解 Coin Framework 架构
- 学习代币生命周期管理
- 研究 `01_理论学习/代码示例.move`

### 2. 实践任务（3.5 小时）
完成 `02_实践任务/任务说明.md` 中的任务：
- 任务 1：创建基础代币
- 任务 2：实现代币转账功能
- 任务 3：构建代币水龙头（Faucet）

### 3. 每日考试（1 小时）
- 完成选择题（30 题）
- 完成编程题（3 题）
- 对照答案自我评分

### 4. 复习总结（0.5 小时）
- 整理 Coin Framework 知识点
- 记录关键 API
- 准备明天的代币管理学习

## 🎓 Week 3 开始！

欢迎来到 **Week 3: DeFi 核心协议**！

本周学习路线：
- **Day 13**：Fungible Token 标准（今天）✨
- **Day 14**：代币管理功能
- **Day 15**：AMM 原理与恒定乘积公式
- **Day 16**：简单 DEX - 流动性池
- **Day 17**：DEX - 交换功能
- **Day 18**：价格预言机集成
- **Day 19**：Week 3 综合项目 - 完整 DEX

## 📋 核心知识点预览

### Aptos Coin 框架核心组件

```
Coin Framework
├── CoinInfo<CoinType>          // 代币元数据
│   ├── name: String            // 代币名称
│   ├── symbol: String          // 代币符号
│   ├── decimals: u8            // 小数位数
│   └── supply: Option<u128>    // 总供应量
├── CoinStore<CoinType>         // 用户余额存储
│   ├── coin: Coin<CoinType>    // 持有的代币
│   ├── frozen: bool            // 是否冻结
│   └── deposit_events         // 存款事件
└── Capabilities                // 权限控制
    ├── MintCapability          // 铸造权限
    ├── BurnCapability          // 销毁权限
    └── FreezeCapability        // 冻结权限
```

### 核心函数

```move
// 初始化代币
coin::initialize<MyCoin>()

// 注册接收代币
coin::register<MyCoin>()

// 转账
coin::transfer<MyCoin>(from, to, amount)

// 查询余额
coin::balance<MyCoin>(addr)

// 铸造（需要权限）
coin::mint(amount, &mint_cap)

// 销毁（需要权限）
coin::burn(coin, &burn_cap)
```

## 🔑 关键概念

### 1. 泛型代币类型
```move
struct MyCoin {}  // 代币类型标识

// 使用泛型表示不同代币
CoinInfo<MyCoin>
CoinStore<MyCoin>
Coin<MyCoin>
```

### 2. 能力系统
```move
// 代币类型必须没有能力
struct MyCoin {}  // ✓ 正确

struct MyCoin has copy {}  // ✗ 错误：不能有 copy
```

### 3. 权限管理
```move
// 只有持有权限才能执行特权操作
struct MintCapability<phantom CoinType> has key, store {}
struct BurnCapability<phantom CoinType> has key, store {}
struct FreezeCapability<phantom CoinType> has key, store {}
```

## 📚 学习资源

### 官方文档
- [Aptos Coin Framework](https://aptos.dev/concepts/coin-and-token/)
- [Coin Module Reference](https://aptos.dev/reference/move?branch=mainnet&page=aptos-framework/doc/coin.md)
- [Managed Coin Example](https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/move-examples/managed_coin)

### 开源项目
- [LayerZero USDC](https://github.com/LayerZero-Labs/aptos-usdc)
- [Liquidswap Coins](https://github.com/pontem-network/liquidswap)
- [Aptos Names Coin](https://github.com/aptos-labs/aptos-names-contracts)

### 工具
- [Aptos Explorer](https://explorer.aptoslabs.com/) - 查看链上代币
- [Petra Wallet](https://petra.app/) - 代币钱包
- [Hippo Labs](https://hippo.space/) - 代币分析

## ✅ 完成标准

今日学习完成后，你应该能够：
- [ ] 理解 CoinInfo 和 CoinStore 的作用
- [ ] 独立创建一个新代币
- [ ] 实现代币的注册和转账
- [ ] 理解权限系统的工作原理
- [ ] 知道如何查询代币信息和余额
- [ ] 了解 Coin 和 Fungible Asset 的区别
- [ ] 完成所有实践任务
- [ ] 考试成绩达到 70 分以上

## 💡 学习建议

### 1. 对比学习
将 Aptos Coin 与你熟悉的 ERC20 对比：
- ERC20 的 `totalSupply` → Aptos 的 `supply`
- ERC20 的 `balanceOf` → Aptos 的 `coin::balance`
- ERC20 的 `transfer` → Aptos 的 `coin::transfer`

### 2. 实践为主
- 先在测试网创建一个代币
- 尝试转账和查询
- 部署代币水龙头
- 与其他同学互相转账测试

### 3. 源码阅读
阅读 Aptos Framework 中的 coin.move：
```bash
# 查看源码
https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/sources/coin.move
```

### 4. 记录笔记
整理一份 Coin Framework API 速查表。

## ⚠️ 常见陷阱

### 1. 代币类型能力
```move
// ❌ 错误：代币类型不能有能力
struct MyCoin has copy {}

// ✓ 正确：代币类型应该为空
struct MyCoin {}
```

### 2. 忘记注册
```move
// ❌ 用户未注册就转账会失败
coin::transfer<MyCoin>(from, to, amount);  // 如果 to 未注册会报错

// ✓ 正确：先检查或使用 deposit
if (!coin::is_account_registered<MyCoin>(to)) {
    coin::register<MyCoin>(&to_signer);
};
```

### 3. 精度问题
```move
// 如果 decimals = 8，那么 1 个代币 = 100000000 个最小单位
// 转账 1 个代币需要传入 100000000
let one_token = 100000000;  // 1.0 token with 8 decimals
```

### 4. 权限丢失
```move
// ⚠️ MintCapability 一旦丢失就无法再铸造
// 务必妥善保管或转移到安全账户
```

### 5. 整数溢出
```move
// 代币数量使用 u64，最大值约 18 * 10^18
// 对于高精度代币要注意溢出
const MAX_U64: u64 = 18446744073709551615;
```

## 🎯 实战技巧

### 代币设计最佳实践

**1. 选择合适的精度**
```
常见精度：
- 稳定币：6-8 位（如 USDC = 6）
- 治理代币：8 位
- 游戏代币：0-2 位（整数或少量小数）
```

**2. 供应量策略**
```
固定供应：
- supply: option::some(1000000 * 10^8)  // 1亿代币

无限供应：
- supply: option::none()  // 可无限铸造
```

**3. 权限管理**
```move
// 选项1：保留在创建者账户
move_to(creator, MintCapability<MyCoin> { ... });

// 选项2：转移到多签账户
coin::transfer_mint_cap(multisig_addr);

// 选项3：销毁权限（不可再铸造）
let MintCapability { } = mint_cap;  // 销毁
```

## 📊 性能对比

| 操作 | Gas 成本 | 说明 |
|------|---------|------|
| 初始化代币 | ~1000 | 只需一次 |
| 注册账户 | ~500 | 每个用户一次 |
| 转账 | ~200-300 | 取决于是否需要注册 |
| 查询余额 | 0 | view 函数免费 |
| 铸造 | ~300 | 需要权限 |
| 销毁 | ~200 | 需要权限 |

## 🔧 开发环境

### 编译项目
```bash
cd Day_13_Fungible_Token标准
aptos move compile
```

### 运行测试
```bash
aptos move test
```

### 发布代币
```bash
aptos move publish --named-addresses my_coin=default
```

## 🌟 今日目标

完成今天的学习后，你将：
1. ✅ 掌握 Aptos 代币标准
2. ✅ 能够独立创建和管理代币
3. ✅ 理解 DeFi 协议的基础
4. ✅ 为后续 DEX 开发做好准备

---

**预计学习时间**：7 小时  
**难度等级**：⭐⭐⭐☆☆  
**重要程度**：⭐⭐⭐⭐⭐

这是 DeFi 开发的起点，让我们开始吧！🚀💰
