/// # 闪电贷完整代码示例
/// 
/// 本文件包含闪电贷协议的完整实现示例，包括：
/// 1. 基础闪电贷协议
/// 2. 多资产闪电贷
/// 3. 套利策略集成
/// 4. 安全检查机制

module flash_loan::examples {
    use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event;
    use aptos_framework::timestamp;

    // ============================================
    // 示例 1: 基础闪电贷协议
    // ============================================
    
    /// Flash Loan Pool - 管理单一资产的流动性池
    struct Pool<phantom CoinType> has key {
        /// 流动性储备
        reserves: Coin<CoinType>,
        /// 手续费率（基点，30 = 0.3%）
        fee_rate: u64,
        /// 管理员地址
        admin: address,
        /// 统计：总闪电贷次数
        total_flash_loans: u64,
        /// 统计：总手续费收入
        total_fees: u64,
        /// 统计：总借贷量
        total_volume: u64,
        /// 暂停标志
        paused: bool,
    }

    /// FlashLoan - Hot Potato（没有任何能力）
    /// 必须在同一交易中被 repay() 消费
    struct FlashLoan {
        /// 借款金额
        amount: u64,
        /// 应付手续费
        fee: u64,
    }

    /// 闪电贷事件
    struct FlashLoanEvent has drop, store {
        borrower: address,
        amount: u64,
        fee: u64,
        timestamp: u64,
    }

    /// 还款事件
    struct RepayEvent has drop, store {
        borrower: address,
        amount: u64,
        fee: u64,
        timestamp: u64,
    }

    // === 错误码 ===
    const E_NOT_ADMIN: u64 = 1;
    const E_INSUFFICIENT_LIQUIDITY: u64 = 2;
    const E_INSUFFICIENT_REPAYMENT: u64 = 3;
    const E_POOL_PAUSED: u64 = 4;
    const E_ZERO_AMOUNT: u64 = 5;
    const E_INVALID_FEE_RATE: u64 = 6;

    // === 常量 ===
    const FEE_DENOMINATOR: u64 = 10000;  // 基点分母
    const MAX_FEE_RATE: u64 = 100;       // 最大手续费率 1%

    // ============================================
    // 管理函数
    // ============================================

    /// 初始化闪电贷池
    public entry fun initialize<CoinType>(
        admin: &signer,
        initial_liquidity: u64,
        fee_rate: u64
    ) {
        assert!(fee_rate <= MAX_FEE_RATE, E_INVALID_FEE_RATE);
        
        let admin_addr = signer::address_of(admin);
        
        // 创建资产池
        let pool = Pool<CoinType> {
            reserves: coin::withdraw<CoinType>(admin, initial_liquidity),
            fee_rate,
            admin: admin_addr,
            total_flash_loans: 0,
            total_fees: 0,
            total_volume: 0,
            paused: false,
        };
        
        // 存储到管理员账户下
        move_to(admin, pool);
    }

    /// 添加流动性
    public entry fun add_liquidity<CoinType>(
        provider: &signer,
        pool_address: address,
        amount: u64
    ) acquires Pool {
        let coins = coin::withdraw<CoinType>(provider, amount);
        let pool = borrow_global_mut<Pool<CoinType>>(pool_address);
        coin::merge(&mut pool.reserves, coins);
    }

    /// 移除流动性（仅管理员）
    public entry fun remove_liquidity<CoinType>(
        admin: &signer,
        amount: u64
    ) acquires Pool {
        let admin_addr = signer::address_of(admin);
        let pool = borrow_global_mut<Pool<CoinType>>(admin_addr);
        assert!(pool.admin == admin_addr, E_NOT_ADMIN);
        
        let coins = coin::extract(&mut pool.reserves, amount);
        coin::deposit(admin_addr, coins);
    }

    // ============================================
    // 核心闪电贷函数
    // ============================================

