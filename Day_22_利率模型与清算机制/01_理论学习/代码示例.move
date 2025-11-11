/// 利率模型与清算机制 - 完整代码示例
/// 
/// 本模块展示了借贷协议中利率模型和清算机制的完整实现
/// 包括线性利率模型、跳跃利率模型、动态利息累积和清算执行

module lending::interest_and_liquidation {
    use std::signer;
    use std::vector;
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    // ===================== 错误代码 =====================

    const ERROR_NOT_INITIALIZED: u64 = 1;
    const ERROR_ALREADY_INITIALIZED: u64 = 2;
    const ERROR_NOT_LIQUIDATABLE: u64 = 3;
    const ERROR_ZERO_LIQUIDATION: u64 = 4;
    const ERROR_INSUFFICIENT_COLLATERAL: u64 = 5;
    const ERROR_INVALID_CLOSE_FACTOR: u64 = 6;
    const ERROR_PRICE_TOO_OLD: u64 = 7;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 8;
    const ERROR_MARKET_NOT_FOUND: u64 = 9;

    // ===================== 常量定义 =====================

    /// 精度常量（18位小数）
    const PRECISION: u128 = 1_000_000_000_000_000_000; // 1e18
    
    /// 价格精度（8位小数）
    const PRICE_PRECISION: u128 = 100_000_000; // 1e8
    
    /// 一年的秒数
    const SECONDS_PER_YEAR: u128 = 31_536_000; // 365 * 24 * 3600
    
    /// 最大健康因子（无限大的替代值）
    const MAX_HEALTH_FACTOR: u128 = 1_000_000_000_000_000_000_000; // 1e21
    
    /// 价格有效期（5分钟）
    const PRICE_STALENESS_THRESHOLD: u64 = 300;

    // ===================== 数据结构 =====================

    /// 线性利率模型
    struct LinearInterestRateModel has store, copy, drop {
        base_rate_per_second: u128,      // 基础利率（每秒），精度 1e18
        slope_per_second: u128,           // 斜率（每秒），精度 1e18
        reserve_factor: u128,             // 储备金率，精度 1e18
    }

    /// 跳跃利率模型（Kinked Interest Rate Model）
    struct KinkedInterestRateModel has store, copy, drop {
        base_rate_per_second: u128,       // 基础利率（每秒），精度 1e18
        optimal_utilization: u128,        // 最优使用率，精度 1e18
        slope_1_per_second: u128,         // 斜率 1（每秒），精度 1e18
        slope_2_per_second: u128,         // 斜率 2（每秒），精度 1e18
        reserve_factor: u128,             // 储备金率，精度 1e18
    }

    /// 利率模型类型
    struct InterestRateModel has store, copy, drop {
        is_kinked: bool,                  // true: 跳跃模型, false: 线性模型
        linear_model: LinearInterestRateModel,
        kinked_model: KinkedInterestRateModel,
    }

    /// 市场状态
    struct MarketState<phantom CoinType> has key {
        total_deposits: u128,             // 总存款（本金）
        total_borrows: u128,              // 总借款（本金）
        borrow_index: u128,               // 借款指数，精度 1e18
        supply_index: u128,               // 存款指数，精度 1e18
        last_update_timestamp: u64,       // 上次更新时间（秒）
        interest_rate_model: InterestRateModel,
        
        // 清算配置
        liquidation_config: LiquidationConfig,
        
        // 事件
        accrue_interest_events: EventHandle<AccrueInterestEvent>,
        liquidation_events: EventHandle<LiquidationEvent>,
    }

    /// 用户账户
    struct UserAccount<phantom CoinType> has key {
        deposit_principal: u128,          // 存款本金
        deposit_index: u128,              // 存款时的指数
        borrow_principal: u128,           // 借款本金
        borrow_index: u128,               // 借款时的指数
        is_collateral_enabled: bool,      // 是否启用为抵押品
    }

    /// 清算配置
    struct LiquidationConfig has store, copy, drop {
        close_factor: u128,               // 单次清算比例，精度 1e18（如 0.5e18 = 50%）
        liquidation_incentive: u128,      // 清算奖励率，精度 1e18（如 0.1e18 = 10%）
        liquidation_penalty: u128,        // 清算惩罚率，精度 1e18（如 0.12e18 = 12%）
        min_health_factor: u128,          // 最小健康因子阈值，精度 1e18（如 1.0e18）
        collateral_factor: u128,          // 抵押率（LTV），精度 1e18（如 0.75e18 = 75%）
    }

