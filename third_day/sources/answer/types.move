/// 投票系统核心数据结构模块
/// 
/// 本模块定义了投票系统所需的所有核心数据结构，包括：
/// - VotingStatus: 投票状态枚举
/// - VotingOption: 投票选项结构
/// - VoterInfo: 投票者信息结构
/// - Voting: 完整投票结构
/// - VotingConfig: 投票配置结构
/// - VotingResult: 投票结果结构
/// - VotingStats: 投票统计结构
module voting::types {
    use std::string::String;
    use std::vector;
    use aptos_framework::timestamp;

    // ==================== 错误码定义 ====================
    
    /// 无效的投票状态
    const E_INVALID_STATUS: u64 = 1001;
    /// 无效的选项索引
    const E_INVALID_OPTION_INDEX: u64 = 1002;
    /// 投票已存在
    const E_VOTING_ALREADY_EXISTS: u64 = 1003;
    /// 投票不存在
    const E_VOTING_NOT_EXISTS: u64 = 1004;

    // ==================== 投票状态常量 ====================
    
    /// 待定状态 - 投票已创建但未开始
    const STATUS_PENDING: u8 = 0;
    /// 活跃状态 - 投票正在进行中
    const STATUS_ACTIVE: u8 = 1;
    /// 结束状态 - 投票已结束
    const STATUS_ENDED: u8 = 2;
    /// 取消状态 - 投票已被取消
    const STATUS_CANCELLED: u8 = 3;

    // ==================== 投票配置常量 ====================
    
    /// 最小选项数量
    const MIN_OPTIONS: u64 = 2;
    /// 最大选项数量
    const MAX_OPTIONS: u64 = 100;
    /// 最小标题长度
    const MIN_TITLE_LENGTH: u64 = 1;
    /// 最大标题长度
    const MAX_TITLE_LENGTH: u64 = 200;
    /// 默认投票持续时间（秒）
    const DEFAULT_DURATION: u64 = 86400; // 24小时

    // ==================== 核心数据结构 ====================

    /// 投票选项结构
    /// 
    /// 表示单个投票选项的完整信息
    struct VotingOption has store, copy, drop {
        /// 选项ID
        id: u64,
        /// 选项标题
        title: String,
        /// 选项描述
        description: String,
        /// 当前票数
        vote_count: u64,
    }

    /// 投票者信息结构
    /// 
    /// 记录单个投票者的投票信息
    struct VoterInfo has store, copy, drop {
        /// 投票者地址
        voter_address: address,
        /// 投票时间戳
        voted_at: u64,
        /// 选择的选项ID
        option_id: u64,
    }

    /// 完整投票结构
    /// 
    /// 包含投票的所有信息和状态
    struct Voting has key, store {
        /// 投票ID
        id: u64,
        /// 投票标题
        title: String,
        /// 投票描述
        description: String,
        /// 创建者地址
        creator: address,
        /// 创建时间戳
        created_at: u64,
        /// 开始时间戳
        start_time: u64,
        /// 结束时间戳
        end_time: u64,
        /// 当前状态
        status: u8,
        /// 投票选项列表
        options: vector<VotingOption>,
        /// 投票者信息列表
        voters: vector<VoterInfo>,
        /// 总投票数
        total_votes: u64,
        /// 是否允许修改投票
        allow_revote: bool,
        /// 是否公开投票者
        public_voters: bool,
    }

    /// 投票配置结构
    /// 
    /// 用于创建新投票的配置信息
    struct VotingConfig has copy, drop {
        /// 投票标题
        title: String,
        /// 投票描述
        description: String,
        /// 投票持续时间（秒）
        duration: u64,
        /// 选项标题列表
        option_titles: vector<String>,
        /// 选项描述列表
        option_descriptions: vector<String>,
        /// 是否允许修改投票
        allow_revote: bool,
        /// 是否公开投票者
        public_voters: bool,
    }

    /// 投票结果结构
    /// 
    /// 包含投票的统计结果
    struct VotingResult has copy, drop {
        /// 投票ID
        voting_id: u64,
        /// 获胜选项ID
        winning_option_id: u64,
        /// 获胜选项标题
        winning_title: String,
        /// 获胜选项票数
        winning_votes: u64,
        /// 总投票数
        total_votes: u64,
        /// 是否平局
        is_tie: bool,
        /// 平局选项ID列表
        tied_option_ids: vector<u64>,
        /// 投票是否有效
        is_valid: bool,
    }

