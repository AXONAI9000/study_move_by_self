/// 多跳交换脚本
/// 
/// 执行两跳路由：X → Z → Y

script {
    use swap_addr::router;
    
    fun multi_hop_swap<X, Y, Z>(
        user: &signer,
        amount_in: u64,
        min_amount_out: u64,
    ) {
        router::swap_two_hop<X, Y, Z>(user, amount_in, min_amount_out);
    }
}