    /// 清算信息
    struct LiquidationInfo has drop {
        can_liquidate: bool,              // 是否可清算
        max_repay_amount: u128,           // 最大偿还金额
        collateral_to_seize: u128,        // 应获得的抵押品数量
        liquidation_reward: u128,         // 清算奖励金额
    }

    /// 价格信息（模拟预言机）
    struct PriceOracle has key {
        prices: vector<PriceData>,
    }

    struct PriceData has store, drop {
        asset: address,                   // 资产地址
        price: u128,                      // 价格，精度 1e8
        timestamp: u64,                   // 更新时间
    }

    // ===================== 事件定义 =====================

    /// 利息累积事件
    struct AccrueInterestEvent has store, drop {
        asset: address,
        borrow_index: u128,
        supply_index: u128,
        total_borrows: u128,
        borrow_rate: u128,
        supply_rate: u128,
        timestamp: u64,
    }

    /// 清算事件
    struct LiquidationEvent has store, drop {
        liquidator: address,
        borrower: address,
        repay_asset: address,
        collateral_asset: address,
        repay_amount: u128,
        collateral_seized: u128,
        liquidation_reward: u128,
        new_health_factor: u128,
        timestamp: u64,
    }

    // ===================== 初始化函数 =====================

    /// 初始化市场（使用跳跃利率模型）
    public entry fun initialize_market<CoinType>(
        admin: &signer,
        base_rate_per_year: u128,         // 年化基础利率，精度 1e18
        optimal_utilization: u128,        // 最优使用率，精度 1e18
        slope_1_per_year: u128,           // 年化斜率 1，精度 1e18
        slope_2_per_year: u128,           // 年化斜率 2，精度 1e18
        reserve_factor: u128,             // 储备金率，精度 1e18
        close_factor: u128,               // 清算比例，精度 1e18
        liquidation_incentive: u128,      // 清算奖励率，精度 1e18
        liquidation_penalty: u128,        // 清算惩罚率，精度 1e18
        collateral_factor: u128,          // 抵押率，精度 1e18
    ) {
        let admin_addr = signer::address_of(admin);
        assert!(!exists<MarketState<CoinType>>(admin_addr), ERROR_ALREADY_INITIALIZED);

        // 创建跳跃利率模型
        let kinked_model = KinkedInterestRateModel {
            base_rate_per_second: base_rate_per_year / SECONDS_PER_YEAR,
            optimal_utilization,
            slope_1_per_second: slope_1_per_year / SECONDS_PER_YEAR,
            slope_2_per_second: slope_2_per_year / SECONDS_PER_YEAR,
            reserve_factor,
        };

        let interest_rate_model = InterestRateModel {
            is_kinked: true,
            linear_model: LinearInterestRateModel {
                base_rate_per_second: 0,
                slope_per_second: 0,
                reserve_factor: 0,
            },
            kinked_model,
        };

        // 创建清算配置
        let liquidation_config = LiquidationConfig {
            close_factor,
            liquidation_incentive,
            liquidation_penalty,
            min_health_factor: PRECISION, // 1.0
            collateral_factor,
        };

        // 创建市场状态
        move_to(admin, MarketState<CoinType> {
            total_deposits: 0,
            total_borrows: 0,
            borrow_index: PRECISION,      // 初始为 1.0
            supply_index: PRECISION,      // 初始为 1.0
            last_update_timestamp: timestamp::now_seconds(),
            interest_rate_model,
            liquidation_config,
            accrue_interest_events: account::new_event_handle<AccrueInterestEvent>(admin),
            liquidation_events: account::new_event_handle<LiquidationEvent>(admin),
        });
    }

    /// 初始化用户账户
    public entry fun initialize_user_account<CoinType>(user: &signer) {
        let user_addr = signer::address_of(user);
        
        if (!exists<UserAccount<CoinType>>(user_addr)) {
            move_to(user, UserAccount<CoinType> {
                deposit_principal: 0,
                deposit_index: PRECISION,
                borrow_principal: 0,
                borrow_index: PRECISION,
                is_collateral_enabled: false,
            });
        };
    }

    // ===================== 利率计算函数 =====================

    /// 计算使用率
    /// 公式: Utilization = Total_Borrows / Total_Deposits
    public fun calculate_utilization(
        total_deposits: u128,
        total_borrows: u128
    ): u128 {
        if (total_deposits == 0) {
            return 0
        };
        
        // utilization = (total_borrows * PRECISION) / total_deposits
        (total_borrows * PRECISION) / total_deposits
    }

