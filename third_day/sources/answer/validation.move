/// 投票系统验证模块
/// 
/// 本模块实现各种验证功能，确保系统安全性和正确性：
/// - 权限验证：验证用户是否为投票创建者
/// - 状态验证：验证投票是否处于特定状态
/// - 时间验证：验证投票时间范围和有效性
/// - 选项验证：验证投票选项的有效性
/// - 投票者验证：验证用户投票资格和历史
/// - 综合验证：组合多种验证条件的复杂验证
module voting::validation {
    use std::string::{String, utf8, length};
    use std::vector;
    use std::signer;
    use aptos_framework::timestamp;
    use voting::types::{Self, Voting};

    // ==================== 错误码定义 ====================
    
    /// 无效的权限
    const E_UNAUTHORIZED: u64 = 2001;
    /// 无效的投票状态
    const E_INVALID_STATUS: u64 = 2002;
    /// 投票已过期
    const E_VOTING_EXPIRED: u64 = 2003;
    /// 投票尚未开始
    const E_VOTING_NOT_STARTED: u64 = 2004;
    /// 无效的选项索引
    const E_INVALID_OPTION: u64 = 2005;
    /// 用户已投票
    const E_ALREADY_VOTED: u64 = 2006;
    /// 用户未投票
    const E_NOT_VOTED: u64 = 2007;
    /// 无效的标题
    const E_INVALID_TITLE: u64 = 2008;
    /// 无效的描述
    const E_INVALID_DESCRIPTION: u64 = 2009;
    /// 选项数量不足
    const E_INSUFFICIENT_OPTIONS: u64 = 2010;
    /// 选项数量过多
    const E_TOO_MANY_OPTIONS: u64 = 2011;
    /// 无效的持续时间
    const E_INVALID_DURATION: u64 = 2012;
    /// 时间冲突
    const E_TIME_CONFLICT: u64 = 2013;

    // ==================== 权限验证 ====================

    /// 验证用户是否为投票创建者
    /// 
    /// @param account 用户账户
    /// @param voting 投票引用
    /// @throws E_UNAUTHORIZED 如果用户不是创建者
    public fun validate_creator(account: &signer, voting: &Voting) {
        let user_addr = signer::address_of(account);
        let creator_addr = types::get_creator(voting);
        assert!(user_addr == creator_addr, E_UNAUTHORIZED);
    }

    /// 检查用户是否为创建者（不抛出错误）
    /// 
    /// @param user_addr 用户地址
    /// @param voting 投票引用
    /// @return 是否为创建者
    public fun is_creator(user_addr: address, voting: &Voting): bool {
        user_addr == types::get_creator(voting)
    }

    /// 验证用户有权限查看投票
    /// 
    /// @param _user_addr 用户地址
    /// @param _voting 投票引用
    /// @return 是否有权限查看
    public fun can_view_voting(_user_addr: address, _voting: &Voting): bool {
        // 所有人都可以查看公开的投票
        // 如果投票不公开投票者信息，仍然可以查看基本信息
        true
    }

    /// 验证用户有权限修改投票
    /// 
    /// @param account 用户账户
    /// @param voting 投票引用
    /// @throws E_UNAUTHORIZED 如果用户无权限
    public fun validate_modify_permission(account: &signer, voting: &Voting) {
        validate_creator(account, voting);
    }

    // ==================== 状态验证 ====================

    /// 验证投票处于待定状态
    /// 
    /// @param voting 投票引用
    /// @throws E_INVALID_STATUS 如果状态不是待定
    public fun validate_pending_status(voting: &Voting) {
        assert!(types::is_pending(voting), E_INVALID_STATUS);
    }

    /// 验证投票处于活跃状态
    /// 
    /// @param voting 投票引用
    /// @throws E_INVALID_STATUS 如果状态不是活跃
    public fun validate_active_status(voting: &Voting) {
        assert!(types::is_active(voting), E_INVALID_STATUS);
    }

    /// 验证投票处于结束状态
    /// 
    /// @param voting 投票引用
    /// @throws E_INVALID_STATUS 如果状态不是结束
    public fun validate_ended_status(voting: &Voting) {
        assert!(types::is_ended(voting), E_INVALID_STATUS);
    }

    /// 验证投票未被取消
    /// 
    /// @param voting 投票引用
    /// @throws E_INVALID_STATUS 如果投票已被取消
    public fun validate_not_cancelled(voting: &Voting) {
        assert!(!types::is_cancelled(voting), E_INVALID_STATUS);
    }

