// ==================== 代码示例：Aptos 交易结构与解析 ====================
// 
// 本文件包含完整的代码示例，演示如何：
// 1. 定义和解析 UserTransaction
// 2. 处理不同类型的 Payload
// 3. 提取和过滤事件
// 4. 验证签名
// 5. 构建交易解析工具

module transaction_examples::transaction_parser {
    use std::vector;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::bcs;
    use aptos_std::ed25519;
    use aptos_framework::timestamp;
    use aptos_framework::account;

    // ===================== 常量定义 =====================

    // Chain IDs
    const MAINNET_CHAIN_ID: u8 = 1;
    const TESTNET_CHAIN_ID: u8 = 2;

    // 错误码
    const ERROR_INVALID_TRANSACTION: u64 = 400;
    const ERROR_INVALID_SIGNATURE: u64 = 401;
    const ERROR_EXPIRED_TRANSACTION: u64 = 402;
    const ERROR_INVALID_SEQUENCE_NUMBER: u64 = 403;
    const ERROR_INVALID_PAYLOAD: u64 = 404;
    const ERROR_PARSING_FAILED: u64 = 406;

    // Gas 限制
    const MAX_GAS_AMOUNT: u64 = 2_000_000;
    const MIN_GAS_PRICE: u64 = 100; // Octas

    // ===================== 数据结构定义 =====================

    /// UserTransaction 的简化表示
    struct UserTransactionData has drop, copy {
        sender: address,
        sequence_number: u64,
        max_gas_amount: u64,
        gas_unit_price: u64,
        expiration_timestamp_secs: u64,
        chain_id: u8,
    }

    /// EntryFunction 解析结果
    struct ParsedEntryFunction has drop {
        module_address: address,
        module_name: String,
        function_name: String,
        type_args_count: u64,
        args_count: u64,
    }

    /// 事件数据结构
    struct EventData has drop, copy {
        sequence_number: u64,
        event_type: String,
        data_length: u64,
    }

    /// 交易摘要
    struct TransactionSummary has drop {
        sender: address,
        sequence_number: u64,
        function_signature: String,
        gas_used: u64,
        success: bool,
        events_count: u64,
        timestamp: u64,
    }

    // ===================== 示例 1: 交易基本信息提取 =====================

    /// 提取交易的基本信息
    public fun extract_basic_info(
        sender: address,
        sequence_number: u64,
        max_gas_amount: u64,
        gas_unit_price: u64,
        expiration_timestamp_secs: u64,
        chain_id: u8,
    ): UserTransactionData {
        UserTransactionData {
            sender,
            sequence_number,
            max_gas_amount,
            gas_unit_price,
            expiration_timestamp_secs,
            chain_id,
        }
    }

    /// 验证交易基本信息
    public fun validate_basic_info(txn: &UserTransactionData): bool {
        // 验证 gas 参数
        if (txn.max_gas_amount == 0 || txn.max_gas_amount > MAX_GAS_AMOUNT) {
            return false
        };
        
        if (txn.gas_unit_price < MIN_GAS_PRICE) {
            return false
        };

        // 验证过期时间
        let current_time = timestamp::now_seconds();
        if (txn.expiration_timestamp_secs <= current_time) {
            return false
        };

        // 验证 chain_id
        if (txn.chain_id != MAINNET_CHAIN_ID && txn.chain_id != TESTNET_CHAIN_ID) {
            return false
        };

        true
    }

    /// 计算最大交易费用
    public fun calculate_max_fee(txn: &UserTransactionData): u64 {
        txn.max_gas_amount * txn.gas_unit_price
    }

    #[test]
    public fun test_basic_info_extraction() {
        let txn = extract_basic_info(
            @0x1234,
            5,
            100_000,
            100,
            timestamp::now_seconds() + 600,
            MAINNET_CHAIN_ID
        );

        assert!(validate_basic_info(&txn), 0);
        assert!(calculate_max_fee(&txn) == 10_000_000, 1);
    }