    /// 计算借款利率（线性模型）
    public fun get_borrow_rate_linear(
        model: &LinearInterestRateModel,
        utilization: u128
    ): u128 {
        // borrow_rate = base_rate + utilization * slope
        let variable_rate = (utilization * model.slope_per_second) / PRECISION;
        model.base_rate_per_second + variable_rate
    }

    /// 计算借款利率（跳跃模型）
    public fun get_borrow_rate_kinked(
        model: &KinkedInterestRateModel,
        utilization: u128
    ): u128 {
        if (utilization <= model.optimal_utilization) {
            // 阶段 1: 正常范围
            // rate = base + (utilization / optimal) * slope_1
            let utilization_ratio = (utilization * PRECISION) / model.optimal_utilization;
            let variable_rate = (utilization_ratio * model.slope_1_per_second) / PRECISION;
            model.base_rate_per_second + variable_rate
        } else {
            // 阶段 2: 高使用率
            // rate = base + slope_1 + ((utilization - optimal) / (1 - optimal)) * slope_2
            let excess_utilization = utilization - model.optimal_utilization;
            let excess_range = PRECISION - model.optimal_utilization;
            let excess_ratio = (excess_utilization * PRECISION) / excess_range;
            let excess_rate = (excess_ratio * model.slope_2_per_second) / PRECISION;
            
            model.base_rate_per_second + model.slope_1_per_second + excess_rate
        }
    }

    /// 计算存款利率
    /// 公式: Supply_Rate = Borrow_Rate × Utilization × (1 - Reserve_Factor)
    public fun get_supply_rate(
        borrow_rate: u128,
        utilization: u128,
        reserve_factor: u128
    ): u128 {
        // rate_to_pool = borrow_rate * (1 - reserve_factor)
        let rate_to_pool = (borrow_rate * (PRECISION - reserve_factor)) / PRECISION;
        
        // supply_rate = rate_to_pool * utilization
        (rate_to_pool * utilization) / PRECISION
    }

    /// 根据模型类型计算借款利率
    public fun calculate_borrow_rate(
        model: &InterestRateModel,
        utilization: u128
    ): u128 {
        if (model.is_kinked) {
            get_borrow_rate_kinked(&model.kinked_model, utilization)
        } else {
            get_borrow_rate_linear(&model.linear_model, utilization)
        }
    }

    /// 获取储备金率
    public fun get_reserve_factor(model: &InterestRateModel): u128 {
        if (model.is_kinked) {
            model.kinked_model.reserve_factor
        } else {
            model.linear_model.reserve_factor
        }
    }

    // ===================== 利息累积函数 =====================

    /// 更新市场利息指数
    /// 这是核心函数，每次操作前都需要调用
    public fun accrue_interest<CoinType>(
        market_addr: address
    ) acquires MarketState {
        let market = borrow_global_mut<MarketState<CoinType>>(market_addr);
        let current_timestamp = timestamp::now_seconds();
        let time_delta = current_timestamp - market.last_update_timestamp;
        
        // 如果在同一秒内，无需更新
        if (time_delta == 0) {
            return
        };
        
        // 计算使用率
        let utilization = calculate_utilization(
            market.total_deposits,
            market.total_borrows
        );
        
        // 计算借款利率（每秒）
        let borrow_rate = calculate_borrow_rate(&market.interest_rate_model, utilization);
        
        // 计算存款利率（每秒）
        let reserve_factor = get_reserve_factor(&market.interest_rate_model);
        let supply_rate = get_supply_rate(borrow_rate, utilization, reserve_factor);
        
        // 更新借款指数
        // new_index = old_index * (1 + rate * time_delta)
        let borrow_interest_factor = PRECISION + (borrow_rate * (time_delta as u128));
        market.borrow_index = (market.borrow_index * borrow_interest_factor) / PRECISION;
        
        // 更新存款指数
        let supply_interest_factor = PRECISION + (supply_rate * (time_delta as u128));
        market.supply_index = (market.supply_index * supply_interest_factor) / PRECISION;
        
        // 更新总借款（考虑利息）
        market.total_borrows = (market.total_borrows * borrow_interest_factor) / PRECISION;
        
        // 更新时间戳
        market.last_update_timestamp = current_timestamp;
        
        // 发出事件
        event::emit_event(&mut market.accrue_interest_events, AccrueInterestEvent {
            asset: market_addr,
            borrow_index: market.borrow_index,
            supply_index: market.supply_index,
            total_borrows: market.total_borrows,
            borrow_rate,
            supply_rate,
            timestamp: current_timestamp,
        });
    }

