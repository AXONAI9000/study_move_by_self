module indexer_demo::data_structures {
    // 定义便于查询和索引的数据结构
    
    use std::string::String;
    
    // 用户资料（存储在链上，可通过 Indexer 查询历史）
    struct UserProfile has key, store {
        username: String,
        email: String,
        created_at: u64,
        updated_at: u64,
        metadata: vector<u8>,
    }

    // 项目数据
    struct Project has key, store {
        id: u64,
        name: String,
        owner: address,
        created_at: u64,
        status: u8,  // 0: active, 1: paused, 2: completed
    }

    // 关系映射
    struct Relationship has key {
        followers: vector<address>,
        following: vector<address>,
        updated_at: u64,
    }

    // 这些结构的变化会触发状态变更，
    // Indexer 可以追踪这些变化并构建历史记录
}
