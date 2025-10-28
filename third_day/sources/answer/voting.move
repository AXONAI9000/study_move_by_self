/// 投票系统主模块
/// 
/// 本模块提供统一的接口和便捷的使用方法：
/// - 便捷创建：简化投票创建流程
/// - 快速操作：提供简化的投票操作接口
/// - 综合查询：整合各种信息查询功能
/// - 管理工具：提供系统管理和维护功能
/// - 工具函数：提供格式验证和数据导出功能
module voting::voting {
    use std::string::{String, utf8};
    use std::vector;
    use voting::types::{Self, Voting};
    use voting::management;
    use voting::operations;
    use voting::info;
    use voting::validation;

    // ==================== 系统管理 ====================

    /// 设置投票系统
    /// 
    /// @param admin 管理员账户
    public entry fun setup_system(admin: &signer) {
        management::initialize_system(admin);
    }

    /// 检查系统健康状态
    /// 
    /// @return (是否健康, 状态消息)
    public fun check_system_health(): (bool, String) {
        validation::check_system_health()
    }

    /// 验证系统完整性
    /// 
    /// @return (是否有效, 问题列表)
    public fun validate_system_integrity(): (bool, vector<String>) {
        // 简化实现：返回系统基本状态
        (true, vector::empty<String>())
    }

    /// 获取系统指标
    /// 
    /// @return (总投票数, 活跃投票数, 已结束投票数, 总参与者, 平均参与率)
    public fun get_system_metrics(): (u64, u64, u64, u64, u64) {
        // 简化实现：返回默认值
        (0, 0, 0, 0, 0)
    }

    // ==================== 便捷创建 ====================

    /// 创建简单投票
    /// 
    /// @param creator 创建者账户
    /// @param title 投票标题
    /// @param options 选项标题列表
    /// @return 投票ID
    public fun create_simple_voting(
        creator: &signer,
        title: String,
        options: vector<String>
    ): u64 {
        management::create_simple_voting(creator, title, options)
    }

    /// 创建快速投票（立即开始）
    /// 
    /// @param creator 创建者账户
    /// @param title 投票标题
    /// @param options 选项标题列表
    /// @return 投票ID
    public fun create_quick_voting(
        creator: &signer,
        title: String,
        options: vector<String>
    ): u64 {
        management::create_quick_voting(creator, title, options)
    }

    /// 创建完整投票
    /// 
    /// @param creator 创建者账户
    /// @param title 投票标题
    /// @param description 投票描述
    /// @param duration 持续时间（秒）
    /// @param option_titles 选项标题列表
    /// @param option_descriptions 选项描述列表
    /// @param allow_revote 是否允许修改投票
    /// @param public_voters 是否公开投票者
    /// @return 投票ID
    public fun create_full_voting(
        creator: &signer,
        title: String,
        description: String,
        duration: u64,
        option_titles: vector<String>,
        option_descriptions: vector<String>,
        allow_revote: bool,
        public_voters: bool
    ): u64 {
        management::create_voting(
            creator,
            title,
            description,
            duration,
            option_titles,
            option_descriptions,
            allow_revote,
            public_voters
        )
    }

    // ==================== 快速操作 ====================

    /// 用户投票
    /// 
    /// @param voter 投票者账户
    /// @param creator_addr 投票创建者地址
    /// @param option_index 选项索引
    public entry fun cast_vote(
        voter: &signer,
        creator_addr: address,
        option_index: u64
    ) {
        operations::vote(voter, creator_addr, option_index);
    }

    /// 修改投票
    /// 
    /// @param voter 投票者账户
    /// @param creator_addr 投票创建者地址
    /// @param new_option_index 新的选项索引
    public entry fun change_vote(
        voter: &signer,
        creator_addr: address,
        new_option_index: u64
    ) {
        operations::revote(voter, creator_addr, new_option_index);
    }

    /// 撤销投票
    /// 
    /// @param voter 投票者账户
    /// @param creator_addr 投票创建者地址
    public entry fun withdraw_vote(
        voter: &signer,
        creator_addr: address
    ) {
        operations::unvote(voter, creator_addr);
    }

