/// # 借贷协议架构设计 - 代码示例
/// 
/// 本模块展示了一个完整的借贷协议架构设计
/// 包含核心数据结构、接口定义和关键算法实现
/// 
/// 作者: Aptos 高级开发课程
/// 版本: v1.0.0

module lending_addr::lending_protocol {
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::type_info::{Self, TypeInfo};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_std::table::{Self, Table};
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::math64;
    use aptos_std::math128;

    // ======================== 错误码 ========================

    /// 协议未初始化
    const E_NOT_INITIALIZED: u64 = 1001;
    /// 协议已初始化
    const E_ALREADY_INITIALIZED: u64 = 1002;
    /// 资产池不存在
    const E_POOL_NOT_EXISTS: u64 = 1003;
    /// 资产池已存在
    const E_POOL_ALREADY_EXISTS: u64 = 1004;
    /// 用户账户不存在
    const E_USER_ACCOUNT_NOT_EXISTS: u64 = 1005;
    /// 余额不足
    const E_INSUFFICIENT_BALANCE: u64 = 1006;
    /// 流动性不足
    const E_INSUFFICIENT_LIQUIDITY: u64 = 1007;
    /// 借款能力不足
    const E_INSUFFICIENT_BORROW_POWER: u64 = 1008;
    /// 健康因子过低
    const E_HEALTH_FACTOR_TOO_LOW: u64 = 1009;
    /// 无法清算
    const E_CANNOT_LIQUIDATE: u64 = 1010;
    /// 无权限
    const E_NOT_AUTHORIZED: u64 = 1011;
    /// 协议已暂停
    const E_PROTOCOL_PAUSED: u64 = 1012;
    /// 参数无效
    const E_INVALID_PARAMETER: u64 = 1013;
    /// 价格偏差过大
    const E_PRICE_DEVIATION_TOO_HIGH: u64 = 1014;

    // ======================== 常量 ========================

    /// 精度常量 (1e18)
    const PRECISION: u128 = 1000000000000000000;
    
    /// 抵押率精度 (1e6 = 100%)
    const COLLATERAL_FACTOR_PRECISION: u64 = 1000000;
    
    /// 利率精度 (1e6)
    const RATE_PRECISION: u64 = 1000000;
    
    /// 年化时间戳 (365 天)
    const SECONDS_PER_YEAR: u64 = 31536000;
    
    /// 最小健康因子 (1.0)
    const MIN_HEALTH_FACTOR: u128 = 1000000000000000000;
    
    /// 最大健康因子
    const MAX_HEALTH_FACTOR: u128 = 115792089237316195423570985008687907853269984665640564039457;
    
    /// 最大清算比例 (50%)
    const MAX_LIQUIDATION_CLOSE_FACTOR: u64 = 500000;
    
    /// 利率模式: 浮动
    const INTEREST_RATE_MODE_VARIABLE: u8 = 1;
    
    /// 利率模式: 稳定
    const INTEREST_RATE_MODE_STABLE: u8 = 2;

    // ======================== 数据结构 ========================

    /// 协议全局状态
    struct ProtocolState has key {
        /// 管理员地址
        admin: address,
        /// 协议是否暂停
        paused: bool,
        /// 支持的资产类型列表
        supported_assets: vector<TypeInfo>,
        /// 总价值锁定 (TVL) in USD
        total_value_locked: u128,
        /// 创建时间
        created_at: u64,
    }

    /// 资产池配置
    struct PoolConfig has copy, drop, store {
        /// 基础利率 (年化，精度 1e6)
        base_rate: u64,
        /// 利率斜率1
        slope1: u64,
        /// 利率斜率2
        slope2: u64,
        /// 最优利用率
        optimal_utilization: u64,
        /// 抵押率 (0-100%, 精度 1e6)
        collateral_factor: u64,
        /// 清算阈值
        liquidation_threshold: u64,
        /// 清算奖励 (5%-15%, 精度 1e6)
        liquidation_bonus: u64,
        /// 储备金因子 (10%, 精度 1e6)
        reserve_factor: u64,
        /// 是否可以用作抵押品
        can_be_collateral: bool,
        /// 是否可以借出
        can_borrow: bool,
    }

