module voting::simple_voting {
    use std::string;
    use std::vector;
    use std::signer;
    use std::table;
    use aptos_framework::timestamp;
    use voting::management::{VotingSystem, VotingInfo, VotingStatus, init_voting_system, register_voting, borrow_voting_by_id, borrow_voting_by_id_mut};

    // 错误码定义 (保留原有错误码，尽量重用)
    const E_INVALID_NAME_LENGTH: u64 = 1001;
    const E_VOTING_NOT_STARTED: u64 = 1002;
    const E_VOTING_ENDED: u64 = 1003;
    const E_ALREADY_VOTED: u64 = 1004;
    const E_INVALID_CANDIDATE_ID: u64 = 1005;
    const E_UNAUTHORIZED: u64 = 1006;
    const E_VOTING_NOT_FOUND: u64 = 1007;

    // 保留候选人结构
    public struct Candidate has store, drop {
        id: u64,
        name: string::String,
        vote_count: u64,
    }

    // 投票结果结构 (用于外部展示)
    public struct VotingResult has store, drop {
        candidate_name: string::String,
        vote_count: u64,
    }

    // 保留管理员权限结构
    public struct AdminCapability has key {
        owner: address,
    }

    //
    // 辅助存储：由于管理模块的 VotingInfo 在 registry 中存储基础信息（id/title/...），
    // 我们在 simple_voting 中维护每个 voting_id 对应的候选人列表和已投票者列表。
    //
    public struct VotingExtras has key {
        candidates: table::Table<u64, vector<Candidate>>, // key: voting_id -> vector<Candidate>
        voters: table::Table<u64, vector<address>>,       // key: voting_id -> vector<address>
    }

    // 初始化模块：创建 AdminCapability 和 VotingExtras（如果不存在）
    public fun init_module(account: &signer) acquires VotingExtras {
        let admin_addr = signer::address_of(account);
        move_to(account, AdminCapability { owner: admin_addr });

        if (!exists<VotingExtras>(admin_addr)) {
            let tbl_cand = table::new<u64, vector<Candidate>>();
            let tbl_voters = table::new<u64, vector<address>>();
            move_to(account, VotingExtras {
                candidates: tbl_cand,
                voters: tbl_voters,
            });
        };
    }

    // 私有函数：检查候选人名称是否有效（长度在2-50个字符之间）
    fun is_valid_candidate_name(name: &string::String): bool {
        let len = string::length(name);
        len >= 2 && len <= 50
    }

    // 私有函数：检查投票者是否已投票（基于 vector）
    fun has_voted(voters: &vector<address>, voter: address): bool {
        let i = 0;
        let len = vector::length(voters);

        while (i < len) {
            if (*vector::borrow(voters, i) == voter) {
                return true
            };
            i = i + 1;
        };

        false
    }

    // 私有函数：按名字查找候选人（返回索引或长度表示未找到）
    fun find_candidate_by_name(candidates: &vector<Candidate>, candidate_name: &string::String): u64 {
        let i = 0;
        let len = vector::length(candidates);

        while (i < len) {
            let candidate = vector::borrow(candidates, i);
            // compare by reference to avoid moving strings
            if (&candidate.name == candidate_name) {
                return i
            };
            i = i + 1;
        };

        len
    }