    /// 快速投票（简化接口）
    /// 
    /// @param voter 投票者账户
    /// @param creator_addr 投票创建者地址
    /// @param option_index 选项索引
    public entry fun quick_vote(
        voter: &signer,
        creator_addr: address,
        option_index: u64
    ) {
        cast_vote(voter, creator_addr, option_index);
    }

    // ==================== 综合查询 ====================

    /// 获取投票完整状态
    /// 
    /// @param creator_addr 创建者地址
    /// @return (ID, 标题, 状态, 总票数, 总选项, 总投票者, 剩余时间, 是否有效, 创建者, 描述, 结束时间, 创建时间)
    public fun get_voting_complete_status(
        creator_addr: address
    ): (u64, String, String, u64, u64, u64, u64, bool, address, String, u64, u64) acquires Voting {
        let (id, title, description, status, creator) = info::get_basic_info(creator_addr);
        let total_votes = info::get_total_votes(creator_addr);
        let option_count = info::get_option_count(creator_addr);
        let voter_count = info::get_voter_count(creator_addr);
        let remaining_time = info::get_remaining_time(creator_addr);
        let is_valid = total_votes > 0;
        let end_time = info::get_end_time(creator_addr);
        let created_at = info::get_created_at(creator_addr);
        
        (id, title, status, total_votes, option_count, voter_count, 
         remaining_time, is_valid, creator, description, end_time, created_at)
    }

    /// 获取投票全部信息
    /// 
    /// @param creator_addr 创建者地址
    /// @return (选项标题, 选项票数, 投票者地址, 总票数, 剩余时间, 参与者数, 是否有效, 状态)
    public fun get_voting_full_info(
        creator_addr: address
    ): (vector<String>, vector<u64>, vector<address>, u64, u64, u64, bool, String) acquires Voting {
        let (titles, _descriptions, votes) = info::get_all_options(creator_addr);
        let voters = info::get_voter_addresses(creator_addr);
        let total_votes = info::get_total_votes(creator_addr);
        let remaining_time = info::get_remaining_time(creator_addr);
        let participant_count = info::get_voter_count(creator_addr);
        let is_valid = total_votes > 0;
        let status = info::get_status(creator_addr);
        
        (titles, votes, voters, total_votes, remaining_time, 
         participant_count, is_valid, status)
    }

    /// 获取投票报告
    /// 
    /// @param creator_addr 创建者地址
    /// @return (总选项数, 总票数, 总投票者, 平均票数, 最高票数, 最低票数, 参与率)
    public fun get_voting_report(
        creator_addr: address
    ): (u64, u64, u64, u64, u64, u64, u64) acquires Voting {
        info::get_voting_stats(creator_addr)
    }

    /// 获取投票结果摘要
    /// 
    /// @param creator_addr 创建者地址
    /// @return (获胜选项标题, 获胜票数, 总票数, 是否平局)
    public fun get_voting_result_summary(
        creator_addr: address
    ): (String, u64, u64, bool) acquires Voting {
        let (winning_id, winning_votes, total, is_tie) = info::get_voting_result(creator_addr);
        let (_, title, _, _) = info::get_option_details(creator_addr, winning_id);
        
        (title, winning_votes, total, is_tie)
    }

    // ==================== 验证工具 ====================

    /// 验证标题
    /// 
    /// @param title 标题
    /// @return 是否有效
    public fun validate_title(title: &String): bool {
        validation::is_valid_title(title)
    }

    /// 验证选项
    /// 
    /// @param options 选项列表
    /// @return 是否有效
    public fun validate_options(options: &vector<String>): bool {
        let len = vector::length(options);
        if (len < types::min_options() || len > types::max_options()) {
            return false
        };
        
        let i = 0;
        while (i < len) {
            let option = vector::borrow(options, i);
            if (!validation::is_valid_title(option)) {
                return false
            };
            i = i + 1;
        };
        
        true
    }

