module indexer_demo::event_definitions {
    // 定义标准化的事件结构，便于 Indexer 处理
    
    use std::string::String;

    // 用户操作事件
    struct UserActionEvent has drop, store {
        user_address: address,
        action_type: String,  // "create", "update", "delete"
        resource_id: u64,
        timestamp: u64,
    }

    // 代币操作事件
    struct TokenOperationEvent has drop, store {
        from_address: address,
        to_address: address,
        token_type: String,
        amount: u64,
        operation: String,  // "transfer", "mint", "burn"
        timestamp: u64,
    }

    // 状态变更事件
    struct StateChangeEvent has drop, store {
        resource_address: address,
        field_name: String,
        old_value: vector<u8>,
        new_value: vector<u8>,
        timestamp: u64,
    }

    // 这些事件可以通过以下 GraphQL 查询：
    /*
    query GetUserActions($userAddr: String!) {
      events(
        where: {
          type: {_eq: "0x[addr]::event_definitions::UserActionEvent"}
          data: {_contains: {user_address: $userAddr}}
        }
        order_by: {transaction_version: desc}
      ) {
        data
        transaction_version
        transaction {
          timestamp
        }
      }
    }
    */
}
