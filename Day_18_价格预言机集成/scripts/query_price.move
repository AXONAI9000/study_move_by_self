// 查询聚合价格示例脚本
script {
    use day18::price_aggregator;
    
    fun query_btc_price(
        aggregator_owner: address
    ) {
        let (price, timestamp) = price_aggregator::get_aggregated_price(
            b"BTC/USD",
            aggregator_owner
        );
        
        // 价格和时间戳会被返回
        // 在实际应用中可以用于展示或进一步处理
        let _ = price;
        let _ = timestamp;
    }
}
