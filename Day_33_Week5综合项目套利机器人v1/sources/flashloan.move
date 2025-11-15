/// 闪电贷模块
/// 提供无抵押的瞬时贷款功能

module arbitrage_bot_addr::flashloan {
    use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    // ==================== 错误码 ====================
    
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 1;
    const ERROR_REPAYMENT_FAILED: u64 = 2;
    const ERROR_UNAUTHORIZED: u64 = 3;

    // ==================== 常量 ====================
    
    /// 闪电贷费率: 0.09% (9/10000)
    const FEE_NUMERATOR: u64 = 9;
    const FEE_DENOMINATOR: u64 = 10000;

    // ==================== 结构体 ====================
    
    /// 流动性池
    struct LiquidityPool<phantom CoinType> has key {
        /// 池中的代币
        coins: Coin<CoinType>,
        /// 累计借出金额
        total_borrowed: u64,
        /// 累计费用收入
        total_fees: u64,
        /// 事件句柄
        flashloan_events: EventHandle<FlashloanEvent>,
    }

    /// 闪电贷事件
    struct FlashloanEvent has drop, store {
        borrower: address,
        amount: u64,
        fee: u64,
        timestamp: u64,
    }

    // ==================== 初始化 ====================
    
    /// 初始化流动性池
    public fun initialize_pool<CoinType>(
        admin: &signer,
        initial_liquidity: Coin<CoinType>
    ) {
        move_to(admin, LiquidityPool<CoinType> {
            coins: initial_liquidity,
            total_borrowed: 0,
            total_fees: 0,
            flashloan_events: account::new_event_handle<FlashloanEvent>(admin),
        });
    }

    // ==================== 核心功能 ====================
    
    /// 执行闪电贷
    /// 
    /// # 参数
    /// - `borrower`: 借款人
    /// - `amount`: 借款金额
    /// - `callback`: 回调函数，使用借来的代币执行操作并归还
    public fun execute_flashloan<CoinType>(
        borrower: &signer,
        amount: u64,
        callback: |&signer, Coin<CoinType>| -> Coin<CoinType>
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool<CoinType>>(@arbitrage_bot_addr);
        
        // 检查流动性
        let available = coin::value(&pool.coins);
        assert!(available >= amount, ERROR_INSUFFICIENT_LIQUIDITY);
        
        // 1. 借出代币
        let borrowed = coin::extract(&mut pool.coins, amount);
        
        // 2. 执行回调（用户的套利逻辑）
        let returned = callback(borrower, borrowed);
        
        // 3. 验证归还金额（本金 + 费用）
        let fee = calculate_fee(amount);
        let required_return = amount + fee;
        let actual_return = coin::value(&returned);
        
        assert!(actual_return >= required_return, ERROR_REPAYMENT_FAILED);
        
        // 4. 归还到池中
        coin::merge(&mut pool.coins, returned);
        
        // 5. 更新统计
        pool.total_borrowed = pool.total_borrowed + amount;
        pool.total_fees = pool.total_fees + fee;
        
        // 6. 发出事件
        event::emit_event(&mut pool.flashloan_events, FlashloanEvent {
            borrower: signer::address_of(borrower),
            amount,
            fee,
            timestamp: aptos_framework::timestamp::now_seconds(),
        });
    }

    // ==================== 辅助函数 ====================
    
    /// 计算闪电贷费用
    public fun calculate_fee(amount: u64): u64 {
        (amount * FEE_NUMERATOR) / FEE_DENOMINATOR
    }

    /// 添加流动性
    public fun add_liquidity<CoinType>(
        provider: &signer,
        coins: Coin<CoinType>
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool<CoinType>>(@arbitrage_bot_addr);
        coin::merge(&mut pool.coins, coins);
    }

    /// 移除流动性
    public fun remove_liquidity<CoinType>(
        admin: &signer,
        amount: u64
    ): Coin<CoinType> acquires LiquidityPool {
        assert!(signer::address_of(admin) == @arbitrage_bot_addr, ERROR_UNAUTHORIZED);
        
        let pool = borrow_global_mut<LiquidityPool<CoinType>>(@arbitrage_bot_addr);
        coin::extract(&mut pool.coins, amount)
    }

    // ==================== 查询函数 ====================
    
    /// 获取可用流动性
    public fun get_available_liquidity<CoinType>(): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<CoinType>>(@arbitrage_bot_addr);
        coin::value(&pool.coins)
    }

    /// 获取统计信息
    public fun get_stats<CoinType>(): (u64, u64) acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<CoinType>>(@arbitrage_bot_addr);
        (pool.total_borrowed, pool.total_fees)
    }
}
