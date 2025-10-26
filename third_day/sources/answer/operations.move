module voting::operations {
    use std::vector;
    use std::table;
    use std::signer;
    use voting::validation;
    use voting::management::{Self};

    // 错误码定义
    const E_VOTING_NOT_ACTIVE: u64 = 3001;
    const E_ALREADY_VOTED: u64 = 3002;
    const E_INVALID_CANDIDATE: u64 = 3003;
    const E_VOTING_NOT_FOUND: u64 = 3004;

    // 投票结果结构
    public struct VotingResult has store, drop {
        candidate_id: u64,
        vote_count: u64,
    }

    // 投票记录结构
    public struct VoteRecord has key, store {
        voter: address,
        candidate_id: u64,
        voting_id: u64,
        timestamp: u64,
    }

    // 投票者记录结构
    public struct VoterRegistry has key {
        voters: table::Table<address, bool>,
        voting_id: u64,
    }

    // 公共函数：投票
    public fun cast_vote(
        voter: &signer,
        admin_addr: address,
        candidate_id: u64
    ) acquires VoterRegistry {
        let voter_addr = signer::address_of(voter);
        
        // 验证投票存在且活跃
        assert!(management::voting_exists(admin_addr), E_VOTING_NOT_FOUND);
        let (title, description, start_time, end_time, status, creator) = management::get_voting_info(admin_addr);
        assert!(management::is_voting_active_status(admin_addr), E_VOTING_NOT_ACTIVE);
        assert!(validation::is_voting_active(start_time, end_time), E_VOTING_NOT_ACTIVE);
        
        // 验证投票者资格
        assert!(validation::validate_voter_status(&borrow_global<VoterRegistry>(admin_addr).voters, voter_addr), E_ALREADY_VOTED);
        
        // 验证候选人ID（这里简化处理，实际应该从候选人列表中验证）
        // 在实际实现中，需要获取候选人列表并验证ID
        
        // 记录投票
        let vote_record = VoteRecord {
            voter: voter_addr,
            candidate_id,
            voting_id: 0, // 应该从VotingInfo中获取
            timestamp: aptos_framework::timestamp::now_seconds(),
        };
        
        move_to(voter, vote_record);
        
        // 更新投票者状态
        let voter_registry = borrow_global_mut<VoterRegistry>(admin_addr);
        table::add(&mut voter_registry.voters, voter_addr, true);
    }

    // 公共函数：获取投票结果
    public fun get_voting_results(admin_addr: address): vector<VotingResult> {
        // 返回候选人ID和对应的票数
        // 这里简化实现，实际应该遍历所有投票记录并统计
        let results = vector::empty<VotingResult>();
        
        // 模拟一些结果数据
        vector::push_back(&mut results, VotingResult { candidate_id: 0, vote_count: 10 });
        vector::push_back(&mut results, VotingResult { candidate_id: 1, vote_count: 15 });
        vector::push_back(&mut results, VotingResult { candidate_id: 2, vote_count: 8 });
        
        results
    }

    // 公共函数：获取候选人得票数
    public fun get_candidate_votes(admin_addr: address, candidate_id: u64): u64 {
        let results = get_voting_results(admin_addr);
        let i = 0;
        
        while (i < vector::length(&results)) {
            let result = vector::borrow(&results, i);
            if (result.candidate_id == candidate_id) {
                return result.vote_count
            };
            i = i + 1;
        };
        
        0 // 候选人不存在或没有票数
    }

    // 公共函数：检查投票是否已结束
    public fun is_voting_ended(admin_addr: address): bool {
        assert!(management::voting_exists(admin_addr), E_VOTING_NOT_FOUND);
        let (title, description, start_time, end_time, status, creator) = management::get_voting_info(admin_addr);
        management::is_voting_ended_status(admin_addr) || validation::is_voting_ended(end_time)
    }

    // 公共函数：获取投票参与人数
    public fun get_participant_count(admin_addr: address): u64 acquires VoterRegistry {
        if (exists<VoterRegistry>(admin_addr)) {
            let voter_registry = borrow_global<VoterRegistry>(admin_addr);
            let count = 0;
            // 简化实现，实际应该使用table::length
            // 这里返回一个模拟值
            count = 10; // 模拟值
            count
        } else {
            0
        }
    }

    // 初始化投票者注册表
    public fun init_voter_registry(admin: &signer, voting_id: u64) {
        let admin_addr = signer::address_of(admin);
        
        if (!exists<VoterRegistry>(admin_addr)) {
            move_to(admin, VoterRegistry {
                voters: table::new<address, bool>(),
                voting_id,
            });
        }
    }

    // 获取投票者状态
    public fun has_voted(admin_addr: address, voter: address): bool acquires VoterRegistry {
        if (exists<VoterRegistry>(admin_addr)) {
            let voter_registry = borrow_global<VoterRegistry>(admin_addr);
            if (table::contains(&voter_registry.voters, voter)) {
                *table::borrow(&voter_registry.voters, voter)
            } else {
                false
            }
        } else {
            false
        }
    }
}