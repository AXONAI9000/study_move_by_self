/// Gas 优化 - 计算优化示例
module gas_optimization::gas_optimized_compute {
    use std::vector;
    
    // ============================================
    // 1. 循环优化
    // ============================================
    
    /// ❌ 未优化：重复调用 length()
    public fun sum_vector_unoptimized(v: &vector<u64>): u64 {
        let sum = 0;
        let i = 0;
        while (i < vector::length(v)) {  // 每次迭代调用
            sum = sum + *vector::borrow(v, i);
            i = i + 1;
        };
        sum
    }
    
    /// ✅ 优化：缓存 length
    public fun sum_vector_optimized(v: &vector<u64>): u64 {
        let sum = 0;
        let len = vector::length(v);  // 只调用一次
        let i = 0;
        while (i < len) {
            sum = sum + *vector::borrow(v, i);
            i = i + 1;
        };
        sum
    }
    
    /// ❌ 未优化：嵌套循环查找
    public fun find_common_unoptimized(
        v1: &vector<u64>,
        v2: &vector<u64>
    ): vector<u64> {
        let result = vector::empty<u64>();
        let i = 0;
        while (i < vector::length(v1)) {
            let j = 0;
            while (j < vector::length(v2)) {
                if (*vector::borrow(v1, i) == *vector::borrow(v2, j)) {
                    vector::push_back(&mut result, *vector::borrow(v1, i));
                    break
                };
                j = j + 1;
            };
            i = i + 1;
        };
        result
    }
    
    /// ✅ 优化：减少循环次数
    public fun find_common_optimized(
        v1: &vector<u64>,
        v2: &vector<u64>
    ): vector<u64> {
        let result = vector::empty<u64>();
        let len1 = vector::length(v1);
        let len2 = vector::length(v2);
        
        // 选择较短的向量作为外层循环
        if (len1 <= len2) {
            let i = 0;
            while (i < len1) {
                if (vector::contains(v2, vector::borrow(v1, i))) {
                    vector::push_back(&mut result, *vector::borrow(v1, i));
                };
                i = i + 1;
            };
        } else {
            let i = 0;
            while (i < len2) {
                if (vector::contains(v1, vector::borrow(v2, i))) {
                    vector::push_back(&mut result, *vector::borrow(v2, i));
                };
                i = i + 1;
            };
        };
        result
    }
    
    // ============================================
    // 2. 条件分支优化
    // ============================================
    
    const TIER_BRONZE: u8 = 0;
    const TIER_SILVER: u8 = 1;
    const TIER_GOLD: u8 = 2;
    const TIER_PLATINUM: u8 = 3;
    const TIER_DIAMOND: u8 = 4;
    
    /// ❌ 未优化：未按概率排序
    public fun get_fee_rate_unoptimized(tier: u8): u64 {
        if (tier == TIER_DIAMOND) {        // 0.1% 用户
            return 10;   // 0.1%
        } else if (tier == TIER_PLATINUM) { // 0.9% 用户
            return 25;   // 0.25%
        } else if (tier == TIER_GOLD) {    // 4% 用户
            return 50;   // 0.5%
        } else if (tier == TIER_SILVER) {  // 15% 用户
            return 75;   // 0.75%
        } else {                            // 80% 用户
            return 100;  // 1%
        }
    }
    
    /// ✅ 优化：按概率降序排列
    public fun get_fee_rate_optimized(tier: u8): u64 {
        if (tier == TIER_BRONZE) {         // 80% 用户
            return 100;
        } else if (tier == TIER_SILVER) {  // 15% 用户
            return 75;
        } else if (tier == TIER_GOLD) {    // 4% 用户
            return 50;
        } else if (tier == TIER_PLATINUM) { // 0.9% 用户
            return 25;
        } else {                            // 0.1% 用户
            return 10;
        }
    }
    
    /// ✅ 最优：使用查找表
    struct FeeSchedule has drop {
        rates: vector<u64>,
    }
    
    public fun create_fee_schedule(): FeeSchedule {
        let rates = vector::empty<u64>();
        vector::push_back(&mut rates, 100);  // Bronze
        vector::push_back(&mut rates, 75);   // Silver
        vector::push_back(&mut rates, 50);   // Gold
        vector::push_back(&mut rates, 25);   // Platinum
        vector::push_back(&mut rates, 10);   // Diamond
        FeeSchedule { rates }
    }
    
    public fun get_fee_rate_lookup(schedule: &FeeSchedule, tier: u8): u64 {
        *vector::borrow(&schedule.rates, (tier as u64))
    }
    
    // ============================================
    // 3. 数学运算优化
    // ============================================
    
    /// ❌ 未优化：使用除法
    public fun divide_by_8_unoptimized(x: u64): u64 {
        x / 8
    }
    
    /// ✅ 优化：使用位运算
    public fun divide_by_8_optimized(x: u64): u64 {
        x >> 3  // 除以 2^3 = 8
    }
    
    public fun divide_by_16(x: u64): u64 {
        x >> 4  // 除以 2^4 = 16
    }
    
    public fun multiply_by_8(x: u64): u64 {
        x << 3  // 乘以 2^3 = 8
    }
    
    public fun multiply_by_16(x: u64): u64 {
        x << 4  // 乘以 2^4 = 16
    }
    
    /// ❌ 未优化：多次除法
    public fun calculate_fee_unoptimized(amount: u64, rate: u64): u64 {
        (amount * rate) / 10000 / 100  // 两次除法
    }
    
    /// ✅ 优化：合并除法
    public fun calculate_fee_optimized(amount: u64, rate: u64): u64 {
        (amount * rate) / 1000000  // 一次除法
    }
    
