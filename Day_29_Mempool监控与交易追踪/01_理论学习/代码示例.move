/// Day 29: Mempool 监控与交易追踪 - Move 代码示例
/// 
/// 本模块演示与 Mempool 监控相关的 Move 合约端代码，
/// 包括事件定义、交易验证逻辑等。

module day29::mempool_monitor {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_framework::timestamp;

    /// 错误码
    const E_NOT_INITIALIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_INVALID_TRANSACTION: u64 = 3;
    const E_INSUFFICIENT_GAS: u64 = 4;

    /// 交易状态枚举
    const STATUS_PENDING: u8 = 0;
    const STATUS_SUCCESS: u8 = 1;
    const STATUS_FAILED: u8 = 2;
    const STATUS_DROPPED: u8 = 3;

    /// 交易记录结构
    struct TransactionRecord has store, drop, copy {
        tx_hash: vector<u8>,
        sender: address,
        sequence_number: u64,
        gas_used: u64,
        gas_price: u64,
        status: u8,
        timestamp: u64,
    }

    /// 监控事件 - 交易提交
    struct TransactionSubmittedEvent has drop, store {
        tx_hash: vector<u8>,
        sender: address,
        sequence_number: u64,
        max_gas: u64,
        gas_price: u64,
        timestamp: u64,
    }

    /// 监控事件 - 交易确认
    struct TransactionConfirmedEvent has drop, store {
        tx_hash: vector<u8>,
        sender: address,
        version: u64,
        gas_used: u64,
        success: bool,
        timestamp: u64,
    }

    /// 监控事件 - 大额交易检测
    struct LargeTransactionEvent has drop, store {
        tx_hash: vector<u8>,
        sender: address,
        amount: u64,
        recipient: address,
        timestamp: u64,
    }

    /// 监控事件 - 高 Gas 交易
    struct HighGasTransactionEvent has drop, store {
        tx_hash: vector<u8>,
        sender: address,
        gas_price: u64,
        timestamp: u64,
    }

    /// 监控状态
    struct MonitorState has key {
        /// 总交易数
        total_transactions: u64,
        /// 成功交易数
        successful_transactions: u64,
        /// 失败交易数
        failed_transactions: u64,
        /// 总 Gas 消耗
        total_gas_used: u64,
        /// 最后更新时间
        last_update: u64,
        /// 事件句柄
        submit_events: EventHandle<TransactionSubmittedEvent>,
        confirm_events: EventHandle<TransactionConfirmedEvent>,
        large_tx_events: EventHandle<LargeTransactionEvent>,
        high_gas_events: EventHandle<HighGasTransactionEvent>,
    }

    /// 交易历史（存储在账户下）
    struct TransactionHistory has key {
        records: vector<TransactionRecord>,
        last_sequence: u64,
    }

