/// 代码示例：价格预言机集成完整实现
/// 
/// 本文件包含：
/// 1. Pyth Oracle 集成示例
/// 2. Switchboard Oracle 集成示例
/// 3. 价格聚合器实现
/// 4. 实际应用示例

// ============================================================================
// 1. Pyth Oracle 集成
// ============================================================================

module day18::pyth_integration {
    use std::vector;
    use std::signer;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    
    // 注意：实际使用时需要导入 Pyth SDK
    // use pyth::pyth;
    // use pyth::price;
    // use pyth::i64;
    
    /// 错误码
    const ERROR_STALE_PRICE: u64 = 1;
    const ERROR_LOW_CONFIDENCE: u64 = 2;
    const ERROR_INVALID_PRICE: u64 = 3;
    const ERROR_PRICE_FEED_NOT_FOUND: u64 = 4;
    
    /// 价格 Feed 配置
    struct PriceFeedConfig has key {
        /// Feed ID (Pyth 提供的唯一标识符)
        feed_id: vector<u8>,
        
        /// 最大价格年龄（秒）
        max_price_age: u64,
        
        /// 最大置信区间（basis points）
        max_confidence_bp: u64,
        
        /// 小数位数
        decimals: u8,
    }
    
    /// 价格数据缓存
    struct PriceCache has key {
        price: u64,
        confidence: u64,
        timestamp: u64,
        expo: i64,
    }
    
    /// 价格更新事件
    struct PriceUpdateEvent has drop, store {
        feed_id: vector<u8>,
        price: u64,
        confidence: u64,
        timestamp: u64,
    }
    
    /// 初始化价格 Feed
    public entry fun initialize_price_feed(
        admin: &signer,
        feed_id: vector<u8>,
        max_price_age: u64,
        max_confidence_bp: u64,
        decimals: u8
    ) {
        let config = PriceFeedConfig {
            feed_id,
            max_price_age,
            max_confidence_bp,
            decimals,
        };
        
        move_to(admin, config);
    }
    
    /// 从 Pyth 获取价格（模拟实现）
    /// 实际使用时应调用 pyth::get_price_unsafe()
    public fun get_price_from_pyth(
        feed_id: vector<u8>
    ): (u64, u64, u64, i64) {
        // 模拟返回值
        // 实际代码：
        // let price_struct = pyth::get_price_unsafe(feed_id);
        // let price = price::get_price(&price_struct);
        // let conf = price::get_conf(&price_struct);
        // let timestamp = price::get_timestamp(&price_struct);
        // let expo = price::get_expo(&price_struct);
        
        // 这里返回模拟数据
        let _ = feed_id;
        let price = 45000_00000000u64;  // BTC: $45,000
        let confidence = 500_00000u64;   // ±$5
        let timestamp = timestamp::now_seconds();
        let expo = -8i64;  // 10^-8
        
        (price, confidence, timestamp, expo)
    }
    
    /// 获取验证过的价格
    public fun get_validated_price(
        feed_id: vector<u8>,
        max_price_age: u64,
        max_confidence_bp: u64
    ): (u64, u64) {
        // 1. 从 Pyth 获取原始价格
        let (raw_price, confidence, timestamp, expo) = get_price_from_pyth(feed_id);
        
        // 2. 检查价格新鲜度
        let current_time = timestamp::now_seconds();
        assert!(
            current_time - timestamp <= max_price_age,
            ERROR_STALE_PRICE
        );
        
        // 3. 检查价格有效性
        assert!(raw_price > 0, ERROR_INVALID_PRICE);
        
        // 4. 转换为标准格式（6 decimals）
        let price = convert_price_to_standard(raw_price, expo);
        let conf = convert_price_to_standard(confidence, expo);
        
        // 5. 检查置信区间
        let confidence_bp = (conf as u128) * 10000 / (price as u128);
        assert!(
            confidence_bp <= (max_confidence_bp as u128),
            ERROR_LOW_CONFIDENCE
        );
        
        (price, timestamp)
    }
    
    /// 转换价格格式
    /// Pyth 价格格式：price * 10^expo
    /// 目标格式：6 decimals
    fun convert_price_to_standard(
        price: u64,
        expo: i64
    ): u64 {
        // 简化实现：假设 expo = -8，目标 6 decimals
        // 实际需要处理各种 expo 值
        
        let _ = expo;
        // price / 10^2 (从 8 decimals 转为 6 decimals)
        price / 100
    }
    
