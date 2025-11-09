/// # Day 15: AMM 核心算法实现
/// 
/// 本模块演示了完整的自动做市商（AMM）核心算法实现，包括：
/// - 恒定乘积公式 (x * y = k)
/// - 流动性管理（添加/移除）
/// - 交换计算
/// - 价格查询
/// - 手续费处理
///
/// 作者：Aptos 课程
/// 日期：2025-01-09

module day15::amm_core {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_std::type_info;
    use aptos_std::math64;

    // ========================= 错误码 =========================

    /// 零数量错误
    const ERROR_ZERO_AMOUNT: u64 = 1;
    /// 流动性不足
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 2;
    /// 输出量不足（滑点保护）
    const ERROR_INSUFFICIENT_OUTPUT: u64 = 3;
    /// 储备为零
    const ERROR_ZERO_RESERVE: u64 = 4;
    /// 数值溢出
    const ERROR_OVERFLOW: u64 = 5;
    /// 池子已存在
    const ERROR_POOL_ALREADY_EXISTS: u64 = 6;
    /// 池子不存在
    const ERROR_POOL_NOT_EXISTS: u64 = 7;
    /// 输入比例不匹配
    const ERROR_INVALID_RATIO: u64 = 8;
    /// LP Token 不足
    const ERROR_INSUFFICIENT_LP_TOKENS: u64 = 9;

    // ========================= 常量 =========================

    /// 手续费率：0.3% = 30 / 10000
    const FEE_NUMERATOR: u64 = 30;
    const FEE_DENOMINATOR: u64 = 10000;

    /// 最小流动性（防止除零）
    const MINIMUM_LIQUIDITY: u64 = 1000;

    // ========================= 数据结构 =========================

    /// LP Token - 代表流动性份额
    struct LPToken<phantom X, phantom Y> has key {}

    /// 流动性池
    struct LiquidityPool<phantom X, phantom Y> has key {
        /// 代币 X 储备
        reserve_x: Coin<X>,
        /// 代币 Y 储备
        reserve_y: Coin<Y>,
        /// LP Token 总供应量
        lp_total_supply: u64,
        /// 最小流动性（锁定）
        locked_liquidity: u64,
        /// 累计手续费 X
        fee_x: u64,
        /// 累计手续费 Y
        fee_y: u64,
        /// 添加流动性事件
        add_liquidity_events: EventHandle<AddLiquidityEvent>,
        /// 移除流动性事件
        remove_liquidity_events: EventHandle<RemoveLiquidityEvent>,
        /// 交换事件
        swap_events: EventHandle<SwapEvent>,
    }

    /// 用户 LP 余额
    struct LPBalance<phantom X, phantom Y> has key {
        /// LP Token 数量
        lp_amount: u64,
    }

    // ========================= 事件 =========================

    /// 添加流动性事件
    struct AddLiquidityEvent has drop, store {
        user: address,
        amount_x: u64,
        amount_y: u64,
        lp_minted: u64,
        total_lp: u64,
    }

    /// 移除流动性事件
    struct RemoveLiquidityEvent has drop, store {
        user: address,
        lp_burned: u64,
        amount_x: u64,
        amount_y: u64,
        total_lp: u64,
    }

    /// 交换事件
    struct SwapEvent has drop, store {
        user: address,
        x_to_y: bool,  // true: X换Y, false: Y换X
        amount_in: u64,
        amount_out: u64,
        fee: u64,
    }

    // ========================= 初始化函数 =========================

    /// 创建流动性池
    /// 只能由管理员调用（这里简化为任何人都可以创建）
    public entry fun create_pool<X, Y>(creator: &signer) {
        let creator_addr = signer::address_of(creator);
        
        // 确保池子不存在
        assert!(!exists<LiquidityPool<X, Y>>(creator_addr), ERROR_POOL_ALREADY_EXISTS);
        
        // 创建空池子
        let pool = LiquidityPool<X, Y> {
            reserve_x: coin::zero<X>(),
            reserve_y: coin::zero<Y>(),
            lp_total_supply: 0,
            locked_liquidity: 0,
            fee_x: 0,
            fee_y: 0,
            add_liquidity_events: account::new_event_handle<AddLiquidityEvent>(creator),
            remove_liquidity_events: account::new_event_handle<RemoveLiquidityEvent>(creator),
            swap_events: account::new_event_handle<SwapEvent>(creator),
        };
        
        move_to(creator, pool);
    }

