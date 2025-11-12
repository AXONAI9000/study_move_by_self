// 借贷协议 MVP - 核心代码示例
// 本文件展示借贷协议的核心实现逻辑

module lending_protocol::lending_pool {
    use std::signer;
    use std::string::{Self, String};
    use aptos_std::table::{Self, Table};
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    // ============ 常量 ============
    
    const RAY: u128 = 1_000_000_000_000_000_000_000_000_000; // 10^27
    const SECONDS_PER_YEAR: u128 = 31536000;
    const HEALTH_FACTOR_LIQUIDATION_THRESHOLD: u128 = 1_000_000_000_000_000_000; // 1.0
    const MAX_U128: u128 = 340282366920938463463374607431768211455;
    
    // ============ 错误码 ============
    
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_POOL_ALREADY_INITIALIZED: u64 = 2;
    const E_POOL_NOT_INITIALIZED: u64 = 3;
    const E_ASSET_NOT_SUPPORTED: u64 = 4;
    const E_INSUFFICIENT_BALANCE: u64 = 5;
    const E_INSUFFICIENT_COLLATERAL: u64 = 6;
    const E_HEALTH_FACTOR_TOO_LOW: u64 = 7;
    const E_HEALTH_FACTOR_OK: u64 = 8;
    const E_AMOUNT_ZERO: u64 = 9;
    const E_LIQUIDATION_TOO_MUCH: u64 = 10;

    // ============ 数据结构 ============
    
    /// 借贷池主结构
    struct LendingPool has key {
        // 储备金映射
        reserves: Table<String, Reserve>,
        // 用户数据
        user_data: Table<address, UserAccount>,
        // 支持的资产列表
        supported_assets: vector<String>,
        // 管理员
        admin: address,
        // 事件句柄
        deposit_events: EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
        borrow_events: EventHandle<BorrowEvent>,
        repay_events: EventHandle<RepayEvent>,
        liquidation_events: EventHandle<LiquidationEvent>,
    }
    
    /// 储备金信息
    struct Reserve has store {
        // 资产符号
        symbol: String,
        // 总存款
        total_deposits: u64,
        // 总借款
        total_borrows: u64,
        // 可用流动性
        available_liquidity: u64,
        // LTV（基点，10000 = 100%）
        ltv: u64,
        // 清算阈值
        liquidation_threshold: u64,
        // 清算奖励
        liquidation_bonus: u64,
        // 储备金因子
        reserve_factor: u64,
        // 最后更新时间
        last_update_timestamp: u64,
        // 流动性索引
        liquidity_index: u128,
        // 借款索引
        borrow_index: u128,
        // 利率配置
        interest_rate_config: InterestRateConfig,
    }
    
    /// 利率配置
    struct InterestRateConfig has store, copy, drop {
        base_rate: u64,
        slope1: u64,
        slope2: u64,
        optimal_utilization: u64,
    }
    
    /// 用户账户
    struct UserAccount has store {
        // 抵押品
        collateral: SimpleMap<String, u64>,
        // 借款信息
        borrows: SimpleMap<String, BorrowInfo>,
        // 健康因子
        health_factor: u128,
    }
    
    /// 借款信息
    struct BorrowInfo has store, copy, drop {
        // 本金
        principal: u64,
        // 借款时的索引
        borrow_index: u128,
        // 借款时间
        timestamp: u64,
    }
    
    // ============ 事件 ============
    
    struct DepositEvent has drop, store {
        user: address,
        asset: String,
        amount: u64,
        timestamp: u64,
    }
    
    struct WithdrawEvent has drop, store {
        user: address,
        asset: String,
        amount: u64,
        timestamp: u64,
    }
    
    struct BorrowEvent has drop, store {
        user: address,
        asset: String,
        amount: u64,
        borrow_rate: u64,
        health_factor: u128,
        timestamp: u64,
    }
    
    struct RepayEvent has drop, store {
        user: address,
        asset: String,
        amount: u64,
        timestamp: u64,
    }
    
    struct LiquidationEvent has drop, store {
        liquidator: address,
        borrower: address,
        debt_asset: String,
        debt_covered: u64,
        collateral_asset: String,
        collateral_liquidated: u64,
        timestamp: u64,
    }
    
    // ============ 初始化 ============
    
    /// 初始化借贷池
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        assert!(!exists<LendingPool>(admin_addr), E_POOL_ALREADY_INITIALIZED);
        