    /// 验证投票可以开始
    /// 
    /// @param voting 投票引用
    /// @throws E_INVALID_STATUS 如果投票不能开始
    public fun validate_can_start(voting: &Voting) {
        validate_pending_status(voting);
        validate_not_cancelled(voting);
    }

    /// 验证投票可以结束
    /// 
    /// @param voting 投票引用
    /// @throws E_INVALID_STATUS 如果投票不能结束
    public fun validate_can_end(voting: &Voting) {
        validate_active_status(voting);
    }

    /// 验证投票可以被取消
    /// 
    /// @param voting 投票引用
    /// @throws E_INVALID_STATUS 如果投票不能取消
    public fun validate_can_cancel(voting: &Voting) {
        assert!(!types::is_ended(voting), E_INVALID_STATUS);
        assert!(!types::is_cancelled(voting), E_INVALID_STATUS);
    }

    // ==================== 时间验证 ====================

    /// 验证投票未过期
    /// 
    /// @param voting 投票引用
    /// @throws E_VOTING_EXPIRED 如果投票已过期
    public fun validate_not_expired(voting: &Voting) {
        let now = timestamp::now_seconds();
        let end_time = types::get_end_time(voting);
        assert!(now <= end_time, E_VOTING_EXPIRED);
    }

    /// 验证投票已开始
    /// 
    /// @param voting 投票引用
    /// @throws E_VOTING_NOT_STARTED 如果投票未开始
    public fun validate_started(voting: &Voting) {
        let now = timestamp::now_seconds();
        let start_time = types::get_start_time(voting);
        assert!(start_time > 0 && now >= start_time, E_VOTING_NOT_STARTED);
    }

    /// 验证投票在有效时间内
    /// 
    /// @param voting 投票引用
    /// @throws E_VOTING_EXPIRED 或 E_VOTING_NOT_STARTED
    public fun validate_time_window(voting: &Voting) {
        validate_started(voting);
        validate_not_expired(voting);
    }

    /// 验证持续时间有效
    /// 
    /// @param duration 持续时间（秒）
    /// @throws E_INVALID_DURATION 如果持续时间无效
    public fun validate_duration(duration: u64) {
        assert!(duration > 0, E_INVALID_DURATION);
        assert!(duration <= 31536000, E_INVALID_DURATION); // 最多1年
    }

    /// 验证时间范围有效
    /// 
    /// @param start_time 开始时间
    /// @param end_time 结束时间
    /// @throws E_TIME_CONFLICT 如果时间范围无效
    public fun validate_time_range(start_time: u64, end_time: u64) {
        assert!(end_time > start_time, E_TIME_CONFLICT);
        let duration = end_time - start_time;
        validate_duration(duration);
    }

    /// 检查投票是否在有效期内（不抛出错误）
    /// 
    /// @param voting 投票引用
    /// @return 是否在有效期内
    public fun is_within_time_window(voting: &Voting): bool {
        let now = timestamp::now_seconds();
        let start_time = types::get_start_time(voting);
        let end_time = types::get_end_time(voting);
        start_time > 0 && now >= start_time && now <= end_time
    }

    /// 获取剩余时间
    /// 
    /// @param voting 投票引用
    /// @return 剩余秒数（如果已过期返回0）
    public fun get_remaining_time(voting: &Voting): u64 {
        let now = timestamp::now_seconds();
        let end_time = types::get_end_time(voting);
        if (now >= end_time) {
            0
        } else {
            end_time - now
        }
    }

    // ==================== 选项验证 ====================

    /// 验证选项索引有效
    /// 
    /// @param voting 投票引用
    /// @param option_index 选项索引
    /// @throws E_INVALID_OPTION 如果索引无效
    public fun validate_option_index(voting: &Voting, option_index: u64) {
        let option_count = types::get_option_count(voting);
        assert!(option_index < option_count, E_INVALID_OPTION);
    }

    /// 验证选项数量有效
    /// 
    /// @param option_count 选项数量
    /// @throws E_INSUFFICIENT_OPTIONS 或 E_TOO_MANY_OPTIONS
    public fun validate_option_count(option_count: u64) {
        assert!(option_count >= types::min_options(), E_INSUFFICIENT_OPTIONS);
        assert!(option_count <= types::max_options(), E_TOO_MANY_OPTIONS);
    }

