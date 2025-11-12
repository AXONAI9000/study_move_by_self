/// Transaction Parser Module
/// 
/// 此模块提供交易解析的核心功能
/// 包括：UserTransaction 解析、验证、EntryFunction 提取等

module day27::transaction_parser {
    use std::vector;
    use std::string::{Self, String};
    use aptos_framework::timestamp;

    // ==================== 常量 ====================
    
    const MAINNET_CHAIN_ID: u8 = 1;
    const TESTNET_CHAIN_ID: u8 = 2;
    const MAX_GAS_AMOUNT: u64 = 2_000_000;
    const MIN_GAS_PRICE: u64 = 100;
    
    // 错误码
    const ERROR_INVALID_GAS_AMOUNT: u64 = 1;
    const ERROR_INVALID_GAS_PRICE: u64 = 2;
    const ERROR_EXPIRED: u64 = 3;
    const ERROR_INVALID_CHAIN_ID: u64 = 4;
    const ERROR_INVALID_SEQUENCE: u64 = 5;

    // ==================== 数据结构 ====================
    
    /// 解析后的交易数据
    struct ParsedTransaction has drop, copy {
        sender: address,
        sequence_number: u64,
        max_gas_amount: u64,
        gas_unit_price: u64,
        expiration_timestamp_secs: u64,
        chain_id: u8,
    }
    
    /// 解析后的 EntryFunction
    struct ParsedEntryFunction has drop {
        module_address: address,
        module_name: String,
        function_name: String,
        type_args_count: u64,
        args_count: u64,
    }

    // ==================== 公共函数 ====================
    
    /// 解析交易基本信息
    public fun parse_transaction_basic(
        sender: address,
        sequence_number: u64,
        max_gas_amount: u64,
        gas_unit_price: u64,
        expiration_timestamp_secs: u64,
        chain_id: u8,
    ): ParsedTransaction {
        ParsedTransaction {
            sender,
            sequence_number,
            max_gas_amount,
            gas_unit_price,
            expiration_timestamp_secs,
            chain_id,
        }
    }
    
    /// 验证交易有效性
    public fun validate_transaction(txn: &ParsedTransaction): bool {
        // 验证 gas 参数
        assert!(
            txn.max_gas_amount > 0 && txn.max_gas_amount <= MAX_GAS_AMOUNT,
            ERROR_INVALID_GAS_AMOUNT
        );
        
        assert!(
            txn.gas_unit_price >= MIN_GAS_PRICE,
            ERROR_INVALID_GAS_PRICE
        );
        
        // 验证未过期
        let current_time = timestamp::now_seconds();
        assert!(
            txn.expiration_timestamp_secs > current_time,
            ERROR_EXPIRED
        );
        
        // 验证 chain_id
        assert!(
            txn.chain_id == MAINNET_CHAIN_ID || txn.chain_id == TESTNET_CHAIN_ID,
            ERROR_INVALID_CHAIN_ID
        );
        
        // 验证 sequence_number
        assert!(
            txn.sequence_number >= 0,
            ERROR_INVALID_SEQUENCE
        );
        
        true
    }
    
    /// 计算最大交易费用
    public fun calculate_max_fee(txn: &ParsedTransaction): u64 {
        txn.max_gas_amount * txn.gas_unit_price
    }
    
    /// 解析 EntryFunction（简化版）
    public fun parse_entry_function(
        module_address: address,
        module_name: vector<u8>,
        function_name: vector<u8>,
        type_args_count: u64,
        args_count: u64,
    ): ParsedEntryFunction {
        ParsedEntryFunction {
            module_address,
            module_name: string::utf8(module_name),
            function_name: string::utf8(function_name),
            type_args_count,
            args_count,
        }
    }
    
    /// 构建函数签名
    public fun build_function_signature(parsed: &ParsedEntryFunction): String {
        let sig = string::utf8(b"0x...::");
        string::append(&mut sig, parsed.module_name);
        string::append_utf8(&mut sig, b"::");
        string::append(&mut sig, parsed.function_name);
        sig
    }

    // ==================== View 函数 ====================
    
    #[view]
    public fun get_sender(txn: &ParsedTransaction): address {
        txn.sender
    }
    
    #[view]
    public fun get_sequence_number(txn: &ParsedTransaction): u64 {
        txn.sequence_number
    }

    // ==================== 测试 ====================
    
    #[test]
    public fun test_parse_and_validate() {
        let txn = parse_transaction_basic(
            @0x1,
            5,
            100_000,
            100,
            timestamp::now_seconds() + 600,
            MAINNET_CHAIN_ID
        );
        
        assert!(validate_transaction(&txn), 0);
        assert!(calculate_max_fee(&txn) == 10_000_000, 1);
    }
    
    #[test]
    public fun test_entry_function_parsing() {
        let parsed = parse_entry_function(
            @0x1,
            b"coin",
            b"transfer",
            1,
            2
        );
        
        let sig = build_function_signature(&parsed);
        // 签名应该包含模块名和函数名
        assert!(string::length(&sig) > 0, 0);
    }
}
