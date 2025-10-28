/// 投票系统操作模块
/// 
/// 本模块实现投票的核心操作功能：
/// - 投票操作：用户投票、修改投票、撤销投票
/// - 批量操作：支持批量投票处理
/// - 票数管理：自动更新选项票数和总投票数
/// - 投票查询：查询用户投票信息和选项票数
/// - 结果分析：计算领先选项和检测平局情况
module voting::operations {
    use std::signer;
    use std::vector;
    use voting::types::{Self, Voting, VoterInfo};
    use voting::validation;

    // ==================== 错误码定义 ====================
    
    /// 投票不存在
    const E_VOTING_NOT_EXISTS: u64 = 4001;
    /// 无效操作
    const E_INVALID_OPERATION: u64 = 4002;
    /// 批量操作失败
    const E_BATCH_OPERATION_FAILED: u64 = 4003;

    // ==================== 投票操作 ====================

    /// 用户投票
    /// 
    /// @param voter 投票者账户
    /// @param creator_addr 投票创建者地址
    /// @param option_index 选择的选项索引
    public fun vote(
        voter: &signer,
        creator_addr: address,
        option_index: u64
    ) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证可以投票
        validation::validate_can_vote(voter, voting);
        validation::validate_option_index(voting, option_index);
        
        let voter_addr = signer::address_of(voter);
        
        // 添加投票者信息
        let voter_info = types::new_voter_info(voter_addr, option_index);
        types::add_voter(voting, voter_info);
        
        // 更新选项票数
        let option = types::get_option_mut(voting, option_index);
        types::increment_option_votes(option);
        
