module indexer_demo::indexer_client {
    // 这个模块演示如何在 Move 合约中设计便于 Indexer 查询的数据结构
    
    use std::signer;
    use std::string::String;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    // 定义便于索引的事件结构
    struct QueryableEvent has drop, store {
        id: u64,
        event_type: String,
        user: address,
        timestamp: u64,
        data: vector<u8>,
    }

    // 事件句柄
    struct EventRegistry has key {
        events: EventHandle<QueryableEvent>,
        event_counter: u64,
    }

    // 初始化
    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        if (!exists<EventRegistry>(addr)) {
            move_to(account, EventRegistry {
                events: account::new_event_handle<QueryableEvent>(account),
                event_counter: 0,
            });
        };
    }

    // 发出可查询的事件
    public entry fun emit_queryable_event(
        account: &signer,
        event_type: String,
        data: vector<u8>
    ) acquires EventRegistry {
        let addr = signer::address_of(account);
        assert!(exists<EventRegistry>(addr), 1);
        
        let registry = borrow_global_mut<EventRegistry>(addr);
        registry.event_counter = registry.event_counter + 1;
        
        event::emit_event(
            &mut registry.events,
            QueryableEvent {
                id: registry.event_counter,
                event_type,
                user: addr,
                timestamp: aptos_framework::timestamp::now_seconds(),
                data,
            }
        );
    }
}
