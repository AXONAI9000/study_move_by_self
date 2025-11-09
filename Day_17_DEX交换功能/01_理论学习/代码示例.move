/// Day 17 代码示例：完整的 DEX Swap 实现
/// 
/// 本模块展示了一个生产级的 Swap 实现，包括：
/// 1. Exact Input 和 Exact Output 两种交换方式
/// 2. 手续费计算和分配
/// 3. 滑点保护机制
/// 4. 多跳路由支持
/// 5. 完整的事件系统
/// 
/// 依赖 Day 16 的流动性池实现

module swap_addr::swap {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_std::type_info;

    // ==================== 错误码 ====================

    const ERROR_ZERO_AMOUNT: u64 = 200;
    const ERROR_INSUFFICIENT_OUTPUT: u64 = 201;
    const ERROR_EXCESSIVE_INPUT: u64 = 202;
    const ERROR_SLIPPAGE_EXCEEDED: u64 = 203;
    const ERROR_POOL_NOT_EXISTS: u64 = 204;
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 205;
    const ERROR_K_INVARIANT: u64 = 206;
    const ERROR_INVALID_PATH: u64 = 207;
    const ERROR_EXPIRED: u64 = 208;
    const ERROR_IDENTICAL_TOKENS: u64 = 209;

    // ==================== 常量 ====================

    /// 手续费率：30 基点 = 0.3%
    const FEE_RATE: u64 = 30;
    const FEE_DENOMINATOR: u64 = 10000;
    
    /// 协议费用：手续费的 1/6 (可选)
    const PROTOCOL_FEE_SHARE: u64 = 1;
    const PROTOCOL_FEE_DENOMINATOR: u64 = 6;

    /// 最小流动性（防止除零）
    const MINIMUM_LIQUIDITY: u64 = 1000;

    // ==================== 数据结构 ====================

    /// 流动性池（复用 Day 16 的设计）
    struct LiquidityPool<phantom X, phantom Y> has key {
        reserve_x: Coin<X>,
        reserve_y: Coin<Y>,
        lp_token_supply: u64,
        /// 累积的协议费用
        protocol_fee_x: Coin<X>,
        protocol_fee_y: Coin<Y>,
        /// 事件句柄
        swap_events: EventHandle<SwapEvent>,
        sync_events: EventHandle<SyncEvent>,
    }

    /// Swap 事件
    struct SwapEvent has drop, store {
        user: address,
        token_in: String,
        token_out: String,
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        reserve_in_after: u64,
        reserve_out_after: u64,
        timestamp: u64,
    }

    /// 储备同步事件
    struct SyncEvent has drop, store {
        reserve_x: u64,
        reserve_y: u64,
        timestamp: u64,
    }

    // ==================== 核心 Swap 函数 ====================

    /// Exact Input Swap: 用户指定输入数量
    /// 
    /// # 参数
    /// - `user`: 用户账户
    /// - `amount_in`: 输入代币数量
    /// - `min_amount_out`: 最小接受的输出数量（滑点保护）
    /// 
    /// # 示例
    /// ```
    /// swap_exact_input<USDC, APT>(user, 1000_000000, 49_00000000);
    /// // 用 1000 USDC 换 APT，最少接受 49 APT
    /// ```
    public entry fun swap_exact_input<X, Y>(
        user: &signer,
        amount_in: u64,
        min_amount_out: u64,
    ) acquires LiquidityPool {
        // 1. 基础验证
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);
        assert!(pool_exists<X, Y>(), ERROR_POOL_NOT_EXISTS);
        
        let user_addr = signer::address_of(user);
        
        // 2. 获取池子并检查储备
        let pool = borrow_global_mut<LiquidityPool<X, Y>>(@swap_addr);
        let reserve_in = coin::value(&pool.reserve_x);
        let reserve_out = coin::value(&pool.reserve_y);
        
        assert!(
            reserve_in > 0 && reserve_out > 0, 
            ERROR_INSUFFICIENT_LIQUIDITY
        );
        
        // 3. 计算输出数量（带手续费）
        let amount_out = get_amount_out_internal(
            amount_in,
            reserve_in,
            reserve_out,
        );
        
        // 4. 滑点检查
        assert!(
            amount_out >= min_amount_out, 
            ERROR_SLIPPAGE_EXCEEDED
        );
        
        // 5. 执行代币转移
        let coins_in = coin::withdraw<X>(user, amount_in);
        let coins_out = coin::extract(&mut pool.reserve_y, amount_out);
        