        move_to(admin, LendingPool {
            reserves: table::new(),
            user_data: table::new(),
            supported_assets: vector::empty(),
            admin: admin_addr,
            deposit_events: account::new_event_handle<DepositEvent>(admin),
            withdraw_events: account::new_event_handle<WithdrawEvent>(admin),
            borrow_events: account::new_event_handle<BorrowEvent>(admin),
            repay_events: account::new_event_handle<RepayEvent>(admin),
            liquidation_events: account::new_event_handle<LiquidationEvent>(admin),
        });
    }
    
    /// 添加支持的资产
    public entry fun add_reserve(
        admin: &signer,
        symbol: String,
        ltv: u64,
        liquidation_threshold: u64,
        liquidation_bonus: u64,
        reserve_factor: u64,
        base_rate: u64,
        slope1: u64,
        slope2: u64,
        optimal_utilization: u64,
    ) acquires LendingPool {
        let pool = borrow_global_mut<LendingPool>(signer::address_of(admin));
        assert!(signer::address_of(admin) == pool.admin, E_NOT_AUTHORIZED);
        
        let reserve = Reserve {
            symbol: symbol,
            total_deposits: 0,
            total_borrows: 0,
            available_liquidity: 0,
            ltv,
            liquidation_threshold,
            liquidation_bonus,
            reserve_factor,
            last_update_timestamp: timestamp::now_seconds(),
            liquidity_index: RAY,
            borrow_index: RAY,
            interest_rate_config: InterestRateConfig {
                base_rate,
                slope1,
                slope2,
                optimal_utilization,
            },
        };
        
        table::add(&mut pool.reserves, symbol, reserve);
        vector::push_back(&mut pool.supported_assets, symbol);
    }
    
    // ============ 核心功能 ============
    
    /// 存款（简化版本，实际需要泛型处理不同代币）
    public entry fun deposit(
        user: &signer,
        asset: String,
        amount: u64
    ) acquires LendingPool {
        assert!(amount > 0, E_AMOUNT_ZERO);
        
        let user_addr = signer::address_of(user);
        let pool = borrow_global_mut<LendingPool>(@lending_protocol);
        
        // 验证资产支持
        assert!(table::contains(&pool.reserves, &asset), E_ASSET_NOT_SUPPORTED);
        
        // 更新利率
        update_interest_rates(&asset);
        
        // 更新储备金
        let reserve = table::borrow_mut(&mut pool.reserves, &asset);
        reserve.total_deposits = reserve.total_deposits + amount;
        reserve.available_liquidity = reserve.available_liquidity + amount;
        
        // 初始化或更新用户账户
        if (!table::contains(&pool.user_data, &user_addr)) {
            table::add(&mut pool.user_data, user_addr, UserAccount {
                collateral: simple_map::create(),
                borrows: simple_map::create(),
                health_factor: MAX_U128,
            });
        };
        
        let user_account = table::borrow_mut(&mut pool.user_data, &user_addr);
        
        // 更新用户抵押品
        if (simple_map::contains_key(&user_account.collateral, &asset)) {
            let current = simple_map::borrow_mut(&mut user_account.collateral, &asset);
            *current = *current + amount;
        } else {
            simple_map::add(&mut user_account.collateral, asset, amount);
        };
        
        // 发射事件
        event::emit_event(&mut pool.deposit_events, DepositEvent {
            user: user_addr,
            asset,
            amount,
            timestamp: timestamp::now_seconds(),
        });
        
        // 注：实际实现需要转移代币到合约
        // coin::transfer<CoinType>(user, @lending_protocol, amount);
    }
    
    /// 借款
    public entry fun borrow(
        user: &signer,
        asset: String,
        amount: u64
    ) acquires LendingPool {
        assert!(amount > 0, E_AMOUNT_ZERO);
        
        let user_addr = signer::address_of(user);
        let pool = borrow_global_mut<LendingPool>(@lending_protocol);
        
        // 验证资产支持
        assert!(table::contains(&pool.reserves, &asset), E_ASSET_NOT_SUPPORTED);
        
        // 更新利率
        update_interest_rates(&asset);
        
        // 检查借款能力
        let borrowing_power = calculate_borrowing_power(user_addr);
        assert!(amount <= borrowing_power, E_INSUFFICIENT_COLLATERAL);
        
        // 更新储备金
        let reserve = table::borrow_mut(&mut pool.reserves, &asset);
        assert!(amount <= reserve.available_liquidity, E_INSUFFICIENT_BALANCE);
        
        reserve.total_borrows = reserve.total_borrows + amount;
        reserve.available_liquidity = reserve.available_liquidity - amount;
        
        // 更新用户借款
        let user_account = table::borrow_mut(&mut pool.user_data, &user_addr);
        
        let borrow_info = BorrowInfo {
            principal: amount,
            borrow_index: reserve.borrow_index,
            timestamp: timestamp::now_seconds(),
        };
        
        if (simple_map::contains_key(&user_account.borrows, &asset)) {
            // 累加到现有借款
            let existing = simple_map::borrow_mut(&mut user_account.borrows, &asset);
            existing.principal = existing.principal + amount;
        } else {
            simple_map::add(&mut user_account.borrows, asset, borrow_info);
        };
        
        // 更新健康因子
        user_account.health_factor = calculate_health_factor_internal(user_addr);
        
        // 验证健康因子
        assert!(
            user_account.health_factor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            E_HEALTH_FACTOR_TOO_LOW
        );
        
        // 计算当前借款利率
        let borrow_rate = calculate_borrow_rate_internal(&asset);
        
        // 发射事件
        event::emit_event(&mut pool.borrow_events, BorrowEvent {
            user: user_addr,
            asset,
            amount,
            borrow_rate,
            health_factor: user_account.health_factor,
            timestamp: timestamp::now_seconds(),
        });
        
        // 注：实际实现需要转移代币给用户
        // coin::transfer<CoinType>(@lending_protocol, user, amount);
    }
    
    /// 还款
    public entry fun repay(
        user: &signer,
        asset: String,
        amount: u64
    ) acquires LendingPool {
        assert!(amount > 0, E_AMOUNT_ZERO);
        
        let user_addr = signer::address_of(user);
        let pool = borrow_global_mut<LendingPool>(@lending_protocol);
        
        // 更新利率
        update_interest_rates(&asset);
        
        // 计算实际债务
        let user_account = table::borrow_mut(&mut pool.user_data, &user_addr);
        assert!(simple_map::contains_key(&user_account.borrows, &asset), E_INSUFFICIENT_BALANCE);
        
        let borrow_info = simple_map::borrow_mut(&mut user_account.borrows, &asset);
        let actual_debt = calculate_current_debt(borrow_info, &asset);
        
        // 确定还款金额
        let repay_amount = if (amount >= actual_debt) {
            actual_debt
        } else {
            amount
        };
        
        // 更新借款
        borrow_info.principal = actual_debt - repay_amount;
        
        // 如果全部还清，移除借款记录
        if (borrow_info.principal == 0) {
            simple_map::remove(&mut user_account.borrows, &asset);
        };
        
        // 更新储备金
        let reserve = table::borrow_mut(&mut pool.reserves, &asset);
        reserve.total_borrows = reserve.total_borrows - repay_amount;
        reserve.available_liquidity = reserve.available_liquidity + repay_amount;
        
        // 更新健康因子
        user_account.health_factor = calculate_health_factor_internal(user_addr);
        
        // 发射事件
        event::emit_event(&mut pool.repay_events, RepayEvent {
            user: user_addr,
            asset,
            amount: repay_amount,
            timestamp: timestamp::now_seconds(),
        });
    }
    
    // ============ 利率计算 ============
    
    /// 更新利率
    fun update_interest_rates(asset: &String) acquires LendingPool {
        let pool = borrow_global_mut<LendingPool>(@lending_protocol);
        let reserve = table::borrow_mut(&mut pool.reserves, asset);
        
        let current_time = timestamp::now_seconds();
        let time_delta = current_time - reserve.last_update_timestamp;
        
        if (time_delta == 0) {
            return
        };
        
        // 计算新的索引
        let borrow_rate = calculate_borrow_rate_for_reserve(reserve);
        reserve.borrow_index = calculate_linear_index(
            reserve.borrow_index,
            borrow_rate,
            time_delta
        );
        
        let supply_rate = calculate_supply_rate(
            borrow_rate,
            reserve.total_borrows,
            reserve.available_liquidity,
            reserve.reserve_factor
        );
        
        reserve.liquidity_index = calculate_linear_index(
            reserve.liquidity_index,
            supply_rate,
            time_delta
        );
        
        reserve.last_update_timestamp = current_time;
    }
    
    /// 计算线性索引
    fun calculate_linear_index(
        current_index: u128,
        rate: u64,
        time_delta: u64
    ): u128 {
        if (time_delta == 0) {
            return current_index
        };
        
        let rate_per_second = (rate as u128) * RAY / SECONDS_PER_YEAR / 10000;
        let accumulation = RAY + rate_per_second * (time_delta as u128);
        (current_index * accumulation) / RAY
    }
    
    /// 计算借款利率
    fun calculate_borrow_rate_for_reserve(reserve: &Reserve): u64 {
        let utilization = calculate_utilization_rate(
            reserve.total_borrows,
            reserve.available_liquidity
        );
        
        calculate_borrow_rate(
            utilization,
            reserve.interest_rate_config.base_rate,
            reserve.interest_rate_config.slope1,
            reserve.interest_rate_config.slope2,
            reserve.interest_rate_config.optimal_utilization
        )
    }
    
    fun calculate_borrow_rate(
        utilization_rate: u64,
        base_rate: u64,
        slope1: u64,
        slope2: u64,
        optimal_utilization: u64
    ): u64 {
        if (utilization_rate <= optimal_utilization) {
            let rate_increase = ((utilization_rate as u128) * (slope1 as u128) / 
                                (optimal_utilization as u128)) as u64;
            base_rate + rate_increase
        } else {
            let excess_utilization = utilization_rate - optimal_utilization;
            let excess_capacity = 10000 - optimal_utilization;
            let rate_increase = ((excess_utilization as u128) * (slope2 as u128) / 
                                (excess_capacity as u128)) as u64;
            base_rate + slope1 + rate_increase
        }
    }
    
    fun calculate_supply_rate(
        borrow_rate: u64,
        total_borrows: u64,
        available_liquidity: u64,
        reserve_factor: u64
    ): u64 {
        let utilization = calculate_utilization_rate(total_borrows, available_liquidity);
        let rate_to_pool = ((borrow_rate as u128) * (10000 - (reserve_factor as u128)) / 10000) as u64;
        ((rate_to_pool as u128) * (utilization as u128) / 10000) as u64
    }
    
    fun calculate_utilization_rate(
        total_borrows: u64,
        available_liquidity: u64
    ): u64 {
        let total = total_borrows + available_liquidity;
        if (total == 0) {
            return 0
        };
        ((total_borrows as u128) * 10000 / (total as u128)) as u64
    }
    
    // ============ 健康因子和借款能力 ============
    
    /// 计算健康因子（内部）
    fun calculate_health_factor_internal(user_addr: address): u128 acquires LendingPool {
        let pool = borrow_global<LendingPool>(@lending_protocol);
        let user = table::borrow(&pool.user_data, &user_addr);
        
        let total_collateral_value = 0u128;
        let total_borrow_value = 0u128;
        
        // 计算抵押品价值
        // 注：实际需要集成价格预言机
        // 这里简化处理
        
        // 如果没有借款
        if (simple_map::length(&user.borrows) == 0) {
            return MAX_U128
        };
        
        // 计算健康因子
        if (total_borrow_value == 0) {
            MAX_U128
        } else {
            (total_collateral_value * 1_000_000_000_000_000_000) / total_borrow_value
        }
    }
    
    /// 计算借款能力
    fun calculate_borrowing_power(user_addr: address): u64 acquires LendingPool {
        // 简化实现
        // 实际需要：抵押品价值 × LTV - 已借款价值
        1000 // 占位符
    }
    
    /// 计算当前债务
    fun calculate_current_debt(borrow_info: &BorrowInfo, asset: &String): u64 acquires LendingPool {
        let pool = borrow_global<LendingPool>(@lending_protocol);
        let reserve = table::borrow(&pool.reserves, asset);
        
        // 债务 = 本金 × (当前索引 / 借款时索引)
        let debt = ((borrow_info.principal as u128) * reserve.borrow_index / 
                   borrow_info.borrow_index) as u64;
        debt
    }
    
    /// 计算借款利率（内部）
    fun calculate_borrow_rate_internal(asset: &String): u64 acquires LendingPool {
        let pool = borrow_global<LendingPool>(@lending_protocol);
        let reserve = table::borrow(&pool.reserves, asset);
        calculate_borrow_rate_for_reserve(reserve)
    }
    
    // ============ 查询函数 ============
    
    #[view]
    public fun get_reserve_data(asset: String): (u64, u64, u64, u128, u128) acquires LendingPool {
        let pool = borrow_global<LendingPool>(@lending_protocol);
        let reserve = table::borrow(&pool.reserves, &asset);
        
        (
            reserve.total_deposits,
            reserve.total_borrows,
            reserve.available_liquidity,
            reserve.liquidity_index,
            reserve.borrow_index
        )
    }
    
    #[view]
    public fun get_user_health_factor(user: address): u128 acquires LendingPool {
        calculate_health_factor_internal(user)
    }
}