    // ========================= 流动性管理 =========================

    /// 添加流动性（首次）
    /// 首次添加流动性时，LP Token 数量 = sqrt(amount_x * amount_y)
    public entry fun add_liquidity_initial<X, Y>(
        provider: &signer,
        pool_address: address,
        amount_x: u64,
        amount_y: u64,
    ) acquires LiquidityPool, LPBalance {
        assert!(amount_x > 0 && amount_y > 0, ERROR_ZERO_AMOUNT);
        
        let provider_addr = signer::address_of(provider);
        let pool = borrow_global_mut<LiquidityPool<X, Y>>(pool_address);
        
        // 确保是首次添加
        assert!(pool.lp_total_supply == 0, ERROR_POOL_ALREADY_EXISTS);
        
        // 从用户账户提取代币
        let coin_x = coin::withdraw<X>(provider, amount_x);
        let coin_y = coin::withdraw<Y>(provider, amount_y);
        
        // 计算初始 LP Token 数量：sqrt(x * y)
        let lp_amount = sqrt_u128((amount_x as u128) * (amount_y as u128));
        
        // 锁定最小流动性（永久锁定，防止除零）
        assert!(lp_amount > MINIMUM_LIQUIDITY, ERROR_INSUFFICIENT_LIQUIDITY);
        pool.locked_liquidity = MINIMUM_LIQUIDITY;
        let actual_lp = lp_amount - MINIMUM_LIQUIDITY;
        
        // 合并到池子储备
        coin::merge(&mut pool.reserve_x, coin_x);
        coin::merge(&mut pool.reserve_y, coin_y);
        
        // 更新总供应量
        pool.lp_total_supply = lp_amount;
        
        // 初始化或更新用户 LP 余额
        if (!exists<LPBalance<X, Y>>(provider_addr)) {
            move_to(provider, LPBalance<X, Y> {
                lp_amount: actual_lp,
            });
        } else {
            let lp_balance = borrow_global_mut<LPBalance<X, Y>>(provider_addr);
            lp_balance.lp_amount = lp_balance.lp_amount + actual_lp;
        };
        
        // 发射事件
        event::emit_event(&mut pool.add_liquidity_events, AddLiquidityEvent {
            user: provider_addr,
            amount_x,
            amount_y,
            lp_minted: actual_lp,
            total_lp: pool.lp_total_supply,
        });
    }

    /// 添加流动性（后续）
    /// 必须按照当前储备比例添加，LP = (amount_x / reserve_x) * total_supply
    public entry fun add_liquidity<X, Y>(
        provider: &signer,
        pool_address: address,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64,
    ) acquires LiquidityPool, LPBalance {
        let provider_addr = signer::address_of(provider);
        let pool = borrow_global_mut<LiquidityPool<X, Y>>(pool_address);
        
        // 获取当前储备
        let reserve_x = coin::value(&pool.reserve_x);
        let reserve_y = coin::value(&pool.reserve_y);
        
        assert!(reserve_x > 0 && reserve_y > 0, ERROR_ZERO_RESERVE);
        
        // 计算实际添加的数量（保持比例）
        let (amount_x, amount_y) = calculate_optimal_amounts(
            amount_x_desired,
            amount_y_desired,
            amount_x_min,
            amount_y_min,
            reserve_x,
            reserve_y,
        );
        
        // 提取代币
        let coin_x = coin::withdraw<X>(provider, amount_x);
        let coin_y = coin::withdraw<Y>(provider, amount_y);
        
        // 计算 LP Token 数量（取两者较小值，确保比例正确）
        let lp_x = ((amount_x as u128) * (pool.lp_total_supply as u128) / (reserve_x as u128) as u64);
        let lp_y = ((amount_y as u128) * (pool.lp_total_supply as u128) / (reserve_y as u128) as u64);
        let lp_amount = if (lp_x < lp_y) { lp_x } else { lp_y };
        
        assert!(lp_amount > 0, ERROR_INSUFFICIENT_LIQUIDITY);
        
        // 合并到池子
        coin::merge(&mut pool.reserve_x, coin_x);
        coin::merge(&mut pool.reserve_y, coin_y);
        
        // 更新总供应量
        pool.lp_total_supply = pool.lp_total_supply + lp_amount;
        
        // 更新用户余额
        if (!exists<LPBalance<X, Y>>(provider_addr)) {
            move_to(provider, LPBalance<X, Y> {
                lp_amount,
            });
        } else {
            let lp_balance = borrow_global_mut<LPBalance<X, Y>>(provider_addr);
            lp_balance.lp_amount = lp_balance.lp_amount + lp_amount;
        };
        
        // 发射事件
        event::emit_event(&mut pool.add_liquidity_events, AddLiquidityEvent {
            user: provider_addr,
            amount_x,
            amount_y,
            lp_minted: lp_amount,
            total_lp: pool.lp_total_supply,
        });
    }