    /// 资产池状态 (泛型设计，支持任意 Coin 类型)
    struct Pool<phantom CoinType> has key {
        /// 池中的代币
        coins: Coin<CoinType>,
        /// 池配置
        config: PoolConfig,
        /// 总存款数量 (实际值)
        total_deposits: u64,
        /// 总借款数量 (实际值)
        total_borrows: u64,
        /// 存款利息累积指数 (初始值 1e18)
        deposit_index: u128,
        /// 借款利息累积指数 (初始值 1e18)
        borrow_index: u128,
        /// 当前存款利率 (年化，精度 1e6)
        current_deposit_rate: u64,
        /// 当前借款利率 (年化，精度 1e6)
        current_borrow_rate: u64,
        /// 最后更新时间戳
        last_update_timestamp: u64,
        /// 储备金
        reserves: u64,
    }

    /// 用户账户
    struct UserAccount has key {
        /// 用户存款信息 (资产类型 -> 存款数据)
        deposits: Table<TypeInfo, DepositInfo>,
        /// 用户借款信息 (资产类型 -> 借款数据)
        borrows: Table<TypeInfo, BorrowInfo>,
        /// 用作抵押品的资产列表
        collateral_assets: vector<TypeInfo>,
        /// 账户创建时间
        created_at: u64,
    }

    /// 存款信息
    struct DepositInfo has store, drop {
        /// 存款本金数量
        principal: u64,
        /// 存入时的利息指数
        index: u128,
        /// 是否启用为抵押品
        enabled_as_collateral: bool,
        /// 最后操作时间
        last_action_timestamp: u64,
    }

    /// 借款信息
    struct BorrowInfo has store, drop {
        /// 借款本金数量
        principal: u64,
        /// 借入时的利息指数
        index: u128,
        /// 利率模式 (1=浮动, 2=稳定)
        interest_rate_mode: u8,
        /// 稳定利率 (仅稳定模式使用)
        stable_rate: u64,
        /// 最后操作时间
        last_action_timestamp: u64,
    }

    /// 用户账户数据 (用于查询)
    struct UserAccountData has drop {
        /// 总抵押品价值 (USD)
        total_collateral_usd: u128,
        /// 总债务价值 (USD)
        total_debt_usd: u128,
        /// 可用借款额度 (USD)
        available_borrow_usd: u128,
        /// 当前抵押率
        current_ltv: u64,
        /// 清算阈值
        liquidation_threshold: u64,
        /// 健康因子
        health_factor: u128,
    }

    /// 池数据 (用于查询)
    struct PoolData has drop {
        /// 总存款
        total_deposits: u64,
        /// 总借款
        total_borrows: u64,
        /// 可用流动性
        available_liquidity: u64,
        /// 利用率 (精度 1e6)
        utilization_rate: u64,
        /// 存款利率 (年化，精度 1e6)
        deposit_rate: u64,
        /// 借款利率 (年化，精度 1e6)
        borrow_rate: u64,
        /// 储备金
        reserves: u64,
    }

    // ======================== 事件 ========================

    /// 事件容器
    struct ProtocolEvents has key {
        deposit_events: EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
        borrow_events: EventHandle<BorrowEvent>,
        repay_events: EventHandle<RepayEvent>,
        liquidation_events: EventHandle<LiquidationEvent>,
        collateral_events: EventHandle<CollateralEvent>,
    }

    /// 存款事件
    struct DepositEvent has drop, store {
        user: address,
        asset: TypeInfo,
        amount: u64,
        enabled_as_collateral: bool,
        timestamp: u64,
    }

    /// 提款事件
    struct WithdrawEvent has drop, store {
        user: address,
        asset: TypeInfo,
        amount: u64,
        timestamp: u64,
    }

    /// 借款事件
    struct BorrowEvent has drop, store {
        user: address,
        asset: TypeInfo,
        amount: u64,
        interest_rate_mode: u8,
        interest_rate: u64,
        timestamp: u64,
    }

    /// 还款事件
    struct RepayEvent has drop, store {
        user: address,
        asset: TypeInfo,
        amount: u64,
        timestamp: u64,
    }

