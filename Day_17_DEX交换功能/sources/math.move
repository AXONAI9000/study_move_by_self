/// 数学辅助函数

module swap_addr::math {
    
    const ERROR_DIVIDE_BY_ZERO: u64 = 1;
    const ERROR_OVERFLOW: u64 = 2;
    
    const MAX_U64: u64 = 18446744073709551615;
    
    /// 安全的乘除运算：(a * b) / c
    /// 使用 u128 避免溢出
    public fun mul_div(a: u64, b: u64, c: u64): u64 {
        assert!(c != 0, ERROR_DIVIDE_BY_ZERO);
        
        let result = ((a as u128) * (b as u128)) / (c as u128);
        assert!(result <= (MAX_U64 as u128), ERROR_OVERFLOW);
        
        (result as u64)
    }
    
    /// 计算平方根（用于 LP Token 计算）
    public fun sqrt(y: u128): u64 {
        if (y < 4) {
            if (y == 0) {
                0
            } else {
                1
            }
        } else {
            let z = y;
            let x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            };
            (z as u64)
        }
    }
    
    /// 最小值
    public fun min(a: u64, b: u64): u64 {
        if (a < b) a else b
    }
    
    /// 最大值
    public fun max(a: u64, b: u64): u64 {
        if (a > b) a else b
    }
    
    #[test]
    fun test_mul_div() {
        assert!(mul_div(100, 50, 10) == 500, 0);
        assert!(mul_div(1000000, 997, 1000) == 997000, 0);
    }
    
    #[test]
    fun test_sqrt() {
        assert!(sqrt(0) == 0, 0);
        assert!(sqrt(1) == 1, 0);
        assert!(sqrt(4) == 2, 0);
        assert!(sqrt(9) == 3, 0);
        assert!(sqrt(100) == 10, 0);
        assert!(sqrt(10000) == 100, 0);
    }
}
