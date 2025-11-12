/// Event Filter Module
/// 
/// 提供灵活的事件过滤功能
/// 支持按类型、序列号、数据长度等条件过滤

module day27::event_filter {
    use std::vector;
    use std::string::{Self, String};
    use std::option::{Self, Option};

    // ==================== 数据结构 ====================
    
    /// 事件数据
    struct EventData has drop, copy {
        sequence_number: u64,
        event_type: String,
        data_length: u64,
    }
    
    /// 事件过滤器
    struct EventFilter has drop {
        type_filter: Option<String>,
        min_sequence: Option<u64>,
        max_sequence: Option<u64>,
        min_data_length: Option<u64>,
    }

    // ==================== 公共函数 ====================
    
    /// 创建事件数据
    public fun create_event(
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
    
    /// 创建过滤器
    public fun create_filter(
        type_filter: Option<String>,
        min_sequence: Option<u64>,
        max_sequence: Option<u64>,
        min_data_length: Option<u64>,
    ): EventFilter {
        EventFilter {
            type_filter,
            min_sequence,
            max_sequence,
            min_data_length,
        }
    }
    
    /// 按类型过滤
    public fun filter_by_type(
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
    
    /// 按序列号范围过滤
    public fun filter_by_sequence_range(
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
    
    /// 统计特定类型事件数量
    public fun count_by_type(
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
    
    /// 检查事件是否匹配过滤器
    public fun matches(event: &EventData, filter: &EventFilter): bool {
        // 检查事件类型
        if (option::is_some(&filter.type_filter)) {
            let expected_type = option::borrow(&filter.type_filter);
            if (&event.event_type != expected_type) {
                return false
            };
        };
        
        // 检查最小序列号
        if (option::is_some(&filter.min_sequence)) {
            let min = *option::borrow(&filter.min_sequence);
            if (event.sequence_number < min) {
                return false
            };
        };
        
        // 检查最大序列号
        if (option::is_some(&filter.max_sequence)) {
            let max = *option::borrow(&filter.max_sequence);
            if (event.sequence_number > max) {
                return false
            };
        };
        
        // 检查最小数据长度
        if (option::is_some(&filter.min_data_length)) {
            let min = *option::borrow(&filter.min_data_length);
            if (event.data_length < min) {
                return false
            };
        };
        
        true
    }
    
    /// 应用过滤器
    public fun apply_filter(
        events: &vector<EventData>,
        filter: &EventFilter,
    ): vector<EventData> {
        let result = vector::empty<EventData>();
        let i = 0;
        let len = vector::length(events);
        
        while (i < len) {
            let event = vector::borrow(events, i);
            if (matches(event, filter)) {
                vector::push_back(&mut result, *event);
            };
            i = i + 1;
        };
        
        result
    }

    // ==================== 测试 ====================
    
    #[test]
    public fun test_event_filtering() {
        let events = vector::empty<EventData>();
        vector::push_back(&mut events, create_event(0, b"SwapEvent", 64));
        vector::push_back(&mut events, create_event(1, b"TransferEvent", 32));
        vector::push_back(&mut events, create_event(2, b"SwapEvent", 128));
        
        // 测试类型过滤
        let swap_events = filter_by_type(&events, string::utf8(b"SwapEvent"));
        assert!(vector::length(&swap_events) == 2, 0);
        
        // 测试序列号过滤
        let filtered = filter_by_sequence_range(&events, 1, 2);
        assert!(vector::length(&filtered) == 2, 1);
        
        // 测试计数
        let count = count_by_type(&events, string::utf8(b"SwapEvent"));
        assert!(count == 2, 2);
    }
    
    #[test]
    public fun test_advanced_filtering() {
        let events = vector::empty<EventData>();
        vector::push_back(&mut events, create_event(0, b"SwapEvent", 64));
        vector::push_back(&mut events, create_event(1, b"TransferEvent", 32));
        vector::push_back(&mut events, create_event(2, b"SwapEvent", 128));
        
        // 创建组合过滤器
        let filter = create_filter(
            option::some(string::utf8(b"SwapEvent")),
            option::some(1),
            option::none(),
            option::none(),
        );
        
        let filtered = apply_filter(&events, &filter);
        assert!(vector::length(&filtered) == 1, 0);
    }
}