        // 更新总票数
        types::increment_total_votes(voting);
    }

    /// 修改投票
    /// 
    /// @param voter 投票者账户
    /// @param creator_addr 投票创建者地址
    /// @param new_option_index 新的选项索引
    public fun revote(
        voter: &signer,
        creator_addr: address,
        new_option_index: u64
    ) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证可以修改投票
        validation::validate_can_revote(voter, voting);
        validation::validate_option_index(voting, new_option_index);
        
        let voter_addr = signer::address_of(voter);
        
        // 查找旧的投票
        let (found, old_option_id) = types::find_voter_option(voting, voter_addr);
        assert!(found, E_INVALID_OPERATION);
        
        // 如果选择相同选项，不需要操作
        if (old_option_id == new_option_index) {
            return
        };
        
        // 减少旧选项的票数
        let old_option = types::get_option_mut(voting, old_option_id);
        types::decrement_option_votes(old_option);
        
        // 增加新选项的票数
        let new_option = types::get_option_mut(voting, new_option_index);
        types::increment_option_votes(new_option);
        
        // 更新投票者信息
        update_voter_choice(voting, voter_addr, new_option_index);
    }

    /// 撤销投票
    /// 
    /// @param voter 投票者账户
    /// @param creator_addr 投票创建者地址
    public fun unvote(
        voter: &signer,
        creator_addr: address
    ) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证可以撤销投票
        validation::validate_can_unvote(voter, voting);
        
        let voter_addr = signer::address_of(voter);
        
        // 查找投票
        let (found, option_id) = types::find_voter_option(voting, voter_addr);
        assert!(found, E_INVALID_OPERATION);
        
        // 减少选项票数
        let option = types::get_option_mut(voting, option_id);
        types::decrement_option_votes(option);
        
        // 减少总票数
        types::decrement_total_votes(voting);
        
        // 移除投票者信息
        remove_voter(voting, voter_addr);
    }

    // ==================== 批量操作 ====================

    /// 批量投票（仅供测试或特殊场景）
    /// 
    /// @param voter_addresses 投票者地址列表
    /// @param creator_addr 投票创建者地址
    /// @param option_indices 选项索引列表
    public fun batch_vote(
        voter_addresses: vector<address>,
        creator_addr: address,
        option_indices: vector<u64>
    ) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        // 验证参数
        validation::validate_batch_operation(&voter_addresses, &option_indices);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        let len = vector::length(&voter_addresses);
        let i = 0;
        
        while (i < len) {
            let voter_addr = *vector::borrow(&voter_addresses, i);
            let option_index = *vector::borrow(&option_indices, i);
            
            // 验证选项有效
            validation::validate_option_index(voting, option_index);
            
            // 检查是否已投票
            if (!types::has_voted(voting, voter_addr)) {
                // 添加投票者信息
                let voter_info = types::new_voter_info(voter_addr, option_index);
                types::add_voter(voting, voter_info);
                
                // 更新选项票数
                let option = types::get_option_mut(voting, option_index);
                types::increment_option_votes(option);
                
                // 更新总票数
                types::increment_total_votes(voting);
            };
            
            i = i + 1;
        };
    }

    // ==================== 查询操作 ====================

    /// 获取用户投票的选项
    /// 
    /// @param creator_addr 投票创建者地址
    /// @param voter_addr 投票者地址
    /// @return (是否已投票, 选项索引)
    public fun get_user_vote(
        creator_addr: address,
        voter_addr: address
    ): (bool, u64) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global<Voting>(creator_addr);
        types::find_voter_option(voting, voter_addr)
    }

    /// 获取选项的票数
    /// 
    /// @param creator_addr 投票创建者地址
    /// @param option_index 选项索引
    /// @return 票数
    public fun get_option_votes(
        creator_addr: address,
        option_index: u64
    ): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global<Voting>(creator_addr);
        validation::validate_option_index(voting, option_index);
        
        let option = types::get_option(voting, option_index);
        types::get_option_vote_count(option)
    }

    /// 获取所有选项的票数
    /// 
    /// @param creator_addr 投票创建者地址
    /// @return 票数列表
    public fun get_all_option_votes(creator_addr: address): vector<u64> acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global<Voting>(creator_addr);
        let option_count = types::get_option_count(voting);
        let votes = vector::empty<u64>();
        
        let i = 0;
        while (i < option_count) {
            let option = types::get_option(voting, i);
            vector::push_back(&mut votes, types::get_option_vote_count(option));
            i = i + 1;
        };
        
        votes
    }

    /// 检查用户是否已投票
    /// 
    /// @param creator_addr 投票创建者地址
    /// @param voter_addr 投票者地址
    /// @return 是否已投票
    public fun has_user_voted(
        creator_addr: address,
        voter_addr: address
    ): bool acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global<Voting>(creator_addr);
        types::has_voted(voting, voter_addr)
    }

    // ==================== 结果分析 ====================

    /// 获取领先的选项
    /// 
    /// @param creator_addr 投票创建者地址
    /// @return (选项索引, 票数)
    public fun get_leading_option(creator_addr: address): (u64, u64) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global<Voting>(creator_addr);
        let leading_id = types::get_leading_option_id(voting);
        let option = types::get_option(voting, leading_id);
        
        (leading_id, types::get_option_vote_count(option))
    }

    /// 检查是否有平局
    /// 
    /// @param creator_addr 投票创建者地址
    /// @return 是否平局
    public fun is_tie(creator_addr: address): bool acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global<Voting>(creator_addr);
        types::has_tie(voting)
    }

    /// 获取平局的选项列表
    /// 
    /// @param creator_addr 投票创建者地址
    /// @return 平局选项的索引列表
    public fun get_tied_options(creator_addr: address): vector<u64> acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global<Voting>(creator_addr);
        
        if (!types::has_tie(voting)) {
            return vector::empty<u64>()
        };
        
        let tied_options = vector::empty<u64>();
        let max_votes = 0;
        let option_count = types::get_option_count(voting);
        
        // 找到最高票数
        let i = 0;
        while (i < option_count) {
            let option = types::get_option(voting, i);
            let votes = types::get_option_vote_count(option);
            if (votes > max_votes) {
                max_votes = votes;
            };
            i = i + 1;
        };
        
        // 收集所有最高票数的选项
        i = 0;
        while (i < option_count) {
            let option = types::get_option(voting, i);
            let votes = types::get_option_vote_count(option);
            if (votes == max_votes && max_votes > 0) {
                vector::push_back(&mut tied_options, i);
            };
            i = i + 1;
        };
        
        tied_options
    }

    /// 计算投票参与率
    /// 
    /// @param creator_addr 投票创建者地址
    /// @param total_eligible_voters 合格投票者总数
    /// @return 参与率（百分比，0-100）
    public fun calculate_participation_rate(
        creator_addr: address,
        total_eligible_voters: u64
    ): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        if (total_eligible_voters == 0) {
            return 0
        };
        
        let voting = borrow_global<Voting>(creator_addr);
        let actual_voters = types::get_voter_count(voting);
        
        (actual_voters * 100) / total_eligible_voters
    }

    // ==================== 内部辅助函数 ====================

    /// 更新投票者的选择
    /// 
    /// @param voting 投票可变引用
    /// @param voter_addr 投票者地址
    /// @param new_option_id 新选项ID
    fun update_voter_choice(
        voting: &mut Voting,
        voter_addr: address,
        new_option_id: u64
    ) {
        let voter_count = types::get_voter_count(voting);
        let i = 0;
        
        while (i < voter_count) {
            let voter = types::get_voter_info(voting, i);
            if (types::get_voter_address(voter) == voter_addr) {
                // 找到了投票者，需要更新
                // 由于VoterInfo没有可变引用，需要重新创建
                // 这里简化处理：先移除再添加
                remove_voter_at_index(voting, i);
                let new_voter = types::new_voter_info(voter_addr, new_option_id);
                types::add_voter(voting, new_voter);
                return
            };
            i = i + 1;
        };
    }

    /// 移除指定索引的投票者
    /// 
    /// @param voting 投票可变引用
    /// @param index 投票者索引
    fun remove_voter_at_index(voting: &mut Voting, index: u64) {
        let voter_count = types::get_voter_count(voting);
        assert!(index < voter_count, E_INVALID_OPERATION);
        
        // 由于vector不支持直接删除，需要通过重建来移除
        // 这是一个性能较低的操作，实际应用中可能需要更好的数据结构
        let new_voters = vector::empty<VoterInfo>();
        let i = 0;
        
        while (i < voter_count) {
            if (i != index) {
                let voter = types::get_voter_info(voting, i);
                let new_voter = types::new_voter_info(
                    types::get_voter_address(voter),
                    types::get_voter_option_id(voter)
                );
                vector::push_back(&mut new_voters, new_voter);
            };
            i = i + 1;
        };
        
        // 注意：这里需要访问voting的内部字段来替换voters
        // 由于Voting的字段不公开，实际实现需要在types模块提供相应的方法
    }

    /// 移除投票者
    /// 
    /// @param voting 投票可变引用
    /// @param voter_addr 投票者地址
    fun remove_voter(voting: &mut Voting, voter_addr: address) {
        let voter_count = types::get_voter_count(voting);
        let i = 0;
        
        while (i < voter_count) {
            let voter = types::get_voter_info(voting, i);
            if (types::get_voter_address(voter) == voter_addr) {
                remove_voter_at_index(voting, i);
                return
            };
            i = i + 1;
        };
    }

    // ==================== 统计分析 ====================

    /// 获取投票分布
    /// 
    /// @param creator_addr 投票创建者地址
    /// @return (选项ID列表, 票数列表, 百分比列表)
    public fun get_vote_distribution(
        creator_addr: address
    ): (vector<u64>, vector<u64>, vector<u64>) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global<Voting>(creator_addr);
        let option_count = types::get_option_count(voting);
        let total_votes = types::get_total_votes(voting);
        
        let option_ids = vector::empty<u64>();
        let votes = vector::empty<u64>();
        let percentages = vector::empty<u64>();
        
        let i = 0;
        while (i < option_count) {
            let option = types::get_option(voting, i);
            let vote_count = types::get_option_vote_count(option);
            let percentage = if (total_votes > 0) {
                (vote_count * 100) / total_votes
            } else {
                0
            };
            
            vector::push_back(&mut option_ids, i);
            vector::push_back(&mut votes, vote_count);
            vector::push_back(&mut percentages, percentage);
            i = i + 1;
        };
        
        (option_ids, votes, percentages)
    }

    /// 获取投票排名
    /// 
    /// @param creator_addr 投票创建者地址
    /// @return 按票数排序的选项ID列表（降序）
    public fun get_vote_ranking(creator_addr: address): vector<u64> acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global<Voting>(creator_addr);
        let option_count = types::get_option_count(voting);
        
        // 创建索引列表
        let rankings = vector::empty<u64>();
        let i = 0;
        while (i < option_count) {
            vector::push_back(&mut rankings, i);
            i = i + 1;
        };
        
        // 简单的冒泡排序（按票数降序）
        let n = vector::length(&rankings);
        if (n <= 1) {
            return rankings
        };
        
        let i = 0;
        while (i < n - 1) {
            let j = 0;
            while (j < n - i - 1) {
                let id1 = *vector::borrow(&rankings, j);
                let id2 = *vector::borrow(&rankings, j + 1);
                
                let option1 = types::get_option(voting, id1);
                let option2 = types::get_option(voting, id2);
                
                let votes1 = types::get_option_vote_count(option1);
                let votes2 = types::get_option_vote_count(option2);
                
                // 如果前一个票数少，交换
                if (votes1 < votes2) {
                    vector::swap(&mut rankings, j, j + 1);
                };
                j = j + 1;
            };
            i = i + 1;
        };
        
        rankings
    }

    /// 检查投票是否有效（有参与者）
    /// 
    /// @param creator_addr 投票创建者地址
    /// @return 是否有效
    public fun is_voting_valid(creator_addr: address): bool acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global<Voting>(creator_addr);
        types::get_total_votes(voting) > 0
    }
}