    /// 初始化监控系统
    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<MonitorState>(addr), E_ALREADY_INITIALIZED);

        move_to(account, MonitorState {
            total_transactions: 0,
            successful_transactions: 0,
            failed_transactions: 0,
            total_gas_used: 0,
            last_update: timestamp::now_seconds(),
            submit_events: account::new_event_handle<TransactionSubmittedEvent>(account),
            confirm_events: account::new_event_handle<TransactionConfirmedEvent>(account),
            large_tx_events: account::new_event_handle<LargeTransactionEvent>(account),
            high_gas_events: account::new_event_handle<HighGasTransactionEvent>(account),
        });
    }

    /// 初始化交易历史
    public entry fun initialize_history(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<TransactionHistory>(addr), E_ALREADY_INITIALIZED);

        move_to(account, TransactionHistory {
            records: vector::empty(),
            last_sequence: 0,
        });
    }

    /// 记录交易提交（由监控系统调用）
    public fun record_transaction_submitted(
        monitor_addr: address,
        tx_hash: vector<u8>,
        sender: address,
        sequence_number: u64,
        max_gas: u64,
        gas_price: u64,
    ) acquires MonitorState {
        assert!(exists<MonitorState>(monitor_addr), E_NOT_INITIALIZED);
        
        let state = borrow_global_mut<MonitorState>(monitor_addr);
        state.total_transactions = state.total_transactions + 1;
        state.last_update = timestamp::now_seconds();

        // 发出交易提交事件
        event::emit_event(&mut state.submit_events, TransactionSubmittedEvent {
            tx_hash,
            sender,
            sequence_number,
            max_gas,
            gas_price,
            timestamp: timestamp::now_seconds(),
        });

        // 检测高 Gas 交易 (Gas Price > 1000)
        if (gas_price > 1000) {
            event::emit_event(&mut state.high_gas_events, HighGasTransactionEvent {
                tx_hash,
                sender,
                gas_price,
                timestamp: timestamp::now_seconds(),
            });
        };
    }

    /// 记录交易确认
    public fun record_transaction_confirmed(
        monitor_addr: address,
        tx_hash: vector<u8>,
        sender: address,
        version: u64,
        gas_used: u64,
        success: bool,
    ) acquires MonitorState {
        assert!(exists<MonitorState>(monitor_addr), E_NOT_INITIALIZED);
        
        let state = borrow_global_mut<MonitorState>(monitor_addr);
        
        if (success) {
            state.successful_transactions = state.successful_transactions + 1;
        } else {
            state.failed_transactions = state.failed_transactions + 1;
        };
        
        state.total_gas_used = state.total_gas_used + gas_used;
        state.last_update = timestamp::now_seconds();

        // 发出交易确认事件
        event::emit_event(&mut state.confirm_events, TransactionConfirmedEvent {
            tx_hash,
            sender,
            version,
            gas_used,
            success,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// 记录大额转账（示例：监控大额交易）
    public fun record_large_transfer(
        monitor_addr: address,
        tx_hash: vector<u8>,
        sender: address,
        amount: u64,
        recipient: address,
    ) acquires MonitorState {
        assert!(exists<MonitorState>(monitor_addr), E_NOT_INITIALIZED);
        
        let state = borrow_global_mut<MonitorState>(monitor_addr);

        // 发出大额交易事件 (金额 > 1,000,000)
        if (amount > 1000000) {
            event::emit_event(&mut state.large_tx_events, LargeTransactionEvent {
                tx_hash,
                sender,
                amount,
                recipient,
                timestamp: timestamp::now_seconds(),
            });
        };
    }

    /// 添加交易记录到历史
    public fun add_transaction_record(
        account_addr: address,
        tx_hash: vector<u8>,
        sender: address,
        sequence_number: u64,
        gas_used: u64,
        gas_price: u64,
        status: u8,
    ) acquires TransactionHistory {
        assert!(exists<TransactionHistory>(account_addr), E_NOT_INITIALIZED);
        
        let history = borrow_global_mut<TransactionHistory>(account_addr);
        
        let record = TransactionRecord {
            tx_hash,
            sender,
            sequence_number,
            gas_used,
            gas_price,
            status,
            timestamp: timestamp::now_seconds(),
        };

        vector::push_back(&mut history.records, record);
        history.last_sequence = sequence_number;

        // 限制历史记录数量 (保留最近1000条)
        if (vector::length(&history.records) > 1000) {
            vector::remove(&mut history.records, 0);
        };
    }

    /// 获取监控统计信息
    public fun get_monitor_stats(monitor_addr: address): (u64, u64, u64, u64) acquires MonitorState {
        assert!(exists<MonitorState>(monitor_addr), E_NOT_INITIALIZED);
        
        let state = borrow_global<MonitorState>(monitor_addr);
        (
            state.total_transactions,
            state.successful_transactions,
            state.failed_transactions,
            state.total_gas_used,
        )
    }

    /// 获取交易历史记录数量
    public fun get_history_count(account_addr: address): u64 acquires TransactionHistory {
        assert!(exists<TransactionHistory>(account_addr), E_NOT_INITIALIZED);
        
        let history = borrow_global<TransactionHistory>(account_addr);
        vector::length(&history.records)
    }

    /// 计算平均 Gas 使用
    public fun get_average_gas_used(monitor_addr: address): u64 acquires MonitorState {
        assert!(exists<MonitorState>(monitor_addr), E_NOT_INITIALIZED);
        
        let state = borrow_global<MonitorState>(monitor_addr);
        if (state.total_transactions == 0) {
            return 0
        };
        
        state.total_gas_used / state.total_transactions
    }

    /// 计算成功率
    public fun get_success_rate(monitor_addr: address): u64 acquires MonitorState {
        assert!(exists<MonitorState>(monitor_addr), E_NOT_INITIALIZED);
        
        let state = borrow_global<MonitorState>(monitor_addr);
        if (state.total_transactions == 0) {
            return 0
        };
        
        // 返回百分比 (0-100)
        (state.successful_transactions * 100) / state.total_transactions
    }

    #[test_only]
    use aptos_framework::account::create_account_for_test;

    #[test(admin = @day29)]
    public fun test_initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        create_account_for_test(admin_addr);
        
        initialize(admin);
        
        assert!(exists<MonitorState>(admin_addr), 0);
        
        let (total, success, failed, gas_used) = get_monitor_stats(admin_addr);
        assert!(total == 0, 1);
        assert!(success == 0, 2);
        assert!(failed == 0, 3);
        assert!(gas_used == 0, 4);
    }

    #[test(admin = @day29)]
    public fun test_record_transactions(admin: &signer) acquires MonitorState {
        let admin_addr = signer::address_of(admin);
        create_account_for_test(admin_addr);
        
        initialize(admin);
        
        // 记录提交
        record_transaction_submitted(
            admin_addr,
            b"hash1",
            @0x1,
            0,
            1000,
            100,
        );
        
        // 记录确认
        record_transaction_confirmed(
            admin_addr,
            b"hash1",
            @0x1,
            12345,
            450,
            true,
        );
        
        let (total, success, _failed, gas_used) = get_monitor_stats(admin_addr);
        assert!(total == 1, 0);
        assert!(success == 1, 1);
        assert!(gas_used == 450, 2);
        
        let avg_gas = get_average_gas_used(admin_addr);
        assert!(avg_gas == 450, 3);
        
        let success_rate = get_success_rate(admin_addr);
        assert!(success_rate == 100, 4);
    }
}

/// 交易验证辅助模块
module day29::transaction_validator {
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    /// 错误码
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_SEQUENCE_NUMBER_TOO_OLD: u64 = 2;
    const E_SEQUENCE_NUMBER_TOO_NEW: u64 = 3;
    const E_GAS_PRICE_TOO_LOW: u64 = 4;
    const E_TRANSACTION_EXPIRED: u64 = 5;

    /// 最小 Gas Price
    const MIN_GAS_PRICE: u64 = 100;
    
    /// 最大序列号间隔
    const MAX_SEQUENCE_GAP: u64 = 100;

    /// 验证交易的基本条件
    public fun validate_transaction(
        sender: &signer,
        sequence_number: u64,
        max_gas_amount: u64,
        gas_unit_price: u64,
        expiration_timestamp: u64,
    ) {
        let sender_addr = signer::address_of(sender);
        
        // 1. 验证序列号
        let current_seq = account::get_sequence_number(sender_addr);
        assert!(sequence_number >= current_seq, E_SEQUENCE_NUMBER_TOO_OLD);
        assert!(sequence_number <= current_seq + MAX_SEQUENCE_GAP, E_SEQUENCE_NUMBER_TOO_NEW);
        
        // 2. 验证余额
        let max_gas_cost = max_gas_amount * gas_unit_price;
        let balance = coin::balance<AptosCoin>(sender_addr);
        assert!(balance >= max_gas_cost, E_INSUFFICIENT_BALANCE);
        
        // 3. 验证 Gas Price
        assert!(gas_unit_price >= MIN_GAS_PRICE, E_GAS_PRICE_TOO_LOW);
        
        // 4. 验证过期时间
        let current_time = timestamp::now_seconds();
        assert!(expiration_timestamp > current_time, E_TRANSACTION_EXPIRED);
    }

    /// 估算交易优先级分数
    public fun calculate_priority_score(
        gas_unit_price: u64,
        arrival_time: u64,
    ): u64 {
        // 优先级 = Gas Price * 权重 - 等待时间惩罚
        let current_time = timestamp::now_seconds();
        let wait_time = current_time - arrival_time;
        
        let gas_score = gas_unit_price * 1000;
        let time_penalty = wait_time * 10;
        
        if (gas_score > time_penalty) {
            gas_score - time_penalty
        } else {
            0
        }
    }

    #[test_only]
    use aptos_framework::account::create_account_for_test;
    use aptos_framework::aptos_coin;
    use aptos_framework::coin::register;

    #[test(framework = @0x1, sender = @0x123)]
    public fun test_calculate_priority(framework: &signer, sender: &signer) {
        // 初始化时间戳
        timestamp::set_time_has_started_for_testing(framework);
        
        let arrival_time = timestamp::now_seconds();
        
        let score = calculate_priority_score(200, arrival_time);
        assert!(score == 200000, 0); // 200 * 1000 - 0
    }
}