    /// 示例：获取 BTC/USD 价格
    #[view]
    public fun get_btc_usd_price(): (u64, u64) {
        // BTC/USD Price Feed ID (Pyth Mainnet)
        let feed_id = x"e62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43";
        
        // 参数：60秒内，置信度 < 1%
        get_validated_price(feed_id, 60, 100)
    }
    
    /// 示例：获取 ETH/USD 价格
    #[view]
    public fun get_eth_usd_price(): (u64, u64) {
        // ETH/USD Price Feed ID
        let feed_id = x"ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";
        
        get_validated_price(feed_id, 60, 100)
    }
    
    /// 示例：获取 APT/USD 价格
    #[view]
    public fun get_apt_usd_price(): (u64, u64) {
        // APT/USD Price Feed ID
        let feed_id = x"03ae4db29ed4ae33d323568895aa00337e658e348b37509f5372ae51f0af00d5";
        
        get_validated_price(feed_id, 60, 100)
    }
}

// ============================================================================
// 2. Switchboard Oracle 集成
// ============================================================================

module day18::switchboard_integration {
    use std::signer;
    use aptos_framework::timestamp;
    
    // 注意：实际使用时需要导入 Switchboard SDK
    // use switchboard::aggregator;
    
    /// 错误码
    const ERROR_STALE_PRICE: u64 = 1;
    const ERROR_AGGREGATOR_INACTIVE: u64 = 2;
    const ERROR_INVALID_PRICE: u64 = 3;
    
    /// Switchboard 聚合器配置
    struct AggregatorConfig has key {
        /// 聚合器地址
        aggregator_addr: address,
        
        /// 最大价格年龄
        max_price_age: u64,
        
        /// 价格名称
        name: vector<u8>,
    }
    
    /// 从 Switchboard 获取价格（模拟实现）
    public fun get_price_from_switchboard(
        aggregator_addr: address
    ): (u128, u64) {
        // 实际代码：
        // let value = aggregator::latest_value(aggregator_addr);
        // let timestamp = aggregator::latest_timestamp(aggregator_addr);
        
        // 模拟返回
        let _ = aggregator_addr;
        let value = 45000_000000u128;  // BTC: $45,000 (6 decimals)
        let timestamp = timestamp::now_seconds();
        
        (value, timestamp)
    }
    
    /// 检查聚合器是否活跃（模拟）
    public fun is_aggregator_active(
        aggregator_addr: address
    ): bool {
        // 实际代码：
        // aggregator::is_active(aggregator_addr)
        
        let _ = aggregator_addr;
        true
    }
    
    /// 获取验证过的价格
    public fun get_validated_price(
        aggregator_addr: address,
        max_price_age: u64
    ): (u64, u64) {
        // 1. 检查聚合器状态
        assert!(
            is_aggregator_active(aggregator_addr),
            ERROR_AGGREGATOR_INACTIVE
        );
        
        // 2. 获取价格
        let (value, timestamp) = get_price_from_switchboard(aggregator_addr);
        
        // 3. 检查新鲜度
        let current_time = timestamp::now_seconds();
        assert!(
            current_time - timestamp <= max_price_age,
            ERROR_STALE_PRICE
        );
        
        // 4. 验证价格
        let price = (value as u64);
        assert!(price > 0, ERROR_INVALID_PRICE);
        
        (price, timestamp)
    }
    
    /// 初始化聚合器配置
    public entry fun initialize_aggregator(
        admin: &signer,
        aggregator_addr: address,
        max_price_age: u64,
        name: vector<u8>
    ) {
        let config = AggregatorConfig {
            aggregator_addr,
            max_price_age,
            name,
        };
        
        move_to(admin, config);
    }
}

// ============================================================================
// 3. 价格聚合器
// ============================================================================

module day18::price_aggregator {
    use std::vector;
    use std::signer;
    use aptos_framework::timestamp;
    use day18::pyth_integration;
    use day18::switchboard_integration;
    