    // ===================== 用户余额查询 =====================

    /// 计算用户当前借款余额（含利息）
    public fun get_user_borrow_balance<CoinType>(
        user_addr: address,
        market_addr: address
    ): u128 acquires UserAccount, MarketState {
        if (!exists<UserAccount<CoinType>>(user_addr)) {
            return 0
        };
        
        let user = borrow_global<UserAccount<CoinType>>(user_addr);
        if (user.borrow_principal == 0) {
            return 0
        };
        
        let market = borrow_global<MarketState<CoinType>>(market_addr);
        
        // current_balance = principal * (current_index / user_index)
        (user.borrow_principal * market.borrow_index) / user.borrow_index
    }

    /// 计算用户当前存款余额（含利息）
    public fun get_user_deposit_balance<CoinType>(
        user_addr: address,
        market_addr: address
    ): u128 acquires UserAccount, MarketState {
        if (!exists<UserAccount<CoinType>>(user_addr)) {
            return 0
        };
        
        let user = borrow_global<UserAccount<CoinType>>(user_addr);
        if (user.deposit_principal == 0) {
            return 0
        };
        
        let market = borrow_global<MarketState<CoinType>>(market_addr);
        
        // current_balance = principal * (current_index / user_index)
        (user.deposit_principal * market.supply_index) / user.deposit_index
    }

    // ===================== 健康因子计算 =====================

    /// 计算用户健康因子
    /// 公式: HF = (总抵押品价值 × 抵押率) / 总债务价值
    /// 
    /// 注意：这是简化版本，实际应该支持多资产
    public fun calculate_health_factor<CollateralType, BorrowType>(
        user_addr: address,
        collateral_market: address,
        borrow_market: address,
        collateral_price: u128,  // 精度 1e8
        borrow_price: u128,      // 精度 1e8
    ): u128 acquires UserAccount, MarketState {
        // 获取抵押品余额
        let collateral_balance = get_user_deposit_balance<CollateralType>(
            user_addr,
            collateral_market
        );
        
        // 获取借款余额
        let borrow_balance = get_user_borrow_balance<BorrowType>(
            user_addr,
            borrow_market
        );
        
        // 如果没有借款，健康因子为无穷大
        if (borrow_balance == 0) {
            return MAX_HEALTH_FACTOR
        };
        
        // 获取抵押率
        let market = borrow_global<MarketState<CollateralType>>(collateral_market);
        let collateral_factor = market.liquidation_config.collateral_factor;
        
        // 计算抵押品价值（USD）
        // collateral_value = balance * price / PRICE_PRECISION
        let collateral_value = (collateral_balance * collateral_price) / PRICE_PRECISION;
        
        // 计算抵押能力
        // collateral_power = collateral_value * collateral_factor / PRECISION
        let collateral_power = (collateral_value * collateral_factor) / PRECISION;
        
        // 计算债务价值（USD）
        let debt_value = (borrow_balance * borrow_price) / PRICE_PRECISION;
        
        // 计算健康因子
        // HF = collateral_power / debt_value
        (collateral_power * PRECISION) / debt_value
    }

    // ===================== 清算检查函数 =====================

    /// 检查用户是否可以被清算
    public fun is_liquidatable<CollateralType, BorrowType>(
        user_addr: address,
        collateral_market: address,
        borrow_market: address,
        collateral_price: u128,
        borrow_price: u128,
    ): bool acquires UserAccount, MarketState {
        let health_factor = calculate_health_factor<CollateralType, BorrowType>(
            user_addr,
            collateral_market,
            borrow_market,
            collateral_price,
            borrow_price
        );
        
        let market = borrow_global<MarketState<BorrowType>>(borrow_market);
        health_factor < market.liquidation_config.min_health_factor
    }

