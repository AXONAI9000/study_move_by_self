/// 价格聚合器模块
/// 支持多种聚合策略
module day18::price_aggregator {
    use std::vector;
    use aptos_framework::timestamp;
    use day18::pyth_oracle;
    use day18::switchboard_oracle;
    
    /// 错误码
    const ERROR_EMPTY_PRICES: u64 = 1;
    const ERROR_INSUFFICIENT_SOURCES: u64 = 2;
    const ERROR_PRICE_DEVIATION_TOO_HIGH: u64 = 3;
    const ERROR_LENGTH_MISMATCH: u64 = 4;
    
    /// 聚合方法
    const AGGREGATION_MEDIAN: u8 = 0;
    const AGGREGATION_MEAN: u8 = 1;
    const AGGREGATION_WEIGHTED_MEAN: u8 = 2;
    
    /// 价格源类型
    const SOURCE_TYPE_PYTH: u8 = 0;
    const SOURCE_TYPE_SWITCHBOARD: u8 = 1;
    
    /// 价格源配置
    struct PriceSource has store, drop {
        source_type: u8,
        identifier: vector<u8>,
        weight: u64,
    }
    
    /// 聚合器配置
    struct AggregatorConfig has key {
        asset_name: vector<u8>,
        sources: vector<PriceSource>,
        aggregation_method: u8,
        max_deviation_bp: u64,
        min_sources: u64,
    }
    
    /// 冒泡排序
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
    
    /// 计算价格偏差
    public fun calculate_deviation(price1: u64, price2: u64): u64 {
        let diff = if (price1 > price2) {
            price1 - price2
        } else {
            price2 - price1
        };
        
        let base = if (price1 > price2) { price2 } else { price1 };
        
        if (base == 0) {
            return 0
        };
        
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
    public entry fun initialize(
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
        _admin: &signer,
        asset_name: vector<u8>,
        source_type: u8,
        identifier: vector<u8>,
        weight: u64
    ) acquires AggregatorConfig {
        // 简化版：实际需要验证 admin 权限
        let config = borrow_global_mut<AggregatorConfig>(@day18);
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
                pyth_oracle::get_validated_price(source.identifier, 60, 100)
            } else {
                switchboard_oracle::get_validated_price(@0x1, 300)
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
}