    /// 错误码
    const ERROR_EMPTY_PRICES: u64 = 1;
    const ERROR_INSUFFICIENT_SOURCES: u64 = 2;
    const ERROR_PRICE_DEVIATION_TOO_HIGH: u64 = 3;
    const ERROR_LENGTH_MISMATCH: u64 = 4;
    
    /// 价格源类型
    const SOURCE_TYPE_PYTH: u8 = 0;
    const SOURCE_TYPE_SWITCHBOARD: u8 = 1;
    
    /// 聚合方法
    const AGGREGATION_MEDIAN: u8 = 0;
    const AGGREGATION_MEAN: u8 = 1;
    const AGGREGATION_WEIGHTED_MEAN: u8 = 2;
    
    /// 价格源配置
    struct PriceSource has store, drop {
        source_type: u8,
        identifier: vector<u8>,  // Feed ID 或 Aggregator 地址
        weight: u64,
    }
    
    /// 聚合器配置
    struct AggregatorConfig has key {
        asset_name: vector<u8>,
        sources: vector<PriceSource>,
        aggregation_method: u8,
        max_deviation_bp: u64,  // basis points
        min_sources: u64,
    }
    
    /// 排序价格（冒泡排序）
    fun sort_prices(prices: &mut vector<u64>) {
        let len = vector::length(prices);
        if (len <= 1) return;
        
        let i = 0;
        while (i < len) {
            let j = 0;
            while (j < len - i - 1) {
                let a = *vector::borrow(prices, j);
                let b = *vector::borrow(prices, j + 1);
                if (a > b) {
                    vector::swap(prices, j, j + 1);
                };
                j = j + 1;
            };
            i = i + 1;
        };
    }
    
    /// 计算中位数
    public fun aggregate_median(prices: vector<u64>): u64 {
        let len = vector::length(&prices);
        assert!(len > 0, ERROR_EMPTY_PRICES);
        
        sort_prices(&mut prices);
        
        if (len % 2 == 1) {
            *vector::borrow(&prices, len / 2)
        } else {
            let mid1 = *vector::borrow(&prices, len / 2 - 1);
            let mid2 = *vector::borrow(&prices, len / 2);
            (mid1 + mid2) / 2
        }
    }
    
    /// 计算平均值
    public fun aggregate_mean(prices: &vector<u64>): u64 {
        let len = vector::length(prices);
        assert!(len > 0, ERROR_EMPTY_PRICES);
        
        let sum = 0u128;
        let i = 0;
        while (i < len) {
            sum = sum + (*vector::borrow(prices, i) as u128);
            i = i + 1;
        };
        
        ((sum / (len as u128)) as u64)
    }
    
    /// 计算加权平均
    public fun aggregate_weighted_mean(
        prices: &vector<u64>,
        weights: &vector<u64>
    ): u64 {
        let len = vector::length(prices);
        assert!(len == vector::length(weights), ERROR_LENGTH_MISMATCH);
        assert!(len > 0, ERROR_EMPTY_PRICES);
        
        let weighted_sum = 0u128;
        let weight_sum = 0u128;
        
        let i = 0;
        while (i < len) {
            let price = *vector::borrow(prices, i);
            let weight = *vector::borrow(weights, i);
            weighted_sum = weighted_sum + (price as u128) * (weight as u128);
            weight_sum = weight_sum + (weight as u128);
            i = i + 1;
        };
        
        ((weighted_sum / weight_sum) as u64)
    }
    
    /// 计算价格偏差（basis points）
    public fun calculate_deviation(price1: u64, price2: u64): u64 {
        let diff = if (price1 > price2) {
            price1 - price2
        } else {
            price2 - price1
        };
        
        let base = if (price1 > price2) { price2 } else { price1 };
        
        ((diff as u128) * 10000 / (base as u128) as u64)
    }
    
    /// 验证价格偏差
    fun verify_price_deviation(
        prices: &vector<u64>,
        final_price: u64,
        max_deviation_bp: u64
    ) {
        let i = 0;
        while (i < vector::length(prices)) {
            let price = *vector::borrow(prices, i);
            let deviation = calculate_deviation(price, final_price);
            assert!(
                deviation <= max_deviation_bp,
                ERROR_PRICE_DEVIATION_TOO_HIGH
            );
            i = i + 1;
        };
    }
    
