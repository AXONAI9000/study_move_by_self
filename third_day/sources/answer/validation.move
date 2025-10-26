module voting::validation {
    use std::string;
    use std::vector;
    use std::table;
    use aptos_framework::timestamp;

    // 错误码定义
    const E_INVALID_NAME_LENGTH: u64 = 1001;
    const E_VOTING_NOT_STARTED: u64 = 1002;
    const E_VOTING_ENDED: u64 = 1003;
    const E_ALREADY_VOTED: u64 = 1004;
    const E_INVALID_CANDIDATE_ID: u64 = 1005;

    // 私有函数：检查候选人名称是否有效（长度在2-50个字符之间）
    fun is_valid_candidate_name_length(name: &string::String): bool {
        let len = string::length(name);
        len >= 2 && len <= 50
    }

    // 私有函数：检查投票者是否已投票
    fun has_voted(voters: &table::Table<address, bool>, voter: address): bool {
        if (table::contains(voters, voter)) {
            *table::borrow(voters, voter)
        } else {
            false
        }
    }

    // 公共函数：验证候选人名称
    public fun validate_candidate_name(name: &string::String): bool {
        is_valid_candidate_name_length(name)
    }

    // 公共函数：验证投票是否在有效期内
    public fun is_voting_active(start_time: u64, end_time: u64): bool {
        let current_time = timestamp::now_seconds();
        current_time >= start_time && current_time <= end_time
    }

    // 公共函数：验证投票是否已开始
    public fun is_voting_started(start_time: u64): bool {
        let current_time = timestamp::now_seconds();
        current_time >= start_time
    }

    // 公共函数：验证投票是否已结束
    public fun is_voting_ended(end_time: u64): bool {
        let current_time = timestamp::now_seconds();
        current_time > end_time
    }

    // 公共函数：验证候选人ID是否有效
    public fun validate_candidate_id(candidates: &vector<string::String>, candidate_id: u64): bool {
        candidate_id < vector::length(candidates)
    }

    // 公共函数：验证投票者是否已投票
    public fun validate_voter_status(voters: &table::Table<address, bool>, voter: address): bool {
        !has_voted(voters, voter)
    }

    // 公共函数：验证投票标题和描述
    public fun validate_voting_info(title: &string::String, description: &string::String): bool {
        let title_len = string::length(title);
        let desc_len = string::length(description);
        title_len >= 3 && title_len <= 100 && desc_len >= 10 && desc_len <= 500
    }
}