        // 6. 更新储备
        coin::merge(&mut pool.reserve_x, coins_in);
        coin::deposit(user_addr, coins_out);
        
        // 7. K 值验证
        verify_k_invariant<X, Y>(reserve_in, reserve_out);
        
        // 8. 发出事件
        emit_swap_event(
            pool,
            user_addr,
            type_info::type_name<X>(),
            type_info::type_name<Y>(),
            amount_in,
            amount_out,
            calculate_fee(amount_in),
            coin::value(&pool.reserve_x),
            coin::value(&pool.reserve_y),
        );
        
        emit_sync_event(pool);
    }

    /// Exact Output Swap: 用户指定输出数量
    /// 
    /// # 参数
    /// - `user`: 用户账户
    /// - `amount_out`: 期望的输出数量
    /// - `max_amount_in`: 最大愿意支付的输入数量（滑点保护）
    /// 
    /// # 示例
    /// ```
    /// swap_exact_output<USDC, APT>(user, 50_00000000, 1050_000000);
    /// // 要得到 50 APT，最多支付 1050 USDC
    /// ```
    public entry fun swap_exact_output<X, Y>(
        user: &signer,
        amount_out: u64,
        max_amount_in: u64,
    ) acquires LiquidityPool {
        // 1. 基础验证
        assert!(amount_out > 0, ERROR_ZERO_AMOUNT);
        assert!(pool_exists<X, Y>(), ERROR_POOL_NOT_EXISTS);
        
        let user_addr = signer::address_of(user);
        
        // 2. 获取池子并检查储备
        let pool = borrow_global_mut<LiquidityPool<X, Y>>(@swap_addr);
        let reserve_in = coin::value(&pool.reserve_x);
        let reserve_out = coin::value(&pool.reserve_y);
        
        assert!(
            reserve_in > 0 && reserve_out > 0, 
            ERROR_INSUFFICIENT_LIQUIDITY
        );
        assert!(
            amount_out < reserve_out,
            ERROR_INSUFFICIENT_OUTPUT
        );
        
        // 3. 计算所需输入数量
        let amount_in = get_amount_in_internal(
            amount_out,
            reserve_in,
            reserve_out,
        );
        
        // 4. 滑点检查
        assert!(
            amount_in <= max_amount_in, 
            ERROR_EXCESSIVE_INPUT
        );
        
        // 5. 执行代币转移
        let coins_in = coin::withdraw<X>(user, amount_in);
        let coins_out = coin::extract(&mut pool.reserve_y, amount_out);
        
        // 6. 更新储备
        coin::merge(&mut pool.reserve_x, coins_in);
        coin::deposit(user_addr, coins_out);
        
        // 7. K 值验证
        verify_k_invariant<X, Y>(reserve_in, reserve_out);
        
        // 8. 发出事件
        emit_swap_event(
            pool,
            user_addr,
            type_info::type_name<X>(),
            type_info::type_name<Y>(),
            amount_in,
            amount_out,
            calculate_fee(amount_in),
            coin::value(&pool.reserve_x),
            coin::value(&pool.reserve_y),
        );
        
        emit_sync_event(pool);
    }

    // ==================== 路由功能 ====================

    /// 两跳交换：X → Z → Y
    /// 
    /// # 示例
    /// ```
    /// swap_two_hop<USDC, APT, TokenA>(user, 1000_000000, 45_00000000);
    /// // USDC → APT → TokenA
    /// ```
    public entry fun swap_two_hop<X, Y, Z>(
        user: &signer,
        amount_in: u64,
        min_amount_out: u64,
    ) acquires LiquidityPool {
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);
        
        // 检查不是相同代币
        assert!(
            type_info::type_of<X>() != type_info::type_of<Y>(),
            ERROR_IDENTICAL_TOKENS
        );
        
        let user_addr = signer::address_of(user);
        
        // 第一跳：X → Z
        let pool1 = borrow_global_mut<LiquidityPool<X, Z>>(@swap_addr);
        let reserve_x = coin::value(&pool1.reserve_x);
        let reserve_z = coin::value(&pool1.reserve_y);
        
        let amount_z = get_amount_out_internal(amount_in, reserve_x, reserve_z);
        
        let coins_in = coin::withdraw<X>(user, amount_in);
        let coins_z = coin::extract(&mut pool1.reserve_y, amount_z);
        coin::merge(&mut pool1.reserve_x, coins_in);
        
        emit_sync_event(pool1);
        
        // 第二跳：Z → Y
        let pool2 = borrow_global_mut<LiquidityPool<Z, Y>>(@swap_addr);
        let reserve_z2 = coin::value(&pool2.reserve_x);
        let reserve_y = coin::value(&pool2.reserve_y);
        
        let amount_out = get_amount_out_internal(
            coin::value(&coins_z), 
            reserve_z2, 
            reserve_y
        );
        
        // 最终滑点检查
        assert!(amount_out >= min_amount_out, ERROR_SLIPPAGE_EXCEEDED);
        
        let coins_out = coin::extract(&mut pool2.reserve_y, amount_out);
        coin::merge(&mut pool2.reserve_x, coins_z);
        coin::deposit(user_addr, coins_out);
        
        emit_sync_event(pool2);
    }

    // ==================== 内部计算函数 ====================

    /// 计算输出数量（带手续费）
    /// 
    /// 公式：amount_out = (reserve_out * amount_in_with_fee) / (reserve_in + amount_in_with_fee)
    /// 其中：amount_in_with_fee = amount_in * (10000 - 30) / 10000
    fun get_amount_out_internal(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64,
    ): u64 {
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERROR_INSUFFICIENT_LIQUIDITY);
        
        // 扣除手续费
        let amount_in_with_fee = ((amount_in as u128) * 
            ((FEE_DENOMINATOR - FEE_RATE) as u128)) / (FEE_DENOMINATOR as u128);
        
        // 计算输出
        let numerator = amount_in_with_fee * (reserve_out as u128);
        let denominator = (reserve_in as u128) + amount_in_with_fee;
        
        let amount_out = numerator / denominator;
        
        (amount_out as u64)
    }

    /// 计算所需输入数量（带手续费）
    /// 
    /// 公式推导：
    /// amount_out = (reserve_out * amount_in_with_fee) / (reserve_in + amount_in_with_fee)
    /// 
    /// 反推：
    /// amount_in = (reserve_in * amount_out * FEE_DENOMINATOR) / 
    ///             ((reserve_out - amount_out) * (FEE_DENOMINATOR - FEE_RATE)) + 1
    fun get_amount_in_internal(
        amount_out: u64,
        reserve_in: u64,
        reserve_out: u64,
    ): u64 {
        assert!(amount_out > 0, ERROR_ZERO_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERROR_INSUFFICIENT_LIQUIDITY);
        assert!(amount_out < reserve_out, ERROR_INSUFFICIENT_OUTPUT);
        
        let numerator = (reserve_in as u128) * (amount_out as u128) * 
            (FEE_DENOMINATOR as u128);
        let denominator = ((reserve_out - amount_out) as u128) * 
            ((FEE_DENOMINATOR - FEE_RATE) as u128);
        
        let amount_in = numerator / denominator + 1; // +1 确保足够
        
        (amount_in as u64)
    }

    /// 计算手续费金额
    fun calculate_fee(amount: u64): u64 {
        ((amount as u128) * (FEE_RATE as u128) / (FEE_DENOMINATOR as u128) as u64)
    }

    /// 验证 K 值不变性（实际会略微增加）
    fun verify_k_invariant<X, Y>(
        old_reserve_in: u64,
        old_reserve_out: u64,
    ) acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<X, Y>>(@swap_addr);
        let new_reserve_x = coin::value(&pool.reserve_x);
        let new_reserve_y = coin::value(&pool.reserve_y);
        
        let k_old = (old_reserve_in as u128) * (old_reserve_out as u128);
        let k_new = (new_reserve_x as u128) * (new_reserve_y as u128);
        
        // K 值应该增加（因为手续费）
        assert!(k_new >= k_old, ERROR_K_INVARIANT);
    }

    // ==================== 查询接口 ====================

    /// 查询给定输入能获得的输出数量
    #[view]
    public fun get_amount_out<X, Y>(amount_in: u64): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<X, Y>>(@swap_addr);
        let reserve_x = coin::value(&pool.reserve_x);
        let reserve_y = coin::value(&pool.reserve_y);
        
        get_amount_out_internal(amount_in, reserve_x, reserve_y)
    }

    /// 查询获得指定输出需要的输入数量
    #[view]
    public fun get_amount_in<X, Y>(amount_out: u64): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<X, Y>>(@swap_addr);
        let reserve_x = coin::value(&pool.reserve_x);
        let reserve_y = coin::value(&pool.reserve_y);
        
        get_amount_in_internal(amount_out, reserve_x, reserve_y)
    }

    /// 查询价格影响（以基点表示，100 = 1%）
    #[view]
    public fun get_price_impact<X, Y>(amount_in: u64): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<X, Y>>(@swap_addr);
        let reserve_x = coin::value(&pool.reserve_x);
        let reserve_y = coin::value(&pool.reserve_y);
        
        // 当前价格
        let price_before = ((reserve_y as u128) * 10000) / (reserve_x as u128);
        
        // 交易后价格
        let amount_out = get_amount_out_internal(amount_in, reserve_x, reserve_y);
        let new_reserve_x = reserve_x + amount_in;
        let new_reserve_y = reserve_y - amount_out;
        let price_after = ((new_reserve_y as u128) * 10000) / (new_reserve_x as u128);
        
        // 价格影响百分比（基点）
        let impact = if (price_after < price_before) {
            ((price_before - price_after) * 10000) / price_before
        } else {
            ((price_after - price_before) * 10000) / price_before
        };
        
        (impact as u64)
    }

    /// 查询当前价格（Y/X）
    #[view]
    public fun get_price<X, Y>(): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<X, Y>>(@swap_addr);
        let reserve_x = coin::value(&pool.reserve_x);
        let reserve_y = coin::value(&pool.reserve_y);
        
        assert!(reserve_x > 0, ERROR_INSUFFICIENT_LIQUIDITY);
        
        // 价格 = reserve_y / reserve_x（以 8 位小数表示）
        let price = ((reserve_y as u128) * 100000000) / (reserve_x as u128);
        (price as u64)
    }

    /// 查询储备
    #[view]
    public fun get_reserves<X, Y>(): (u64, u64) acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<X, Y>>(@swap_addr);
        (
            coin::value(&pool.reserve_x),
            coin::value(&pool.reserve_y)
        )
    }

    // ==================== 辅助函数 ====================

    /// 检查池子是否存在
    fun pool_exists<X, Y>(): bool {
        exists<LiquidityPool<X, Y>>(@swap_addr)
    }

    /// 发出 Swap 事件
    fun emit_swap_event(
        pool: &mut LiquidityPool,
        user: address,
        token_in: String,
        token_out: String,
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        reserve_in_after: u64,
        reserve_out_after: u64,
    ) {
        event::emit_event(
            &mut pool.swap_events,
            SwapEvent {
                user,
                token_in,
                token_out,
                amount_in,
                amount_out,
                fee_amount,
                reserve_in_after,
                reserve_out_after,
                timestamp: timestamp::now_seconds(),
            }
        );
    }

    /// 发出同步事件
    fun emit_sync_event<X, Y>(pool: &mut LiquidityPool<X, Y>) {
        event::emit_event(
            &mut pool.sync_events,
            SyncEvent {
                reserve_x: coin::value(&pool.reserve_x),
                reserve_y: coin::value(&pool.reserve_y),
                timestamp: timestamp::now_seconds(),
            }
        );
    }

    // ==================== 高级功能 ====================

    /// 带截止时间的 Swap（防止交易在 Mempool 中停留太久）
    public entry fun swap_exact_input_with_deadline<X, Y>(
        user: &signer,
        amount_in: u64,
        min_amount_out: u64,
        deadline: u64,
    ) acquires LiquidityPool {
        // 检查是否过期
        assert!(
            timestamp::now_seconds() <= deadline,
            ERROR_EXPIRED
        );
        
        swap_exact_input<X, Y>(user, amount_in, min_amount_out);
    }

    /// 支持带协议费用的 Swap
    public entry fun swap_with_protocol_fee<X, Y>(
        user: &signer,
        amount_in: u64,
        min_amount_out: u64,
    ) acquires LiquidityPool {
        // 类似基础 swap，但收取额外的协议费用
        // 实现细节省略...
        swap_exact_input<X, Y>(user, amount_in, min_amount_out);
    }

    // ==================== 测试辅助函数 ====================

    #[test_only]
    public fun init_pool_for_test<X, Y>(
        account: &signer,
        reserve_x: Coin<X>,
        reserve_y: Coin<Y>,
    ) {
        move_to(account, LiquidityPool<X, Y> {
            reserve_x,
            reserve_y,
            lp_token_supply: 0,
            protocol_fee_x: coin::zero<X>(),
            protocol_fee_y: coin::zero<Y>(),
            swap_events: account::new_event_handle<SwapEvent>(account),
            sync_events: account::new_event_handle<SyncEvent>(account),
        });
    }
}
