/// 投票系统完整示例
/// 这是一个功能完整的链上投票系统，展示了所有核心概念
module voting_example::simple_voting {
    use std::signer;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_std::table::{Self, Table};
    use aptos_std::smart_table::{Self, SmartTable};

    // ==================== 错误码 ====================
    
    const ERROR_NOT_INITIALIZED: u64 = 1;
    /// 投票系统已经初始化
    const ERROR_ALREADY_INITIALIZED: u64 = 2;
    const ERROR_NOT_ADMIN: u64 = 3;
    /// 提案未找到
    const ERROR_PROPOSAL_NOT_FOUND: u64 = 4;
    /// 无效的投票时间段
    const ERROR_INVALID_VOTING_PERIOD: u64 = 5;
    /// 投票尚未开始
    const ERROR_VOTING_NOT_STARTED: u64 = 6;
    /// 投票已结束
    const ERROR_VOTING_ENDED: u64 = 7;
    /// 已经投过票
    const ERROR_ALREADY_VOTED: u64 = 8;
    /// 无效的投票类型
    const ERROR_INVALID_VOTE_TYPE: u64 = 9;
    const ERROR_PROPOSAL_NOT_PASSED: u64 = 10;
    const ERROR_ALREADY_EXECUTED: u64 = 11;
    const ERROR_NOT_EXECUTABLE: u64 = 12;
    const ERROR_QUORUM_NOT_REACHED: u64 = 13;

    // ==================== 常量 ====================
    
    // 提案状态
    const STATUS_PENDING: u8 = 0;      // 待定（等待投票开始）
    const STATUS_ACTIVE: u8 = 1;       // 活跃（投票中）
    const STATUS_SUCCEEDED: u8 = 2;    // 通过
    const STATUS_DEFEATED: u8 = 3;     // 否决
    const STATUS_EXECUTED: u8 = 4;     // 已执行

    // 投票类型
    const VOTE_NO: u8 = 0;             // 反对
    const VOTE_YES: u8 = 1;            // 赞成
    const VOTE_ABSTAIN: u8 = 2;        // 弃权

    // 时间常量（秒）
    const MIN_VOTING_PERIOD: u64 = 86400;        // 最小投票期：1 天
    const MAX_VOTING_PERIOD: u64 = 604800;       // 最大投票期：7 天
    const EXECUTION_DELAY: u64 = 172800;         // 执行延迟：2 天

    // ==================== 数据结构 ====================
    
    /// 提案结构
    struct Proposal has store, drop, copy {
        id: u64,
        title: String,
        description: String,
        proposer: address,
        created_at: u64,
        voting_start: u64,
        voting_end: u64,
        yes_votes: u64,
        no_votes: u64,
        abstain_votes: u64,
        status: u8,
        executable: bool,
        executed: bool,
    }

    /// 投票记录
    struct Vote has store, drop, copy {
        proposal_id: u64,
        voter: address,
        vote_type: u8,
        voting_power: u64,
        timestamp: u64,
    }

    /// 治理配置
    struct GovernanceConfig has key {
        admin: address,
        min_voting_period: u64,
        max_voting_period: u64,
        quorum_percentage: u64,        // 法定人数百分比（如 30 表示 30%）
        approval_threshold: u64,       // 通过阈值（如 50 表示 50%）
        total_voting_power: u64,       // 总投票权（简化：假设固定值）
    }

    /// 投票系统主结构
    struct VotingSystem has key {
        proposals: SmartTable<u64, Proposal>,
        votes: Table<u64, Table<address, Vote>>,  // 提案ID -> (地址 -> 投票)
        next_proposal_id: u64,
        total_proposals: u64,
        active_proposals: u64,
    }

    /// 事件
    struct ProposalCreatedEvent has drop, store {
        proposal_id: u64,
        proposer: address,
        title: String,
        voting_end: u64,
    }

    struct VoteCastEvent has drop, store {
        proposal_id: u64,
        voter: address,
        vote_type: u8,
        voting_power: u64,
    }

    struct ProposalExecutedEvent has drop, store {
        proposal_id: u64,
        executor: address,
        success: bool,
    }

    struct GovernanceEvents has key {
        proposal_created_events: EventHandle<ProposalCreatedEvent>,
        vote_cast_events: EventHandle<VoteCastEvent>,
        proposal_executed_events: EventHandle<ProposalExecutedEvent>,
    }

