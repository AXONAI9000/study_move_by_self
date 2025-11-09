/// 价格聚合器测试
#[test_only]
module day18::price_aggregator_test {
    use std::vector;
    use day18::price_aggregator;
    
    #[test]
    fun test_median_aggregation() {
        // 测试奇数个价格
        let prices = vector[100, 102, 103, 101, 105];
        let median = price_aggregator::aggregate_median(prices);
        assert!(median == 102, 0);
        
        // 测试偶数个价格
        let prices = vector[100, 110];
        let median = price_aggregator::aggregate_median(prices);
        assert!(median == 105, 1);
    }
    
    #[test]
    fun test_mean_aggregation() {
        let prices = vector[100, 200];
        let mean = price_aggregator::aggregate_mean(&prices);
        assert!(mean == 150, 0);
    }
    
    #[test]
    fun test_weighted_average() {
        let prices = vector[100, 110];
        let weights = vector[70, 30];
        let avg = price_aggregator::aggregate_weighted_mean(&prices, &weights);
        assert!(avg == 103, 0);
    }
    
    #[test]
    fun test_calculate_deviation() {
        // 10% deviation
        let dev = price_aggregator::calculate_deviation(100, 110);
        assert!(dev == 1000, 0);  // 1000 bp = 10%
        
        // Same price
        let dev = price_aggregator::calculate_deviation(100, 100);
        assert!(dev == 0, 1);
    }
}