    /// 闪电贷借款
    /// 
    /// # 参数
    /// - pool_address: 资产池地址
    /// - amount: 借款金额
    /// 
    /// # 返回
    /// - (Coin<CoinType>, FlashLoan): 借入的代币和 Hot Potato
    /// 
    /// # 注意
    /// - 必须在同一交易中调用 repay() 归还
    /// - FlashLoan 是 Hot Potato，无法丢弃
    public fun flash_loan<CoinType>(
        pool_address: address,
        amount: u64
    ): (Coin<CoinType>, FlashLoan) acquires Pool {
        // 1. 获取池子
        let pool = borrow_global_mut<Pool<CoinType>>(pool_address);
        
        // 2. 安全检查
        assert!(!pool.paused, E_POOL_PAUSED);
        assert!(amount > 0, E_ZERO_AMOUNT);
        assert!(
            coin::value(&pool.reserves) >= amount,
            E_INSUFFICIENT_LIQUIDITY
        );
        
        // 3. 计算手续费
        let fee = calculate_fee(amount, pool.fee_rate);
        
        // 4. 提取资金
        let coins = coin::extract(&mut pool.reserves, amount);
        
        // 5. 创建 Hot Potato
        let flash_loan = FlashLoan { amount, fee };
        
        // 6. 更新统计
        pool.total_flash_loans = pool.total_flash_loans + 1;
        pool.total_volume = pool.total_volume + amount;
        
        // 7. 发射事件
        event::emit(FlashLoanEvent {
            borrower: tx_context::sender(),
            amount,
            fee,
            timestamp: timestamp::now_seconds(),
        });
        
        (coins, flash_loan)
    }

    /// 闪电贷还款
    /// 
    /// # 参数
    /// - pool_address: 资产池地址
    /// - coins: 归还的代币（本金 + 手续费）
    /// - flash_loan: FlashLoan Hot Potato
    /// 
    /// # 注意
    /// - 必须归还足够的金额（本金 + 手续费）
    /// - 消费 FlashLoan，使其无法再被使用
    public fun repay<CoinType>(
        pool_address: address,
        coins: Coin<CoinType>,
        flash_loan: FlashLoan
    ) acquires Pool {
        // 1. 解构 FlashLoan（消费 Hot Potato）
        let FlashLoan { amount, fee } = flash_loan;
        
        // 2. 检查归还金额
        let repay_amount = coin::value(&coins);
        assert!(
            repay_amount >= amount + fee,
            E_INSUFFICIENT_REPAYMENT
        );
        
        // 3. 获取池子
        let pool = borrow_global_mut<Pool<CoinType>>(pool_address);
        
        // 4. 记录归还前余额（用于不变量检查）
        let balance_before = coin::value(&pool.reserves);
        
        // 5. 归还资金
        coin::merge(&mut pool.reserves, coins);
        
        // 6. 不变量检查：余额应增加至少 fee
        let balance_after = coin::value(&pool.reserves);
        assert!(balance_after >= balance_before + fee, E_INVARIANT_VIOLATION);
        
        // 7. 更新统计
        pool.total_fees = pool.total_fees + fee;
        
        // 8. 发射事件
        event::emit(RepayEvent {
            borrower: tx_context::sender(),
            amount,
            fee,
            timestamp: timestamp::now_seconds(),
        });
    }

    // ============================================
    // 辅助函数
    // ============================================

    /// 计算手续费
    public fun calculate_fee(amount: u64, fee_rate: u64): u64 {
        (amount * fee_rate) / FEE_DENOMINATOR
    }

    /// 查询池子流动性
    public fun get_liquidity<CoinType>(pool_address: address): u64 acquires Pool {
        let pool = borrow_global<Pool<CoinType>>(pool_address);
        coin::value(&pool.reserves)
    }

    /// 查询手续费率
    public fun get_fee_rate<CoinType>(pool_address: address): u64 acquires Pool {
        let pool = borrow_global<Pool<CoinType>>(pool_address);
        pool.fee_rate
    }

    // ============================================
    // 示例 2: 套利策略集成
    // ============================================

    /// DEX 套利示例
    /// 展示如何使用闪电贷进行 DEX 套利
    public entry fun arbitrage_example<CoinX, CoinY>(
        user: &signer,
        pool_address: address,
        dex_a_address: address,
        dex_b_address: address,
        amount: u64
    ) acquires Pool {
        // 1. 闪电贷借入 CoinX
        let (borrowed_x, flash_loan) = flash_loan<CoinX>(pool_address, amount);
        
        // 2. 在 DEX A 用 CoinX 买 CoinY
        let bought_y = dex::swap<CoinX, CoinY>(
            dex_a_address,
            borrowed_x,
            0  // min_out, 实际应计算滑点保护
        );
        
        // 3. 在 DEX B 用 CoinY 卖回 CoinX
        let sold_x = dex::swap<CoinY, CoinX>(
            dex_b_address,
            bought_y,
            amount + flash_loan.fee  // 至少需要这么多才能还款
        );
        
        // 4. 归还闪电贷
        repay<CoinX>(pool_address, sold_x, flash_loan);
        
        // 5. 剩余的就是利润（如果有的话）
        // 利润会留在用户账户中
    }

    // ============================================
    // 示例 3: 多资产闪电贷
    // ============================================

