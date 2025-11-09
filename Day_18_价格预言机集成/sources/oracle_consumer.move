/// 预言机消费者示例：在应用中使用预言机
module day18::oracle_consumer {
    use day18::price_aggregator;
    
    /// 计算资产的美元价值
    public fun calculate_usd_value(
        asset_name: vector<u8>,
        amount: u64,
        oracle_addr: address
    ): u64 acquires price_aggregator::AggregatorConfig {
        let (price, _) = price_aggregator::get_aggregated_price(
            asset_name,
            oracle_addr
        );
        
        // value = amount * price (both in 6 decimals)
        ((amount as u128) * (price as u128) / 1_000_000 as u64)
    }
    
    /// 计算两个资产的汇率
    public fun calculate_exchange_rate(
        asset_a: vector<u8>,
        asset_b: vector<u8>,
        oracle_addr: address
    ): u64 acquires price_aggregator::AggregatorConfig {
        let (price_a, _) = price_aggregator::get_aggregated_price(
            asset_a,
            oracle_addr
        );
        
        let (price_b, _) = price_aggregator::get_aggregated_price(
            asset_b,
            oracle_addr
        );
        
        // rate = price_a / price_b * 1_000_000 (6 decimals)
        ((price_a as u128) * 1_000_000 / (price_b as u128) as u64)
    }
    
    /// 检查价格变化百分比
    public fun check_price_change(
        asset_name: vector<u8>,
        old_price: u64,
        oracle_addr: address
    ): u64 acquires price_aggregator::AggregatorConfig {
        let (new_price, _) = price_aggregator::get_aggregated_price(
            asset_name,
            oracle_addr
        );
        
        let change = if (new_price > old_price) {
            ((new_price - old_price) as u128) * 10000 / (old_price as u128)
        } else {
            ((old_price - new_price) as u128) * 10000 / (old_price as u128)
        };
        
        (change as u64)  // basis points
    }
}