    /// 验证选项标题列表
    /// 
    /// @param titles 标题列表
    /// @throws 相关错误
    public fun validate_option_titles(titles: &vector<String>) {
        let len = vector::length(titles);
        validate_option_count(len);
        
        let i = 0;
        while (i < len) {
            let title = vector::borrow(titles, i);
            validate_option_title(title);
            i = i + 1;
        };
    }

    /// 验证单个选项标题
    /// 
    /// @param title 选项标题
    /// @throws E_INVALID_TITLE 如果标题无效
    public fun validate_option_title(title: &String) {
        let len = length(title);
        assert!(len > 0, E_INVALID_TITLE);
        assert!(len <= 100, E_INVALID_TITLE);
    }

    // ==================== 投票者验证 ====================

    /// 验证用户未投票
    /// 
    /// @param voting 投票引用
    /// @param voter_addr 投票者地址
    /// @throws E_ALREADY_VOTED 如果用户已投票
    public fun validate_not_voted(voting: &Voting, voter_addr: address) {
        assert!(!types::has_voted(voting, voter_addr), E_ALREADY_VOTED);
    }

    /// 验证用户已投票
    /// 
    /// @param voting 投票引用
    /// @param voter_addr 投票者地址
    /// @throws E_NOT_VOTED 如果用户未投票
    public fun validate_has_voted(voting: &Voting, voter_addr: address) {
        assert!(types::has_voted(voting, voter_addr), E_NOT_VOTED);
    }

    /// 验证用户可以投票
    /// 
    /// @param account 用户账户
    /// @param voting 投票引用
    /// @throws 相关错误
    public fun validate_can_vote(account: &signer, voting: &Voting) {
        // 验证投票状态
        validate_active_status(voting);
        validate_not_cancelled(voting);
        
        // 验证时间窗口
        validate_time_window(voting);
        
        // 验证用户未投票
        let voter_addr = signer::address_of(account);
        validate_not_voted(voting, voter_addr);
    }

    /// 验证用户可以修改投票
    /// 
    /// @param account 用户账户
    /// @param voting 投票引用
    /// @throws 相关错误
    public fun validate_can_revote(account: &signer, voting: &Voting) {
        // 验证允许重新投票
        assert!(types::is_revote_allowed(voting), E_UNAUTHORIZED);
        
        // 验证投票状态
        validate_active_status(voting);
        validate_not_cancelled(voting);
        
        // 验证时间窗口
        validate_time_window(voting);
        
        // 验证用户已投票
        let voter_addr = signer::address_of(account);
        validate_has_voted(voting, voter_addr);
    }

    /// 验证用户可以撤销投票
    /// 
    /// @param account 用户账户
    /// @param voting 投票引用
    /// @throws 相关错误
    public fun validate_can_unvote(account: &signer, voting: &Voting) {
        // 验证允许重新投票（撤销需要相同权限）
        assert!(types::is_revote_allowed(voting), E_UNAUTHORIZED);
        
        // 验证投票状态
        validate_active_status(voting);
        
        // 验证用户已投票
        let voter_addr = signer::address_of(account);
        validate_has_voted(voting, voter_addr);
    }

    // ==================== 标题和描述验证 ====================

    /// 验证投票标题
    /// 
    /// @param title 标题
    /// @throws E_INVALID_TITLE 如果标题无效
    public fun validate_title(title: &String) {
        let len = length(title);
        assert!(len >= types::min_title_length(), E_INVALID_TITLE);
        assert!(len <= types::max_title_length(), E_INVALID_TITLE);
    }

    /// 验证投票描述
    /// 
    /// @param description 描述
    /// @throws E_INVALID_DESCRIPTION 如果描述无效
    public fun validate_description(description: &String) {
        let len = length(description);
        assert!(len <= 1000, E_INVALID_DESCRIPTION); // 最多1000字符
    }

    /// 检查标题是否有效（不抛出错误）
    /// 
    /// @param title 标题
    /// @return 是否有效
    public fun is_valid_title(title: &String): bool {
        let len = length(title);
        len >= types::min_title_length() && len <= types::max_title_length()
    }

    /// 检查描述是否有效（不抛出错误）
    /// 
    /// @param description 描述
    /// @return 是否有效
    public fun is_valid_description(description: &String): bool {
        let len = length(description);
        len <= 1000
    }

    // ==================== 综合验证 ====================