    /// 多资产闪电贷结构
    struct MultiFlashLoan {
        loans: vector<FlashLoanInfo>,
    }

    struct FlashLoanInfo has drop, store {
        coin_type: TypeInfo,
        amount: u64,
        fee: u64,
    }

    /// 同时借入多种资产
    /// 
    /// 使用场景：
    /// - 三角套利需要多种代币
    /// - 复杂的清算策略
    public fun multi_flash_loan<CoinA, CoinB>(
        pool_a_address: address,
        pool_b_address: address,
        amount_a: u64,
        amount_b: u64
    ): (Coin<CoinA>, Coin<CoinB>, MultiFlashLoan) acquires Pool {
        // 1. 借入第一个资产
        let (coins_a, flash_loan_a) = flash_loan<CoinA>(pool_a_address, amount_a);
        
        // 2. 借入第二个资产
        let (coins_b, flash_loan_b) = flash_loan<CoinB>(pool_b_address, amount_b);
        
        // 3. 创建多资产 Hot Potato
        let multi_loan = MultiFlashLoan {
            loans: vector[
                FlashLoanInfo {
                    coin_type: type_info::type_of<CoinA>(),
                    amount: flash_loan_a.amount,
                    fee: flash_loan_a.fee,
                },
                FlashLoanInfo {
                    coin_type: type_info::type_of<CoinB>(),
                    amount: flash_loan_b.amount,
                    fee: flash_loan_b.fee,
                }
            ]
        };
        
        (coins_a, coins_b, multi_loan)
    }

    /// 归还多资产闪电贷
    public fun multi_repay<CoinA, CoinB>(
        pool_a_address: address,
        pool_b_address: address,
        coins_a: Coin<CoinA>,
        coins_b: Coin<CoinB>,
        multi_loan: MultiFlashLoan
    ) acquires Pool {
        let MultiFlashLoan { loans } = multi_loan;
        
        // 提取贷款信息
        let info_a = vector::borrow(&loans, 0);
        let info_b = vector::borrow(&loans, 1);
        
        // 重新创建单个 FlashLoan 用于还款
        let flash_loan_a = FlashLoan {
            amount: info_a.amount,
            fee: info_a.fee,
        };
        let flash_loan_b = FlashLoan {
            amount: info_b.amount,
            fee: info_b.fee,
        };
        
        // 分别还款
        repay<CoinA>(pool_a_address, coins_a, flash_loan_a);
        repay<CoinB>(pool_b_address, coins_b, flash_loan_b);
    }

    // ============================================
    // 示例 4: 三角套利策略
    // ============================================

    /// 三角套利
    /// Path: CoinX → CoinY → CoinZ → CoinX
    /// 
    /// 市场状态：
    /// - Pool A: X/Y 价格偏低
    /// - Pool B: Y/Z 价格正常
    /// - Pool C: Z/X 价格正常
    /// 
    /// 套利路径：
    /// 1. 借 X
    /// 2. A: X → Y (买入便宜的 Y)
    /// 3. B: Y → Z
    /// 4. C: Z → X (回到 X)
    /// 5. 还 X（应该有盈余）
    public entry fun triangular_arbitrage<CoinX, CoinY, CoinZ>(
        user: &signer,
        flash_pool: address,
        pool_a: address,  // X/Y
        pool_b: address,  // Y/Z
        pool_c: address,  // Z/X
        borrow_amount: u64
    ) acquires Pool {
        // 1. 闪电贷借入 CoinX
        let (borrowed_x, flash_loan) = flash_loan<CoinX>(flash_pool, borrow_amount);
        
        // 2. Pool A: X → Y
        let bought_y = dex::swap<CoinX, CoinY>(pool_a, borrowed_x, 0);
        
        // 3. Pool B: Y → Z
        let bought_z = dex::swap<CoinY, CoinZ>(pool_b, bought_y, 0);
        
        // 4. Pool C: Z → X
        let final_x = dex::swap<CoinZ, CoinX>(
            pool_c,
            bought_z,
            borrow_amount + flash_loan.fee  // 至少需要足够还款
        );
        
        // 5. 归还闪电贷
        repay<CoinX>(flash_pool, final_x, flash_loan);
        
        // 如果有利润，会留在用户账户
    }

    // ============================================
    // 示例 5: 清算套利策略
    // ============================================

