/// Swap 模块框架 - 学生实现区域
/// 
/// 本文件是实践任务的起始代码
/// 请在标记的 TODO 区域实现相应功能

module swap_addr::swap {
    use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    
    // ==================== 错误码 ====================
    
    const ERROR_ZERO_AMOUNT: u64 = 200;
    const ERROR_INSUFFICIENT_OUTPUT: u64 = 201;
    const ERROR_EXCESSIVE_INPUT: u64 = 202;
    const ERROR_SLIPPAGE_EXCEEDED: u64 = 203;
    const ERROR_POOL_NOT_EXISTS: u64 = 204;
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 205;
    const ERROR_K_INVARIANT: u64 = 206;
    
    // ==================== 常量 ====================
    
    /// 手续费率：30 基点 = 0.3%
    const FEE_RATE: u64 = 30;
    const FEE_DENOMINATOR: u64 = 10000;
    
    // ==================== 数据结构 ====================
    
    /// 简化的流动性池
    struct Pool<phantom X, phantom Y> has key {
        reserve_x: Coin<X>,
        reserve_y: Coin<Y>,
    }
    
    // ==================== 核心功能 ====================
    
    /// TODO: 实现 swap_exact_input 函数
    /// 
    /// 要求：
    /// 1. 验证参数
    /// 2. 计算输出数量
    /// 3. 检查滑点
    /// 4. 转移代币
    /// 5. 验证 K 值
    public entry fun swap_exact_input<X, Y>(
        user: &signer,
        amount_in: u64,
        min_amount_out: u64,
    ) acquires Pool {
        // TODO: 实现此函数
        abort ERROR_POOL_NOT_EXISTS
    }
    
    /// TODO: 实现 swap_exact_output 函数
    public entry fun swap_exact_output<X, Y>(
        user: &signer,
        amount_out: u64,
        max_amount_in: u64,
    ) acquires Pool {
        // TODO: 实现此函数
        abort ERROR_POOL_NOT_EXISTS
    }
    
    // ==================== 辅助函数 ====================
    
    /// TODO: 实现输出计算函数
    fun get_amount_out_internal(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64,
    ): u64 {
        // TODO: 实现带手续费的输出计算
        0
    }
    
    /// TODO: 实现输入计算函数
    fun get_amount_in_internal(
        amount_out: u64,
        reserve_in: u64,
        reserve_out: u64,
    ): u64 {
        // TODO: 实现反向计算
        0
    }
    
    /// TODO: 实现 K 值验证
    fun verify_k_invariant<X, Y>(
        old_reserve_in: u64,
        old_reserve_out: u64,
    ) acquires Pool {
        // TODO: 验证 K 值不减少
    }
    
    // ==================== 查询接口 ====================
    
    #[view]
    public fun get_amount_out<X, Y>(amount_in: u64): u64 acquires Pool {
        // TODO: 实现
        0
    }
    
    #[view]
    public fun get_reserves<X, Y>(): (u64, u64) acquires Pool {
        // TODO: 实现
        (0, 0)
    }
}