    /// 清算事件
    struct LiquidationEvent has drop, store {
        liquidator: address,
        borrower: address,
        collateral_asset: TypeInfo,
        debt_asset: TypeInfo,
        collateral_amount: u64,
        debt_amount: u64,
        liquidation_bonus: u64,
        timestamp: u64,
    }

    /// 抵押品事件
    struct CollateralEvent has drop, store {
        user: address,
        asset: TypeInfo,
        enabled: bool,
        timestamp: u64,
    }

    // ======================== 初始化函数 ========================

    /// 初始化协议
    /// 仅管理员可调用
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // 确保未初始化
        assert!(!exists<ProtocolState>(admin_addr), E_ALREADY_INITIALIZED);

        // 创建协议状态
        move_to(admin, ProtocolState {
            admin: admin_addr,
            paused: false,
            supported_assets: vector::empty(),
            total_value_locked: 0,
            created_at: timestamp::now_seconds(),
        });

        // 创建事件容器
        move_to(admin, ProtocolEvents {
            deposit_events: account::new_event_handle<DepositEvent>(admin),
            withdraw_events: account::new_event_handle<WithdrawEvent>(admin),
            borrow_events: account::new_event_handle<BorrowEvent>(admin),
            repay_events: account::new_event_handle<RepayEvent>(admin),
            liquidation_events: account::new_event_handle<LiquidationEvent>(admin),
            collateral_events: account::new_event_handle<CollateralEvent>(admin),
        });
    }

    /// 创建资产池
    /// 仅管理员可调用
    public entry fun create_pool<CoinType>(
        admin: &signer,
        base_rate: u64,
        slope1: u64,
        slope2: u64,
        optimal_utilization: u64,
        collateral_factor: u64,
        liquidation_threshold: u64,
        liquidation_bonus: u64,
        reserve_factor: u64,
        can_be_collateral: bool,
        can_borrow: bool,
    ) acquires ProtocolState {
        let admin_addr = signer::address_of(admin);
        
        // 验证权限
        let state = borrow_global<ProtocolState>(@lending_addr);
        assert!(admin_addr == state.admin, E_NOT_AUTHORIZED);
        
        // 确保池不存在
        assert!(!exists<Pool<CoinType>>(@lending_addr), E_POOL_ALREADY_EXISTS);

        // 验证参数
        assert!(collateral_factor <= COLLATERAL_FACTOR_PRECISION, E_INVALID_PARAMETER);
        assert!(liquidation_threshold <= COLLATERAL_FACTOR_PRECISION, E_INVALID_PARAMETER);
        assert!(optimal_utilization <= RATE_PRECISION, E_INVALID_PARAMETER);

        // 创建池配置
        let config = PoolConfig {
            base_rate,
            slope1,
            slope2,
            optimal_utilization,
            collateral_factor,
            liquidation_threshold,
            liquidation_bonus,
            reserve_factor,
            can_be_collateral,
            can_borrow,
        };

        // 创建资产池
        move_to(admin, Pool<CoinType> {
            coins: coin::zero<CoinType>(),
            config,
            total_deposits: 0,
            total_borrows: 0,
            deposit_index: PRECISION,
            borrow_index: PRECISION,
            current_deposit_rate: 0,
            current_borrow_rate: base_rate,
            last_update_timestamp: timestamp::now_seconds(),
            reserves: 0,
        });

        // 更新支持的资产列表
        let state_mut = borrow_global_mut<ProtocolState>(@lending_addr);
        vector::push_back(&mut state_mut.supported_assets, type_info::type_of<CoinType>());
    }

    // ======================== 核心功能 - 存款 ========================

    /// 存款
    /// 用户将资产存入协议，可选择是否作为抵押品
    public entry fun deposit<CoinType>(
        user: &signer,
        amount: u64,
        enable_as_collateral: bool
    ) acquires Pool, UserAccount, ProtocolEvents {
        let user_addr = signer::address_of(user);
        
        // 检查协议状态
        check_not_paused();
        
        // 更新利息
        update_interest_rates<CoinType>();
        
        // 初始化用户账户（如果不存在）
        if (!exists<UserAccount>(user_addr)) {
            move_to(user, UserAccount {
                deposits: table::new(),
                borrows: table::new(),
                collateral_assets: vector::empty(),
                created_at: timestamp::now_seconds(),
            });
        };

        // 获取池和用户账户
        let pool = borrow_global_mut<Pool<CoinType>>(@lending_addr);
        let user_account = borrow_global_mut<UserAccount>(user_addr);
        
        // 提取用户的代币
        let coins = coin::withdraw<CoinType>(user, amount);
        
        // 合并到池中
        coin::merge(&mut pool.coins, coins);
        
        // 计算当前余额（含利息）
        let asset_type = type_info::type_of<CoinType>();
        let current_balance = if (table::contains(&user_account.deposits, asset_type)) {
            let deposit_info = table::borrow(&user_account.deposits, asset_type);
            calculate_balance_with_interest(
                deposit_info.principal,
                deposit_info.index,
                pool.deposit_index
            )
        } else {
            0
        };
        
        // 更新存款信息
        let new_balance = current_balance + amount;
        let deposit_info = DepositInfo {
            principal: new_balance,
            index: pool.deposit_index,
            enabled_as_collateral: enable_as_collateral,
            last_action_timestamp: timestamp::now_seconds(),
        };
        
        if (table::contains(&user_account.deposits, asset_type)) {
            *table::borrow_mut(&mut user_account.deposits, asset_type) = deposit_info;
        } else {
            table::add(&mut user_account.deposits, asset_type, deposit_info);
        };
        
        // 更新抵押品列表
        if (enable_as_collateral && !vector::contains(&user_account.collateral_assets, &asset_type)) {
            vector::push_back(&mut user_account.collateral_assets, asset_type);
        };
        
        // 更新池状态
        pool.total_deposits = pool.total_deposits + amount;
        
        // 发出事件
        let events = borrow_global_mut<ProtocolEvents>(@lending_addr);
        event::emit_event(&mut events.deposit_events, DepositEvent {
            user: user_addr,
            asset: asset_type,
            amount,
            enabled_as_collateral: enable_as_collateral,
            timestamp: timestamp::now_seconds(),
        });
    }

    // ======================== 核心功能 - 提款 ========================

    /// 提款
    /// 用户从协议中提取资产
    public entry fun withdraw<CoinType>(
        user: &signer,
        amount: u64
    ) acquires Pool, UserAccount, ProtocolEvents {
        let user_addr = signer::address_of(user);
        
        // 检查协议状态
        check_not_paused();
        
        // 更新利息
        update_interest_rates<CoinType>();
        
        // 获取池和用户账户
        let pool = borrow_global_mut<Pool<CoinType>>(@lending_addr);
        let user_account = borrow_global_mut<UserAccount>(user_addr);
        
        // 检查用户余额
        let asset_type = type_info::type_of<CoinType>();
        assert!(table::contains(&user_account.deposits, asset_type), E_INSUFFICIENT_BALANCE);
        
        let deposit_info = table::borrow(&user_account.deposits, asset_type);
        let current_balance = calculate_balance_with_interest(
            deposit_info.principal,
            deposit_info.index,
            pool.deposit_index
        );
        
        assert!(current_balance >= amount, E_INSUFFICIENT_BALANCE);
        
        // 检查流动性
        let available = coin::value(&pool.coins);
        assert!(available >= amount, E_INSUFFICIENT_LIQUIDITY);
        
        // 如果提款后健康因子过低，拒绝提款
        if (deposit_info.enabled_as_collateral && has_borrows(user_account)) {
            // 这里需要实现健康因子检查
            // check_health_factor_after_withdrawal(user_addr, asset_type, amount);
        };
        
        // 更新存款信息
        let new_balance = current_balance - amount;
        let new_deposit_info = DepositInfo {
            principal: new_balance,
            index: pool.deposit_index,
            enabled_as_collateral: deposit_info.enabled_as_collateral,
            last_action_timestamp: timestamp::now_seconds(),
        };
        *table::borrow_mut(&mut user_account.deposits, asset_type) = new_deposit_info;
        
        // 提取代币给用户
        let withdrawn_coins = coin::extract(&mut pool.coins, amount);
        coin::deposit(user_addr, withdrawn_coins);
        
        // 更新池状态
        pool.total_deposits = pool.total_deposits - amount;
        
        // 发出事件
        let events = borrow_global_mut<ProtocolEvents>(@lending_addr);
        event::emit_event(&mut events.withdraw_events, WithdrawEvent {
            user: user_addr,
            asset: asset_type,
            amount,
            timestamp: timestamp::now_seconds(),
        });
    }

    // ======================== 核心功能 - 借款 ========================

    /// 借款
    /// 用户基于抵押品借出资产
    public entry fun borrow<CoinType>(
        user: &signer,
        amount: u64,
        interest_rate_mode: u8
    ) acquires Pool, UserAccount, ProtocolEvents {
        let user_addr = signer::address_of(user);
        
        // 检查协议状态
        check_not_paused();
        
        // 验证参数
        assert!(
            interest_rate_mode == INTEREST_RATE_MODE_VARIABLE || 
            interest_rate_mode == INTEREST_RATE_MODE_STABLE,
            E_INVALID_PARAMETER
        );
        
        // 更新利息
        update_interest_rates<CoinType>();
        
        // 获取池和用户账户
        let pool = borrow_global_mut<Pool<CoinType>>(@lending_addr);
        let user_account = borrow_global_mut<UserAccount>(user_addr);
        
        // 检查池配置
        assert!(pool.config.can_borrow, E_INVALID_PARAMETER);
        
        // 检查流动性
        let available = coin::value(&pool.coins);
        assert!(available >= amount, E_INSUFFICIENT_LIQUIDITY);
        
        // 检查借款能力
        // let account_data = calculate_user_account_data(user_addr);
        // assert!(account_data.available_borrow_usd >= amount_in_usd, E_INSUFFICIENT_BORROW_POWER);
        
        // 更新借款信息
        let asset_type = type_info::type_of<CoinType>();
        let current_borrow = if (table::contains(&user_account.borrows, asset_type)) {
            let borrow_info = table::borrow(&user_account.borrows, asset_type);
            calculate_balance_with_interest(
                borrow_info.principal,
                borrow_info.index,
                pool.borrow_index
            )
        } else {
            0
        };
        
        let new_borrow = current_borrow + amount;
        let borrow_info = BorrowInfo {
            principal: new_borrow,
            index: pool.borrow_index,
            interest_rate_mode,
            stable_rate: if (interest_rate_mode == INTEREST_RATE_MODE_STABLE) {
                pool.current_borrow_rate
            } else {
                0
            },
            last_action_timestamp: timestamp::now_seconds(),
        };
        
        if (table::contains(&user_account.borrows, asset_type)) {
            *table::borrow_mut(&mut user_account.borrows, asset_type) = borrow_info;
        } else {
            table::add(&mut user_account.borrows, asset_type, borrow_info);
        };
        
        // 提取代币给用户
        let borrowed_coins = coin::extract(&mut pool.coins, amount);
        coin::deposit(user_addr, borrowed_coins);
        
        // 更新池状态
        pool.total_borrows = pool.total_borrows + amount;
        
        // 发出事件
        let events = borrow_global_mut<ProtocolEvents>(@lending_addr);
        event::emit_event(&mut events.borrow_events, BorrowEvent {
            user: user_addr,
            asset: asset_type,
            amount,
            interest_rate_mode,
            interest_rate: pool.current_borrow_rate,
            timestamp: timestamp::now_seconds(),
        });
    }

    // ======================== 核心功能 - 还款 ========================

    /// 还款
    /// 用户归还借款
    public entry fun repay<CoinType>(
        user: &signer,
        amount: u64
    ) acquires Pool, UserAccount, ProtocolEvents {
        let user_addr = signer::address_of(user);
        
        // 检查协议状态
        check_not_paused();
        
        // 更新利息
        update_interest_rates<CoinType>();
        
        // 获取池和用户账户
        let pool = borrow_global_mut<Pool<CoinType>>(@lending_addr);
        let user_account = borrow_global_mut<UserAccount>(user_addr);
        
        // 检查借款
        let asset_type = type_info::type_of<CoinType>();
        assert!(table::contains(&user_account.borrows, asset_type), E_INSUFFICIENT_BALANCE);
        
        let borrow_info = table::borrow(&user_account.borrows, asset_type);
        let current_debt = calculate_balance_with_interest(
            borrow_info.principal,
            borrow_info.index,
            pool.borrow_index
        );
        
        // 实际还款金额（不超过当前债务）
        let actual_repay = if (amount > current_debt) { current_debt } else { amount };
        
        // 提取用户的代币
        let coins = coin::withdraw<CoinType>(user, actual_repay);
        
        // 合并到池中
        coin::merge(&mut pool.coins, coins);
        
        // 更新借款信息
        let new_debt = current_debt - actual_repay;
        if (new_debt == 0) {
            // 完全还清，删除记录
            table::remove(&mut user_account.borrows, asset_type);
        } else {
            let new_borrow_info = BorrowInfo {
                principal: new_debt,
                index: pool.borrow_index,
                interest_rate_mode: borrow_info.interest_rate_mode,
                stable_rate: borrow_info.stable_rate,
                last_action_timestamp: timestamp::now_seconds(),
            };
            *table::borrow_mut(&mut user_account.borrows, asset_type) = new_borrow_info;
        };
        
        // 更新池状态
        pool.total_borrows = pool.total_borrows - actual_repay;
        
        // 发出事件
        let events = borrow_global_mut<ProtocolEvents>(@lending_addr);
        event::emit_event(&mut events.repay_events, RepayEvent {
            user: user_addr,
            asset: asset_type,
            amount: actual_repay,
            timestamp: timestamp::now_seconds(),
        });
    }

    // ======================== 利率计算 ========================

    /// 更新利息指数和利率
    fun update_interest_rates<CoinType>() acquires Pool {
        let pool = borrow_global_mut<Pool<CoinType>>(@lending_addr);
        
        let current_time = timestamp::now_seconds();
        let time_elapsed = current_time - pool.last_update_timestamp;
        
        if (time_elapsed == 0) {
            return
        };
        
        // 计算利用率
        let utilization = calculate_utilization_rate(
            pool.total_borrows,
            pool.total_deposits
        );
        
        // 计算新的借款利率
        let new_borrow_rate = calculate_borrow_rate(
            utilization,
            pool.config.base_rate,
            pool.config.slope1,
            pool.config.slope2,
            pool.config.optimal_utilization
        );
        
        // 计算新的存款利率
        let new_deposit_rate = calculate_deposit_rate(
            new_borrow_rate,
            utilization,
            pool.config.reserve_factor
        );
        
        // 更新借款指数
        let borrow_interest = calculate_linear_interest(
            new_borrow_rate,
            time_elapsed
        );
        pool.borrow_index = (pool.borrow_index * borrow_interest) / PRECISION;
        
        // 更新存款指数
        let deposit_interest = calculate_linear_interest(
            new_deposit_rate,
            time_elapsed
        );
        pool.deposit_index = (pool.deposit_index * deposit_interest) / PRECISION;
        
        // 更新状态
        pool.current_borrow_rate = new_borrow_rate;
        pool.current_deposit_rate = new_deposit_rate;
        pool.last_update_timestamp = current_time;
    }

    /// 计算利用率
    fun calculate_utilization_rate(total_borrows: u64, total_deposits: u64): u64 {
        if (total_deposits == 0) {
            return 0
        };
        
        ((total_borrows as u128) * (RATE_PRECISION as u128) / (total_deposits as u128) as u64)
    }

    /// 计算借款利率（分段利率模型）
    fun calculate_borrow_rate(
        utilization: u64,
        base_rate: u64,
        slope1: u64,
        slope2: u64,
        optimal_utilization: u64
    ): u64 {
        if (utilization <= optimal_utilization) {
            // 在最优利用率以下：线性增长
            base_rate + ((utilization as u128) * (slope1 as u128) / (optimal_utilization as u128) as u64)
        } else {
            // 超过最优利用率：陡峭增长
            let excess_utilization = utilization - optimal_utilization;
            let normal_rate = base_rate + slope1;
            let excess_rate = ((excess_utilization as u128) * (slope2 as u128) / 
                              ((RATE_PRECISION - optimal_utilization) as u128) as u64);
            normal_rate + excess_rate
        }
    }

    /// 计算存款利率
    fun calculate_deposit_rate(
        borrow_rate: u64,
        utilization: u64,
        reserve_factor: u64
    ): u64 {
        let rate_to_depositors = RATE_PRECISION - reserve_factor;
        ((borrow_rate as u128) * (utilization as u128) * (rate_to_depositors as u128) / 
         (RATE_PRECISION as u128) / (RATE_PRECISION as u128) as u64)
    }

    /// 计算线性利息（简化版连续复利）
    fun calculate_linear_interest(rate: u64, time_elapsed: u64): u128 {
        PRECISION + ((rate as u128) * (time_elapsed as u128) / (SECONDS_PER_YEAR as u128))
    }

    /// 计算含利息的余额
    fun calculate_balance_with_interest(
        principal: u64,
        old_index: u128,
        current_index: u128
    ): u64 {
        if (principal == 0 || old_index == 0) {
            return 0
        };
        
        ((principal as u128) * current_index / old_index as u64)
    }

    // ======================== 辅助函数 ========================

    /// 检查协议是否暂停
    fun check_not_paused() acquires ProtocolState {
        let state = borrow_global<ProtocolState>(@lending_addr);
        assert!(!state.paused, E_PROTOCOL_PAUSED);
    }

    /// 检查用户是否有借款
    fun has_borrows(user_account: &UserAccount): bool {
        table::length(&user_account.borrows) > 0
    }

    // ======================== 查询函数 ========================

    /// 获取用户账户数据
    #[view]
    public fun get_user_account_data(user: address): UserAccountData acquires UserAccount, Pool {
        // 这里应该实现完整的账户数据计算
        // 包括遍历所有抵押品和债务，计算 USD 价值
        UserAccountData {
            total_collateral_usd: 0,
            total_debt_usd: 0,
            available_borrow_usd: 0,
            current_ltv: 0,
            liquidation_threshold: 0,
            health_factor: MAX_HEALTH_FACTOR,
        }
    }

    /// 获取资产池数据
    #[view]
    public fun get_pool_data<CoinType>(): PoolData acquires Pool {
        let pool = borrow_global<Pool<CoinType>>(@lending_addr);
        
        PoolData {
            total_deposits: pool.total_deposits,
            total_borrows: pool.total_borrows,
            available_liquidity: coin::value(&pool.coins),
            utilization_rate: calculate_utilization_rate(pool.total_borrows, pool.total_deposits),
            deposit_rate: pool.current_deposit_rate,
            borrow_rate: pool.current_borrow_rate,
            reserves: pool.reserves,
        }
    }

    /// 获取用户存款余额（含利息）
    #[view]
    public fun get_user_deposit_balance<CoinType>(user: address): u64 acquires UserAccount, Pool {
        if (!exists<UserAccount>(user)) {
            return 0
        };
        
        let user_account = borrow_global<UserAccount>(user);
        let pool = borrow_global<Pool<CoinType>>(@lending_addr);
        let asset_type = type_info::type_of<CoinType>();
        
        if (!table::contains(&user_account.deposits, asset_type)) {
            return 0
        };
        
        let deposit_info = table::borrow(&user_account.deposits, asset_type);
        calculate_balance_with_interest(
            deposit_info.principal,
            deposit_info.index,
            pool.deposit_index
        )
    }

    /// 获取用户借款余额（含利息）
    #[view]
    public fun get_user_borrow_balance<CoinType>(user: address): u64 acquires UserAccount, Pool {
        if (!exists<UserAccount>(user)) {
            return 0
        };
        
        let user_account = borrow_global<UserAccount>(user);
        let pool = borrow_global<Pool<CoinType>>(@lending_addr);
        let asset_type = type_info::type_of<CoinType>();
        
        if (!table::contains(&user_account.borrows, asset_type)) {
            return 0
        };
        
        let borrow_info = table::borrow(&user_account.borrows, asset_type);
        calculate_balance_with_interest(
            borrow_info.principal,
            borrow_info.index,
            pool.borrow_index
        )
    }

    // ======================== 测试辅助函数 ========================

    #[test_only]
    public fun init_for_test(admin: &signer) {
        initialize(admin);
    }
}