    /// 移除流动性
    /// 按比例取回两种代币
    public entry fun remove_liquidity<X, Y>(
        provider: &signer,
        pool_address: address,
        lp_amount: u64,
        amount_x_min: u64,
        amount_y_min: u64,
    ) acquires LiquidityPool, LPBalance {
        assert!(lp_amount > 0, ERROR_ZERO_AMOUNT);
        
        let provider_addr = signer::address_of(provider);
        let pool = borrow_global_mut<LiquidityPool<X, Y>>(pool_address);
        let lp_balance = borrow_global_mut<LPBalance<X, Y>>(provider_addr);
        
        // 检查余额
        assert!(lp_balance.lp_amount >= lp_amount, ERROR_INSUFFICIENT_LP_TOKENS);
        
        // 获取储备
        let reserve_x = coin::value(&pool.reserve_x);
        let reserve_y = coin::value(&pool.reserve_y);
        
        // 计算取回数量
        let amount_x = ((lp_amount as u128) * (reserve_x as u128) / (pool.lp_total_supply as u128) as u64);
        let amount_y = ((lp_amount as u128) * (reserve_y as u128) / (pool.lp_total_supply as u128) as u64);
        
        // 滑点保护
        assert!(amount_x >= amount_x_min, ERROR_INSUFFICIENT_OUTPUT);
        assert!(amount_y >= amount_y_min, ERROR_INSUFFICIENT_OUTPUT);
        
        // 提取代币
        let coin_x = coin::extract(&mut pool.reserve_x, amount_x);
        let coin_y = coin::extract(&mut pool.reserve_y, amount_y);
        
        // 存入用户账户
        coin::deposit(provider_addr, coin_x);
        coin::deposit(provider_addr, coin_y);
        
        // 更新状态
        lp_balance.lp_amount = lp_balance.lp_amount - lp_amount;
        pool.lp_total_supply = pool.lp_total_supply - lp_amount;
        
        // 发射事件
        event::emit_event(&mut pool.remove_liquidity_events, RemoveLiquidityEvent {
            user: provider_addr,
            lp_burned: lp_amount,
            amount_x,
            amount_y,
            total_lp: pool.lp_total_supply,
        });
    }

    // ========================= 交换函数 =========================

    /// 用 X 换 Y
    /// amount_out = (amount_in * (1 - fee) * reserve_y) / (reserve_x + amount_in * (1 - fee))
    public entry fun swap_x_to_y<X, Y>(
        trader: &signer,
        pool_address: address,
        amount_in: u64,
        min_amount_out: u64,
    ) acquires LiquidityPool {
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);
        
        let trader_addr = signer::address_of(trader);
        let pool = borrow_global_mut<LiquidityPool<X, Y>>(pool_address);
        
        // 获取储备
        let reserve_x = coin::value(&pool.reserve_x);
        let reserve_y = coin::value(&pool.reserve_y);
        
        assert!(reserve_x > 0 && reserve_y > 0, ERROR_ZERO_RESERVE);
        
