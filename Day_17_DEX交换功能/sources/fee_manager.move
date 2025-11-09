/// 手续费管理模块
/// 
/// 管理手续费收取和分配

module swap_addr::fee_manager {
    
    const FEE_RATE: u64 = 30;
    const FEE_DENOMINATOR: u64 = 10000;
    
    /// 计算手续费金额
    public fun calculate_fee(amount: u64): u64 {
        ((amount as u128) * (FEE_RATE as u128) / 
            (FEE_DENOMINATOR as u128) as u64)
    }
    
    /// 计算扣除手续费后的金额
    public fun amount_after_fee(amount: u64): u64 {
        ((amount as u128) * ((FEE_DENOMINATOR - FEE_RATE) as u128) / 
            (FEE_DENOMINATOR as u128) as u64)
    }
    
    #[test]
    fun test_calculate_fee() {
        // 10000 * 0.3% = 30
        assert!(calculate_fee(10000) == 30, 0);
    }
    
    #[test]
    fun test_amount_after_fee() {
        // 10000 * 99.7% = 9970
        assert!(amount_after_fee(10000) == 9970, 0);
    }
}
