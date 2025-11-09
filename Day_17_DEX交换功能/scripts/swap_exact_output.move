/// 精确输出交换脚本

script {
    use swap_addr::swap;
    
    fun swap<X, Y>(
        user: &signer,
        amount_out: u64,
        max_amount_in: u64,
    ) {
        swap::swap_exact_output<X, Y>(user, amount_out, max_amount_in);
    }
}