        // 计算输出量（含手续费）
        let amount_out = get_amount_out(amount_in, reserve_x, reserve_y);
        
        // 滑点保护
        assert!(amount_out >= min_amount_out, ERROR_INSUFFICIENT_OUTPUT);
        
        // 计算手续费
        let fee = ((amount_in as u128) * (FEE_NUMERATOR as u128) / (FEE_DENOMINATOR as u128) as u64);
        
        // 提取输入代币
        let coin_in = coin::withdraw<X>(trader, amount_in);
        
        // 提取输出代币
        let coin_out = coin::extract(&mut pool.reserve_y, amount_out);
        
        // 合并输入代币到池子
        coin::merge(&mut pool.reserve_x, coin_in);
        
        // 存入输出代币到用户账户
        coin::deposit(trader_addr, coin_out);
        
        // 更新手续费统计
        pool.fee_x = pool.fee_x + fee;
        
        // 发射事件
        event::emit_event(&mut pool.swap_events, SwapEvent {
            user: trader_addr,
            x_to_y: true,
            amount_in,
            amount_out,
            fee,
        });
    }

    /// 用 Y 换 X
    public entry fun swap_y_to_x<X, Y>(
        trader: &signer,
        pool_address: address,
        amount_in: u64,
        min_amount_out: u64,
    ) acquires LiquidityPool {
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);
        
        let trader_addr = signer::address_of(trader);
        let pool = borrow_global_mut<LiquidityPool<X, Y>>(pool_address);
        
        // 获取储备
        let reserve_x = coin::value(&pool.reserve_x);
        let reserve_y = coin::value(&pool.reserve_y);
        
        assert!(reserve_x > 0 && reserve_y > 0, ERROR_ZERO_RESERVE);
        
        // 计算输出量（含手续费）
        let amount_out = get_amount_out(amount_in, reserve_y, reserve_x);
        
        // 滑点保护
        assert!(amount_out >= min_amount_out, ERROR_INSUFFICIENT_OUTPUT);
        
        // 计算手续费
        let fee = ((amount_in as u128) * (FEE_NUMERATOR as u128) / (FEE_DENOMINATOR as u128) as u64);
        
        // 提取输入代币
        let coin_in = coin::withdraw<Y>(trader, amount_in);
        
        // 提取输出代币
        let coin_out = coin::extract(&mut pool.reserve_x, amount_out);
        
        // 合并输入代币到池子
        coin::merge(&mut pool.reserve_y, coin_in);
        
        // 存入输出代币到用户账户
        coin::deposit(trader_addr, coin_out);
        
        // 更新手续费统计
        pool.fee_y = pool.fee_y + fee;
        
        // 发射事件
        event::emit_event(&mut pool.swap_events, SwapEvent {
            user: trader_addr,
            x_to_y: false,
            amount_in,
            amount_out,
            fee,
        });
    }

    // ========================= 查询函数 =========================

    /// 计算输出量（不含手续费）
    /// Δy = (Δx * y) / (x + Δx)
    public fun get_amount_out_without_fee(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64,
    ): u64 {
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERROR_ZERO_RESERVE);
        
        let amount_out = ((amount_in as u128) * (reserve_out as u128) 
            / ((reserve_in as u128) + (amount_in as u128)) as u64);
        
        amount_out
    }

    /// 计算输出量（含手续费）
    /// Δy = (Δx * (1 - fee) * y) / (x + Δx * (1 - fee))
    public fun get_amount_out(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64,
    ): u64 {
        assert!(amount_in > 0, ERROR_ZERO_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERROR_ZERO_RESERVE);
        
        // 扣除手续费后的输入量
        let amount_in_with_fee = ((amount_in as u128) * ((FEE_DENOMINATOR - FEE_NUMERATOR) as u128) 
            / (FEE_DENOMINATOR as u128) as u64);
        
        // 计算输出量
        let numerator = (amount_in_with_fee as u128) * (reserve_out as u128);
        let denominator = (reserve_in as u128) + (amount_in_with_fee as u128);
        
        (numerator / denominator as u64)
    }

    /// 计算所需输入量（给定期望输出）
    /// Δx = (Δy * x) / ((y - Δy) * (1 - fee))
    public fun get_amount_in(
        amount_out: u64,
        reserve_in: u64,
        reserve_out: u64,
    ): u64 {
        assert!(amount_out > 0, ERROR_ZERO_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERROR_ZERO_RESERVE);
        assert!(amount_out < reserve_out, ERROR_INSUFFICIENT_LIQUIDITY);
        
        let numerator = (reserve_in as u128) * (amount_out as u128) * (FEE_DENOMINATOR as u128);
        let denominator = ((reserve_out - amount_out) as u128) * ((FEE_DENOMINATOR - FEE_NUMERATOR) as u128);
        
        ((numerator / denominator) as u64) + 1  // 向上取整
    }

    /// 获取即时价格（Y/X）
    #[view]
    public fun get_price<X, Y>(pool_address: address): u64 acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<X, Y>>(pool_address);
        let reserve_x = coin::value(&pool.reserve_x);
        let reserve_y = coin::value(&pool.reserve_y);
        
        assert!(reserve_x > 0, ERROR_ZERO_RESERVE);
        
        // 返回价格（放大 1e8 倍以保持精度）
        ((reserve_y as u128) * 100000000 / (reserve_x as u128) as u64)
    }

    /// 获取池子储备信息
    #[view]
    public fun get_reserves<X, Y>(pool_address: address): (u64, u64, u64) acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<X, Y>>(pool_address);
        (
            coin::value(&pool.reserve_x),
            coin::value(&pool.reserve_y),
            pool.lp_total_supply
        )
    }

    /// 获取用户 LP 余额
    #[view]
    public fun get_lp_balance<X, Y>(user: address): u64 acquires LPBalance {
        if (!exists<LPBalance<X, Y>>(user)) {
            return 0
        };
        let lp_balance = borrow_global<LPBalance<X, Y>>(user);
        lp_balance.lp_amount
    }

    /// 计算价格影响
    /// Price Impact = |P_new - P_old| / P_old
    public fun calculate_price_impact(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64,
    ): u64 {
        // 旧价格
        let old_price = ((reserve_out as u128) * 100000000 / (reserve_in as u128));
        
        // 新储备
        let new_reserve_in = reserve_in + amount_in;
        let amount_out = get_amount_out(amount_in, reserve_in, reserve_out);
        let new_reserve_out = reserve_out - amount_out;
        
        // 新价格
        let new_price = ((new_reserve_out as u128) * 100000000 / (new_reserve_in as u128));
        
        // 价格影响（百分比，放大 1e6 倍）
        if (new_price > old_price) {
            (((new_price - old_price) * 1000000 / old_price) as u64)
        } else {
            (((old_price - new_price) * 1000000 / old_price) as u64)
        }
    }

    // ========================= 辅助函数 =========================

    /// 计算最优添加数量
    fun calculate_optimal_amounts(
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64,
        reserve_x: u64,
        reserve_y: u64,
    ): (u64, u64) {
        // 根据 amount_x_desired 计算所需的 y
        let amount_y_optimal = ((amount_x_desired as u128) * (reserve_y as u128) 
            / (reserve_x as u128) as u64);
        
        if (amount_y_optimal <= amount_y_desired) {
            assert!(amount_y_optimal >= amount_y_min, ERROR_INVALID_RATIO);
            (amount_x_desired, amount_y_optimal)
        } else {
            // 根据 amount_y_desired 计算所需的 x
            let amount_x_optimal = ((amount_y_desired as u128) * (reserve_x as u128) 
                / (reserve_y as u128) as u64);
            assert!(amount_x_optimal <= amount_x_desired, ERROR_INVALID_RATIO);
            assert!(amount_x_optimal >= amount_x_min, ERROR_INVALID_RATIO);
            (amount_x_optimal, amount_y_desired)
        }
    }

    /// 计算平方根（牛顿迭代法）
    fun sqrt_u128(x: u128): u64 {
        if (x == 0) return 0;
        
        let z = (x + 1) / 2;
        let y = x;
        
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        };
        
        (y as u64)
    }

    // ========================= 测试函数 =========================

    #[test_only]
    use aptos_framework::managed_coin;

    #[test_only]
    struct TestCoinX {}

    #[test_only]
    struct TestCoinY {}

    #[test(admin = @0x123, user = @0x456)]
    fun test_create_pool(admin: &signer, user: &signer) {
        // 初始化代币
        let admin_addr = signer::address_of(admin);
        account::create_account_for_test(admin_addr);
        
        managed_coin::initialize<TestCoinX>(admin, b"Test X", b"TX", 8, false);
        managed_coin::initialize<TestCoinY>(admin, b"Test Y", b"TY", 8, false);
        
        // 创建池子
        create_pool<TestCoinX, TestCoinY>(admin);
        
        // 验证池子存在
        assert!(exists<LiquidityPool<TestCoinX, TestCoinY>>(admin_addr), 1);
    }

    #[test(admin = @0x123, provider = @0x456)]
    fun test_add_initial_liquidity(admin: &signer, provider: &signer) acquires LiquidityPool, LPBalance {
        let admin_addr = signer::address_of(admin);
        let provider_addr = signer::address_of(provider);
        
        account::create_account_for_test(admin_addr);
        account::create_account_for_test(provider_addr);
        
        // 初始化代币
        managed_coin::initialize<TestCoinX>(admin, b"Test X", b"TX", 8, false);
        managed_coin::initialize<TestCoinY>(admin, b"Test Y", b"TY", 8, false);
        
        // 注册和铸造
        managed_coin::register<TestCoinX>(provider);
        managed_coin::register<TestCoinY>(provider);
        managed_coin::mint<TestCoinX>(admin, provider_addr, 100000);
        managed_coin::mint<TestCoinY>(admin, provider_addr, 200000);
        
        // 创建池子
        create_pool<TestCoinX, TestCoinY>(admin);
        
        // 添加初始流动性
        add_liquidity_initial<TestCoinX, TestCoinY>(provider, admin_addr, 10000, 20000);
        
        // 验证储备
        let (reserve_x, reserve_y, lp_supply) = get_reserves<TestCoinX, TestCoinY>(admin_addr);
        assert!(reserve_x == 10000, 2);
        assert!(reserve_y == 20000, 3);
        
        // 验证 LP Token
        let lp_balance = get_lp_balance<TestCoinX, TestCoinY>(provider_addr);
        assert!(lp_balance > 0, 4);
    }

    #[test(admin = @0x123, trader = @0x789)]
    fun test_swap(admin: &signer, trader: &signer) acquires LiquidityPool, LPBalance {
        let admin_addr = signer::address_of(admin);
        let trader_addr = signer::address_of(trader);
        
        account::create_account_for_test(admin_addr);
        account::create_account_for_test(trader_addr);
        
        // 初始化代币
        managed_coin::initialize<TestCoinX>(admin, b"Test X", b"TX", 8, false);
        managed_coin::initialize<TestCoinY>(admin, b"Test Y", b"TY", 8, false);
        
        // 注册和铸造
        managed_coin::register<TestCoinX>(admin);
        managed_coin::register<TestCoinY>(admin);
        managed_coin::register<TestCoinX>(trader);
        managed_coin::register<TestCoinY>(trader);
        
        managed_coin::mint<TestCoinX>(admin, admin_addr, 100000);
        managed_coin::mint<TestCoinY>(admin, admin_addr, 200000);
        managed_coin::mint<TestCoinX>(admin, trader_addr, 10000);
        
        // 创建池子并添加流动性
        create_pool<TestCoinX, TestCoinY>(admin);
        add_liquidity_initial<TestCoinX, TestCoinY>(admin, admin_addr, 10000, 20000);
        
        // 执行交换
        swap_x_to_y<TestCoinX, TestCoinY>(trader, admin_addr, 1000, 1);
        
        // 验证余额变化
        let balance_y = coin::balance<TestCoinY>(trader_addr);
        assert!(balance_y > 0, 5);
    }
}
