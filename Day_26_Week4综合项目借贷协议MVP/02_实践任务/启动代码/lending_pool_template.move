// 借贷协议 MVP - 启动代码模板
// 请在 TODO 标记处填充实现

module lending_protocol::lending_pool {
    use std::signer;
    use std::string::String;
    use aptos_std::table::{Self, Table};
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    // ============ 常量 ============
    
    const RAY: u128 = 1_000_000_000_000_000_000_000_000_000;
    const SECONDS_PER_YEAR: u128 = 31536000;
    const HEALTH_FACTOR_LIQUIDATION_THRESHOLD: u128 = 1_000_000_000_000_000_000;
    const MAX_U128: u128 = 340282366920938463463374607431768211455;
    
    // ============ 错误码 ============
    
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_POOL_ALREADY_INITIALIZED: u64 = 2;
    const E_ASSET_NOT_SUPPORTED: u64 = 4;
    const E_INSUFFICIENT_BALANCE: u64 = 5;
    const E_INSUFFICIENT_COLLATERAL: u64 = 6;
    const E_HEALTH_FACTOR_TOO_LOW: u64 = 7;
    const E_HEALTH_FACTOR_OK: u64 = 8;
    const E_AMOUNT_ZERO: u64 = 9;
    
    // ============ 数据结构 ============
    
    struct LendingPool has key {
        reserves: Table<String, Reserve>,
        user_data: Table<address, UserAccount>,
        supported_assets: vector<String>,
        admin: address,
        deposit_events: EventHandle<DepositEvent>,
        borrow_events: EventHandle<BorrowEvent>,
        repay_events: EventHandle<RepayEvent>,
        liquidation_events: EventHandle<LiquidationEvent>,
    }
    
    struct Reserve has store {
        symbol: String,
        total_deposits: u64,
        total_borrows: u64,
        available_liquidity: u64,
        ltv: u64,
        liquidation_threshold: u64,
        liquidation_bonus: u64,
        reserve_factor: u64,
        last_update_timestamp: u64,
        liquidity_index: u128,
        borrow_index: u128,
        interest_rate_config: InterestRateConfig,
    }
    
    struct InterestRateConfig has store, copy, drop {
        base_rate: u64,
        slope1: u64,
        slope2: u64,
        optimal_utilization: u64,
    }
    
    struct UserAccount has store {
        collateral: SimpleMap<String, u64>,
        borrows: SimpleMap<String, BorrowInfo>,
        health_factor: u128,
    }
    
    struct BorrowInfo has store, copy, drop {
        principal: u64,
        borrow_index: u128,
        timestamp: u64,
    }
    
    // ============ 事件 ============
    
    struct DepositEvent has drop, store {
        user: address,
        asset: String,
        amount: u64,
        timestamp: u64,
    }
    
    struct BorrowEvent has drop, store {
        user: address,
        asset: String,
        amount: u64,
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
        collateral_asset: String,
        debt_covered: u64,
        collateral_liquidated: u64,
        timestamp: u64,
    }
    
    // ============ 初始化 ============
    
    /// TODO: 实现初始化函数
    public entry fun initialize(admin: &signer) {
        // 1. 验证未初始化
        // 2. 创建 LendingPool 结构
        // 3. move_to admin
    }
    