    /// 投票统计结构
    /// 
    /// 提供详细的投票数据分析
    struct VotingStats has copy, drop {
        /// 总选项数
        total_options: u64,
        /// 总投票数
        total_votes: u64,
        /// 参与投票的人数
        total_voters: u64,
        /// 平均每选项票数
        average_votes_per_option: u64,
        /// 最高票数
        max_votes: u64,
        /// 最低票数
        min_votes: u64,
        /// 参与率（如果有总人数限制）
        participation_rate: u64,
    }

    /// 全局投票系统状态
    /// 
    /// 管理所有投票的全局信息
    public struct VotingSystem has key {
        /// 下一个投票ID
        next_voting_id: u64,
        /// 总投票数
        total_votings: u64,
        /// 活跃投票数
        active_votings: u64,
        /// 总参与者数
        total_participants: u64,
    }

    // ==================== 构造函数 ====================

    /// 创建新的投票选项
    /// 
    /// @param id 选项ID
    /// @param title 选项标题
    /// @param description 选项描述
    /// @return 新创建的投票选项
    public fun new_voting_option(
        id: u64,
        title: String,
        description: String
    ): VotingOption {
        VotingOption {
            id,
            title,
            description,
            vote_count: 0,
        }
    }

    /// 创建新的投票者信息
    /// 
    /// @param voter_address 投票者地址
    /// @param option_id 选择的选项ID
    /// @return 新创建的投票者信息
    public fun new_voter_info(
        voter_address: address,
        option_id: u64
    ): VoterInfo {
        VoterInfo {
            voter_address,
            voted_at: timestamp::now_seconds(),
            option_id,
        }
    }

    /// 创建新的投票
    /// 
    /// @param id 投票ID
    /// @param title 投票标题
    /// @param description 投票描述
    /// @param creator 创建者地址
    /// @param duration 持续时间
    /// @param options 选项列表
    /// @param allow_revote 是否允许修改投票
    /// @param public_voters 是否公开投票者
    /// @return 新创建的投票
    public fun new_voting(
        id: u64,
        title: String,
        description: String,
        creator: address,
        duration: u64,
        options: vector<VotingOption>,
        allow_revote: bool,
        public_voters: bool
    ): Voting {
        let now = timestamp::now_seconds();
        Voting {
            id,
            title,
            description,
            creator,
            created_at: now,
            start_time: 0,
            end_time: now + duration,
            status: STATUS_PENDING,
            options,
            voters: vector::empty(),
            total_votes: 0,
            allow_revote,
            public_voters,
        }
    }

    /// 创建投票配置
    /// 
    /// @param title 标题
    /// @param description 描述
    /// @param duration 持续时间
    /// @param option_titles 选项标题列表
    /// @param option_descriptions 选项描述列表
    /// @param allow_revote 是否允许重新投票
    /// @param public_voters 是否公开投票者
    /// @return 投票配置
    public fun new_voting_config(
        title: String,
        description: String,
        duration: u64,
        option_titles: vector<String>,
        option_descriptions: vector<String>,
        allow_revote: bool,
        public_voters: bool
    ): VotingConfig {
        VotingConfig {
            title,
            description,
            duration,
            option_titles,
            option_descriptions,
            allow_revote,
            public_voters,
        }
    }

    // ==================== Getter函数 ====================

    /// 获取投票ID
    public fun get_voting_id(voting: &Voting): u64 {
        voting.id
    }

    /// 获取投票标题
    public fun get_voting_title(voting: &Voting): String {
        voting.title
    }

    /// 获取投票描述
    public fun get_voting_description(voting: &Voting): String {
        voting.description
    }

    /// 获取创建者地址
    public fun get_creator(voting: &Voting): address {
        voting.creator
    }

    /// 获取创建时间
    public fun get_created_at(voting: &Voting): u64 {
        voting.created_at
    }

    /// 获取开始时间
    public fun get_start_time(voting: &Voting): u64 {
        voting.start_time
    }

    /// 获取结束时间
    public fun get_end_time(voting: &Voting): u64 {
        voting.end_time
    }

    /// 获取投票状态
    public fun get_status(voting: &Voting): u8 {
        voting.status
    }

    /// 获取总投票数
    public fun get_total_votes(voting: &Voting): u64 {
        voting.total_votes
    }

    /// 获取是否允许重新投票
    public fun is_revote_allowed(voting: &Voting): bool {
        voting.allow_revote
    }

    /// 获取是否公开投票者
    public fun is_public_voters(voting: &Voting): bool {
        voting.public_voters
    }

    /// 获取选项数量
    public fun get_option_count(voting: &Voting): u64 {
        vector::length(&voting.options)
    }

    /// 获取投票者数量
    public fun get_voter_count(voting: &Voting): u64 {
        vector::length(&voting.voters)
    }

    /// 获取选项引用
    public fun get_option(voting: &Voting, index: u64): &VotingOption {
        vector::borrow(&voting.options, index)
    }