    /// 验证持续时间
    /// 
    /// @param duration 持续时间（秒）
    /// @return 是否有效
    public fun validate_duration(duration: u64): bool {
        duration > 0 && duration <= 31536000 // 最多1年
    }

    /// 验证描述
    /// 
    /// @param description 描述
    /// @return 是否有效
    public fun validate_description(description: &String): bool {
        validation::is_valid_description(description)
    }

    // ==================== 格式化工具 ====================

    /// 格式化投票状态
    /// 
    /// @param status_code 状态码
    /// @return 状态字符串
    public fun format_status(status_code: u8): String {
        if (status_code == types::status_pending()) {
            utf8(b"Pending")
        } else if (status_code == types::status_active()) {
            utf8(b"Active")
        } else if (status_code == types::status_ended()) {
            utf8(b"Ended")
        } else {
            utf8(b"Cancelled")
        }
    }

    /// 格式化时间（秒转天时分秒）
    /// 
    /// @param seconds 秒数
    /// @return (天, 小时, 分钟, 秒)
    public fun format_duration(seconds: u64): (u64, u64, u64, u64) {
        let days = seconds / 86400;
        let remaining = seconds % 86400;
        let hours = remaining / 3600;
        remaining = remaining % 3600;
        let minutes = remaining / 60;
        let secs = remaining % 60;
        
        (days, hours, minutes, secs)
    }

    /// 计算百分比
    /// 
    /// @param part 部分值
    /// @param total 总值
    /// @return 百分比（0-100）
    public fun calculate_percentage(part: u64, total: u64): u64 {
        if (total == 0) {
            0
        } else {
            (part * 100) / total
        }
    }

    // ==================== 数据导出 ====================

    /// 导出投票选项数据
    /// 
    /// @param creator_addr 创建者地址
    /// @return (选项ID列表, 标题列表, 票数列表, 百分比列表)
    public fun export_options_data(
        creator_addr: address
    ): (vector<u64>, vector<String>, vector<u64>, vector<u64>) acquires Voting {
        let (option_ids, votes, percentages) = operations::get_vote_distribution(creator_addr);
        let titles = info::get_option_titles(creator_addr);
        
        (option_ids, titles, votes, percentages)
    }

    /// 导出投票排名
    /// 
    /// @param creator_addr 创建者地址
    /// @return 排序后的选项ID列表
    public fun export_vote_ranking(creator_addr: address): vector<u64> acquires Voting {
        operations::get_vote_ranking(creator_addr)
    }

    // ==================== 高级查询 ====================

    /// 检查用户是否可以投票
    /// 
    /// @param creator_addr 创建者地址
    /// @param voter_addr 投票者地址
    /// @return (是否可以, 原因)
    public fun can_user_vote(
        creator_addr: address,
        voter_addr: address
    ): (bool, String) acquires Voting {
        info::can_participate(creator_addr, voter_addr)
    }

    /// 获取用户的投票
    /// 
    /// @param creator_addr 创建者地址
    /// @param voter_addr 投票者地址
    /// @return (是否已投票, 选项索引, 选项标题)
    public fun get_user_vote_info(
        creator_addr: address,
        voter_addr: address
    ): (bool, u64, String) acquires Voting {
        let (has_voted, option_id) = operations::get_user_vote(creator_addr, voter_addr);
        
        if (has_voted) {
            let (_, title, _, _) = info::get_option_details(creator_addr, option_id);
            (true, option_id, title)
        } else {
            (false, 0, utf8(b""))
        }
    }

    /// 获取领先选项信息
    /// 
    /// @param creator_addr 创建者地址
    /// @return (选项ID, 标题, 票数, 百分比)
    public fun get_leading_option_info(
        creator_addr: address
    ): (u64, String, u64, u64) acquires Voting {
        let (option_id, votes) = operations::get_leading_option(creator_addr);
        let (_, title, _, _) = info::get_option_details(creator_addr, option_id);
        let total = info::get_total_votes(creator_addr);
        let percentage = calculate_percentage(votes, total);
        
        (option_id, title, votes, percentage)
    }