    // ==================== 初始化 ====================
    
    /// 初始化投票系统
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // 确保未初始化
        assert!(!exists<VotingSystem>(admin_addr), ERROR_ALREADY_INITIALIZED);
        
        // 创建治理配置
        move_to(admin, GovernanceConfig {
            admin: admin_addr,
            min_voting_period: MIN_VOTING_PERIOD,
            max_voting_period: MAX_VOTING_PERIOD,
            quorum_percentage: 30,         // 30% 法定人数
            approval_threshold: 50,        // 50% 通过阈值
            total_voting_power: 1000000,   // 假设总投票权为 100 万
        });

        // 创建投票系统
        move_to(admin, VotingSystem {
            proposals: smart_table::new(),
            votes: table::new(),
            next_proposal_id: 1,
            total_proposals: 0,
            active_proposals: 0,
        });

        // 创建事件句柄
        move_to(admin, GovernanceEvents {
            proposal_created_events: account::new_event_handle<ProposalCreatedEvent>(admin),
            vote_cast_events: account::new_event_handle<VoteCastEvent>(admin),
            proposal_executed_events: account::new_event_handle<ProposalExecutedEvent>(admin),
        });
    }

    // ==================== 提案管理 ====================
    
    /// 创建提案
    public entry fun create_proposal(
        proposer: &signer,
        title: vector<u8>,
        description: vector<u8>,
        voting_period: u64,  // 投票持续时间（秒）
        executable: bool,
    ) acquires VotingSystem, GovernanceConfig, GovernanceEvents {
        let proposer_addr = signer::address_of(proposer);
        assert_initialized();
        
        // 验证投票期限
        let config = borrow_global<GovernanceConfig>(@voting_example);
        assert!(
            voting_period >= config.min_voting_period && 
            voting_period <= config.max_voting_period,
            ERROR_INVALID_VOTING_PERIOD
        );

        let system = borrow_global_mut<VotingSystem>(@voting_example);
        let proposal_id = system.next_proposal_id;
        
        let now = timestamp::now_seconds();
        let voting_start = now;  // 立即开始投票（也可以设置延迟）
        let voting_end = now + voting_period;

        // 创建提案
        let proposal = Proposal {
            id: proposal_id,
            title: string::utf8(title),
            description: string::utf8(description),
            proposer: proposer_addr,
            created_at: now,
            voting_start,
            voting_end,
            yes_votes: 0,
            no_votes: 0,
            abstain_votes: 0,
            status: STATUS_ACTIVE,  // 直接进入活跃状态
            executable,
            executed: false,
        };

        // 存储提案
        smart_table::add(&mut system.proposals, proposal_id, proposal);
        
        // 初始化投票记录表
        table::add(&mut system.votes, proposal_id, table::new<address, Vote>());
        
        // 更新统计
        system.next_proposal_id = proposal_id + 1;
        system.total_proposals = system.total_proposals + 1;
        system.active_proposals = system.active_proposals + 1;

        // 发射事件
        let events = borrow_global_mut<GovernanceEvents>(@voting_example);
        event::emit_event(
            &mut events.proposal_created_events,
            ProposalCreatedEvent {
                proposal_id,
                proposer: proposer_addr,
                title: string::utf8(title),
                voting_end,
            }
        );
    }

    /// 投票
    public entry fun vote(
        voter: &signer,
        proposal_id: u64,
        vote_type: u8,  // 0=反对, 1=赞成, 2=弃权
    ) acquires VotingSystem, GovernanceEvents {
        let voter_addr = signer::address_of(voter);
        assert_initialized();

        // 验证投票类型
        assert!(vote_type <= VOTE_ABSTAIN, ERROR_INVALID_VOTE_TYPE);

        let system = borrow_global_mut<VotingSystem>(@voting_example);
        
        // 检查提案存在
        assert!(smart_table::contains(&system.proposals, proposal_id), ERROR_PROPOSAL_NOT_FOUND);
        
        let proposal = smart_table::borrow_mut(&mut system.proposals, proposal_id);
        
        // 检查投票时间
        let now = timestamp::now_seconds();
        assert!(now >= proposal.voting_start, ERROR_VOTING_NOT_STARTED);
        assert!(now < proposal.voting_end, ERROR_VOTING_ENDED);
        
        // 检查是否已投票
        let proposal_votes = table::borrow(&system.votes, proposal_id);
        assert!(!table::contains(proposal_votes, voter_addr), ERROR_ALREADY_VOTED);

        // 计算投票权重（简化版：每人 1 票）
        let voting_power = get_voting_power(voter_addr);

        // 记录投票
        let vote_record = Vote {
            proposal_id,
            voter: voter_addr,
            vote_type,
            voting_power,
            timestamp: now,
        };
        
        let proposal_votes_mut = table::borrow_mut(&mut system.votes, proposal_id);
        table::add(proposal_votes_mut, voter_addr, vote_record);

        // 更新提案统计
        if (vote_type == VOTE_YES) {
            proposal.yes_votes = proposal.yes_votes + voting_power;
        } else if (vote_type == VOTE_NO) {
            proposal.no_votes = proposal.no_votes + voting_power;
        } else {
            proposal.abstain_votes = proposal.abstain_votes + voting_power;
        };

        // 发射事件
        let events = borrow_global_mut<GovernanceEvents>(@voting_example);
        event::emit_event(
            &mut events.vote_cast_events,
            VoteCastEvent {
                proposal_id,
                voter: voter_addr,
                vote_type,
                voting_power,
            }
        );
    }

    /// 统计投票结果并更新状态
    public entry fun finalize_proposal(
        proposal_id: u64
    ) acquires VotingSystem, GovernanceConfig {
        assert_initialized();

        let system = borrow_global_mut<VotingSystem>(@voting_example);
        assert!(smart_table::contains(&system.proposals, proposal_id), ERROR_PROPOSAL_NOT_FOUND);
        
        let proposal = smart_table::borrow_mut(&mut system.proposals, proposal_id);
        
        // 检查投票已结束
        let now = timestamp::now_seconds();
        assert!(now >= proposal.voting_end, ERROR_VOTING_NOT_STARTED);
        
        // 检查尚未统计
        assert!(proposal.status == STATUS_ACTIVE, ERROR_ALREADY_EXECUTED);

        let config = borrow_global<GovernanceConfig>(@voting_example);
        
        // 计算总票数
        let total_votes = proposal.yes_votes + proposal.no_votes + proposal.abstain_votes;
        
        // 检查法定人数
        let quorum_required = (config.total_voting_power * config.quorum_percentage) / 100;
        let quorum_reached = total_votes >= quorum_required;

        // 判断是否通过
        let approval_required = (total_votes * config.approval_threshold) / 100;
        let approved = proposal.yes_votes >= approval_required;

        // 更新状态
        if (quorum_reached && approved) {
            proposal.status = STATUS_SUCCEEDED;
        } else {
            proposal.status = STATUS_DEFEATED;
        };

        // 更新活跃提案数
        system.active_proposals = system.active_proposals - 1;
    }

    /// 执行通过的提案
    public entry fun execute_proposal(
        executor: &signer,
        proposal_id: u64
    ) acquires VotingSystem, GovernanceEvents {
        assert_initialized();
        let executor_addr = signer::address_of(executor);

        let system = borrow_global_mut<VotingSystem>(@voting_example);
        assert!(smart_table::contains(&system.proposals, proposal_id), ERROR_PROPOSAL_NOT_FOUND);
        
        let proposal = smart_table::borrow_mut(&mut system.proposals, proposal_id);
        
        // 验证提案已通过
        assert!(proposal.status == STATUS_SUCCEEDED, ERROR_PROPOSAL_NOT_PASSED);
        
        // 验证可执行
        assert!(proposal.executable, ERROR_NOT_EXECUTABLE);
        
        // 验证未执行
        assert!(!proposal.executed, ERROR_ALREADY_EXECUTED);
        
        // 验证执行延迟
        let now = timestamp::now_seconds();
        assert!(now >= proposal.voting_end + EXECUTION_DELAY, ERROR_VOTING_NOT_STARTED);

        // 执行提案逻辑（这里简化，实际应用中需要根据提案类型执行不同操作）
        // execute_proposal_action(proposal);

        // 标记为已执行
        proposal.executed = true;
        proposal.status = STATUS_EXECUTED;

        // 发射事件
        let events = borrow_global_mut<GovernanceEvents>(@voting_example);
        event::emit_event(
            &mut events.proposal_executed_events,
            ProposalExecutedEvent {
                proposal_id,
                executor: executor_addr,
                success: true,
            }
        );
    }

    // ==================== 查询函数 ====================
    
    /// 获取提案信息
    #[view]
    public fun get_proposal(proposal_id: u64): Proposal acquires VotingSystem {
        assert_initialized();
        let system = borrow_global<VotingSystem>(@voting_example);
        assert!(smart_table::contains(&system.proposals, proposal_id), ERROR_PROPOSAL_NOT_FOUND);
        *smart_table::borrow(&system.proposals, proposal_id)
    }

    /// 检查用户是否已投票
    #[view]
    public fun has_voted(proposal_id: u64, voter: address): bool acquires VotingSystem {
        if (!exists<VotingSystem>(@voting_example)) {
            return false
        };
        
        let system = borrow_global<VotingSystem>(@voting_example);
        if (!table::contains(&system.votes, proposal_id)) {
            return false
        };
        
        let proposal_votes = table::borrow(&system.votes, proposal_id);
        table::contains(proposal_votes, voter)
    }

    /// 获取用户的投票记录
    #[view]
    public fun get_vote(proposal_id: u64, voter: address): Option<Vote> acquires VotingSystem {
        if (!has_voted(proposal_id, voter)) {
            return option::none()
        };
        
        let system = borrow_global<VotingSystem>(@voting_example);
        let proposal_votes = table::borrow(&system.votes, proposal_id);
        let vote = table::borrow(proposal_votes, voter);
        option::some(*vote)
    }

    /// 获取所有提案 ID
    #[view]
    public fun get_all_proposal_ids(): vector<u64> acquires VotingSystem {
        assert_initialized();
        let system = borrow_global<VotingSystem>(@voting_example);
        smart_table::keys(&system.proposals)
    }

    /// 获取提案总数
    #[view]
    public fun get_proposal_count(): u64 acquires VotingSystem {
        assert_initialized();
        let system = borrow_global<VotingSystem>(@voting_example);
        system.total_proposals
    }

    /// 获取活跃提案数
    #[view]
    public fun get_active_proposal_count(): u64 acquires VotingSystem {
        assert_initialized();
        let system = borrow_global<VotingSystem>(@voting_example);
        system.active_proposals
    }

    /// 获取治理配置
    #[view]
    public fun get_config(): (address, u64, u64, u64, u64) acquires GovernanceConfig {
        assert_initialized();
        let config = borrow_global<GovernanceConfig>(@voting_example);
        (
            config.admin,
            config.quorum_percentage,
            config.approval_threshold,
            config.min_voting_period,
            config.max_voting_period
        )
    }

    // ==================== 辅助函数 ====================
    
    /// 检查是否已初始化
    fun assert_initialized() {
        assert!(exists<VotingSystem>(@voting_example), ERROR_NOT_INITIALIZED);
    }

    /// 检查是否为管理员
    fun assert_admin(caller: address) acquires GovernanceConfig {
        let config = borrow_global<GovernanceConfig>(@voting_example);
        assert!(caller == config.admin, ERROR_NOT_ADMIN);
    }

    /// 获取投票权重（简化版：每人 1 票）
    fun get_voting_power(_voter: address): u64 {
        1  // 在实际应用中，可以根据代币余额计算
    }

    // ==================== 管理函数 ====================
    
    /// 更新治理参数（仅管理员）
    public entry fun update_governance_params(
        admin: &signer,
        quorum_percentage: u64,
        approval_threshold: u64,
    ) acquires GovernanceConfig {
        let admin_addr = signer::address_of(admin);
        assert_initialized();
        assert_admin(admin_addr);

        let config = borrow_global_mut<GovernanceConfig>(@voting_example);
        config.quorum_percentage = quorum_percentage;
        config.approval_threshold = approval_threshold;
    }

    // ==================== 测试辅助函数 ====================
    
    #[test_only]
    public fun initialize_for_test(admin: &signer) {
        initialize(admin);
    }

    #[test_only]
    public fun create_test_proposal(
        proposer: &signer,
        voting_period: u64
    ) acquires VotingSystem, GovernanceConfig, GovernanceEvents {
        create_proposal(
            proposer,
            b"Test Proposal",
            b"This is a test proposal",
            voting_period,
            false
        );
    }
}
