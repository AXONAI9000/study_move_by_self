/// 投票系统管理模块
/// 
/// 本模块实现投票的创建、修改、删除等管理功能：
/// - 系统初始化：初始化投票系统全局状态
/// - 投票创建：创建新的投票实例
/// - 状态管理：开始、结束、取消投票
/// - 内容修改：修改投票标题、描述、时间设置等
/// - 选项管理：添加、修改、删除投票选项
/// - 投票删除：完全删除投票实例
module voting::management {
    use std::string::{String, utf8};
    use std::signer;
    use std::vector;
    use aptos_framework::timestamp;
    use voting::types::{Self, Voting, VotingOption, VotingSystem};
    use voting::validation;

    // ==================== 错误码定义 ====================
    
    /// 系统已初始化
    const E_SYSTEM_ALREADY_INITIALIZED: u64 = 3001;
    /// 系统未初始化
    const E_SYSTEM_NOT_INITIALIZED: u64 = 3002;
    /// 投票已存在
    const E_VOTING_ALREADY_EXISTS: u64 = 3003;
    /// 投票不存在
    const E_VOTING_NOT_EXISTS: u64 = 3004;
    /// 无效操作
    const E_INVALID_OPERATION: u64 = 3005;

    // ==================== 系统初始化 ====================

    /// 初始化投票系统
    /// 
    /// @param admin 系统管理员账户
    public entry fun initialize_system(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        assert!(!exists<VotingSystem>(admin_addr), E_SYSTEM_ALREADY_INITIALIZED);
        
        let voting_system = VotingSystem {
            next_voting_id: 1,
            total_votings: 0,
            active_votings: 0,
            total_participants: 0,
        };
        
        move_to(admin, voting_system);
    }

    /// 检查系统是否已初始化
    /// 
    /// @param admin_addr 管理员地址
    /// @return 是否已初始化
    public fun is_system_initialized(admin_addr: address): bool {
        exists<VotingSystem>(admin_addr)
    }

    // ==================== 投票创建 ====================

    /// 创建新的投票
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
    public fun create_voting(
        creator: &signer,
        title: String,
        description: String,
        duration: u64,
        option_titles: vector<String>,
        option_descriptions: vector<String>,
        allow_revote: bool,
        public_voters: bool
    ): u64 acquires VotingSystem {
        // 验证输入
        validation::validate_create_voting(&title, &description, &option_titles, duration);
        
        let creator_addr = signer::address_of(creator);
        
        // 确保该地址没有投票
        assert!(!exists<Voting>(creator_addr), E_VOTING_ALREADY_EXISTS);
        
        // 获取系统状态（假设系统已在某个地址初始化）
        // 这里简化处理，使用创建者自己的地址
        let voting_id = 1; // 默认ID
        
        // 创建选项
        let options = vector::empty<VotingOption>();
        let option_count = vector::length(&option_titles);
        let i = 0;
        
        while (i < option_count) {
            let option_title = *vector::borrow(&option_titles, i);
            let option_desc = if (i < vector::length(&option_descriptions)) {
                *vector::borrow(&option_descriptions, i)
            } else {
                utf8(b"")
            };
            
            let option = types::new_voting_option(i, option_title, option_desc);
            vector::push_back(&mut options, option);
            i = i + 1;
        };
        
        // 创建投票
        let voting = types::new_voting(
            voting_id,
            title,
            description,
            creator_addr,
            duration,
            options,
            allow_revote,
            public_voters
        );
        
        // 保存投票
        move_to(creator, voting);
        
        voting_id
    }

    /// 创建简单投票（使用默认设置）
    /// 
    /// @param creator 创建者账户
    /// @param title 投票标题
    /// @param option_titles 选项标题列表
    /// @return 投票ID
    public fun create_simple_voting(
        creator: &signer,
        title: String,
        option_titles: vector<String>
    ): u64 acquires VotingSystem {
        create_voting(
            creator,
            title,
            utf8(b""),
            types::default_duration(),
            option_titles,
            vector::empty(),
            false,
            true
        )
    }