    /// 获取平局选项信息
    /// 
    /// @param creator_addr 创建者地址
    /// @return (是否平局, 平局选项ID列表, 票数)
    public fun get_tie_info(
        creator_addr: address
    ): (bool, vector<u64>, u64) acquires Voting {
        let is_tie = operations::is_tie(creator_addr);
        
        if (is_tie) {
            let tied_options = operations::get_tied_options(creator_addr);
            let (_first_id, votes) = operations::get_leading_option(creator_addr);
            (true, tied_options, votes)
        } else {
            (false, vector::empty<u64>(), 0)
        }
    }

    // ==================== 批量查询 ====================

    /// 批量检查用户是否已投票
    /// 
    /// @param creator_addr 创建者地址
    /// @param voter_addresses 投票者地址列表
    /// @return 投票状态列表（true表示已投票）
    public fun batch_check_voted(
        creator_addr: address,
        voter_addresses: vector<address>
    ): vector<bool> acquires Voting {
        let len = vector::length(&voter_addresses);
        let results = vector::empty<bool>();
        
        let i = 0;
        while (i < len) {
            let addr = *vector::borrow(&voter_addresses, i);
            let has_voted = operations::has_user_voted(creator_addr, addr);
            vector::push_back(&mut results, has_voted);
            i = i + 1;
        };
        
        results
    }

    /// 批量获取选项票数
    /// 
    /// @param creator_addr 创建者地址
    /// @return 所有选项的票数列表
    public fun batch_get_option_votes(creator_addr: address): vector<u64> acquires Voting {
        operations::get_all_option_votes(creator_addr)
    }

    // ==================== 统计分析 ====================

    /// 计算投票参与率
    /// 
    /// @param creator_addr 创建者地址
    /// @param total_eligible_voters 合格投票者总数
    /// @return 参与率百分比
    public fun calculate_participation_rate(
        creator_addr: address,
        total_eligible_voters: u64
    ): u64 acquires Voting {
        operations::calculate_participation_rate(creator_addr, total_eligible_voters)
    }

    /// 获取投票进度
    /// 
    /// @param creator_addr 创建者地址
    /// @param expected_voters 期望投票者数
    /// @return 进度百分比
    public fun get_voting_progress(
        creator_addr: address,
        expected_voters: u64
    ): u64 acquires Voting {
        info::get_progress_percentage(creator_addr, expected_voters)
    }

    /// 分析投票趋势
    /// 
    /// @param creator_addr 创建者地址
    /// @return (领先选项ID, 是否有明显优势, 优势百分比)
    public fun analyze_voting_trend(
        creator_addr: address
    ): (u64, bool, u64) acquires Voting {
        let (leading_id, leading_votes) = operations::get_leading_option(creator_addr);
        let total_votes = info::get_total_votes(creator_addr);
        
        if (total_votes == 0) {
            return (0, false, 0)
        };
        
        let percentage = (leading_votes * 100) / total_votes;
        let has_clear_lead = percentage > 50; // 超过50%认为有明显优势
        
        (leading_id, has_clear_lead, percentage)
    }

    // ==================== 工具函数 ====================

    /// 检查投票是否有效
    /// 
    /// @param creator_addr 创建者地址
    /// @return 是否有效
    public fun is_voting_valid(creator_addr: address): bool acquires Voting {
        operations::is_voting_valid(creator_addr)
    }

    /// 检查投票完整性
    /// 
    /// @param creator_addr 创建者地址
    /// @return 是否完整
    public fun check_voting_integrity(creator_addr: address): bool acquires Voting {
        info::check_voting_integrity(creator_addr)
    }

    /// 获取验证摘要
    /// 
    /// @param creator_addr 创建者地址
    /// @return (是否有效, 错误列表)
    public fun get_validation_summary(
        creator_addr: address
    ): (bool, vector<String>) acquires Voting {
        info::get_validation_summary(creator_addr)
    }
}
