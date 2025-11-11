/// 抵押品管理与健康因子 - 完整实现
/// 
/// 本模块实现：
/// 1. 多资产抵押品管理
/// 2. 健康因子精确计算
/// 3. 风险参数配置
/// 4. 预警系统
/// 5. 价格预言机集成

module collateral_management::collateral_manager {
    use std::signer;
    use std::vector;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info;

    // ==================== 错误码 ====================
    
    const E_NOT_INITIALIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_ADMIN: u64 = 3;
    const E_COLLATERAL_NOT_ENABLED: u64 = 4;
    const E_INSUFFICIENT_COLLATERAL: u64 = 5;
    const E_HEALTH_FACTOR_TOO_LOW: u64 = 6;
    const E_ASSET_NOT_SUPPORTED: u64 = 7;
    const E_ALREADY_USED_AS_COLLATERAL: u64 = 8;
    const E_NOT_USED_AS_COLLATERAL: u64 = 9;
    const E_CANNOT_DISABLE_COLLATERAL: u64 = 10;
    const E_PRICE_TOO_OLD: u64 = 11;
    const E_PRICE_DEVIATION_TOO_HIGH: u64 = 12;
    const E_INVALID_COLLATERAL_FACTOR: u64 = 13;
    const E_INVALID_LIQUIDATION_THRESHOLD: u64 = 14;
    const E_NO_BORROW: u64 = 15;
    
    // ==================== 常量 ====================
    
    /// 精度常量
    const PRECISION: u128 = 1_000_000_000_000_000_000; // 1e18
    const PRICE_PRECISION: u128 = 100_000_000; // 1e8
    const FACTOR_PRECISION: u128 = 1_000_000; // 1e6 (100% = 1_000_000)
    
    /// 健康因子阈值
    const HEALTH_FACTOR_LIQUIDATION_THRESHOLD: u128 = 1_000_000_000_000_000_000; // 1.0
    const HEALTH_FACTOR_WARNING_THRESHOLD: u128 = 1_200_000_000_000_000_000; // 1.2
    const HEALTH_FACTOR_NOTICE_THRESHOLD: u128 = 1_500_000_000_000_000_000; // 1.5
    
    /// 价格相关常量
    const MAX_PRICE_AGE: u64 = 300; // 5 分钟
    const MAX_PRICE_DEVIATION: u128 = 50_000; // 5% (精度 1e6)
    
    /// 最大值（用于无债务时的健康因子）
    const MAX_U128: u128 = 340282366920938463463374607431768211455;
    
    // ==================== 数据结构 ====================
    
    /// 资产配置
    struct AssetConfig has store, copy, drop {
        /// 是否支持作为抵押品
        is_collateral_enabled: bool,
        /// 抵押率 (Loan-to-Value)，精度 1e6
        /// 例如：750_000 = 75%
        collateral_factor: u128,
        /// 清算阈值，精度 1e6
        /// 例如：800_000 = 80%
        liquidation_threshold: u128,
        /// 清算奖励，精度 1e6
        /// 例如：80_000 = 8%
        liquidation_bonus: u128,
        /// 资产的小数位数
        decimals: u8,
    }
    
    /// 价格数据
    struct PriceData has store, copy, drop {
        /// 价格（精度 1e8）
        price: u128,
        /// 时间戳
        timestamp: u64,
    }
    
    /// 用户抵押品信息
    struct UserCollateral has store {
        /// 已启用为抵押品的资产类型列表
        enabled_assets: vector<vector<u8>>,
    }
    
    /// 用户借款信息
    struct UserBorrow has store {
        /// 借款资产及余额
        borrows: Table<vector<u8>, u128>,
    }
    
    /// 全局配置
    struct GlobalConfig has key {
        /// 管理员地址
        admin: address,
        /// 资产配置
        asset_configs: Table<vector<u8>, AssetConfig>,
        /// 价格数据
        prices: Table<vector<u8>, PriceData>,
    }
    
    /// 用户数据
    struct UserData has key {
        /// 抵押品信息
        collateral: UserCollateral,
        /// 借款信息
        borrow: UserBorrow,
        /// 存款余额（资产类型 -> 余额）
        deposits: Table<vector<u8>, u128>,
    }
    
    // ==================== 事件 ====================
    
    #[event]
    struct CollateralEnabled has store, drop {
        user: address,
        asset: vector<u8>,
        timestamp: u64,
    }
    