    /// 初始化聚合器
    public entry fun initialize_aggregator(
        admin: &signer,
        asset_name: vector<u8>,
        aggregation_method: u8,
        max_deviation_bp: u64,
        min_sources: u64
    ) {
        let config = AggregatorConfig {
            asset_name,
            sources: vector::empty<PriceSource>(),
            aggregation_method,
            max_deviation_bp,
            min_sources,
        };
        
        move_to(admin, config);
    }
    
    /// 添加价格源
    public entry fun add_price_source(
        admin: &signer,
        asset_name: vector<u8>,
        source_type: u8,
        identifier: vector<u8>,
        weight: u64
    ) acquires AggregatorConfig {
        let admin_addr = signer::address_of(admin);
        let config = borrow_global_mut<AggregatorConfig>(admin_addr);
        
        assert!(config.asset_name == asset_name, 0);
        
        let source = PriceSource {
            source_type,
            identifier,
            weight,
        };
        
        vector::push_back(&mut config.sources, source);
    }
    
    /// 获取聚合价格
    public fun get_aggregated_price(
        asset_name: vector<u8>,
        aggregator_owner: address
    ): (u64, u64) acquires AggregatorConfig {
        let config = borrow_global<AggregatorConfig>(aggregator_owner);
        assert!(config.asset_name == asset_name, 0);
        
        let prices = vector::empty<u64>();
        let weights = vector::empty<u64>();
        let oldest_timestamp = timestamp::now_seconds();
        
        // 从所有源获取价格
        let i = 0;
        while (i < vector::length(&config.sources)) {
            let source = vector::borrow(&config.sources, i);
            
            let (price, ts) = if (source.source_type == SOURCE_TYPE_PYTH) {
                pyth_integration::get_validated_price(source.identifier, 60, 100)
            } else {
                // Switchboard (简化：需要将 vector<u8> 转为 address)
                // 实际实现需要更复杂的转换
                switchboard_integration::get_validated_price(@0x1, 60)
            };
            
            vector::push_back(&mut prices, price);
            vector::push_back(&mut weights, source.weight);
            
            if (ts < oldest_timestamp) {
                oldest_timestamp = ts;
            };
            
            i = i + 1;
        };
        
        // 检查最少源数量
        assert!(
            vector::length(&prices) >= config.min_sources,
            ERROR_INSUFFICIENT_SOURCES
        );
        
        // 聚合价格
        let final_price = if (config.aggregation_method == AGGREGATION_MEDIAN) {
            aggregate_median(prices)
        } else if (config.aggregation_method == AGGREGATION_MEAN) {
            aggregate_mean(&prices)
        } else {
            aggregate_weighted_mean(&prices, &weights)
        };
        
        // 验证偏差
        verify_price_deviation(&prices, final_price, config.max_deviation_bp);
        
        (final_price, oldest_timestamp)
    }
    
    /// 批量获取多个资产价格
    #[view]
    public fun get_multiple_prices(
        asset_names: vector<vector<u8>>,
        aggregator_owner: address
    ): vector<u64> acquires AggregatorConfig {
        let prices = vector::empty<u64>();
        let i = 0;
        
        while (i < vector::length(&asset_names)) {
            let asset_name = *vector::borrow(&asset_names, i);
            let (price, _) = get_aggregated_price(asset_name, aggregator_owner);
            vector::push_back(&mut prices, price);
            i = i + 1;
        };
        
        prices
    }
}

// ============================================================================
// 4. TWAP (时间加权平均价格) 实现
// ============================================================================

module day18::twap_oracle {
    use std::signer;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    
    /// 错误码
    const ERROR_INSUFFICIENT_HISTORY: u64 = 1;
    const ERROR_INVALID_PERIOD: u64 = 2;
    
    /// 价格观察记录
    struct PriceObservation has store, drop {
        timestamp: u64,
        cumulative_price: u128,
        price: u64,
    }
    
    /// TWAP Oracle
    struct TWAPOracle has key {
        asset_name: vector<u8>,
        observations: vector<PriceObservation>,
        max_observations: u64,
        last_price: u64,
        last_timestamp: u64,
        cumulative_price: u128,
    }
    
    /// 价格更新事件
    struct PriceUpdateEvent has drop, store {
        asset_name: vector<u8>,
        price: u64,
        timestamp: u64,
        cumulative_price: u128,
    }
    
