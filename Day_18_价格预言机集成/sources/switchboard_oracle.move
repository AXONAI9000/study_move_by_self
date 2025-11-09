/// Switchboard Oracle 集成模块
module day18::switchboard_oracle {
    use aptos_framework::timestamp;
    
    /// 错误码
    const ERROR_STALE_PRICE: u64 = 1;
    const ERROR_AGGREGATOR_INACTIVE: u64 = 2;
    const ERROR_INVALID_PRICE: u64 = 3;
    
    /// 聚合器配置
    struct AggregatorConfig has key {
        aggregator_addr: address,
        max_price_age: u64,
        name: vector<u8>,
    }
    
    /// 初始化聚合器
    public entry fun initialize(
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
    
    /// 模拟从 Switchboard 获取价格
    fun get_mock_switchboard_price(_aggregator_addr: address): (u128, u64) {
        let value = 45000_000000u128;  // $45,000
        let timestamp = timestamp::now_seconds();
        (value, timestamp)
    }
    
    /// 模拟检查聚合器状态
    fun is_mock_aggregator_active(_aggregator_addr: address): bool {
        true
    }
    
    /// 获取验证过的价格
    public fun get_validated_price(
        aggregator_addr: address,
        max_price_age: u64
    ): (u64, u64) {
        // 检查聚合器状态
        assert!(
            is_mock_aggregator_active(aggregator_addr),
            ERROR_AGGREGATOR_INACTIVE
        );
        
        // 获取价格
        let (value, ts) = get_mock_switchboard_price(aggregator_addr);
        
        // 检查新鲜度
        let current_time = timestamp::now_seconds();
        assert!(
            current_time - ts <= max_price_age,
            ERROR_STALE_PRICE
        );
        
        // 验证价格
        let price = (value as u64);
        assert!(price > 0, ERROR_INVALID_PRICE);
        
        (price, ts)
    }
    
    /// 检查聚合器是否活跃
    #[view]
    public fun is_aggregator_active(aggregator_addr: address): bool {
        is_mock_aggregator_active(aggregator_addr)
    }
}