    // 公共函数：验证投票标题和描述
    public fun validate_voting_info(title: &string::String, description: &string::String): bool {
        let title_len = string::length(title);
        let desc_len = string::length(description);
        title_len >= 3 && title_len <= 100 && desc_len >= 10 && desc_len <= 500
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

    ////////////////////////////////////////////////////////////////////////////
    // Registry-based API (public) - 使用 management 的 VotingSystem registry
    ////////////////////////////////////////////////////////////////////////////

    /// 创建新投票并注册到管理模块的 registry 中
    /// 返回 assigned voting_id
    public fun create_voting(
        admin: &signer,
        title: string::String,
        description: string::String,
        start_time: u64,
        end_time: u64
    ): u64 acquires AdminCapability, VotingExtras, VotingSystem {
        let admin_addr = signer::address_of(admin);

        // 验证管理员权限
        assert!(exists<AdminCapability>(admin_addr), E_UNAUTHORIZED);
        let admin_cap = borrow_global<AdminCapability>(admin_addr);
        assert!(admin_cap.owner == admin_addr, E_UNAUTHORIZED);

        // 验证投票信息
        assert!(validate_voting_info(&title, &description), E_INVALID_NAME_LENGTH);
        assert!(start_time < end_time, E_INVALID_NAME_LENGTH);

        // 确保管理模块的 VotingSystem 已初始化
        init_voting_system(admin);

        // 构造 management::VotingInfo (id will be set by register_voting)
        let info = VotingInfo {
            id: 0,
            title: title,
            description: description,
            start_time: start_time,
            end_time: end_time,
            status: VotingStatus::NotStarted,
            creator: admin_addr,
        };

        // 注册并获取 voting_id
        let voting_id = register_voting(admin, info);

        // 在本模块的 VotingExtras 中为该 voting_id 创建候选人和投票者列表
        // 确保 VotingExtras 存在
        if (!exists<VotingExtras>(admin_addr)) {
            let tbl_cand = table::new<u64, vector<Candidate>>();
            let tbl_voters = table::new<u64, vector<address>>();
            move_to(admin, VotingExtras {
                candidates: tbl_cand,
                voters: tbl_voters,
            });
        };

        let extras = borrow_global_mut<VotingExtras>(admin_addr);
        table::add(&mut extras.candidates, voting_id, vector::empty<Candidate>());
        table::add(&mut extras.voters, voting_id, vector::empty<address>());

        voting_id
    }

    /// 添加候选人到指定 voting_id
    /// 参数 voting_id: 管理模块中分配的投票 id
    public fun add_candidate(
        admin: &signer,
        voting_id: u64,
        candidate_name: string::String
    ) acquires AdminCapability, VotingExtras, VotingSystem {
        let admin_addr = signer::address_of(admin);

        // 验证管理员权限
        assert!(exists<AdminCapability>(admin_addr), E_UNAUTHORIZED);
        let admin_cap = borrow_global<AdminCapability>(admin_addr);
        assert!(admin_cap.owner == admin_addr, E_UNAUTHORIZED);

        // 验证投票存在（registry）
        assert!(voting_exists(admin_addr, voting_id), E_VOTING_NOT_FOUND);

        // 读取 voting status via registry
        let vinfo_ref = voting::management::borrow_voting_by_id(admin_addr, voting_id);
        assert!(vinfo_ref.status == VotingStatus::NotStarted, E_VOTING_NOT_STARTED);

        // 验证候选人名称
        assert!(is_valid_candidate_name(&candidate_name), E_INVALID_NAME_LENGTH);

        // 在 extras 中添加候选人
        let extras = borrow_global_mut<VotingExtras>(admin_addr);
        let cands = table::borrow_mut(&mut extras.candidates, voting_id);
        let candidate_id = vector::length(cands);
        let candidate = Candidate { id: candidate_id, name: candidate_name, vote_count: 0 };
        vector::push_back(cands, candidate);
    }

    /// 开始指定 voting_id 的投票
    /// 参数 voting_id: 管理模块中分配的投票 id
    public fun start_voting(admin: &signer, voting_id: u64) acquires AdminCapability, VotingSystem {
        let admin_addr = signer::address_of(admin);

        // 验证管理员权限
        assert!(exists<AdminCapability>(admin_addr), E_UNAUTHORIZED);
        let admin_cap = borrow_global<AdminCapability>(admin_addr);
        assert!(admin_cap.owner == admin_addr, E_UNAUTHORIZED);

        // 修改 registry 中的 voting 状态
        let vinfo_mut = voting::management::borrow_voting_by_id_mut(admin, voting_id);
        assert!(vinfo_mut.status == VotingStatus::NotStarted, E_VOTING_NOT_STARTED);
        vinfo_mut.status = VotingStatus::Active;
    }

    /// 结束指定 voting_id 的投票
    /// 参数 voting_id: 管理模块中分配的投票 id
    public fun end_voting(admin: &signer, voting_id: u64) acquires AdminCapability, VotingSystem {
        let admin_addr = signer::address_of(admin);

        // 验证管理员权限
        assert!(exists<AdminCapability>(admin_addr), E_UNAUTHORIZED);
        let admin_cap = borrow_global<AdminCapability>(admin_addr);
        assert!(admin_cap.owner == admin_addr, E_UNAUTHORIZED);

        // 修改 registry 中的 voting 状态
        let vinfo_mut = voting::management::borrow_voting_by_id_mut(admin, voting_id);
        assert!(vinfo_mut.status == VotingStatus::Active, E_VOTING_ENDED);
        vinfo_mut.status = VotingStatus::Ended;
    }

    /// 投票：通过 voting_id 和候选人名称投票
    /// admin_addr: 投票所属管理员地址
    /// voting_id: 管理模块分配的投票 id
    public fun cast_vote(
        voter: &signer,
        admin_addr: address,
        voting_id: u64,
        candidate_name: string::String
    ) acquires VotingExtras, VotingSystem {
        let voter_addr = signer::address_of(voter);

        // 验证投票存在（registry）
        assert!(voting_exists(admin_addr, voting_id), E_VOTING_NOT_FOUND);

        // 读取 registry 中的投票信息（只读）
        let vinfo_ref = voting::management::borrow_voting_by_id(admin_addr, voting_id);

        // 验证投票状态与时间
        assert!(vinfo_ref.status == VotingStatus::Active, E_VOTING_NOT_STARTED);
        assert!(is_voting_active(vinfo_ref.start_time, vinfo_ref.end_time), E_VOTING_NOT_STARTED);

        // 从 extras 中检查并记录投票
        let extras = borrow_global_mut<VotingExtras>(admin_addr);
        let voters_vec = table::borrow_mut(&mut extras.voters, voting_id);
        assert!(!has_voted(voters_vec, voter_addr), E_ALREADY_VOTED);

        // 找到候选人
        let cands = table::borrow_mut(&mut extras.candidates, voting_id);
        let candidate_index = find_candidate_by_name(cands, &candidate_name);
        assert!(candidate_index < vector::length(cands), E_INVALID_CANDIDATE_ID);

        // 记录投票者并增加候选人票数
        vector::push_back(voters_vec, voter_addr);
        let cand_ref = vector::borrow_mut(cands, candidate_index);
        cand_ref.vote_count = cand_ref.vote_count + 1;
    }

    /// 获取投票结果（返回每个候选人名和票数的结构列表）
    /// 参数 voting_id: 管理模块分配的投票 id
    public fun get_voting_results(admin_addr: address, voting_id: u64): vector<VotingResult> acquires VotingExtras, VotingSystem {
        assert!(voting_exists(admin_addr, voting_id), E_VOTING_NOT_FOUND);

        let extras = borrow_global<VotingExtras>(admin_addr);
        let cands = table::borrow(&extras.candidates, voting_id);

        let results = vector::empty<VotingResult>();
        let i = 0;
        let len = vector::length(cands);

        while (i < len) {
            let candidate = vector::borrow(cands, i);
            let result = VotingResult {
                candidate_name: candidate.name,
                vote_count: candidate.vote_count,
            };
            vector::push_back(&mut results, result);
            i = i + 1;
        };

        results
    }

    /// 获取候选人得票数
    public fun get_candidate_votes(admin_addr: address, voting_id: u64, candidate_name: string::String): u64 acquires VotingExtras, VotingSystem {
        assert!(voting::management::voting_exists(admin_addr, voting_id), E_VOTING_NOT_FOUND);
        let extras = borrow_global<VotingExtras>(admin_addr);
        let cands = table::borrow(&extras.candidates, voting_id);

        let idx = find_candidate_by_name(cands, &candidate_name);
        if (idx < vector::length(cands)) {
            let candidate = vector::borrow(cands, idx);
            candidate.vote_count
        } else {
            0
        }
    }

    /// 检查投票是否已结束（基于 registry 的 VotingInfo）
    public fun is_voting_finished(admin_addr: address, voting_id: u64): bool acquires VotingSystem {
        assert!(voting::management::voting_exists(admin_addr, voting_id), E_VOTING_NOT_FOUND);
        let vinfo = voting::management::borrow_voting_by_id(admin_addr, voting_id);
        vinfo.status == VotingStatus::Ended || is_voting_ended(vinfo.end_time)
    }

    /// 获取投票详情
    public fun get_voting_details(admin_addr: address, voting_id: u64): (string::String, string::String, u64, u64, VotingStatus, address) acquires VotingSystem {
        assert!(voting::management::voting_exists(admin_addr, voting_id), E_VOTING_NOT_FOUND);
        let vinfo = voting::management::borrow_voting_by_id(admin_addr, voting_id);
        (vinfo.title, vinfo.description, vinfo.start_time, vinfo.end_time, vinfo.status, vinfo.creator)
    }

    /// 获取候选人名称列表
    public fun get_candidates(admin_addr: address, voting_id: u64): vector<string::String> acquires VotingExtras, VotingSystem {
        assert!(voting::management::voting_exists(admin_addr, voting_id), E_VOTING_NOT_FOUND);
        let extras = borrow_global<VotingExtras>(admin_addr);
        let cands = table::borrow(&extras.candidates, voting_id);

        let names = vector::empty<string::String>();
        let i = 0;
        let len = vector::length(cands);

        while (i < len) {
            let candidate = vector::borrow(cands, i);
            vector::push_back(&mut names, candidate.name);
            i = i + 1;
        };

        names
    }

    /// 获取投票状态
    public fun get_voting_status(admin_addr: address, voting_id: u64): VotingStatus acquires VotingSystem {
        assert!(voting::management::voting_exists(admin_addr, voting_id), E_VOTING_NOT_FOUND);
        voting::management::borrow_voting_by_id(admin_addr, voting_id).status
    }

    /// 获取投票参与人数
    public fun get_participant_count(admin_addr: address, voting_id: u64): u64 acquires VotingExtras, VotingSystem {
        assert!(voting::management::voting_exists(admin_addr, voting_id), E_VOTING_NOT_FOUND);
        let extras = borrow_global<VotingExtras>(admin_addr);
        let voters_vec = table::borrow(&extras.voters, voting_id);
        vector::length(voters_vec)
    }

    /// 检查投票是否存在（通过 management registry）
    public fun voting_exists(admin_addr: address, voting_id: u64): bool acquires VotingSystem {
        voting::management::voting_exists(admin_addr, voting_id)
    }
}