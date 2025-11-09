/// 精确输入交换脚本
/// 
/// 使用示例：
/// aptos move run --function-id 'swap_addr::swap_exact_input_script::swap' \
///   --type-args '0x1::aptos_coin::AptosCoin' '0x1::test_coin::USDC' \
///   --args u64:1000000000 u64:990000000

script {
    use swap_addr::swap;
    
    fun swap<X, Y>(
        user: &signer,
        amount_in: u64,
        min_amount_out: u64,
    ) {
        swap::swap_exact_input<X, Y>(user, amount_in, min_amount_out);
    }
}