    /// 初始化 TWAP Oracle
    public entry fun initialize(
        admin: &signer,
        asset_name: vector<u8>,
        initial_price: u64,
        max_observations: u64
    ) {
        let current_time = timestamp::now_seconds();
        
        let oracle = TWAPOracle {
            asset_name,
            observations: vector::empty<PriceObservation>(),
            max_observations,
            last_price: initial_price,
            last_timestamp: current_time,
            cumulative_price: 0,
        };
        
        move_to(admin, oracle);
    }
    
    /// 更新价格
    public entry fun update_price(
        admin: &signer,
        new_price: u64
    ) acquires TWAPOracle {
        let admin_addr = signer::address_of(admin);
        let oracle = borrow_global_mut<TWAPOracle>(admin_addr);
        
        let current_time = timestamp::now_seconds();
        let time_elapsed = current_time - oracle.last_timestamp;
        
        // 更新累积价格
        oracle.cumulative_price = oracle.cumulative_price + 
            (oracle.last_price as u128) * (time_elapsed as u128);
        
        // 添加观察记录
        let observation = PriceObservation {
            timestamp: current_time,
            cumulative_price: oracle.cumulative_price,
            price: new_price,
        };
        
        vector::push_back(&mut oracle.observations, observation);
        
        // 如果超过最大记录数，删除最旧的
        if (vector::length(&oracle.observations) > oracle.max_observations) {
            vector::remove(&mut oracle.observations, 0);
        };
        
        // 更新状态
        oracle.last_price = new_price;
        oracle.last_timestamp = current_time;
        
        // 发出事件
        event::emit(PriceUpdateEvent {
            asset_name: oracle.asset_name,
            price: new_price,
            timestamp: current_time,
            cumulative_price: oracle.cumulative_price,
        });
    }
    
    /// 获取 TWAP（指定时间段）
    #[view]
    public fun get_twap(
        oracle_addr: address,
        period: u64  // 秒
    ): u64 acquires TWAPOracle {
        let oracle = borrow_global<TWAPOracle>(oracle_addr);
        let current_time = timestamp::now_seconds();
        let start_time = current_time - period;
        
        assert!(period > 0, ERROR_INVALID_PERIOD);
        
        // 找到最接近 start_time 的观察记录
        let observations = &oracle.observations;
        let len = vector::length(observations);
        
        assert!(len > 0, ERROR_INSUFFICIENT_HISTORY);
        
        // 简化实现：使用最近两个观察点
        if (len == 1) {
            return vector::borrow(observations, 0).price
        };
        
        let latest = vector::borrow(observations, len - 1);
        let previous = vector::borrow(observations, len - 2);
        
        // TWAP = (累积价格差) / 时间差
        let cumulative_diff = latest.cumulative_price - previous.cumulative_price;
        let time_diff = latest.timestamp - previous.timestamp;
        
        ((cumulative_diff / (time_diff as u128)) as u64)
    }
    
    /// 获取最新价格
    #[view]
    public fun get_latest_price(
        oracle_addr: address
    ): (u64, u64) acquires TWAPOracle {
        let oracle = borrow_global<TWAPOracle>(oracle_addr);
        (oracle.last_price, oracle.last_timestamp)
    }
}

// ============================================================================
// 5. 实际应用：在借贷协议中使用预言机
// ============================================================================

module day18::lending_with_oracle {
    use std::signer;
    use day18::price_aggregator;
    
    /// 错误码
    const ERROR_UNDERCOLLATERALIZED: u64 = 1;
    const ERROR_HEALTH_FACTOR_TOO_LOW: u64 = 2;
    
    /// 用户抵押品
    struct UserCollateral has key {
        amount: u64,
        asset_name: vector<u8>,
    }
    
    /// 用户债务
    struct UserDebt has key {
        amount: u64,
        asset_name: vector<u8>,
    }
    
    /// 存入抵押品
    public entry fun deposit_collateral(
        user: &signer,
        amount: u64,
        asset_name: vector<u8>
    ) {
        let collateral = UserCollateral {
            amount,
            asset_name,
        };
        
        move_to(user, collateral);
    }
    