    /// 使用闪电贷进行清算套利
    /// 
    /// 流程：
    /// 1. 闪电贷借入清算所需代币
    /// 2. 清算不良债务，获得折扣抵押品
    /// 3. 卖出抵押品
    /// 4. 归还闪电贷
    /// 5. 保留利润
    public entry fun liquidation_arbitrage<DebtCoin, CollateralCoin>(
        liquidator: &signer,
        flash_pool: address,
        lending_protocol: address,
        debt_holder: address,
        debt_amount: u64
    ) acquires Pool {
        // 1. 闪电贷借入债务代币
        let (debt_coins, flash_loan) = flash_loan<DebtCoin>(
            flash_pool,
            debt_amount
        );
        
        // 2. 清算债务，获得抵押品
        // 通常会得到 110% 价值的抵押品（10% 清算奖励）
        let collateral = lending::liquidate<DebtCoin, CollateralCoin>(
            lending_protocol,
            debt_holder,
            debt_coins
        );
        
        // 3. 在 DEX 卖出抵押品换回债务代币
        let repay_coins = dex::swap<CollateralCoin, DebtCoin>(
            dex_address,
            collateral,
            debt_amount + flash_loan.fee
        );
        
        // 4. 归还闪电贷
        repay<DebtCoin>(flash_pool, repay_coins, flash_loan);
        
        // 5. 如果清算奖励足够，会有利润留下
    }

    // ============================================
    // 示例 6: 安全检查机制
    // ============================================

    /// 高级安全检查
    module flash_loan::security {
        
        /// 重入保护（Move 自动提供，但这里展示概念）
        struct ReentrancyGuard has key {
            locked: bool,
        }
        
        /// 价格操纵检查
        /// 比较闪电贷前后的价格变化
        public fun check_price_manipulation<CoinX, CoinY>(
            price_before: u64,
            price_after: u64,
            max_deviation_bps: u64  // 最大允许偏差（基点）
        ) {
            let deviation = if (price_after > price_before) {
                ((price_after - price_before) * 10000) / price_before
            } else {
                ((price_before - price_after) * 10000) / price_before
            };
            
            assert!(
                deviation <= max_deviation_bps,
                E_PRICE_MANIPULATION_DETECTED
            );
        }
        
        /// Gas 限制检查
        /// 防止恶意用户消耗过多 Gas
        public fun check_gas_limit(gas_used: u64, max_gas: u64) {
            assert!(gas_used <= max_gas, E_GAS_LIMIT_EXCEEDED);
        }
        
        /// 白名单检查
        /// 某些高风险操作可能需要白名单
        public fun check_whitelist(user: address, whitelist: &vector<address>) {
            assert!(
                vector::contains(whitelist, &user),
                E_NOT_WHITELISTED
            );
        }
    }

    // ============================================
    // 测试辅助函数
    // ============================================

    #[test_only]
    public fun init_for_test<CoinType>(
        admin: &signer,
        liquidity: u64,
        fee_rate: u64
    ) {
        initialize<CoinType>(admin, liquidity, fee_rate);
    }

    #[test_only]
    public fun destroy_flash_loan_for_test(flash_loan: FlashLoan) {
        let FlashLoan { amount: _, fee: _ } = flash_loan;
    }
}

// ============================================
// 使用示例总结
// ============================================

/*
## 基础使用

```move
// 1. 初始化池子
flash_loan::initialize<USDC>(admin, 1000000, 30);  // 0.3% 手续费

// 2. 借款
let (coins, flash_loan) = flash_loan::flash_loan<USDC>(pool_addr, 10000);

// 3. 执行你的策略
// ... 套利、清算等 ...

// 4. 归还（必须！）
flash_loan::repay<USDC>(pool_addr, coins, flash_loan);
```

## 套利示例

```move
public entry fun my_arbitrage(user: &signer) {
    // 借 10,000 USDC
    let (usdc, flash_loan) = flash_loan::flash_loan<USDC>(pool, 10000);
    
    // 在 DEX A 买 APT (便宜)
    let apt = dex_a::swap<USDC, APT>(usdc);
    
    // 在 DEX B 卖 APT (贵)
    let usdc_back = dex_b::swap<APT, USDC>(apt);
    
    // 还款
    flash_loan::repay<USDC>(pool, usdc_back, flash_loan);
    
    // 利润自动留在账户中
}
```

## 安全要点

1. ✅ Hot Potato 确保必须还款
2. ✅ 检查流动性足够
3. ✅ 验证归还金额
4. ✅ 不变量检查（余额增加）
5. ✅ 事件记录所有操作

## 常见错误

❌ 忘记还款 → 编译错误（Hot Potato 保护）
❌ 还款不足 → E_INSUFFICIENT_REPAYMENT
❌ 流动性不足 → E_INSUFFICIENT_LIQUIDITY
❌ 池子暂停 → E_POOL_PAUSED
*/