    /// 计算清算信息
    public fun calculate_liquidation_info<CollateralType, BorrowType>(
        borrower: address,
        collateral_market: address,
        borrow_market: address,
        repay_amount: u128,
        collateral_price: u128,
        borrow_price: u128,
    ): LiquidationInfo acquires UserAccount, MarketState {
        // 1. 检查是否可清算
        let can_liquidate = is_liquidatable<CollateralType, BorrowType>(
            borrower,
            collateral_market,
            borrow_market,
            collateral_price,
            borrow_price
        );
        
        if (!can_liquidate) {
            return LiquidationInfo {
                can_liquidate: false,
                max_repay_amount: 0,
                collateral_to_seize: 0,
                liquidation_reward: 0,
            }
        };
        
        // 2. 计算最大清算金额
        let borrow_balance = get_user_borrow_balance<BorrowType>(borrower, borrow_market);
        let market = borrow_global<MarketState<BorrowType>>(borrow_market);
        let close_factor = market.liquidation_config.close_factor;
        let max_repay = (borrow_balance * close_factor) / PRECISION;
        
        // 3. 限制实际偿还金额
        let actual_repay = if (repay_amount > max_repay) {
            max_repay
        } else {
            repay_amount
        };
        
        // 4. 计算应获得的抵押品
        // collateral = (repay_amount * (1 + incentive) * borrow_price) / collateral_price
        let incentive = market.liquidation_config.liquidation_incentive;
        let repay_value = (actual_repay * borrow_price) / PRICE_PRECISION;
        let incentive_value = (repay_value * incentive) / PRECISION;
        let total_value = repay_value + incentive_value;
        let collateral_amount = (total_value * PRICE_PRECISION) / collateral_price;
        
        // 5. 计算奖励
        let reward = (actual_repay * incentive) / PRECISION;
        
        LiquidationInfo {
            can_liquidate: true,
            max_repay_amount: actual_repay,
            collateral_to_seize: collateral_amount,
            liquidation_reward: reward,
        }
    }

    // ===================== 清算执行函数 =====================

    /// 执行清算
    /// 
    /// 流程：
    /// 1. 检查健康因子
    /// 2. 计算清算金额
    /// 3. 转移偿还资产
    /// 4. 减少借款人债务
    /// 5. 转移抵押品
    /// 6. 发出事件
    public entry fun liquidate<CollateralType, BorrowType>(
        liquidator: &signer,
        borrower: address,
        collateral_market: address,
        borrow_market: address,
        repay_amount: u128,
        collateral_price: u128,
        borrow_price: u128,
    ) acquires MarketState, UserAccount {
        let liquidator_addr = signer::address_of(liquidator);
        
        // 1. 更新市场利息
        accrue_interest<CollateralType>(collateral_market);
        accrue_interest<BorrowType>(borrow_market);
        
        // 2. 计算清算信息
        let info = calculate_liquidation_info<CollateralType, BorrowType>(
            borrower,
            collateral_market,
            borrow_market,
            repay_amount,
            collateral_price,
            borrow_price
        );
        
        assert!(info.can_liquidate, ERROR_NOT_LIQUIDATABLE);
        assert!(info.max_repay_amount > 0, ERROR_ZERO_LIQUIDATION);
        
        // 3. 减少借款人的债务
        let borrower_account = borrow_global_mut<UserAccount<BorrowType>>(borrower);
        let borrow_market_state = borrow_global<MarketState<BorrowType>>(borrow_market);
        
        // 计算本金减少量
        let principal_to_reduce = (info.max_repay_amount * borrower_account.borrow_index) 
            / borrow_market_state.borrow_index;
        borrower_account.borrow_principal = borrower_account.borrow_principal - principal_to_reduce;
        
        // 4. 减少借款人的抵押品
        let borrower_collateral = borrow_global_mut<UserAccount<CollateralType>>(borrower);
        let collateral_market_state = borrow_global<MarketState<CollateralType>>(collateral_market);
        
        // 计算本金减少量
        let collateral_principal_to_seize = (info.collateral_to_seize * borrower_collateral.deposit_index)
            / collateral_market_state.supply_index;
        borrower_collateral.deposit_principal = borrower_collateral.deposit_principal - collateral_principal_to_seize;
        
        // 5. 增加清算人的抵押品
        if (!exists<UserAccount<CollateralType>>(liquidator_addr)) {
            move_to(liquidator, UserAccount<CollateralType> {
                deposit_principal: collateral_principal_to_seize,
                deposit_index: collateral_market_state.supply_index,
                borrow_principal: 0,
                borrow_index: PRECISION,
                is_collateral_enabled: false,
            });
        } else {
            let liquidator_account = borrow_global_mut<UserAccount<CollateralType>>(liquidator_addr);
            
            // 更新平均指数
            let current_balance = (liquidator_account.deposit_principal * collateral_market_state.supply_index)
                / liquidator_account.deposit_index;
            let new_balance = current_balance + info.collateral_to_seize;
            liquidator_account.deposit_principal = (new_balance * liquidator_account.deposit_index)
                / collateral_market_state.supply_index;
        };
        
        // 6. 更新市场总量
        let borrow_market_mut = borrow_global_mut<MarketState<BorrowType>>(borrow_market);
        borrow_market_mut.total_borrows = borrow_market_mut.total_borrows - info.max_repay_amount;
        
        // 7. 计算新的健康因子
        let new_health_factor = calculate_health_factor<CollateralType, BorrowType>(
            borrower,
            collateral_market,
            borrow_market,
            collateral_price,
            borrow_price
        );
        
        // 8. 发出清算事件
        event::emit_event(&mut borrow_market_mut.liquidation_events, LiquidationEvent {
            liquidator: liquidator_addr,
            borrower,
            repay_asset: borrow_market,
            collateral_asset: collateral_market,
            repay_amount: info.max_repay_amount,
            collateral_seized: info.collateral_to_seize,
            liquidation_reward: info.liquidation_reward,
            new_health_factor,
            timestamp: timestamp::now_seconds(),
        });
    }