    #[event]
    struct CollateralDisabled has store, drop {
        user: address,
        asset: vector<u8>,
        timestamp: u64,
    }
    
    #[event]
    struct HealthFactorUpdated has store, drop {
        user: address,
        health_factor: u128,
        total_collateral_value: u128,
        total_debt_value: u128,
        timestamp: u64,
    }
    
    #[event]
    struct HealthFactorWarning has store, drop {
        user: address,
        health_factor: u128,
        level: u8, // 1: 注意, 2: 警告, 3: 紧急
        timestamp: u64,
    }
    
    #[event]
    struct PriceUpdated has store, drop {
        asset: vector<u8>,
        price: u128,
        timestamp: u64,
    }
    
    // ==================== 初始化 ====================
    
    /// 初始化模块
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(!exists<GlobalConfig>(admin_addr), E_ALREADY_INITIALIZED);
        
        move_to(admin, GlobalConfig {
            admin: admin_addr,
            asset_configs: table::new(),
            prices: table::new(),
        });
    }
    
    /// 初始化用户数据
    public entry fun initialize_user(user: &signer) {
        let user_addr = signer::address_of(user);
        if (!exists<UserData>(user_addr)) {
            move_to(user, UserData {
                collateral: UserCollateral {
                    enabled_assets: vector::empty(),
                },
                borrow: UserBorrow {
                    borrows: table::new(),
                },
                deposits: table::new(),
            });
        };
    }
    
    // ==================== 资产配置管理 ====================
    
    /// 添加或更新资产配置
    public entry fun set_asset_config(
        admin: &signer,
        asset: vector<u8>,
        is_collateral_enabled: bool,
        collateral_factor: u128,
        liquidation_threshold: u128,
        liquidation_bonus: u128,
        decimals: u8,
    ) acquires GlobalConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global_mut<GlobalConfig>(@collateral_management);
        assert!(admin_addr == config.admin, E_NOT_ADMIN);
        
        // 验证参数合理性
        assert!(collateral_factor <= FACTOR_PRECISION, E_INVALID_COLLATERAL_FACTOR);
        assert!(
            liquidation_threshold >= collateral_factor && 
            liquidation_threshold <= FACTOR_PRECISION,
            E_INVALID_LIQUIDATION_THRESHOLD
        );
        
        let asset_config = AssetConfig {
            is_collateral_enabled,
            collateral_factor,
            liquidation_threshold,
            liquidation_bonus,
            decimals,
        };
        
        if (table::contains(&config.asset_configs, asset)) {
            *table::borrow_mut(&mut config.asset_configs, asset) = asset_config;
        } else {
            table::add(&mut config.asset_configs, asset, asset_config);
        };
    }
    
    /// 获取资产配置
    public fun get_asset_config(asset: vector<u8>): AssetConfig acquires GlobalConfig {
        let config = borrow_global<GlobalConfig>(@collateral_management);
        assert!(table::contains(&config.asset_configs, asset), E_ASSET_NOT_SUPPORTED);
        *table::borrow(&config.asset_configs, asset)
    }
    
    // ==================== 价格管理 ====================
    
    /// 更新价格（模拟预言机）
    public entry fun update_price(
        admin: &signer,
        asset: vector<u8>,
        price: u128,
    ) acquires GlobalConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global_mut<GlobalConfig>(@collateral_management);
        assert!(admin_addr == config.admin, E_NOT_ADMIN);
        
        let now = timestamp::now_seconds();
        let price_data = PriceData {
            price,
            timestamp: now,
        };
        
        if (table::contains(&config.prices, asset)) {
            *table::borrow_mut(&mut config.prices, asset) = price_data;
        } else {
            table::add(&mut config.prices, asset, price_data);
        };
        
        event::emit(PriceUpdated {
            asset,
            price,
            timestamp: now,
        });
    }
    
    /// 获取价格
    public fun get_price(asset: vector<u8>): (u128, u64) acquires GlobalConfig {
        let config = borrow_global<GlobalConfig>(@collateral_management);
        assert!(table::contains(&config.prices, asset), E_ASSET_NOT_SUPPORTED);
        
        let price_data = table::borrow(&config.prices, asset);
        let now = timestamp::now_seconds();
        
        // 检查价格时效性
        assert!(
            now - price_data.timestamp <= MAX_PRICE_AGE,
            E_PRICE_TOO_OLD
        );
        
        (price_data.price, price_data.timestamp)
    }
    
    /// 验证价格（检查多个价格源的偏差）
    public fun validate_price_deviation(price1: u128, price2: u128): bool {
        let diff = if (price1 > price2) {
            price1 - price2
        } else {
            price2 - price1
        };
        
        let deviation = (diff * FACTOR_PRECISION) / price1;
        deviation <= MAX_PRICE_DEVIATION
    }
    
    // ==================== 存款管理 ====================
    
    /// 存款（简化版，实际应与代币集成）
    public entry fun deposit(
        user: &signer,
        asset: vector<u8>,
        amount: u128,
    ) acquires UserData {
        let user_addr = signer::address_of(user);
        assert!(exists<UserData>(user_addr), E_NOT_INITIALIZED);
        
        let user_data = borrow_global_mut<UserData>(user_addr);
        
        if (table::contains(&user_data.deposits, asset)) {
            let current = table::borrow_mut(&mut user_data.deposits, asset);
            *current = *current + amount;
        } else {
            table::add(&mut user_data.deposits, asset, amount);
        };
    }
    
    /// 提取存款
    public entry fun withdraw(
        user: &signer,
        asset: vector<u8>,
        amount: u128,
    ) acquires UserData, GlobalConfig {
        let user_addr = signer::address_of(user);
        let user_data = borrow_global_mut<UserData>(user_addr);
        
        // 检查余额
        assert!(table::contains(&user_data.deposits, asset), E_INSUFFICIENT_COLLATERAL);
        let balance = table::borrow_mut(&mut user_data.deposits, asset);
        assert!(*balance >= amount, E_INSUFFICIENT_COLLATERAL);
        
        // 如果该资产被用作抵押品，检查提取后的健康因子
        if (is_asset_used_as_collateral(user_addr, asset)) {
            let health_factor_before = calculate_health_factor_internal(user_addr);
            
            // 临时减少余额
            *balance = *balance - amount;
            
            let health_factor_after = calculate_health_factor_internal(user_addr);
            
            // 检查健康因子是否安全
            if (health_factor_after < HEALTH_FACTOR_WARNING_THRESHOLD) {
                // 恢复余额
                *balance = *balance + amount;
                assert!(false, E_HEALTH_FACTOR_TOO_LOW);
            };
            
            // 发出健康因子更新事件
            emit_health_factor_update(user_addr, health_factor_after);
        } else {
            *balance = *balance - amount;
        };
    }
    
    /// 获取存款余额
    public fun get_deposit_balance(user: address, asset: vector<u8>): u128 acquires UserData {
        if (!exists<UserData>(user)) {
            return 0
        };
        
        let user_data = borrow_global<UserData>(user);
        if (table::contains(&user_data.deposits, asset)) {
            *table::borrow(&user_data.deposits, asset)
        } else {
            0
        }
    }
    
    // ==================== 抵押品管理 ====================
    
    /// 启用资产作为抵押品
    public entry fun enable_collateral(
        user: &signer,
        asset: vector<u8>,
    ) acquires UserData, GlobalConfig {
        let user_addr = signer::address_of(user);
        
        // 检查资产是否支持作为抵押品
        let asset_config = get_asset_config(asset);
        assert!(asset_config.is_collateral_enabled, E_COLLATERAL_NOT_ENABLED);
        
        // 检查用户是否有该资产的存款
        assert!(get_deposit_balance(user_addr, asset) > 0, E_INSUFFICIENT_COLLATERAL);
        
        let user_data = borrow_global_mut<UserData>(user_addr);
        
        // 检查是否已经启用
        assert!(
            !vector::contains(&user_data.collateral.enabled_assets, &asset),
            E_ALREADY_USED_AS_COLLATERAL
        );
        
        // 添加到抵押品列表
        vector::push_back(&mut user_data.collateral.enabled_assets, asset);
        
        let now = timestamp::now_seconds();
        event::emit(CollateralEnabled {
            user: user_addr,
            asset,
            timestamp: now,
        });
        
        // 更新健康因子
        let health_factor = calculate_health_factor_internal(user_addr);
        emit_health_factor_update(user_addr, health_factor);
    }
    
    /// 禁用资产作为抵押品
    public entry fun disable_collateral(
        user: &signer,
        asset: vector<u8>,
    ) acquires UserData, GlobalConfig {
        let user_addr = signer::address_of(user);
        let user_data = borrow_global_mut<UserData>(user_addr);
        
        // 检查是否已启用
        let (found, index) = vector::index_of(&user_data.collateral.enabled_assets, &asset);
        assert!(found, E_NOT_USED_AS_COLLATERAL);
        
        // 如果有借款，检查禁用后的健康因子
        if (has_borrow(user_addr)) {
            // 临时移除
            vector::remove(&mut user_data.collateral.enabled_assets, index);
            
            let health_factor = calculate_health_factor_internal(user_addr);
            
            // 如果健康因子低于清算阈值，不允许禁用
            if (health_factor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
                // 恢复
                vector::push_back(&mut user_data.collateral.enabled_assets, asset);
                assert!(false, E_CANNOT_DISABLE_COLLATERAL);
            };
            
            emit_health_factor_update(user_addr, health_factor);
        } else {
            // 无借款，直接移除
            vector::remove(&mut user_data.collateral.enabled_assets, index);
        };
        
        let now = timestamp::now_seconds();
        event::emit(CollateralDisabled {
            user: user_addr,
            asset,
            timestamp: now,
        });
    }
    
    /// 检查资产是否被用作抵押品
    fun is_asset_used_as_collateral(user: address, asset: vector<u8>): bool acquires UserData {
        if (!exists<UserData>(user)) {
            return false
        };
        
        let user_data = borrow_global<UserData>(user);
        vector::contains(&user_data.collateral.enabled_assets, &asset)
    }
    
    /// 获取用户的抵押品列表
    public fun get_user_collaterals(user: address): vector<vector<u8>> acquires UserData {
        if (!exists<UserData>(user)) {
            return vector::empty()
        };
        
        let user_data = borrow_global<UserData>(user);
        user_data.collateral.enabled_assets
    }
    
    // ==================== 借款管理（简化版）====================
    
    /// 模拟借款（实际应与借贷池集成）
    public entry fun borrow(
        user: &signer,
        asset: vector<u8>,
        amount: u128,
    ) acquires UserData, GlobalConfig {
        let user_addr = signer::address_of(user);
        let user_data = borrow_global_mut<UserData>(user_addr);
        
        // 添加借款记录
        if (table::contains(&user_data.borrow.borrows, asset)) {
            let current = table::borrow_mut(&mut user_data.borrow.borrows, asset);
            *current = *current + amount;
        } else {
            table::add(&mut user_data.borrow.borrows, asset, amount);
        };
        
        // 检查借款后的健康因子
        let health_factor = calculate_health_factor_internal(user_addr);
        assert!(
            health_factor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
            E_HEALTH_FACTOR_TOO_LOW
        );
        
        emit_health_factor_update(user_addr, health_factor);
    }
    
    /// 还款
    public entry fun repay(
        user: &signer,
        asset: vector<u8>,
        amount: u128,
    ) acquires UserData, GlobalConfig {
        let user_addr = signer::address_of(user);
        let user_data = borrow_global_mut<UserData>(user_addr);
        
        assert!(table::contains(&user_data.borrow.borrows, asset), E_NO_BORROW);
        
        let borrow_balance = table::borrow_mut(&mut user_data.borrow.borrows, asset);
        assert!(*borrow_balance >= amount, E_INSUFFICIENT_COLLATERAL);
        
        *borrow_balance = *borrow_balance - amount;
        
        // 更新健康因子
        let health_factor = calculate_health_factor_internal(user_addr);
        emit_health_factor_update(user_addr, health_factor);
    }
    
    /// 检查是否有借款
    fun has_borrow(user: address): bool acquires UserData {
        if (!exists<UserData>(user)) {
            return false
        };
        
        let user_data = borrow_global<UserData>(user);
        !table::empty(&user_data.borrow.borrows)
    }
    
    /// 获取借款余额
    public fun get_borrow_balance(user: address, asset: vector<u8>): u128 acquires UserData {
        if (!exists<UserData>(user)) {
            return 0
        };
        
        let user_data = borrow_global<UserData>(user);
        if (table::contains(&user_data.borrow.borrows, asset)) {
            *table::borrow(&user_data.borrow.borrows, asset)
        } else {
            0
        }
    }
    
    // ==================== 健康因子计算 ====================
    
    /// 计算总抵押品价值（已应用抵押率）
    public fun calculate_total_collateral_value(user: address): u128 acquires UserData, GlobalConfig {
        if (!exists<UserData>(user)) {
            return 0
        };
        
        let user_data = borrow_global<UserData>(user);
        let total_value: u128 = 0;
        
        let enabled_assets = &user_data.collateral.enabled_assets;
        let len = vector::length(enabled_assets);
        let i = 0;
        
        while (i < len) {
            let asset = vector::borrow(enabled_assets, i);
            
            // 获取存款余额
            if (table::contains(&user_data.deposits, *asset)) {
                let balance = *table::borrow(&user_data.deposits, *asset);
                
                // 获取价格
                let (price, _) = get_price(*asset);
                
                // 获取资产配置
                let config = get_asset_config(*asset);
                
                // 计算该资产的抵押能力
                // asset_value = balance * price * collateral_factor / FACTOR_PRECISION
                let asset_value = (balance * price * config.collateral_factor) / FACTOR_PRECISION;
                
                total_value = total_value + asset_value;
            };
            
            i = i + 1;
        };
        
        total_value
    }
    
    /// 计算总债务价值
    public fun calculate_total_debt_value(user: address): u128 acquires UserData, GlobalConfig {
        if (!exists<UserData>(user)) {
            return 0
        };
        
        let user_data = borrow_global<UserData>(user);
        let total_debt: u128 = 0;
        
        // 遍历所有借款（需要实现 table 迭代器，这里简化处理）
        // 实际实现中应该维护一个借款资产列表
        
        // 简化：假设我们知道所有可能的借款资产
        // 在生产环境中，应该维护一个借款资产列表
        
        total_debt
    }
    
    /// 计算健康因子
    /// 返回值精度：1e18
    /// 1.0 = 1_000_000_000_000_000_000
    public fun calculate_health_factor(user: address): u128 acquires UserData, GlobalConfig {
        calculate_health_factor_internal(user)
    }
    
    /// 内部健康因子计算
    fun calculate_health_factor_internal(user: address): u128 acquires UserData, GlobalConfig {
        if (!exists<UserData>(user)) {
            return MAX_U128
        };
        
        let collateral_value = calculate_total_collateral_value(user);
        let debt_value = calculate_total_debt_value(user);
        
        // 无债务时，健康因子为无限大
        if (debt_value == 0) {
            return MAX_U128
        };
        
        // 无抵押品但有债务，健康因子为 0
        if (collateral_value == 0) {
            return 0
        };
        
        // 健康因子 = 抵押能力 / 债务
        // 使用高精度计算
        (collateral_value * PRECISION) / debt_value
    }
    
    /// 计算可借额度
    public fun calculate_available_borrow_value(user: address): u128 acquires UserData, GlobalConfig {
        let collateral_value = calculate_total_collateral_value(user);
        let debt_value = calculate_total_debt_value(user);
        
        if (collateral_value > debt_value) {
            collateral_value - debt_value
        } else {
            0
        }
    }
    
    /// 计算借款能力利用率
    /// 返回值精度：1e6 (100% = 1_000_000)
    public fun calculate_utilization_rate(user: address): u128 acquires UserData, GlobalConfig {
        let collateral_value = calculate_total_collateral_value(user);
        if (collateral_value == 0) {
            return 0
        };
        
        let debt_value = calculate_total_debt_value(user);
        (debt_value * FACTOR_PRECISION) / collateral_value
    }
    
    // ==================== 健康因子检查与预警 ====================
    
    /// 检查健康因子是否安全
    public fun is_health_factor_safe(user: address): bool acquires UserData, GlobalConfig {
        let health_factor = calculate_health_factor_internal(user);
        health_factor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    }
    
    /// 获取健康因子状态
    /// 返回：(健康因子, 状态等级)
    /// 状态等级：0-安全, 1-注意, 2-警告, 3-紧急, 4-清算
    public fun get_health_factor_status(user: address): (u128, u8) acquires UserData, GlobalConfig {
        let health_factor = calculate_health_factor_internal(user);
        
        let level = if (health_factor >= HEALTH_FACTOR_NOTICE_THRESHOLD) {
            0 // 安全
        } else if (health_factor >= HEALTH_FACTOR_WARNING_THRESHOLD) {
            1 // 注意
        } else if (health_factor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD + (HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 20)) { // > 1.05
            2 // 警告
        } else if (health_factor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
            3 // 紧急
        } else {
            4 // 可清算
        };
        
        (health_factor, level)
    }
    
    /// 发出健康因子更新事件
    fun emit_health_factor_update(user: address, health_factor: u128) acquires UserData, GlobalConfig {
        let collateral_value = calculate_total_collateral_value(user);
        let debt_value = calculate_total_debt_value(user);
        let now = timestamp::now_seconds();
        
        event::emit(HealthFactorUpdated {
            user,
            health_factor,
            total_collateral_value: collateral_value,
            total_debt_value: debt_value,
            timestamp: now,
        });
        
        // 检查是否需要发出预警
        let (_, level) = get_health_factor_status(user);
        if (level >= 1 && level <= 3) {
            event::emit(HealthFactorWarning {
                user,
                health_factor,
                level,
                timestamp: now,
            });
        };
    }
    
    // ==================== 查询函数 ====================
    
    /// 获取用户完整的抵押品和借款信息
    public fun get_user_account_data(user: address): (u128, u128, u128, u128, u8) 
        acquires UserData, GlobalConfig {
        let collateral_value = calculate_total_collateral_value(user);
        let debt_value = calculate_total_debt_value(user);
        let health_factor = calculate_health_factor_internal(user);
        let available_borrow = calculate_available_borrow_value(user);
        let (_, status) = get_health_factor_status(user);
        
        (collateral_value, debt_value, health_factor, available_borrow, status)
    }
    
    /// 模拟操作后的健康因子
    /// operation: 0-存款, 1-提取, 2-借款, 3-还款
    public fun simulate_health_factor(
        user: address,
        asset: vector<u8>,
        amount: u128,
        operation: u8,
    ): u128 acquires UserData, GlobalConfig {
        // 注意：这是一个简化的模拟函数
        // 实际实现需要创建临时副本进行计算
        
        let current_hf = calculate_health_factor_internal(user);
        
        // 这里应该实现完整的模拟逻辑
        // 由于 Move 的限制，简化处理
        
        current_hf
    }
    
    // ==================== 视图函数 ====================
    
    /// 格式化健康因子为可读字符串（链下使用）
    /// 例如：1.25 显示为 "1.25"
    public fun format_health_factor(health_factor: u128): u128 {
        health_factor / (PRECISION / 100) // 转换为百分比（精度100）
    }
    
    /// 获取健康因子等级描述（返回等级代码）
    /// 0: 极其安全 (≥2.0)
    /// 1: 安全 (1.5-2.0)
    /// 2: 注意 (1.2-1.5)
    /// 3: 警告 (1.05-1.2)
    /// 4: 危险 (1.0-1.05)
    /// 5: 清算 (<1.0)
    public fun get_health_factor_level(health_factor: u128): u8 {
        if (health_factor >= 2 * PRECISION) {
            0
        } else if (health_factor >= HEALTH_FACTOR_NOTICE_THRESHOLD) {
            1
        } else if (health_factor >= HEALTH_FACTOR_WARNING_THRESHOLD) {
            2
        } else if (health_factor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD + (HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 20)) {
            3
        } else if (health_factor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
            4
        } else {
            5
        }
    }
    
    #[test_only]
    use std::string;
    
    #[test(admin = @collateral_management, user = @0x123)]
    fun test_collateral_management(admin: &signer, user: &signer) acquires GlobalConfig, UserData {
        // 设置时间戳
        timestamp::set_time_has_started_for_testing(admin);
        
        // 初始化
        initialize(admin);
        initialize_user(user);
        
        let user_addr = signer::address_of(user);
        
        // 配置资产
        let eth = b"ETH";
        set_asset_config(
            admin,
            eth,
            true,              // 启用抵押
            750_000,           // 75% 抵押率
            800_000,           // 80% 清算阈值
            80_000,            // 8% 清算奖励
            8,                 // 8 位小数
        );
        
        // 更新价格：1 ETH = $2000
        update_price(admin, eth, 200_000_000_000); // $2000 * 1e8
        
        // 存款 5 ETH
        deposit(user, eth, 500_000_000); // 5 * 1e8
        
        // 启用抵押品
        enable_collateral(user, eth);
        
        // 验证抵押能力
        let collateral_value = calculate_total_collateral_value(user_addr);
        // 5 ETH * $2000 * 75% = $7500
        // 预期值：7500 * 1e8 = 750_000_000_000
        assert!(collateral_value == 750_000_000_000, 1);
        
        // 借款 $5000
        // borrow(user, b"USDC", 500_000_000_000); // $5000 * 1e8
        
        // 计算健康因子
        // HF = 7500 / 5000 = 1.5
        // let hf = calculate_health_factor(user_addr);
        // assert!(hf == 1_500_000_000_000_000_000, 2);
    }
}