    /// 计算健康因子
    /// 健康因子 = (抵押品价值 * 抵押率) / 债务价值
    #[view]
    public fun calculate_health_factor(
        user_addr: address,
        oracle_addr: address,
        collateral_ratio: u64  // basis points, 例如 15000 = 150%
    ): u64 acquires UserCollateral, UserDebt {
        // 获取抵押品价值
        let collateral = borrow_global<UserCollateral>(user_addr);
        let (collateral_price, _) = price_aggregator::get_aggregated_price(
            collateral.asset_name,
            oracle_addr
        );
        let collateral_value = (collateral.amount as u128) * (collateral_price as u128);
        
        // 获取债务价值
        let debt = borrow_global<UserDebt>(user_addr);
        let (debt_price, _) = price_aggregator::get_aggregated_price(
            debt.asset_name,
            oracle_addr
        );
        let debt_value = (debt.amount as u128) * (debt_price as u128);
        
        // 健康因子
        if (debt_value == 0) {
            return 10000  // 无债务，健康因子最大
        };
        
        let health_factor = (collateral_value * (collateral_ratio as u128)) / 
                           (debt_value * 10000);
        
        (health_factor as u64)
    }
    
    /// 检查是否可以清算
    #[view]
    public fun is_liquidatable(
        user_addr: address,
        oracle_addr: address
    ): bool acquires UserCollateral, UserDebt {
        let health_factor = calculate_health_factor(user_addr, oracle_addr, 15000);
        
        // 健康因子 < 100% 时可清算
        health_factor < 10000
    }
}

// ============================================================================
// 6. 断路器模式（Circuit Breaker）
// ============================================================================

module day18::circuit_breaker {
    use std::signer;
    use aptos_framework::timestamp;
    use day18::price_aggregator;
    
    /// 错误码
    const ERROR_CIRCUIT_BREAKER_TRIGGERED: u64 = 1;
    const ERROR_SYSTEM_PAUSED: u64 = 2;
    
    /// 断路器配置
    struct CircuitBreaker has key {
        /// 是否暂停
        is_paused: bool,
        
        /// 最大单次价格变化（basis points）
        max_price_change_bp: u64,
        
        /// 上次验证的价格
        last_validated_price: u64,
        
        /// 上次检查时间
        last_check_timestamp: u64,
        
        /// 资产名称
        asset_name: vector<u8>,
    }
    
    /// 初始化断路器
    public entry fun initialize(
        admin: &signer,
        asset_name: vector<u8>,
        max_price_change_bp: u64,
        initial_price: u64
    ) {
        let breaker = CircuitBreaker {
            is_paused: false,
            max_price_change_bp,
            last_validated_price: initial_price,
            last_check_timestamp: timestamp::now_seconds(),
            asset_name,
        };
        
        move_to(admin, breaker);
    }
    
    /// 获取价格（带断路器保护）
    public fun get_price_with_circuit_breaker(
        breaker_addr: address,
        oracle_addr: address
    ): u64 acquires CircuitBreaker {
        let breaker = borrow_global_mut<CircuitBreaker>(breaker_addr);
        
        // 检查是否暂停
        assert!(!breaker.is_paused, ERROR_SYSTEM_PAUSED);
        
        // 获取新价格
        let (new_price, _) = price_aggregator::get_aggregated_price(
            breaker.asset_name,
            oracle_addr
        );
        
        // 计算价格变化
        let last_price = breaker.last_validated_price;
        let price_change_bp = if (new_price > last_price) {
            ((new_price - last_price) as u128) * 10000 / (last_price as u128)
        } else {
            ((last_price - new_price) as u128) * 10000 / (last_price as u128)
        };
        
        // 检查价格变化是否超过阈值
        if (price_change_bp > (breaker.max_price_change_bp as u128)) {
            // 触发断路器
            breaker.is_paused = true;
            abort ERROR_CIRCUIT_BREAKER_TRIGGERED
        };
        
        // 更新状态
        breaker.last_validated_price = new_price;
        breaker.last_check_timestamp = timestamp::now_seconds();
        
        new_price
    }
    
    /// 手动恢复（仅管理员）
    public entry fun resume(
        admin: &signer
    ) acquires CircuitBreaker {
        let admin_addr = signer::address_of(admin);
        let breaker = borrow_global_mut<CircuitBreaker>(admin_addr);
        breaker.is_paused = false;
    }
}