    /// ❌ 未优化：重复计算
    public fun calculate_interest_unoptimized(
        principal: u64,
        rate: u64,
        days: u64
    ): u64 {
        let daily_rate = rate / 365;
        let interest = 0;
        let i = 0;
        while (i < days) {
            interest = interest + (principal * daily_rate) / 10000;
            i = i + 1;
        };
        interest
    }
    
    /// ✅ 优化：减少计算
    public fun calculate_interest_optimized(
        principal: u64,
        rate: u64,
        days: u64
    ): u64 {
        (principal * rate * days) / 3650000  // 一次性计算
    }
    
    // ============================================
    // 4. 函数调用优化
    // ============================================
    
    /// 辅助函数：计算百分比
    fun calculate_percentage(value: u64, percent: u64): u64 {
        (value * percent) / 100
    }
    
    /// ❌ 未优化：多次函数调用
    public fun apply_discounts_unoptimized(
        prices: &vector<u64>,
        discount: u64
    ): vector<u64> {
        let result = vector::empty<u64>();
        let i = 0;
        while (i < vector::length(prices)) {
            let price = *vector::borrow(prices, i);
            let discounted = price - calculate_percentage(price, discount);
            vector::push_back(&mut result, discounted);
            i = i + 1;
        };
        result
    }
    
    /// ✅ 优化：内联简单计算
    public fun apply_discounts_optimized(
        prices: &vector<u64>,
        discount: u64
    ): vector<u64> {
        let result = vector::empty<u64>();
        let len = vector::length(prices);
        let i = 0;
        while (i < len) {
            let price = *vector::borrow(prices, i);
            let discounted = price - (price * discount) / 100;  // 内联计算
            vector::push_back(&mut result, discounted);
            i = i + 1;
        };
        result
    }
    
    // ============================================
    // 5. 提前退出优化
    // ============================================
    
    /// ❌ 未优化：总是遍历完整个向量
    public fun find_value_unoptimized(v: &vector<u64>, target: u64): bool {
        let found = false;
        let i = 0;
        while (i < vector::length(v)) {
            if (*vector::borrow(v, i) == target) {
                found = true;
            };
            i = i + 1;
        };
        found
    }
    
    /// ✅ 优化：找到后立即返回
    public fun find_value_optimized(v: &vector<u64>, target: u64): bool {
        let len = vector::length(v);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(v, i) == target) {
                return true
            };
            i = i + 1;
        };
        false
    }
    
    // ============================================
    // 6. 批量计算优化
    // ============================================
    
    /// ❌ 未优化：逐个计算
    public fun calculate_totals_unoptimized(
        amounts: &vector<u64>,
        fee_rate: u64
    ): (u64, u64) {
        let total = 0;
        let total_fees = 0;
        let i = 0;
        while (i < vector::length(amounts)) {
            let amount = *vector::borrow(amounts, i);
            let fee = (amount * fee_rate) / 10000;
            total = total + amount;
            total_fees = total_fees + fee;
            i = i + 1;
        };
        (total, total_fees)
    }
    
    /// ✅ 优化：先求和再计算
    public fun calculate_totals_optimized(
        amounts: &vector<u64>,
        fee_rate: u64
    ): (u64, u64) {
        let total = 0;
        let len = vector::length(amounts);
        let i = 0;
        
        // 先计算总额
        while (i < len) {
            total = total + *vector::borrow(amounts, i);
            i = i + 1;
        };
        
        // 一次性计算总手续费
        let total_fees = (total * fee_rate) / 10000;
        
        (total, total_fees)
    }
    
    // ============================================
    // 测试函数
    // ============================================
    
    #[test]
    public fun test_loop_optimization() {
        let v = vector::empty<u64>();
        vector::push_back(&mut v, 10);
        vector::push_back(&mut v, 20);
        vector::push_back(&mut v, 30);
        vector::push_back(&mut v, 40);
        vector::push_back(&mut v, 50);
        
        let sum1 = sum_vector_unoptimized(&v);
        let sum2 = sum_vector_optimized(&v);
        
        assert!(sum1 == sum2, 0);
        assert!(sum1 == 150, 1);
    }
    
    #[test]
    public fun test_condition_optimization() {
        let schedule = create_fee_schedule();
        
        assert!(get_fee_rate_unoptimized(TIER_BRONZE) == 100, 0);
        assert!(get_fee_rate_optimized(TIER_BRONZE) == 100, 1);
        assert!(get_fee_rate_lookup(&schedule, TIER_BRONZE) == 100, 2);
        
        assert!(get_fee_rate_lookup(&schedule, TIER_DIAMOND) == 10, 3);
    }
    
    #[test]
    public fun test_math_optimization() {
        assert!(divide_by_8_unoptimized(80) == 10, 0);
        assert!(divide_by_8_optimized(80) == 10, 1);
        
        assert!(multiply_by_8(10) == 80, 2);
        assert!(divide_by_16(160) == 10, 3);
        
        let fee1 = calculate_fee_unoptimized(1000000, 250);
        let fee2 = calculate_fee_optimized(1000000, 250);
        assert!(fee1 == fee2, 4);
    }
    
    #[test]
    public fun test_batch_calculation() {
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        vector::push_back(&mut amounts, 2000);
        vector::push_back(&mut amounts, 3000);
        
        let (total1, fees1) = calculate_totals_unoptimized(&amounts, 250);
        let (total2, fees2) = calculate_totals_optimized(&amounts, 250);
        
        assert!(total1 == total2, 0);
        assert!(fees1 == fees2, 1);
        assert!(total1 == 6000, 2);
    }
}