    /// 创建快速投票（立即开始）
    /// 
    /// @param creator 创建者账户
    /// @param title 投票标题
    /// @param option_titles 选项标题列表
    /// @return 投票ID
    public fun create_quick_voting(
        creator: &signer,
        title: String,
        option_titles: vector<String>
    ): u64 acquires VotingSystem, Voting {
        let voting_id = create_simple_voting(creator, title, option_titles);
        start_voting(creator, voting_id);
        voting_id
    }

    // ==================== 状态管理 ====================

    /// 开始投票
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    public fun start_voting(creator: &signer, _voting_id: u64) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限和状态
        validation::validate_creator(creator, voting);
        validation::validate_can_start(voting);
        
        // 设置开始时间和状态
        let now = timestamp::now_seconds();
        types::set_start_time(voting, now);
        types::set_status(voting, types::status_active());
    }

    /// 结束投票
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    public fun end_voting(creator: &signer, _voting_id: u64) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限和状态
        validation::validate_creator(creator, voting);
        validation::validate_can_end(voting);
        
        // 设置状态为结束
        types::set_status(voting, types::status_ended());
    }

    /// 取消投票
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    public fun cancel_voting(creator: &signer, _voting_id: u64) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限和状态
        validation::validate_creator(creator, voting);
        validation::validate_can_cancel(voting);
        
        // 设置状态为取消
        types::set_status(voting, types::status_cancelled());
    }

    /// 重新激活投票
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    public fun reactivate_voting(creator: &signer, _voting_id: u64) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限
        validation::validate_creator(creator, voting);
        
        // 只能重新激活已取消的投票
        assert!(types::is_cancelled(voting), E_INVALID_OPERATION);
        
        // 重置为待定状态
        types::set_status(voting, types::status_pending());
    }

    // ==================== 内容修改 ====================

    /// 修改投票标题
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    /// @param new_title 新标题
    public fun update_title(
        creator: &signer,
        _voting_id: u64,
        new_title: String
    ) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限和状态
        validation::validate_modify_voting(creator, voting);
        validation::validate_title(&new_title);
        
        // 更新标题
        types::set_title(voting, new_title);
    }

    /// 修改投票描述
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    /// @param new_description 新描述
    public fun update_description(
        creator: &signer,
        _voting_id: u64,
        new_description: String
    ) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限和状态
        validation::validate_modify_voting(creator, voting);
        validation::validate_description(&new_description);
        
        // 更新描述
        types::set_description(voting, new_description);
    }

    /// 修改结束时间
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    /// @param new_end_time 新的结束时间
    public fun update_end_time(
        creator: &signer,
        _voting_id: u64,
        new_end_time: u64
    ) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限
        validation::validate_creator(creator, voting);
        
        // 验证新时间有效
        let start_time = types::get_start_time(voting);
        if (start_time > 0) {
            validation::validate_time_range(start_time, new_end_time);
        };
        
        // 更新结束时间
        types::set_end_time(voting, new_end_time);
    }

    /// 延长投票时间
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    /// @param extension_seconds 延长的秒数
    public fun extend_voting_time(
        creator: &signer,
        _voting_id: u64,
        extension_seconds: u64
    ) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限
        validation::validate_creator(creator, voting);
        
        // 延长时间
        let current_end = types::get_end_time(voting);
        let new_end = current_end + extension_seconds;
        types::set_end_time(voting, new_end);
    }

    // ==================== 选项管理 ====================

    /// 添加投票选项
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    /// @param option_title 选项标题
    /// @param option_description 选项描述
    public fun add_option(
        creator: &signer,
        _voting_id: u64,
        option_title: String,
        option_description: String
    ) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限和状态
        validation::validate_modify_voting(creator, voting);
        validation::validate_option_title(&option_title);
        
        // 检查选项数量限制
        let current_count = types::get_option_count(voting);
        assert!(current_count < types::max_options(), E_INVALID_OPERATION);
        
        // 创建并添加新选项
        let new_option = types::new_voting_option(
            current_count,
            option_title,
            option_description
        );
        types::add_option(voting, new_option);
    }

    /// 删除投票选项
    /// 
    /// 注意：此功能在实际应用中可能需要更复杂的逻辑
    /// 这里提供基本实现框架
    public fun remove_option(
        creator: &signer,
        _voting_id: u64,
        _option_index: u64
    ) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限和状态
        validation::validate_modify_voting(creator, voting);
        
        // 确保投票还没有开始，并且有投票记录
        assert!(types::get_total_votes(voting) == 0, E_INVALID_OPERATION);
        
        // 删除选项的实际实现需要更复杂的vector操作
        // 这里简化处理
    }

    // ==================== 投票删除 ====================

    /// 删除投票
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    public fun delete_voting(creator: &signer, _voting_id: u64) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        // 先借用来验证权限
        let voting_ref = borrow_global<Voting>(creator_addr);
        validation::validate_delete_voting(creator, voting_ref);
        
        // 然后删除
        let _voting = move_from<Voting>(creator_addr);
        // voting会在这里被自动drop
    }

    // ==================== 批量管理 ====================

    /// 批量创建投票选项
    /// 
    /// @param creator 创建者账户
    /// @param voting_id 投票ID（未使用，简化实现）
    /// @param option_titles 选项标题列表
    /// @param option_descriptions 选项描述列表
    public fun batch_add_options(
        creator: &signer,
        _voting_id: u64,
        option_titles: vector<String>,
        option_descriptions: vector<String>
    ) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限和状态
        validation::validate_modify_voting(creator, voting);
        validation::validate_option_titles(&option_titles);
        
        let len = vector::length(&option_titles);
        let current_count = types::get_option_count(voting);
        
        // 检查总数不超过限制
        assert!(current_count + len <= types::max_options(), E_INVALID_OPERATION);
        
        let i = 0;
        while (i < len) {
            let title = *vector::borrow(&option_titles, i);
            let description = if (i < vector::length(&option_descriptions)) {
                *vector::borrow(&option_descriptions, i)
            } else {
                utf8(b"")
            };
            
            let option = types::new_voting_option(
                current_count + i,
                title,
                description
            );
            types::add_option(voting, option);
            i = i + 1;
        };
    }

    // ==================== 辅助函数 ====================

    /// 检查投票是否存在
    /// 
    /// @param creator_addr 创建者地址
    /// @return 是否存在
    public fun voting_exists(creator_addr: address): bool {
        exists<Voting>(creator_addr)
    }

    /// 获取投票引用（只读）
    /// 
    /// @param creator_addr 创建者地址
    /// @return 投票引用
    public fun borrow_voting(creator_addr: address): &Voting acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        borrow_global<Voting>(creator_addr)
    }

    /// 强制结束已过期的投票
    /// 
    /// @param creator_addr 创建者地址
    public fun force_end_expired_voting(creator_addr: address) acquires Voting {
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 检查是否过期
        assert!(types::is_expired(voting), E_INVALID_OPERATION);
        
        // 如果还是活跃状态，强制结束
        if (types::is_active(voting)) {
            types::set_status(voting, types::status_ended());
        };
    }

    /// 重置投票（清除所有投票记录）
    /// 
    /// 谨慎使用：此操作不可逆
    public fun reset_voting(creator: &signer, _voting_id: u64) acquires Voting {
        let creator_addr = signer::address_of(creator);
        assert!(exists<Voting>(creator_addr), E_VOTING_NOT_EXISTS);
        
        let voting = borrow_global_mut<Voting>(creator_addr);
        
        // 验证权限
        validation::validate_creator(creator, voting);
        
        // 只能重置待定或已取消的投票
        assert!(
            types::is_pending(voting) || types::is_cancelled(voting),
            E_INVALID_OPERATION
        );
        
        // 重置所有选项的票数（需要具体实现）
        let option_count = types::get_option_count(voting);
        let i = 0;
        while (i < option_count) {
            let option = types::get_option_mut(voting, i);
            // 重置票数为0
            while (types::get_option_vote_count(option) > 0) {
                types::decrement_option_votes(option);
            };
            i = i + 1;
        };
        
        // 重置总票数（通过减少到0）
        while (types::get_total_votes(voting) > 0) {
            types::decrement_total_votes(voting);
        };
    }
}
