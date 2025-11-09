/// Pyth Oracle 集成模块
/// 提供安全的价格获取和验证功能
module day18::pyth_oracle {
    use std::vector;
    use aptos_framework::timestamp;
    
    /// 错误码
    const ERROR_STALE_PRICE: u64 = 1;
    const ERROR_LOW_CONFIDENCE: u64 = 2;
    const ERROR_INVALID_PRICE: u64 = 3;
    const ERROR_PRICE_FEED_NOT_FOUND: u64 = 4;
    
    /// 价格 Feed 配置
    struct PriceFeedConfig has key {
        feed_id: vector<u8>,
        max_price_age: u64,
        max_confidence_bp: u64,
        decimals: u8,
    }
    
    /// 价格数据
    struct PriceData has store, drop, copy {
        price: u64,
        confidence: u64,
        timestamp: u64,
        expo: i64,
    }
    
    /// 初始化价格 Feed
    public entry fun initialize(
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
    
    /// 模拟从 Pyth 获取价格
    /// 实际项目中应调用 Pyth SDK
    fun get_mock_pyth_price(_feed_id: vector<u8>): PriceData {
        PriceData {
            price: 45000_00000000,  // $45,000
            confidence: 500_00000,  // ±$5
            timestamp: timestamp::now_seconds(),
            expo: -8,
        }
    }
    
    /// 获取验证过的价格
    public fun get_validated_price(
        feed_id: vector<u8>,
        max_price_age: u64,
        max_confidence_bp: u64
    ): (u64, u64) {
        let price_data = get_mock_pyth_price(feed_id);
        
        // 检查新鲜度
        let current_time = timestamp::now_seconds();
        assert!(
            current_time - price_data.timestamp <= max_price_age,
            ERROR_STALE_PRICE
        );
        
        // 转换为 6 decimals
        let price = price_data.price / 100;  // 从 8 decimals 转为 6
        let confidence = price_data.confidence / 100;
        
        // 检查置信区间
        let confidence_bp = (confidence as u128) * 10000 / (price as u128);
        assert!(
            confidence_bp <= (max_confidence_bp as u128),
            ERROR_LOW_CONFIDENCE
        );
        
        (price, price_data.timestamp)
    }
    
    /// 获取 BTC/USD 价格
    #[view]
    public fun get_btc_usd_price(): (u64, u64) {
        let feed_id = x"e62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43";
        get_validated_price(feed_id, 60, 100)
    }
    
    /// 获取 ETH/USD 价格
    #[view]
    public fun get_eth_usd_price(): (u64, u64) {
        let feed_id = x"ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";
        get_validated_price(feed_id, 60, 100)
    }
    
    /// 获取 APT/USD 价格
    #[view]
    public fun get_apt_usd_price(): (u64, u64) {
        let feed_id = x"03ae4db29ed4ae33d323568895aa00337e658e348b37509f5372ae51f0af00d5";
        get_validated_price(feed_id, 60, 100)
    }
}