    /// TODO: 实现添加资产储备
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
        // 1. 验证管理员权限
        // 2. 创建 Reserve 结构
        // 3. 添加到 reserves 表
        // 4. 添加到 supported_assets
    }
    
    // ============ 核心功能 ============
    
    /// TODO: 实现存款功能
    public entry fun deposit(
        user: &signer,
        asset: String,
        amount: u64
    ) acquires LendingPool {
        // 1. 验证金额 > 0
        // 2. 验证资产被支持
        // 3. 更新利率和索引
        // 4. 更新储备金数据
        // 5. 更新用户抵押品
        // 6. 发射事件
        // 7. 转移代币（实际项目）
    }
    
    /// TODO: 实现借款功能
    public entry fun borrow(
        user: &signer,
        asset: String,
        amount: u64
    ) acquires LendingPool {
        // 1. 验证金额 > 0
        // 2. 验证资产被支持
        // 3. 更新利率和索引
        // 4. 检查借款能力
        // 5. 更新储备金数据
        // 6. 更新用户借款
        // 7. 计算并验证健康因子
        // 8. 发射事件
        // 9. 转移代币（实际项目）
    }
    
    /// TODO: 实现还款功能
    public entry fun repay(
        user: &signer,
        asset: String,
        amount: u64
    ) acquires LendingPool {
        // 1. 验证金额 > 0
        // 2. 更新利率和索引
        // 3. 计算实际债务（含利息）
        // 4. 确定还款金额
        // 5. 更新用户借款
        // 6. 更新储备金数据
        // 7. 更新健康因子
        // 8. 发射事件
    }
    
    /// TODO: 实现清算功能
    public entry fun liquidate(
        liquidator: &signer,
        borrower: address,
        debt_asset: String,
        collateral_asset: String,
        debt_to_cover: u64
    ) acquires LendingPool {
        // 1. 验证健康因子 < 1.0
        // 2. 计算最大可清算债务（50%）
        // 3. 计算需要的抵押品（含奖励）
        // 4. 转移债务资产（清算人 -> 协议）
        // 5. 转移抵押品（借款人 -> 清算人）
        // 6. 更新账户数据
        // 7. 更新健康因子
        // 8. 发射事件
    }
    
    // ============ 利率计算 ============
    
    /// TODO: 实现利率更新
    fun update_interest_rates(asset: &String) acquires LendingPool {
        // 1. 获取储备金
        // 2. 计算时间差
        // 3. 计算借款利率
        // 4. 更新借款索引
        // 5. 计算存款利率
        // 6. 更新流动性索引
        // 7. 更新时间戳
    }
    
    /// TODO: 实现索引计算
    fun calculate_linear_index(
        current_index: u128,
        rate: u64,
        time_delta: u64
    ): u128 {
        // 使用线性累积公式
        // index_new = index_old × (1 + rate × time)
    }
    
    /// TODO: 实现借款利率计算
    fun calculate_borrow_rate(
        utilization_rate: u64,
        base_rate: u64,
        slope1: u64,
        slope2: u64,
        optimal_utilization: u64
    ): u64 {
        // 实现分段线性利率模型
        // U ≤ U_optimal: 使用 slope1
        // U > U_optimal: 使用 slope2
    }
    
    /// TODO: 实现存款利率计算
    fun calculate_supply_rate(
        borrow_rate: u64,
        total_borrows: u64,
        available_liquidity: u64,
        reserve_factor: u64
    ): u64 {
        // supply_rate = borrow_rate × utilization × (1 - reserve_factor)
    }
    
    /// TODO: 实现使用率计算
    fun calculate_utilization_rate(
        total_borrows: u64,
        available_liquidity: u64
    ): u64 {
        // utilization = total_borrows / (total_borrows + available_liquidity)
    }
    
    // ============ 健康因子 ============
    
    /// TODO: 实现健康因子计算
    fun calculate_health_factor_internal(user_addr: address): u128 acquires LendingPool {
        // 1. 获取用户账户
        // 2. 计算抵押品总价值（加权）
        // 3. 计算借款总价值
        // 4. 计算健康因子
        // HF = (collateral × threshold) / borrow
    }
    
    /// TODO: 实现借款能力计算
    fun calculate_borrowing_power(user_addr: address): u64 acquires LendingPool {
        // 1. 计算抵押品价值 × LTV
        // 2. 减去已借款价值
        // 3. 返回剩余借款能力
    }
    
    /// TODO: 实现当前债务计算
    fun calculate_current_debt(borrow_info: &BorrowInfo, asset: &String): u64 acquires LendingPool {
        // debt = principal × (current_index / borrow_index)
    }
    
    // ============ 查询函数 ============
    
    #[view]
    public fun get_reserve_data(asset: String): (u64, u64, u64) acquires LendingPool {
        // TODO: 返回储备金数据
        (0, 0, 0)
    }
    
    #[view]
    public fun get_user_health_factor(user: address): u128 acquires LendingPool {
        // TODO: 返回用户健康因子
        MAX_U128
    }
    
    // ============ 测试辅助函数 ============
    
    #[test_only]
    public fun init_for_test(admin: &signer) {
        initialize(admin);
    }
}
