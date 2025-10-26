// 这是一个展示如何使用投票系统的示例文件
module voting::usage_example {
    use std::signer;
    use std::string;
    use voting::simple_voting::{
        Self,
        create_voting,
        add_candidate,
        start_voting,
        cast_vote,
        end_voting,
        get_voting_details,
        get_candidates,
        get_voting_results,
        get_participant_count,
        get_voting_status
    };

    // 示例：创建并运行一个完整的投票流程
    public fun run_voting_example(admin: &signer, voter1: &signer, voter2: &signer) {
        let admin_addr = signer::address_of(admin);
        let voter1_addr = signer::address_of(voter1);
        let voter2_addr = signer::address_of(voter2);
        
        // 1. 创建投票
        let title = string::utf8(b"Best Programming Language");
        let description = string::utf8(b"Vote for your favorite programming language");
        let current_time = 1000000; // 示例时间戳
        let duration = 86400; // 24小时
        
        create_voting(
            admin,
            title,
            description,
            current_time,
            current_time + duration
        );
        
        // 2. 添加候选人
        add_candidate(admin, string::utf8(b"Move"));
        add_candidate(admin, string::utf8(b"Rust"));
        add_candidate(admin, string::utf8(b"Solidity"));
        
        // 3. 开始投票
        start_voting(admin);
        
        // 4. 投票
        cast_vote(voter1, admin_addr, 0); // 投给Move
        cast_vote(voter2, admin_addr, 1); // 投给Rust
        
        // 5. 查看投票状态
        let status = get_voting_status(admin_addr);
        let participants = get_participant_count(admin_addr);
        
        // 6. 结束投票
        end_voting(admin);
        
        // 7. 查看结果
        let results = get_voting_results(admin_addr);
        let candidates = get_candidates(admin_addr);
        let (title, description, start_time, end_time, final_status, creator) = get_voting_details(admin_addr);
    }
    
    // 示例：验证投票信息
    public fun validate_voting_info_example() {
        let valid_title = string::utf8(b"Valid Title");
        let valid_desc = string::utf8(b"This is a valid description with enough characters");
        let invalid_title = string::utf8(b"A"); // 太短
        let invalid_desc = string::utf8(b"Short"); // 太短
        
        let is_valid1 = simple_voting::validate_voting_info(&valid_title, &valid_desc);
        let is_valid2 = simple_voting::validate_voting_info(&invalid_title, &valid_desc);
        let is_valid3 = simple_voting::validate_voting_info(&valid_title, &invalid_desc);
        
        // is_valid1 应该为 true
        // is_valid2 应该为 false
        // is_valid3 应该为 false
    }
    
    // 示例：检查投票时间状态
    public fun check_voting_time_status_example() {
        let past_time = 1000000;
        let current_time = 2000000;
        let future_time = 3000000;
        
        // 检查投票是否已开始
        let started1 = simple_voting::is_voting_started(past_time); // true
        let started2 = simple_voting::is_voting_started(future_time); // false
        
        // 检查投票是否在有效期内
        let active1 = simple_voting::is_voting_active(past_time, future_time); // true
        let active2 = simple_voting::is_voting_active(current_time, past_time); // false
        
        // 检查投票是否已结束
        let ended1 = simple_voting::is_voting_ended(past_time); // true
        let ended2 = simple_voting::is_voting_ended(future_time); // false
    }
}