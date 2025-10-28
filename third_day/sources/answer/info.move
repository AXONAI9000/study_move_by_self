/// 投票系统信息模块
/// 
/// 本模块实现投票系统的信息查询和统计功能：
/// - 基本信息：获取投票的基本属性和配置
/// - 详细信息：获取投票选项和投票者信息
/// - 结果统计：计算投票结果和有效性
/// - 进度分析：提供投票进度和剩余时间
/// - 系统统计：提供全局统计和趋势分析
module voting::info {
    use std::string::{String, utf8};
    use std::vector;
    use voting::types::{Self, Voting};
    use voting::validation;

    // ==================== 错误码定义 ====================
    
    /// 投票不存在
    const E_VOTING_NOT_EXISTS: u64 = 5001;

    // ==================== 基本信息查询 ====================

    /// 检查投票是否存在
    /// 
    /// @param creator_addr 创建者地址
    /// @return 是否存在
    public fun voting_exists(creator_addr: address): bool {
        exists<Voting>(creator_addr)
    }

    /// 获取投票ID
    /// 
    /// @param creator_addr 创建者地址
    /// @return 投票ID
    public fun get_voting_id(creator_addr: address): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::get_voting_id(voting)
    }

    /// 获取投票标题
    /// 
    /// @param creator_addr 创建者地址
    /// @return 标题
    public fun get_title(creator_addr: address): String acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::get_voting_title(voting)
    }

    /// 获取投票描述
    /// 
    /// @param creator_addr 创建者地址
    /// @return 描述
    public fun get_description(creator_addr: address): String acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::get_voting_description(voting)
    }

    /// 获取创建者地址
    /// 
    /// @param creator_addr 创建者地址
    /// @return 创建者地址
    public fun get_creator(creator_addr: address): address acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::get_creator(voting)
    }

    /// 获取投票状态
    /// 
    /// @param creator_addr 创建者地址
    /// @return 状态字符串
    public fun get_status(creator_addr: address): String acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        let status = types::get_status(voting);
        
        if (status == types::status_pending()) {
            utf8(b"Pending")
        } else if (status == types::status_active()) {
            utf8(b"Active")
        } else if (status == types::status_ended()) {
            utf8(b"Ended")
        } else {
            utf8(b"Cancelled")
        }
    }

    /// 获取投票基本信息
    /// 
    /// @param creator_addr 创建者地址
    /// @return (ID, 标题, 描述, 状态, 创建者)
    public fun get_basic_info(
        creator_addr: address
    ): (u64, String, String, String, address) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        
        (
            types::get_voting_id(voting),
            types::get_voting_title(voting),
            types::get_voting_description(voting),
            get_status(creator_addr),
            types::get_creator(voting)
        )
    }

    // ==================== 时间信息查询 ====================

    /// 获取创建时间
    /// 
    /// @param creator_addr 创建者地址
    /// @return 创建时间戳
    public fun get_created_at(creator_addr: address): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::get_created_at(voting)
    }

    /// 获取开始时间
    /// 
    /// @param creator_addr 创建者地址
    /// @return 开始时间戳
    public fun get_start_time(creator_addr: address): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::get_start_time(voting)
    }

    /// 获取结束时间
    /// 
    /// @param creator_addr 创建者地址
    /// @return 结束时间戳
    public fun get_end_time(creator_addr: address): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::get_end_time(voting)
    }

    /// 获取剩余时间
    /// 
    /// @param creator_addr 创建者地址
    /// @return 剩余秒数
    public fun get_remaining_time(creator_addr: address): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        validation::get_remaining_time(voting)
    }

    /// 获取时间信息
    /// 
    /// @param creator_addr 创建者地址
    /// @return (创建时间, 开始时间, 结束时间, 剩余时间)
    public fun get_time_info(
        creator_addr: address
    ): (u64, u64, u64, u64) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        
        (
            types::get_created_at(voting),
            types::get_start_time(voting),
            types::get_end_time(voting),
            validation::get_remaining_time(voting)
        )
    }

    // ==================== 选项信息查询 ====================

    /// 获取选项数量
    /// 
    /// @param creator_addr 创建者地址
    /// @return 选项数量
    public fun get_option_count(creator_addr: address): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::get_option_count(voting)
    }

    /// 获取选项标题列表
    /// 
    /// @param creator_addr 创建者地址
    /// @return 标题列表
    public fun get_option_titles(creator_addr: address): vector<String> acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        let option_count = types::get_option_count(voting);
        let titles = vector::empty<String>();
        
        let i = 0;
        while (i < option_count) {
            let option = types::get_option(voting, i);
            vector::push_back(&mut titles, types::get_option_title(option));
            i = i + 1;
        };
        
        titles
    }

    /// 获取选项详细信息
    /// 
    /// @param creator_addr 创建者地址
    /// @param option_index 选项索引
    /// @return (ID, 标题, 描述, 票数)
    public fun get_option_details(
        creator_addr: address,
        option_index: u64
    ): (u64, String, String, u64) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        validation::validate_option_index(voting, option_index);
        
        let option = types::get_option(voting, option_index);
        
        (
            types::get_option_id(option),
            types::get_option_title(option),
            types::get_option_description(option),
            types::get_option_vote_count(option)
        )
    }

    /// 获取所有选项的详细信息
    /// 
    /// @param creator_addr 创建者地址
    /// @return (标题列表, 描述列表, 票数列表)
    public fun get_all_options(
        creator_addr: address
    ): (vector<String>, vector<String>, vector<u64>) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        let option_count = types::get_option_count(voting);
        
        let titles = vector::empty<String>();
        let descriptions = vector::empty<String>();
        let votes = vector::empty<u64>();
        
        let i = 0;
        while (i < option_count) {
            let option = types::get_option(voting, i);
            vector::push_back(&mut titles, types::get_option_title(option));
            vector::push_back(&mut descriptions, types::get_option_description(option));
            vector::push_back(&mut votes, types::get_option_vote_count(option));
            i = i + 1;
        };
        
        (titles, descriptions, votes)
    }

    // ==================== 投票者信息查询 ====================

    /// 获取投票者数量
    /// 
    /// @param creator_addr 创建者地址
    /// @return 投票者数量
    public fun get_voter_count(creator_addr: address): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::get_voter_count(voting)
    }

    /// 获取总投票数
    /// 
    /// @param creator_addr 创建者地址
    /// @return 总投票数
    public fun get_total_votes(creator_addr: address): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::get_total_votes(voting)
    }

    /// 获取所有投票者地址
    /// 
    /// @param creator_addr 创建者地址
    /// @return 投票者地址列表
    public fun get_voter_addresses(creator_addr: address): vector<address> acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        let voter_count = types::get_voter_count(voting);
        let addresses = vector::empty<address>();
        
        let i = 0;
        while (i < voter_count) {
            let voter = types::get_voter_info(voting, i);
            vector::push_back(&mut addresses, types::get_voter_address(voter));
            i = i + 1;
        };
        
        addresses
    }

    /// 检查用户是否已投票
    /// 
    /// @param creator_addr 创建者地址
    /// @param voter_addr 投票者地址
    /// @return 是否已投票
    public fun has_voted(creator_addr: address, voter_addr: address): bool acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::has_voted(voting, voter_addr)
    }

    // ==================== 配置信息查询 ====================

    /// 是否允许重新投票
    /// 
    /// @param creator_addr 创建者地址
    /// @return 是否允许
    public fun is_revote_allowed(creator_addr: address): bool acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::is_revote_allowed(voting)
    }

    /// 是否公开投票者
    /// 
    /// @param creator_addr 创建者地址
    /// @return 是否公开
    public fun is_public_voters(creator_addr: address): bool acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        types::is_public_voters(voting)
    }

    /// 获取配置信息
    /// 
    /// @param creator_addr 创建者地址
    /// @return (允许重新投票, 公开投票者)
    public fun get_config_info(creator_addr: address): (bool, bool) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        
        (
            types::is_revote_allowed(voting),
            types::is_public_voters(voting)
        )
    }

    // ==================== 结果统计查询 ====================

    /// 获取投票结果
    /// 
    /// @param creator_addr 创建者地址
    /// @return (获胜选项ID, 获胜票数, 总票数, 是否平局)
    public fun get_voting_result(
        creator_addr: address
    ): (u64, u64, u64, bool) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        
        let leading_id = types::get_leading_option_id(voting);
        let leading_option = types::get_option(voting, leading_id);
        let leading_votes = types::get_option_vote_count(leading_option);
        let total = types::get_total_votes(voting);
        let is_tie = types::has_tie(voting);
        
        (leading_id, leading_votes, total, is_tie)
    }

    /// 获取投票统计
    /// 
    /// @param creator_addr 创建者地址
    /// @return (总选项数, 总票数, 总投票者, 平均票数, 最高票数, 最低票数, 参与率)
    public fun get_voting_stats(
        creator_addr: address
    ): (u64, u64, u64, u64, u64, u64, u64) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        
        let option_count = types::get_option_count(voting);
        let total_votes = types::get_total_votes(voting);
        let voter_count = types::get_voter_count(voting);
        
        let avg_votes = if (option_count > 0) {
            total_votes / option_count
        } else {
            0
        };
        
        let (max_votes, min_votes) = get_max_min_votes(voting);
        
        (
            option_count,
            total_votes,
            voter_count,
            avg_votes,
            max_votes,
            min_votes,
            0 // 参与率需要外部数据
        )
    }

    /// 获取完整统计信息
    /// 
    /// @param creator_addr 创建者地址
    /// @return (投票ID, 标题, 状态, 总选项, 总票数, 总投票者, 剩余时间, 是否有效)
    public fun get_complete_stats(
        creator_addr: address
    ): (u64, String, String, u64, u64, u64, u64, bool) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        
        (
            types::get_voting_id(voting),
            types::get_voting_title(voting),
            get_status(creator_addr),
            types::get_option_count(voting),
            types::get_total_votes(voting),
            types::get_voter_count(voting),
            validation::get_remaining_time(voting),
            types::get_total_votes(voting) > 0
        )
    }

    // ==================== 权限检查 ====================

    /// 检查用户是否可以查看投票
    /// 
    /// @param creator_addr 创建者地址
    /// @param user_addr 用户地址
    /// @return 是否可以查看
    public fun can_view_voting(creator_addr: address, user_addr: address): bool acquires Voting {
        if (!exists<Voting>(creator_addr)) {
            return false
        };
        
        let voting = borrow_global<Voting>(creator_addr);
        validation::can_view_voting(user_addr, voting)
    }

    /// 检查用户是否可以投票
    /// 
    /// @param creator_addr 创建者地址
    /// @param voter_addr 投票者地址
    /// @return (是否可以, 原因)
    public fun can_participate(
        creator_addr: address,
        voter_addr: address
    ): (bool, String) acquires Voting {
        if (!exists<Voting>(creator_addr)) {
            return (false, utf8(b"Voting does not exist"))
        };
        
        let voting = borrow_global<Voting>(creator_addr);
        validation::can_participate(voting, voter_addr)
    }

    // ==================== 辅助函数 ====================

    /// 获取最高和最低票数
    /// 
    /// @param voting 投票引用
    /// @return (最高票数, 最低票数)
    fun get_max_min_votes(voting: &Voting): (u64, u64) {
        let option_count = types::get_option_count(voting);
        if (option_count == 0) {
            return (0, 0)
        };
        
        let first_option = types::get_option(voting, 0);
        let max_votes = types::get_option_vote_count(first_option);
        let min_votes = types::get_option_vote_count(first_option);
        
        let i = 1;
        while (i < option_count) {
            let option = types::get_option(voting, i);
            let votes = types::get_option_vote_count(option);
            
            if (votes > max_votes) {
                max_votes = votes;
            };
            if (votes < min_votes) {
                min_votes = votes;
            };
            
            i = i + 1;
        };
        
        (max_votes, min_votes)
    }

    /// 获取投票进度百分比
    /// 
    /// @param creator_addr 创建者地址
    /// @param expected_voters 期望的投票者数量
    /// @return 进度百分比（0-100）
    public fun get_progress_percentage(
        creator_addr: address,
        expected_voters: u64
    ): u64 acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        if (expected_voters == 0) {
            return 0
        };
        
        let voting = borrow_global<Voting>(creator_addr);
        let actual_voters = types::get_voter_count(voting);
        
        let percentage = (actual_voters * 100) / expected_voters;
        if (percentage > 100) {
            100
        } else {
            percentage
        }
    }

    /// 检查投票完整性
    /// 
    /// @param creator_addr 创建者地址
    /// @return 是否完整
    public fun check_voting_integrity(creator_addr: address): bool acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        validation::validate_voting_integrity(voting)
    }

    /// 获取验证摘要
    /// 
    /// @param creator_addr 创建者地址
    /// @return (是否有效, 错误列表)
    public fun get_validation_summary(
        creator_addr: address
    ): (bool, vector<String>) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        let voting = borrow_global<Voting>(creator_addr);
        validation::get_validation_summary(voting)
    }
}