    // ===================== 辅助函数 =====================

    /// 将年化利率转换为每秒利率
    public fun annual_rate_to_per_second(annual_rate: u128): u128 {
        annual_rate / SECONDS_PER_YEAR
    }

    /// 将每秒利率转换为年化利率（APR）
    public fun per_second_to_annual_rate(per_second_rate: u128): u128 {
        per_second_rate * SECONDS_PER_YEAR
    }

    /// 计算 APY（复合年化收益率）
    /// APY = (1 + rate)^periods - 1
    /// 
    /// 注意：这里使用近似计算，实际应该使用更精确的指数运算
    public fun calculate_apy(per_second_rate: u128): u128 {
        // 简化版本：APY ≈ APR × 1.005（考虑复利）
        let apr = per_second_to_annual_rate(per_second_rate);
        (apr * 1005) / 1000
    }

    // ===================== 查询函数（用于前端）=====================

    /// 获取市场信息
    public fun get_market_info<CoinType>(
        market_addr: address
    ): (u128, u128, u128, u128, u128, u64) acquires MarketState {
        let market = borrow_global<MarketState<CoinType>>(market_addr);
        
        let utilization = calculate_utilization(market.total_deposits, market.total_borrows);
        let borrow_rate = calculate_borrow_rate(&market.interest_rate_model, utilization);
        let reserve_factor = get_reserve_factor(&market.interest_rate_model);
        let supply_rate = get_supply_rate(borrow_rate, utilization, reserve_factor);
        
        (
            market.total_deposits,
            market.total_borrows,
            utilization,
            borrow_rate,
            supply_rate,
            market.last_update_timestamp
        )
    }

    /// 获取用户账户信息
    public fun get_user_account_info<CoinType>(
        user_addr: address,
        market_addr: address
    ): (u128, u128, bool) acquires UserAccount, MarketState {
        let deposit_balance = get_user_deposit_balance<CoinType>(user_addr, market_addr);
        let borrow_balance = get_user_borrow_balance<CoinType>(user_addr, market_addr);
        
        let user = borrow_global<UserAccount<CoinType>>(user_addr);
        
        (deposit_balance, borrow_balance, user.is_collateral_enabled)
    }

    // ===================== 测试辅助函数 =====================

    #[test_only]
    /// 创建测试用跳跃利率模型（USDC 参数）
    public fun create_test_kinked_model_usdc(): InterestRateModel {
        InterestRateModel {
            is_kinked: true,
            linear_model: LinearInterestRateModel {
                base_rate_per_second: 0,
                slope_per_second: 0,
                reserve_factor: 0,
            },
            kinked_model: KinkedInterestRateModel {
                base_rate_per_second: 0,                              // 0% 基础利率
                optimal_utilization: 900_000_000_000_000_000,          // 90% 最优使用率
                slope_1_per_second: 40_000_000_000_000_000 / SECONDS_PER_YEAR,  // 4% 斜率 1
                slope_2_per_second: 600_000_000_000_000_000 / SECONDS_PER_YEAR, // 60% 斜率 2
                reserve_factor: 100_000_000_000_000_000,               // 10% 储备金率
            },
        }
    }

    #[test_only]
    /// 创建测试用清算配置
    public fun create_test_liquidation_config(): LiquidationConfig {
        LiquidationConfig {
            close_factor: 500_000_000_000_000_000,           // 50%
            liquidation_incentive: 100_000_000_000_000_000,  // 10%
            liquidation_penalty: 120_000_000_000_000_000,    // 12%
            min_health_factor: PRECISION,                     // 1.0
            collateral_factor: 750_000_000_000_000_000,      // 75%
        }
    }
}