    /// 获取选项可变引用
    public fun get_option_mut(voting: &mut Voting, index: u64): &mut VotingOption {
        vector::borrow_mut(&mut voting.options, index)
    }

    /// 获取选项ID
    public fun get_option_id(option: &VotingOption): u64 {
        option.id
    }

    /// 获取选项标题
    public fun get_option_title(option: &VotingOption): String {
        option.title
    }

    /// 获取选项描述
    public fun get_option_description(option: &VotingOption): String {
        option.description
    }

    /// 获取选项票数
    public fun get_option_vote_count(option: &VotingOption): u64 {
        option.vote_count
    }

    /// 获取投票者信息
    public fun get_voter_info(voting: &Voting, index: u64): &VoterInfo {
        vector::borrow(&voting.voters, index)
    }

    /// 获取投票者地址
    public fun get_voter_address(voter: &VoterInfo): address {
        voter.voter_address
    }

    /// 获取投票时间
    public fun get_voted_at(voter: &VoterInfo): u64 {
        voter.voted_at
    }

    /// 获取投票者选择的选项ID
    public fun get_voter_option_id(voter: &VoterInfo): u64 {
        voter.option_id
    }

    // ==================== Setter函数 ====================

    /// 设置投票标题
    public fun set_title(voting: &mut Voting, title: String) {
        voting.title = title;
    }

    /// 设置投票描述
    public fun set_description(voting: &mut Voting, description: String) {
        voting.description = description;
    }

    /// 设置开始时间
    public fun set_start_time(voting: &mut Voting, start_time: u64) {
        voting.start_time = start_time;
    }

    /// 设置结束时间
    public fun set_end_time(voting: &mut Voting, end_time: u64) {
        voting.end_time = end_time;
    }

    /// 设置投票状态
    public fun set_status(voting: &mut Voting, status: u8) {
        assert!(status <= STATUS_CANCELLED, E_INVALID_STATUS);
        voting.status = status;
    }

    /// 增加选项票数
    public fun increment_option_votes(option: &mut VotingOption) {
        option.vote_count = option.vote_count + 1;
    }

    /// 减少选项票数
    public fun decrement_option_votes(option: &mut VotingOption) {
        if (option.vote_count > 0) {
            option.vote_count = option.vote_count - 1;
        };
    }

    /// 增加总投票数
    public fun increment_total_votes(voting: &mut Voting) {
        voting.total_votes = voting.total_votes + 1;
    }

    /// 减少总投票数
    public fun decrement_total_votes(voting: &mut Voting) {
        if (voting.total_votes > 0) {
            voting.total_votes = voting.total_votes - 1;
        };
    }

    /// 添加投票者
    public fun add_voter(voting: &mut Voting, voter: VoterInfo) {
        vector::push_back(&mut voting.voters, voter);
    }

    /// 添加选项
    public fun add_option(voting: &mut Voting, option: VotingOption) {
        vector::push_back(&mut voting.options, option);
    }

    // ==================== 状态检查函数 ====================

    /// 检查是否为待定状态
    public fun is_pending(voting: &Voting): bool {
        voting.status == STATUS_PENDING
    }

    /// 检查是否为活跃状态
    public fun is_active(voting: &Voting): bool {
        voting.status == STATUS_ACTIVE
    }

    /// 检查是否为结束状态
    public fun is_ended(voting: &Voting): bool {
        voting.status == STATUS_ENDED
    }

    /// 检查是否为取消状态
    public fun is_cancelled(voting: &Voting): bool {
        voting.status == STATUS_CANCELLED
    }

    /// 检查投票是否已过期
    public fun is_expired(voting: &Voting): bool {
        timestamp::now_seconds() > voting.end_time
    }

    /// 检查用户是否已投票
    public fun has_voted(voting: &Voting, voter_address: address): bool {
        let len = vector::length(&voting.voters);
        let i = 0;
        while (i < len) {
            let voter = vector::borrow(&voting.voters, i);
            if (voter.voter_address == voter_address) {
                return true
            };
            i = i + 1;
        };
        false
    }

    // ==================== 状态常量访问器 ====================

    /// 获取待定状态常量
    public fun status_pending(): u8 { STATUS_PENDING }

    /// 获取活跃状态常量
    public fun status_active(): u8 { STATUS_ACTIVE }

    /// 获取结束状态常量
    public fun status_ended(): u8 { STATUS_ENDED }

    /// 获取取消状态常量
    public fun status_cancelled(): u8 { STATUS_CANCELLED }

    /// 获取最小选项数
    public fun min_options(): u64 { MIN_OPTIONS }

    /// 获取最大选项数
    public fun max_options(): u64 { MAX_OPTIONS }