    // ===================== 示例 2: EntryFunction 解析 =====================

    /// 模拟解析 EntryFunction Payload
    /// 实际实现需要使用 BCS 反序列化
    public fun parse_entry_function_mock(
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

    /// 构造函数完整签名
    public fun get_function_signature(parsed: &ParsedEntryFunction): String {
        let sig = string::utf8(b"");
        
        // 添加模块地址（简化版，实际需要格式化地址）
        string::append_utf8(&mut sig, b"0x");
        string::append_utf8(&mut sig, b"...");
        string::append_utf8(&mut sig, b"::");
        
        // 添加模块名
        string::append(&mut sig, parsed.module_name);
        string::append_utf8(&mut sig, b"::");
        
        // 添加函数名
        string::append(&mut sig, parsed.function_name);
        
        sig
    }

    /// 检查是否是转账函数
    public fun is_transfer_function(parsed: &ParsedEntryFunction): bool {
        parsed.function_name == string::utf8(b"transfer")
    }

    /// 检查是否是交换函数
    public fun is_swap_function(parsed: &ParsedEntryFunction): bool {
        let fn_name = parsed.function_name;
        fn_name == string::utf8(b"swap") ||
        fn_name == string::utf8(b"swap_exact_input") ||
        fn_name == string::utf8(b"swap_exact_output")
    }

    #[test]
    public fun test_entry_function_parsing() {
        let parsed = parse_entry_function_mock(
            @0x1,
            b"coin",
            b"transfer",
            1, // 1 个类型参数 <CoinType>
            2  // 2 个参数 (to: address, amount: u64)
        );

        assert!(is_transfer_function(&parsed), 0);
        assert!(!is_swap_function(&parsed), 1);
    }

    // ===================== 示例 3: 事件处理 =====================

    /// 创建事件数据
    public fun create_event_data(
        sequence_number: u64,
        event_type: vector<u8>,
        data_length: u64,
    ): EventData {
        EventData {
            sequence_number,
            event_type: string::utf8(event_type),
            data_length,
        }
    }

    /// 过滤特定类型的事件
    public fun filter_events_by_type(
        events: &vector<EventData>,
        event_type: String,
    ): vector<EventData> {
        let result = vector::empty<EventData>();
        let i = 0;
        let len = vector::length(events);

        while (i < len) {
            let event = vector::borrow(events, i);
            if (event.event_type == event_type) {
                vector::push_back(&mut result, *event);
            };
            i = i + 1;
        };

        result
    }

    /// 过滤序列号范围内的事件
    public fun filter_events_by_sequence_range(
        events: &vector<EventData>,
        min_seq: u64,
        max_seq: u64,
    ): vector<EventData> {
        let result = vector::empty<EventData>();
        let i = 0;
        let len = vector::length(events);

        while (i < len) {
            let event = vector::borrow(events, i);
            if (event.sequence_number >= min_seq && event.sequence_number <= max_seq) {
                vector::push_back(&mut result, *event);
            };
            i = i + 1;
        };

        result
    }

    /// 统计事件类型分布
    public fun count_events_by_type(
        events: &vector<EventData>,
        event_type: String,
    ): u64 {
        let count = 0;
        let i = 0;
        let len = vector::length(events);

        while (i < len) {
            let event = vector::borrow(events, i);
            if (event.event_type == event_type) {
                count = count + 1;
            };
            i = i + 1;
        };

        count
    }

    #[test]
    public fun test_event_filtering() {
        let events = vector::empty<EventData>();
        vector::push_back(&mut events, create_event_data(0, b"SwapEvent", 64));
        vector::push_back(&mut events, create_event_data(1, b"TransferEvent", 32));
        vector::push_back(&mut events, create_event_data(2, b"SwapEvent", 64));
        vector::push_back(&mut events, create_event_data(3, b"LiquidityEvent", 48));

        // 测试类型过滤
        let swap_events = filter_events_by_type(&events, string::utf8(b"SwapEvent"));
        assert!(vector::length(&swap_events) == 2, 0);

        // 测试序列号过滤
        let filtered = filter_events_by_sequence_range(&events, 1, 2);
        assert!(vector::length(&filtered) == 2, 1);

        // 测试计数
        let count = count_events_by_type(&events, string::utf8(b"SwapEvent"));
        assert!(count == 2, 2);
    }

    // ===================== 示例 4: 签名验证（简化版）=====================

    /// 验证 Ed25519 签名（模拟）
    /// 实际实现需要使用 aptos_std::ed25519
    public fun verify_ed25519_signature_mock(
        public_key: vector<u8>,
        signature: vector<u8>,
        message: vector<u8>,
    ): bool {
        // 检查长度
        if (vector::length(&public_key) != 32) {
            return false
        };
        if (vector::length(&signature) != 64) {
            return false
        };
        if (vector::is_empty(&message)) {
            return false
        };

        // 实际实现会调用 ed25519 验证函数
        // 这里简化为长度检查通过即返回 true
        true
    }

    /// 提取签名消息
    public fun construct_signing_message(
        txn: &UserTransactionData
    ): vector<u8> {
        // 实际实现需要：
        // 1. BCS 序列化交易（不包括签名）
        // 2. 添加 "APTOS::RawTransaction" 前缀
        
        // 这里返回模拟数据
        let message = vector::empty<u8>();
        vector::append(&mut message, bcs::to_bytes(&txn.sender));
        vector::append(&mut message, bcs::to_bytes(&txn.sequence_number));
        message
    }

    #[test]
    public fun test_signature_verification() {
        let public_key = vector::empty<u8>();
        let i = 0;
        while (i < 32) {
            vector::push_back(&mut public_key, (i as u8));
            i = i + 1;
        };

        let signature = vector::empty<u8>();
        i = 0;
        while (i < 64) {
            vector::push_back(&mut signature, (i as u8));
            i = i + 1;
        };

        let message = b"test message";

        assert!(verify_ed25519_signature_mock(public_key, signature, *message), 0);
    }

    // ===================== 示例 5: 交易分析工具 =====================

    /// 创建交易摘要
    public fun create_transaction_summary(
        sender: address,
        sequence_number: u64,
        function_signature: String,
        gas_used: u64,
        success: bool,
        events_count: u64,
    ): TransactionSummary {
        TransactionSummary {
            sender,
            sequence_number,
            function_signature,
            gas_used,
            success,
            events_count,
            timestamp: timestamp::now_seconds(),
        }
    }

    /// 批量分析交易
    public fun analyze_transactions_batch(
        senders: vector<address>,
        sequences: vector<u64>,
        gas_used: vector<u64>,
    ): vector<TransactionSummary> {
        let summaries = vector::empty<TransactionSummary>();
        let len = vector::length(&senders);
        
        assert!(len == vector::length(&sequences), ERROR_INVALID_TRANSACTION);
        assert!(len == vector::length(&gas_used), ERROR_INVALID_TRANSACTION);

        let i = 0;
        while (i < len) {
            let summary = create_transaction_summary(
                *vector::borrow(&senders, i),
                *vector::borrow(&sequences, i),
                string::utf8(b"unknown::function"),
                *vector::borrow(&gas_used, i),
                true,
                0,
            );
            vector::push_back(&mut summaries, summary);
            i = i + 1;
        };

        summaries
    }

    /// 计算平均 gas 使用
    public fun calculate_average_gas(summaries: &vector<TransactionSummary>): u64 {
        if (vector::is_empty(summaries)) {
            return 0
        };

        let total_gas = 0u128;
        let i = 0;
        let len = vector::length(summaries);

        while (i < len) {
            let summary = vector::borrow(summaries, i);
            total_gas = total_gas + (summary.gas_used as u128);
            i = i + 1;
        };

        ((total_gas / (len as u128)) as u64)
    }

    /// 统计成功率
    public fun calculate_success_rate(summaries: &vector<TransactionSummary>): u64 {
        if (vector::is_empty(summaries)) {
            return 0
        };

        let success_count = 0;
        let i = 0;
        let len = vector::length(summaries);

        while (i < len) {
            let summary = vector::borrow(summaries, i);
            if (summary.success) {
                success_count = success_count + 1;
            };
            i = i + 1;
        };

        // 返回百分比 (0-100)
        (success_count * 100) / len
    }

    /// 查找最高 gas 消耗交易
    public fun find_highest_gas_transaction(
        summaries: &vector<TransactionSummary>
    ): Option<TransactionSummary> {
        if (vector::is_empty(summaries)) {
            return option::none()
        };

        let max_gas = 0;
        let max_index = 0;
        let i = 0;
        let len = vector::length(summaries);

        while (i < len) {
            let summary = vector::borrow(summaries, i);
            if (summary.gas_used > max_gas) {
                max_gas = summary.gas_used;
                max_index = i;
            };
            i = i + 1;
        };

        option::some(*vector::borrow(summaries, max_index))
    }

    #[test]
    public fun test_transaction_analysis() {
        let senders = vector::empty<address>();
        vector::push_back(&mut senders, @0x1);
        vector::push_back(&mut senders, @0x2);
        vector::push_back(&mut senders, @0x3);

        let sequences = vector::empty<u64>();
        vector::push_back(&mut sequences, 1);
        vector::push_back(&mut sequences, 2);
        vector::push_back(&mut sequences, 3);

        let gas_used = vector::empty<u64>();
        vector::push_back(&mut gas_used, 1000);
        vector::push_back(&mut gas_used, 2000);
        vector::push_back(&mut gas_used, 1500);

        let summaries = analyze_transactions_batch(senders, sequences, gas_used);
        
        // 测试批量分析
        assert!(vector::length(&summaries) == 3, 0);

        // 测试平均 gas
        let avg_gas = calculate_average_gas(&summaries);
        assert!(avg_gas == 1500, 1);

        // 测试成功率
        let success_rate = calculate_success_rate(&summaries);
        assert!(success_rate == 100, 2);

        // 测试最高 gas 交易
        let highest = find_highest_gas_transaction(&summaries);
        assert!(option::is_some(&highest), 3);
        let txn = option::borrow(&highest);
        assert!(txn.gas_used == 2000, 4);
    }

    // ===================== 示例 6: 交易过滤器 =====================

    struct TransactionFilter has drop {
        min_gas: Option<u64>,
        max_gas: Option<u64>,
        sender_filter: Option<address>,
        function_filter: Option<String>,
    }

    public fun create_filter(
        min_gas: Option<u64>,
        max_gas: Option<u64>,
        sender_filter: Option<address>,
        function_filter: Option<String>,
    ): TransactionFilter {
        TransactionFilter {
            min_gas,
            max_gas,
            sender_filter,
            function_filter,
        }
    }

    public fun matches_filter(
        summary: &TransactionSummary,
        filter: &TransactionFilter,
    ): bool {
        // 检查 gas 范围
        if (option::is_some(&filter.min_gas)) {
            let min = *option::borrow(&filter.min_gas);
            if (summary.gas_used < min) {
                return false
            };
        };

        if (option::is_some(&filter.max_gas)) {
            let max = *option::borrow(&filter.max_gas);
            if (summary.gas_used > max) {
                return false
            };
        };

        // 检查发送者
        if (option::is_some(&filter.sender_filter)) {
            let sender = *option::borrow(&filter.sender_filter);
            if (summary.sender != sender) {
                return false
            };
        };

        // 检查函数签名
        if (option::is_some(&filter.function_filter)) {
            let function = option::borrow(&filter.function_filter);
            if (&summary.function_signature != function) {
                return false
            };
        };

        true
    }

    public fun apply_filter(
        summaries: &vector<TransactionSummary>,
        filter: &TransactionFilter,
    ): vector<TransactionSummary> {
        let result = vector::empty<TransactionSummary>();
        let i = 0;
        let len = vector::length(summaries);

        while (i < len) {
            let summary = vector::borrow(summaries, i);
            if (matches_filter(summary, filter)) {
                vector::push_back(&mut result, *summary);
            };
            i = i + 1;
        };

        result
    }

    #[test]
    public fun test_transaction_filtering() {
        let senders = vector::empty<address>();
        vector::push_back(&mut senders, @0x1);
        vector::push_back(&mut senders, @0x2);

        let sequences = vector::empty<u64>();
        vector::push_back(&mut sequences, 1);
        vector::push_back(&mut sequences, 2);

        let gas_used = vector::empty<u64>();
        vector::push_back(&mut gas_used, 1000);
        vector::push_back(&mut gas_used, 2000);

        let summaries = analyze_transactions_batch(senders, sequences, gas_used);

        // 创建过滤器：只要 gas >= 1500 的交易
        let filter = create_filter(
            option::some(1500),
            option::none(),
            option::none(),
            option::none(),
        );

        let filtered = apply_filter(&summaries, &filter);
        assert!(vector::length(&filtered) == 1, 0);

        // 创建过滤器：只要来自 @0x1 的交易
        let filter2 = create_filter(
            option::none(),
            option::none(),
            option::some(@0x1),
            option::none(),
        );

        let filtered2 = apply_filter(&summaries, &filter2);
        assert!(vector::length(&filtered2) == 1, 1);
    }

    // ===================== 示例 7: 实用工具函数 =====================

    /// 格式化地址为字符串（简化版）
    public fun format_address(addr: address): String {
        // 实际实现需要将 address 转换为十六进制字符串
        // 这里返回占位符
        string::utf8(b"0x...")
    }

    /// 格式化 gas 为可读格式
    public fun format_gas(gas: u64): String {
        // 将 gas 格式化为 "X.XX APT" 格式
        // 1 APT = 100,000,000 Octas
        // 简化实现
        if (gas >= 100_000_000) {
            string::utf8(b">= 1 APT")
        } else if (gas >= 10_000_000) {
            string::utf8(b">= 0.1 APT")
        } else if (gas >= 1_000_000) {
            string::utf8(b">= 0.01 APT")
        } else {
            string::utf8(b"< 0.01 APT")
        }
    }

    /// 检查交易是否在时间范围内
    public fun is_in_time_range(
        txn_timestamp: u64,
        start_time: u64,
        end_time: u64,
    ): bool {
        txn_timestamp >= start_time && txn_timestamp <= end_time
    }

    /// 计算两个时间戳之间的间隔（秒）
    public fun time_diff(timestamp1: u64, timestamp2: u64): u64 {
        if (timestamp1 > timestamp2) {
            timestamp1 - timestamp2
        } else {
            timestamp2 - timestamp1
        }
    }

    #[test]
    public fun test_utility_functions() {
        let addr = @0x1234;
        let _ = format_address(addr);

        let gas = 15_000_000;
        let formatted = format_gas(gas);
        assert!(formatted == string::utf8(b">= 0.1 APT"), 0);

        let now = timestamp::now_seconds();
        assert!(is_in_time_range(now, now - 100, now + 100), 1);

        let diff = time_diff(1000, 500);
        assert!(diff == 500, 2);
    }
}

// ===================== 总结 =====================
//
// 本文件展示了：
// 1. ✅ 交易基本信息的提取和验证
// 2. ✅ EntryFunction Payload 的解析
// 3. ✅ 事件的过滤和统计
// 4. ✅ 签名验证的基本流程
// 5. ✅ 交易分析和统计工具
// 6. ✅ 灵活的过滤器系统
// 7. ✅ 实用的工具函数
//
// 这些示例为构建完整的交易解析和分析工具提供了基础。
// 在实际应用中，需要：
// - 使用真实的 BCS 反序列化
// - 完整的签名验证实现
// - 更复杂的事件处理
// - 与链上数据的集成