    /// 验证创建投票的所有条件
    /// 
    /// @param title 标题
    /// @param description 描述
    /// @param option_titles 选项标题列表
    /// @param duration 持续时间
    /// @throws 相关错误
    public fun validate_create_voting(
        title: &String,
        description: &String,
        option_titles: &vector<String>,
        duration: u64
    ) {
        validate_title(title);
        validate_description(description);
        validate_option_titles(option_titles);
        validate_duration(duration);
    }

    /// 验证修改投票的所有条件
    /// 
    /// @param account 用户账户
    /// @param voting 投票引用
    /// @throws 相关错误
    public fun validate_modify_voting(account: &signer, voting: &Voting) {
        validate_creator(account, voting);
        validate_pending_status(voting);
        validate_not_cancelled(voting);
    }

    /// 验证删除投票的条件
    /// 
    /// @param account 用户账户
    /// @param voting 投票引用
    /// @throws 相关错误
    public fun validate_delete_voting(account: &signer, voting: &Voting) {
        validate_creator(account, voting);
        // 可以删除任何状态的投票，但建议只删除已结束或已取消的
    }

    /// 验证批量操作的有效性
    /// 
    /// @param addresses 地址列表
    /// @param option_indices 选项索引列表
    /// @throws E_INVALID_OPTION 如果参数不匹配
    public fun validate_batch_operation(
        addresses: &vector<address>,
        option_indices: &vector<u64>
    ) {
        let addr_len = vector::length(addresses);
        let option_len = vector::length(option_indices);
        assert!(addr_len == option_len, E_INVALID_OPTION);
    }

    // ==================== 系统验证 ====================

    /// 验证系统健康状态
    /// 
    /// @return (是否健康, 状态消息)
    public fun check_system_health(): (bool, String) {
        // 检查时间戳服务是否可用
        let now = timestamp::now_seconds();
        if (now == 0) {
            return (false, utf8(b"Timestamp service unavailable"))
        };
        
        (true, utf8(b"System healthy"))
    }

    /// 验证投票完整性
    /// 
    /// @param voting 投票引用
    /// @return 是否有效
    public fun validate_voting_integrity(voting: &Voting): bool {
        // 检查选项数量
        let option_count = types::get_option_count(voting);
        if (option_count < types::min_options()) {
            return false
        };
        
        // 检查票数一致性
        let total_votes = types::get_total_votes(voting);
        let calculated_votes = 0u64;
        let i = 0;
        while (i < option_count) {
            let option = types::get_option(voting, i);
            calculated_votes = calculated_votes + types::get_option_vote_count(option);
            i = i + 1;
        };
        
        if (total_votes != calculated_votes) {
            return false
        };
        
        // 检查投票者数量
        let voter_count = types::get_voter_count(voting);
        if (voter_count > total_votes) {
            return false
        };
        
        true
    }

    // ==================== 辅助验证函数 ====================

    /// 获取验证结果摘要
    /// 
    /// @param voting 投票引用
    /// @return (是否有效, 错误列表)
    public fun get_validation_summary(voting: &Voting): (bool, vector<String>) {
        let errors = vector::empty<String>();
        let is_valid = true;
        
        // 检查选项数量
        let option_count = types::get_option_count(voting);
        if (option_count < types::min_options()) {
            vector::push_back(&mut errors, utf8(b"Insufficient options"));
            is_valid = false;
        };
        
        // 检查票数一致性
        if (!validate_voting_integrity(voting)) {
            vector::push_back(&mut errors, utf8(b"Vote count mismatch"));
            is_valid = false;
        };
        
        // 检查时间设置
        let start_time = types::get_start_time(voting);
        let end_time = types::get_end_time(voting);
        if (start_time > 0 && end_time <= start_time) {
            vector::push_back(&mut errors, utf8(b"Invalid time range"));
            is_valid = false;
        };
        
        (is_valid, errors)
    }

    /// 检查投票是否可以参与
    /// 
    /// @param voting 投票引用
    /// @param voter_addr 投票者地址
    /// @return (是否可以, 原因)
    public fun can_participate(voting: &Voting, voter_addr: address): (bool, String) {
        // 检查状态
        if (!types::is_active(voting)) {
            return (false, utf8(b"Voting is not active"))
        };
        
        // 检查时间
        if (!is_within_time_window(voting)) {
            return (false, utf8(b"Outside time window"))
        };
        
        // 检查是否已投票
        if (types::has_voted(voting, voter_addr)) {
            if (types::is_revote_allowed(voting)) {
                return (true, utf8(b"Can revote"))
            } else {
                return (false, utf8(b"Already voted"))
            }
        };
        
        (true, utf8(b"Can vote"))
    }
}