    /// 获取最小标题长度
    public fun min_title_length(): u64 { MIN_TITLE_LENGTH }

    /// 获取最大标题长度
    public fun max_title_length(): u64 { MAX_TITLE_LENGTH }

    /// 获取默认持续时间
    public fun default_duration(): u64 { DEFAULT_DURATION }

    // ==================== 辅助函数 ====================

    /// 查找用户投票的选项ID
    /// 
    /// @param voting 投票引用
    /// @param voter_address 投票者地址
    /// @return (是否找到, 选项ID)
    public fun find_voter_option(voting: &Voting, voter_address: address): (bool, u64) {
        let len = vector::length(&voting.voters);
        let i = 0;
        while (i < len) {
            let voter = vector::borrow(&voting.voters, i);
            if (voter.voter_address == voter_address) {
                return (true, voter.option_id)
            };
            i = i + 1;
        };
        (false, 0)
    }

    /// 获取领先的选项ID
    /// 
    /// @param voting 投票引用
    /// @return 领先选项的ID
    public fun get_leading_option_id(voting: &Voting): u64 {
        let max_votes = 0;
        let leading_id = 0;
        let len = vector::length(&voting.options);
        let i = 0;
        
        while (i < len) {
            let option = vector::borrow(&voting.options, i);
            if (option.vote_count > max_votes) {
                max_votes = option.vote_count;
                leading_id = option.id;
            };
            i = i + 1;
        };
        
        leading_id
    }

    /// 检查是否有平局
    /// 
    /// @param voting 投票引用
    /// @return 是否存在平局
    public fun has_tie(voting: &Voting): bool {
        let max_votes = 0;
        let max_count = 0;
        let len = vector::length(&voting.options);
        let i = 0;
        
        // 找到最高票数
        while (i < len) {
            let option = vector::borrow(&voting.options, i);
            if (option.vote_count > max_votes) {
                max_votes = option.vote_count;
                max_count = 1;
            } else if (option.vote_count == max_votes && max_votes > 0) {
                max_count = max_count + 1;
            };
            i = i + 1;
        };
        
        max_count > 1
    }

    /// 创建投票结果
    /// 
    /// @param voting 投票引用
    /// @return 投票结果结构
    public fun create_voting_result(voting: &Voting): VotingResult {
        let leading_id = get_leading_option_id(voting);
        let is_tie = has_tie(voting);
        let tied_ids = vector::empty<u64>();
        
        if (is_tie) {
            let max_votes = 0;
            let len = vector::length(&voting.options);
            let i = 0;
            
            // 找到最高票数
            while (i < len) {
                let option = vector::borrow(&voting.options, i);
                if (option.vote_count > max_votes) {
                    max_votes = option.vote_count;
                };
                i = i + 1;
            };
            
            // 收集所有平局的选项
            i = 0;
            while (i < len) {
                let option = vector::borrow(&voting.options, i);
                if (option.vote_count == max_votes) {
                    vector::push_back(&mut tied_ids, option.id);
                };
                i = i + 1;
            };
        };
        
        let winning_option = vector::borrow(&voting.options, leading_id);
        
        VotingResult {
            voting_id: voting.id,
            winning_option_id: leading_id,
            winning_title: winning_option.title,
            winning_votes: winning_option.vote_count,
            total_votes: voting.total_votes,
            is_tie,
            tied_option_ids: tied_ids,
            is_valid: voting.total_votes > 0,
        }
    }

    /// 创建投票统计
    /// 
    /// @param voting 投票引用
    /// @return 投票统计结构
    public fun create_voting_stats(voting: &Voting): VotingStats {
        let option_count = vector::length(&voting.options);
        let mut_max_votes = 0;
        let mut_min_votes = 0;
        
        if (option_count > 0) {
            let first_option = vector::borrow(&voting.options, 0);
            mut_min_votes = first_option.vote_count;
            
            let i = 0;
            while (i < option_count) {
                let option = vector::borrow(&voting.options, i);
                if (option.vote_count > mut_max_votes) {
                    mut_max_votes = option.vote_count;
                };
                if (option.vote_count < mut_min_votes) {
                    mut_min_votes = option.vote_count;
                };
                i = i + 1;
            };
        };
        
        let avg_votes = if (option_count > 0) {
            voting.total_votes / option_count
        } else {
            0
        };
        
        VotingStats {
            total_options: option_count,
            total_votes: voting.total_votes,
            total_voters: vector::length(&voting.voters),
            average_votes_per_option: avg_votes,
            max_votes: mut_max_votes,
            min_votes: mut_min_votes,
            participation_rate: 0, // 需要外部计算
        }
    }
}
