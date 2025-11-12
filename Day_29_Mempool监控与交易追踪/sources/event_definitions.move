/// Day 29: Mempool 监控器 - Move 端事件定义
module day29::event_definitions {
    use std::string::String;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    /// 监控事件结构定义

    struct TransactionDetectedEvent has drop, store {
        tx_hash: vector<u8>,
        sender: address,
        tx_type: String,
        gas_price: u64,
        timestamp: u64,
    }

    struct OpportunityFoundEvent has drop, store {
        opportunity_type: String,  // "arbitrage", "liquidation", etc.
        dex_a: String,
        dex_b: String,
        profit_estimate: u64,
        timestamp: u64,
    }
}
