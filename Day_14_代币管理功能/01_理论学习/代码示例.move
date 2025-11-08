/// Day 14: 代币管理功能完整代码示例
/// 
/// 本模块展示：
/// 1. 权限分离存储
/// 2. 铸造限额控制
/// 3. 转账销毁机制
/// 4. 合规冻结系统
/// 5. 多签名操作
/// 6. 时间锁保护
/// 7. 事件系统

module token_manager::managed_token {
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability, FreezeCapability};
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    /// ===================== 错误码 =====================
    const ERROR_NOT_ADMIN: u64 = 1;
    const ERROR_NOT_AUTHORIZED: u64 = 2;
    const ERROR_EXCEED_DAILY_LIMIT: u64 = 3;
    const ERROR_TIMELOCK_NOT_EXPIRED: u64 = 4;
    const ERROR_ALREADY_EXECUTED: u64 = 5;
    const ERROR_INSUFFICIENT_SIGNATURES: u64 = 6;
    const ERROR_ALREADY_SIGNED: u64 = 7;
    const ERROR_NOT_SIGNER: u64 = 8;
    const ERROR_INVALID_PROPOSAL: u64 = 9;
    const ERROR_NOT_COMPLIANCE_ADMIN: u64 = 10;
    const ERROR_ACCOUNT_FROZEN: u64 = 11;

    /// ===================== 代币定义 =====================
    struct ManagedToken {}

    /// ===================== 权限存储结构 =====================
    
    /// 铸造权限持有者
    struct MintCapStore has key {
        mint_cap: MintCapability<ManagedToken>,
        daily_limit: u64,
        minted_today: u64,
        last_reset_timestamp: u64,
    }

    /// 销毁权限持有者
    struct BurnCapStore has key {
        burn_cap: BurnCapability<ManagedToken>,
        total_burned: u64,
    }

    /// 冻结权限持有者
    struct FreezeCapStore has key {
        freeze_cap: FreezeCapability<ManagedToken>,
        compliance_admin: address,
        frozen_accounts: Table<address, FreezeReason>,
        freeze_history: vector<FreezeRecord>,
    }

    /// 冻结原因
    struct FreezeReason has store {
        reason_code: u8,        // 1=法律要求, 2=可疑活动, 3=其他
        description: String,
        frozen_at: u64,
        frozen_by: address,
    }

    /// 冻结历史记录
    struct FreezeRecord has store, drop, copy {
        account: address,
        action: u8,             // 0=冻结, 1=解冻
        timestamp: u64,
        operator: address,
    }

    /// ===================== 多签名结构 =====================
    
    struct MultiSigConfig has key {
        signers: vector<address>,
        required_signatures: u64,
        next_proposal_id: u64,
        proposals: Table<u64, MintProposal>,
    }

    struct MintProposal has store {
        recipient: address,
        amount: u64,
        proposer: address,
        signatures: vector<address>,
        executed: bool,
        created_at: u64,
    }

    /// ===================== 时间锁结构 =====================
    
    struct TimeLockConfig has key {
        delay: u64,  // 延迟时间（秒）
        scheduled_mints: Table<u64, ScheduledMint>,
        next_schedule_id: u64,
    }

    struct ScheduledMint has store {
        recipient: address,
        amount: u64,
        unlock_time: u64,
        executed: bool,
    }

    /// ===================== 通缩配置 =====================
    
    struct DeflationConfig has key {
        burn_rate_basis_points: u64,  // 基点（1% = 100）
        total_burned_from_transfers: u64,
    }

    const BASIS_POINTS_DIVISOR: u64 = 10000;

    /// ===================== 事件 =====================
    
    struct TokenEvents has key {
        mint_events: EventHandle<MintEvent>,
        burn_events: EventHandle<BurnEvent>,
        freeze_events: EventHandle<FreezeEvent>,
        proposal_events: EventHandle<ProposalEvent>,
    }

    struct MintEvent has drop, store {
        recipient: address,
        amount: u64,
        minted_by: address,
        timestamp: u64,
    }

    struct BurnEvent has drop, store {
        amount: u64,
        burned_by: address,
        reason: String,
        timestamp: u64,
    }

    struct FreezeEvent has drop, store {
        account: address,
        frozen: bool,  // true=冻结, false=解冻
        reason: String,
        timestamp: u64,
    }

    struct ProposalEvent has drop, store {
        proposal_id: u64,
        action: String,  // "created", "signed", "executed"
        actor: address,
        timestamp: u64,
    }

    /// ===================== 初始化函数 =====================

    /// 初始化代币（只在部署时调用一次）
    fun init_module(admin: &signer) {
        // 1. 初始化代币
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<ManagedToken>(
            admin,
            string::utf8(b"Managed Token"),
            string::utf8(b"MGT"),
            8,  // 8 位小数
            true,  // 追踪供应量
        );

        // 2. 分离存储三个权限
        move_to(admin, MintCapStore {
            mint_cap,
            daily_limit: 1000000 * 100000000,  // 每天最多铸造 100 万个币
            minted_today: 0,
            last_reset_timestamp: timestamp::now_seconds(),
        });

        move_to(admin, BurnCapStore {
            burn_cap,
            total_burned: 0,
        });

        move_to(admin, FreezeCapStore {
            freeze_cap,
            compliance_admin: signer::address_of(admin),
            frozen_accounts: table::new(),
            freeze_history: vector::empty(),
        });

        // 3. 初始化多签名配置（3/5 多签）
        move_to(admin, MultiSigConfig {
            signers: vector[
                signer::address_of(admin),
                // 需要手动添加其他签名者
            ],
            required_signatures: 1,  // 初始为 1，之后可以修改
            next_proposal_id: 0,
            proposals: table::new(),
        });

        // 4. 初始化时间锁（24 小时延迟）
        move_to(admin, TimeLockConfig {
            delay: 86400,  // 24 小时
            scheduled_mints: table::new(),
            next_schedule_id: 0,
        });

        // 5. 初始化通缩配置（1% 销毁率）
        move_to(admin, DeflationConfig {
            burn_rate_basis_points: 100,  // 1%
            total_burned_from_transfers: 0,
        });

        // 6. 初始化事件
        move_to(admin, TokenEvents {
            mint_events: account::new_event_handle<MintEvent>(admin),
            burn_events: account::new_event_handle<BurnEvent>(admin),
            freeze_events: account::new_event_handle<FreezeEvent>(admin),
            proposal_events: account::new_event_handle<ProposalEvent>(admin),
        });
    }

    /// ===================== 铸造功能 =====================

    /// 普通铸造（带日限额）
    public entry fun mint_tokens(
        admin: &signer,
        recipient: address,
        amount: u64
    ) acquires MintCapStore, TokenEvents {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @token_manager, ERROR_NOT_ADMIN);

        let mint_store = borrow_global_mut<MintCapStore>(@token_manager);
        
        // 检查并重置日限额
        check_and_reset_daily_limit(mint_store);
        
        // 检查限额
        assert!(
            mint_store.minted_today + amount <= mint_store.daily_limit,
            ERROR_EXCEED_DAILY_LIMIT
        );

        // 铸造
        let coins = coin::mint(amount, &mint_store.mint_cap);
        coin::deposit(recipient, coins);
        
        // 更新统计
        mint_store.minted_today = mint_store.minted_today + amount;

        // 发射事件
        let events = borrow_global_mut<TokenEvents>(@token_manager);
        event::emit_event(&mut events.mint_events, MintEvent {
            recipient,
            amount,
            minted_by: admin_addr,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// 检查并重置日限额
    fun check_and_reset_daily_limit(mint_store: &mut MintCapStore) {
        let now = timestamp::now_seconds();
        let current_day = now / 86400;
        let last_day = mint_store.last_reset_timestamp / 86400;
        
        if (current_day > last_day) {
            mint_store.minted_today = 0;
            mint_store.last_reset_timestamp = now;
        }
    }

    /// ===================== 销毁功能 =====================

    /// 从账户销毁代币
    public entry fun burn_from_account(
        account: &signer,
        amount: u64
    ) acquires BurnCapStore, TokenEvents {
        let account_addr = signer::address_of(account);
        
        // 提取代币
        let coins = coin::withdraw<ManagedToken>(account, amount);
        
        // 获取销毁权限
        let burn_store = borrow_global_mut<BurnCapStore>(@token_manager);
        
        // 销毁
        coin::burn(coins, &burn_store.burn_cap);
        burn_store.total_burned = burn_store.total_burned + amount;

        // 发射事件
        let events = borrow_global_mut<TokenEvents>(@token_manager);
        event::emit_event(&mut events.burn_events, BurnEvent {
            amount,
            burned_by: account_addr,
            reason: string::utf8(b"User burn"),
            timestamp: timestamp::now_seconds(),
        });
    }

    /// 通缩转账（自动销毁一部分）
    public entry fun transfer_with_burn(
        from: &signer,
        to: address,
        amount: u64
    ) acquires BurnCapStore, DeflationConfig, TokenEvents {
        let config = borrow_global_mut<DeflationConfig>(@token_manager);
        
        // 计算销毁数量
        let burn_amount = (amount * config.burn_rate_basis_points) / BASIS_POINTS_DIVISOR;
        let transfer_amount = amount - burn_amount;
        
        // 提取全部
        let all_coins = coin::withdraw<ManagedToken>(from, amount);
        
        // 分离要销毁的部分
        let burn_coins = coin::extract(&mut all_coins, burn_amount);
        
        // 销毁
        let burn_store = borrow_global_mut<BurnCapStore>(@token_manager);
        coin::burn(burn_coins, &burn_store.burn_cap);
        burn_store.total_burned = burn_store.total_burned + burn_amount;
        config.total_burned_from_transfers = config.total_burned_from_transfers + burn_amount;
        
        // 转账剩余
        coin::deposit(to, all_coins);

        // 发射事件
        let events = borrow_global_mut<TokenEvents>(@token_manager);
        event::emit_event(&mut events.burn_events, BurnEvent {
            amount: burn_amount,
            burned_by: signer::address_of(from),
            reason: string::utf8(b"Deflationary transfer"),
            timestamp: timestamp::now_seconds(),
        });
    }

    /// ===================== 冻结功能 =====================

    /// 冻结账户
    public entry fun freeze_account(
        admin: &signer,
        account_addr: address,
        reason_code: u8,
        description: vector<u8>
    ) acquires FreezeCapStore, TokenEvents {
        let freeze_store = borrow_global_mut<FreezeCapStore>(@token_manager);
        
        // 验证权限
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == freeze_store.compliance_admin, ERROR_NOT_COMPLIANCE_ADMIN);
        
        // 执行冻结
        coin::freeze_coin_store<ManagedToken>(account_addr, &freeze_store.freeze_cap);
        
        // 记录原因
        let desc = string::utf8(description);
        table::add(&mut freeze_store.frozen_accounts, account_addr, FreezeReason {
            reason_code,
            description: desc,
            frozen_at: timestamp::now_seconds(),
            frozen_by: admin_addr,
        });
        
        // 记录历史
        vector::push_back(&mut freeze_store.freeze_history, FreezeRecord {
            account: account_addr,
            action: 0,  // 冻结
            timestamp: timestamp::now_seconds(),
            operator: admin_addr,
        });

        // 发射事件
        let events = borrow_global_mut<TokenEvents>(@token_manager);
        event::emit_event(&mut events.freeze_events, FreezeEvent {
            account: account_addr,
            frozen: true,
            reason: desc,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// 解冻账户
    public entry fun unfreeze_account(
        admin: &signer,
        account_addr: address
    ) acquires FreezeCapStore, TokenEvents {
        let freeze_store = borrow_global_mut<FreezeCapStore>(@token_manager);
        
        // 验证权限
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == freeze_store.compliance_admin, ERROR_NOT_COMPLIANCE_ADMIN);
        
        // 执行解冻
        coin::unfreeze_coin_store<ManagedToken>(account_addr, &freeze_store.freeze_cap);
        
        // 移除冻结记录
        if (table::contains(&freeze_store.frozen_accounts, account_addr)) {
            table::remove(&mut freeze_store.frozen_accounts, account_addr);
        };
        
        // 记录历史
        vector::push_back(&mut freeze_store.freeze_history, FreezeRecord {
            account: account_addr,
            action: 1,  // 解冻
            timestamp: timestamp::now_seconds(),
            operator: admin_addr,
        });

        // 发射事件
        let events = borrow_global_mut<TokenEvents>(@token_manager);
        event::emit_event(&mut events.freeze_events, FreezeEvent {
            account: account_addr,
            frozen: false,
            reason: string::utf8(b"Unfrozen"),
            timestamp: timestamp::now_seconds(),
        });
    }

    /// ===================== 多签名功能 =====================

    /// 创建铸造提案
    public entry fun propose_mint(
        proposer: &signer,
        recipient: address,
        amount: u64
    ) acquires MultiSigConfig, TokenEvents {
        let multisig = borrow_global_mut<MultiSigConfig>(@token_manager);
        
        // 验证是签名者之一
        let proposer_addr = signer::address_of(proposer);
        assert!(vector::contains(&multisig.signers, &proposer_addr), ERROR_NOT_SIGNER);
        
        // 创建提案
        let proposal_id = multisig.next_proposal_id;
        table::add(&mut multisig.proposals, proposal_id, MintProposal {
            recipient,
            amount,
            proposer: proposer_addr,
            signatures: vector[proposer_addr],  // 提案者自动签名
            executed: false,
            created_at: timestamp::now_seconds(),
        });
        
        multisig.next_proposal_id = proposal_id + 1;

        // 发射事件
        let events = borrow_global_mut<TokenEvents>(@token_manager);
        event::emit_event(&mut events.proposal_events, ProposalEvent {
            proposal_id,
            action: string::utf8(b"created"),
            actor: proposer_addr,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// 签名提案
    public entry fun sign_proposal(
        signer_account: &signer,
        proposal_id: u64
    ) acquires MultiSigConfig, TokenEvents {
        let multisig = borrow_global_mut<MultiSigConfig>(@token_manager);
        
        assert!(table::contains(&multisig.proposals, proposal_id), ERROR_INVALID_PROPOSAL);
        let proposal = table::borrow_mut(&mut multisig.proposals, proposal_id);
        
        let signer_addr = signer::address_of(signer_account);
        
        // 验证
        assert!(vector::contains(&multisig.signers, &signer_addr), ERROR_NOT_SIGNER);
        assert!(!vector::contains(&proposal.signatures, &signer_addr), ERROR_ALREADY_SIGNED);
        assert!(!proposal.executed, ERROR_ALREADY_EXECUTED);
        
        // 添加签名
        vector::push_back(&mut proposal.signatures, signer_addr);

        // 发射事件
        let events = borrow_global_mut<TokenEvents>(@token_manager);
        event::emit_event(&mut events.proposal_events, ProposalEvent {
            proposal_id,
            action: string::utf8(b"signed"),
            actor: signer_addr,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// 执行提案
    public entry fun execute_proposal(
        executor: &signer,
        proposal_id: u64
    ) acquires MultiSigConfig, MintCapStore, TokenEvents {
        let multisig = borrow_global_mut<MultiSigConfig>(@token_manager);
        
        assert!(table::contains(&multisig.proposals, proposal_id), ERROR_INVALID_PROPOSAL);
        let proposal = table::borrow_mut(&mut multisig.proposals, proposal_id);
        
        // 检查签名数量
        assert!(
            vector::length(&proposal.signatures) >= multisig.required_signatures,
            ERROR_INSUFFICIENT_SIGNATURES
        );
        assert!(!proposal.executed, ERROR_ALREADY_EXECUTED);
        
        // 执行铸造
        let mint_store = borrow_global_mut<MintCapStore>(@token_manager);
        let coins = coin::mint(proposal.amount, &mint_store.mint_cap);
        coin::deposit(proposal.recipient, coins);
        
        proposal.executed = true;

        // 发射事件
        let events = borrow_global_mut<TokenEvents>(@token_manager);
        event::emit_event(&mut events.proposal_events, ProposalEvent {
            proposal_id,
            action: string::utf8(b"executed"),
            actor: signer::address_of(executor),
            timestamp: timestamp::now_seconds(),
        });

        event::emit_event(&mut events.mint_events, MintEvent {
            recipient: proposal.recipient,
            amount: proposal.amount,
            minted_by: @token_manager,
            timestamp: timestamp::now_seconds(),
        });
    }

    /// ===================== 时间锁功能 =====================

    /// 调度延迟铸造
    public entry fun schedule_mint(
        admin: &signer,
        recipient: address,
        amount: u64
    ) acquires TimeLockConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @token_manager, ERROR_NOT_ADMIN);
        
        let timelock = borrow_global_mut<TimeLockConfig>(@token_manager);
        let now = timestamp::now_seconds();
        
        let schedule_id = timelock.next_schedule_id;
        table::add(&mut timelock.scheduled_mints, schedule_id, ScheduledMint {
            recipient,
            amount,
            unlock_time: now + timelock.delay,
            executed: false,
        });
        
        timelock.next_schedule_id = schedule_id + 1;
    }

    /// 执行调度的铸造
    public entry fun execute_scheduled_mint(
        executor: &signer,
        schedule_id: u64
    ) acquires TimeLockConfig, MintCapStore, TokenEvents {
        let timelock = borrow_global_mut<TimeLockConfig>(@token_manager);
        
        assert!(table::contains(&timelock.scheduled_mints, schedule_id), ERROR_INVALID_PROPOSAL);
        let scheduled = table::borrow_mut(&mut timelock.scheduled_mints, schedule_id);
        
        let now = timestamp::now_seconds();
        assert!(now >= scheduled.unlock_time, ERROR_TIMELOCK_NOT_EXPIRED);
        assert!(!scheduled.executed, ERROR_ALREADY_EXECUTED);
        
        // 执行铸造
        let mint_store = borrow_global_mut<MintCapStore>(@token_manager);
        let coins = coin::mint(scheduled.amount, &mint_store.mint_cap);
        coin::deposit(scheduled.recipient, coins);
        
        scheduled.executed = true;

        // 发射事件
        let events = borrow_global_mut<TokenEvents>(@token_manager);
        event::emit_event(&mut events.mint_events, MintEvent {
            recipient: scheduled.recipient,
            amount: scheduled.amount,
            minted_by: signer::address_of(executor),
            timestamp: now,
        });
    }

    /// ===================== 查询函数 =====================

    #[view]
    /// 查询是否被冻结
    public fun is_frozen(account: address): bool {
        coin::is_coin_store_frozen<ManagedToken>(account)
    }

    #[view]
    /// 查询冻结原因
    public fun get_freeze_reason(account: address): (u8, String, u64) 
    acquires FreezeCapStore {
        let freeze_store = borrow_global<FreezeCapStore>(@token_manager);
        if (table::contains(&freeze_store.frozen_accounts, account)) {
            let reason = table::borrow(&freeze_store.frozen_accounts, account);
            (reason.reason_code, reason.description, reason.frozen_at)
        } else {
            (0, string::utf8(b"Not frozen"), 0)
        }
    }

    #[view]
    /// 查询今日已铸造数量
    public fun get_minted_today(): u64 acquires MintCapStore {
        let mint_store = borrow_global<MintCapStore>(@token_manager);
        mint_store.minted_today
    }

    #[view]
    /// 查询总销毁数量
    public fun get_total_burned(): u64 acquires BurnCapStore {
        borrow_global<BurnCapStore>(@token_manager).total_burned
    }

    #[view]
    /// 查询提案信息
    public fun get_proposal(proposal_id: u64): (address, u64, u64, bool) 
    acquires MultiSigConfig {
        let multisig = borrow_global<MultiSigConfig>(@token_manager);
        assert!(table::contains(&multisig.proposals, proposal_id), ERROR_INVALID_PROPOSAL);
        
        let proposal = table::borrow(&multisig.proposals, proposal_id);
        (
            proposal.recipient,
            proposal.amount,
            vector::length(&proposal.signatures),
            proposal.executed
        )
    }

    /// ===================== 管理函数 =====================

    /// 添加签名者
    public entry fun add_signer(
        admin: &signer,
        new_signer: address
    ) acquires MultiSigConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @token_manager, ERROR_NOT_ADMIN);
        
        let multisig = borrow_global_mut<MultiSigConfig>(@token_manager);
        if (!vector::contains(&multisig.signers, &new_signer)) {
            vector::push_back(&mut multisig.signers, new_signer);
        }
    }

    /// 更新所需签名数
    public entry fun update_required_signatures(
        admin: &signer,
        new_required: u64
    ) acquires MultiSigConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @token_manager, ERROR_NOT_ADMIN);
        
        let multisig = borrow_global_mut<MultiSigConfig>(@token_manager);
        multisig.required_signatures = new_required;
    }

    /// 更新日铸造限额
    public entry fun update_daily_limit(
        admin: &signer,
        new_limit: u64
    ) acquires MintCapStore {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @token_manager, ERROR_NOT_ADMIN);
        
        let mint_store = borrow_global_mut<MintCapStore>(@token_manager);
        mint_store.daily_limit = new_limit;
    }

    /// 更新销毁率
    public entry fun update_burn_rate(
        admin: &signer,
        new_rate: u64
    ) acquires DeflationConfig {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @token_manager, ERROR_NOT_ADMIN);
        
        let config = borrow_global_mut<DeflationConfig>(@token_manager);
        config.burn_rate_basis_points = new_rate;
    }
}
