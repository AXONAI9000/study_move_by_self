/// Day 08 代码示例：事件系统与链下索引
/// 
/// 本文件包含完整的事件系统应用示例

module day08::event_examples {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_std::type_info;

    // ============================================================================
    // 示例 1：基础代币系统的事件
    // ============================================================================

    /// 转账事件
    struct TransferEvent has drop, store {
        from: address,
        to: address,
        amount: u64,
        timestamp: u64
    }

    /// 铸币事件
    struct MintEvent has drop, store {
        recipient: address,
        amount: u64,
        total_supply: u64,
        timestamp: u64
    }

    /// 销毁事件
    struct BurnEvent has drop, store {
        owner: address,
        amount: u64,
        total_supply: u64,
        timestamp: u64
    }

    /// 代币存储
    struct SimpleCoin has key {
        balance: u64,
        // 三个不同类型的事件句柄
        transfer_events: event::EventHandle<TransferEvent>,
        mint_events: event::EventHandle<MintEvent>,
        burn_events: event::EventHandle<BurnEvent>
    }

    /// 全局供应量
    struct GlobalSupply has key {
        total: u64
    }

    /// 初始化代币系统
    public entry fun initialize_coin(account: &signer) {
        let addr = signer::address_of(account);
        
        move_to(account, SimpleCoin {
            balance: 0,
            transfer_events: event::new_event_handle<TransferEvent>(account),
            mint_events: event::new_event_handle<MintEvent>(account),
            burn_events: event::new_event_handle<BurnEvent>(account)
        });

        move_to(account, GlobalSupply { total: 0 });
    }

    /// 铸币
    public entry fun mint(admin: &signer, recipient: address, amount: u64) 
        acquires SimpleCoin, GlobalSupply 
    {
        let supply = borrow_global_mut<GlobalSupply>(@day08);
        supply.total = supply.total + amount;

        let coin = borrow_global_mut<SimpleCoin>(recipient);
        coin.balance = coin.balance + amount;

        // 发射铸币事件
        event::emit_event(
            &mut coin.mint_events,
            MintEvent {
                recipient,
                amount,
                total_supply: supply.total,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    /// 转账
    public entry fun transfer(from: &signer, to: address, amount: u64) 
        acquires SimpleCoin 
    {
        let from_addr = signer::address_of(from);

        // 扣除发送方余额
        let from_coin = borrow_global_mut<SimpleCoin>(from_addr);
        assert!(from_coin.balance >= amount, 1);
        from_coin.balance = from_coin.balance - amount;

        // 增加接收方余额
        let to_coin = borrow_global_mut<SimpleCoin>(to);
        to_coin.balance = to_coin.balance + amount;

        // 发射转账事件（在发送方的事件句柄中）
        let from_coin = borrow_global_mut<SimpleCoin>(from_addr);
        event::emit_event(
            &mut from_coin.transfer_events,
            TransferEvent {
                from: from_addr,
                to,
                amount,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    /// 销毁代币
    public entry fun burn(account: &signer, amount: u64) 
        acquires SimpleCoin, GlobalSupply 
    {
        let addr = signer::address_of(account);
        
        let supply = borrow_global_mut<GlobalSupply>(@day08);
        let coin = borrow_global_mut<SimpleCoin>(addr);
        
        assert!(coin.balance >= amount, 2);
        coin.balance = coin.balance - amount;
        supply.total = supply.total - amount;

        // 发射销毁事件
        event::emit_event(
            &mut coin.burn_events,
            BurnEvent {
                owner: addr,
                amount,
                total_supply: supply.total,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    // ============================================================================
    // 示例 2：NFT 市场事件
    // ============================================================================

    /// NFT 列出事件
    struct NFTListedEvent has drop, store {
        seller: address,
        token_id: u64,
        price: u64,
        timestamp: u64
    }

    /// NFT 购买事件
    struct NFTPurchasedEvent has drop, store {
        buyer: address,
        seller: address,
        token_id: u64,
        price: u64,
        timestamp: u64
    }

    /// NFT 取消列出事件
    struct NFTDelistedEvent has drop, store {
        seller: address,
        token_id: u64,
        timestamp: u64
    }

    /// NFT 市场
    struct NFTMarketplace has key {
        // 使用多个事件句柄追踪不同的操作
        list_events: event::EventHandle<NFTListedEvent>,
        purchase_events: event::EventHandle<NFTPurchasedEvent>,
        delist_events: event::EventHandle<NFTDelistedEvent>
    }

    /// 初始化市场
    public entry fun initialize_marketplace(account: &signer) {
        move_to(account, NFTMarketplace {
            list_events: event::new_event_handle<NFTListedEvent>(account),
            purchase_events: event::new_event_handle<NFTPurchasedEvent>(account),
            delist_events: event::new_event_handle<NFTDelistedEvent>(account)
        });
    }

    /// 列出 NFT
    public entry fun list_nft(seller: &signer, token_id: u64, price: u64) 
        acquires NFTMarketplace 
    {
        let marketplace = borrow_global_mut<NFTMarketplace>(@day08);
        
        // 实际列出逻辑...
        
        event::emit_event(
            &mut marketplace.list_events,
            NFTListedEvent {
                seller: signer::address_of(seller),
                token_id,
                price,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    /// 购买 NFT
    public entry fun purchase_nft(buyer: &signer, seller: address, token_id: u64, price: u64) 
        acquires NFTMarketplace 
    {
        let marketplace = borrow_global_mut<NFTMarketplace>(@day08);
        
        // 实际购买逻辑...
        
        event::emit_event(
            &mut marketplace.purchase_events,
            NFTPurchasedEvent {
                buyer: signer::address_of(buyer),
                seller,
                token_id,
                price,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    // ============================================================================
    // 示例 3：DeFi 流动性池事件
    // ============================================================================

    /// 添加流动性事件
    struct AddLiquidityEvent has drop, store {
        provider: address,
        token_a_amount: u64,
        token_b_amount: u64,
        lp_tokens_minted: u64,
        total_liquidity: u64,
        timestamp: u64
    }

    /// 移除流动性事件
    struct RemoveLiquidityEvent has drop, store {
        provider: address,
        lp_tokens_burned: u64,
        token_a_amount: u64,
        token_b_amount: u64,
        total_liquidity: u64,
        timestamp: u64
    }

    /// 交换事件
    struct SwapEvent has drop, store {
        trader: address,
        token_in_amount: u64,
        token_out_amount: u64,
        is_a_to_b: bool,  // true: A->B, false: B->A
        price: u64,
        timestamp: u64
    }

    /// 流动性池
    struct LiquidityPool has key {
        token_a_reserve: u64,
        token_b_reserve: u64,
        total_lp_tokens: u64,
        // 不同操作的事件句柄
        add_liquidity_events: event::EventHandle<AddLiquidityEvent>,
        remove_liquidity_events: event::EventHandle<RemoveLiquidityEvent>,
        swap_events: event::EventHandle<SwapEvent>
    }

    /// 初始化流动性池
    public entry fun initialize_pool(account: &signer) {
        move_to(account, LiquidityPool {
            token_a_reserve: 0,
            token_b_reserve: 0,
            total_lp_tokens: 0,
            add_liquidity_events: event::new_event_handle<AddLiquidityEvent>(account),
            remove_liquidity_events: event::new_event_handle<RemoveLiquidityEvent>(account),
            swap_events: event::new_event_handle<SwapEvent>(account)
        });
    }

    /// 添加流动性
    public entry fun add_liquidity(
        provider: &signer,
        token_a_amount: u64,
        token_b_amount: u64
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool>(@day08);
        
        // 计算 LP 代币数量
        let lp_tokens_minted = 100; // 简化计算
        
        pool.token_a_reserve = pool.token_a_reserve + token_a_amount;
        pool.token_b_reserve = pool.token_b_reserve + token_b_amount;
        pool.total_lp_tokens = pool.total_lp_tokens + lp_tokens_minted;

        event::emit_event(
            &mut pool.add_liquidity_events,
            AddLiquidityEvent {
                provider: signer::address_of(provider),
                token_a_amount,
                token_b_amount,
                lp_tokens_minted,
                total_liquidity: pool.total_lp_tokens,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    /// 交换代币
    public entry fun swap(
        trader: &signer,
        token_in_amount: u64,
        is_a_to_b: bool
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool>(@day08);
        
        // 简化的交换逻辑
        let token_out_amount = token_in_amount * 99 / 100; // 1% 手续费
        
        if (is_a_to_b) {
            pool.token_a_reserve = pool.token_a_reserve + token_in_amount;
            pool.token_b_reserve = pool.token_b_reserve - token_out_amount;
        } else {
            pool.token_b_reserve = pool.token_b_reserve + token_in_amount;
            pool.token_a_reserve = pool.token_a_reserve - token_out_amount;
        };

        let price = if (is_a_to_b) {
            pool.token_b_reserve * 1000000 / pool.token_a_reserve
        } else {
            pool.token_a_reserve * 1000000 / pool.token_b_reserve
        };

        event::emit_event(
            &mut pool.swap_events,
            SwapEvent {
                trader: signer::address_of(trader),
                token_in_amount,
                token_out_amount,
                is_a_to_b,
                price,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    // ============================================================================
    // 示例 4：游戏系统事件
    // ============================================================================

    /// 玩家升级事件
    struct LevelUpEvent has drop, store {
        player: address,
        old_level: u64,
        new_level: u64,
        experience: u64,
        timestamp: u64
    }

    /// 物品获得事件
    struct ItemAcquiredEvent has drop, store {
        player: address,
        item_id: u64,
        item_type: u8,
        rarity: u8,
        timestamp: u64
    }

    /// 战斗事件
    struct BattleEvent has drop, store {
        attacker: address,
        defender: address,
        winner: address,
        damage_dealt: u64,
        rewards: u64,
        timestamp: u64
    }

    /// 游戏状态
    struct GameState has key {
        level_up_events: event::EventHandle<LevelUpEvent>,
        item_events: event::EventHandle<ItemAcquiredEvent>,
        battle_events: event::EventHandle<BattleEvent>
    }

    /// 初始化游戏
    public entry fun initialize_game(account: &signer) {
        move_to(account, GameState {
            level_up_events: event::new_event_handle<LevelUpEvent>(account),
            item_events: event::new_event_handle<ItemAcquiredEvent>(account),
            battle_events: event::new_event_handle<BattleEvent>(account)
        });
    }

    /// 玩家升级
    public entry fun level_up(player: &signer, old_level: u64, new_level: u64, exp: u64) 
        acquires GameState 
    {
        let game = borrow_global_mut<GameState>(@day08);
        
        event::emit_event(
            &mut game.level_up_events,
            LevelUpEvent {
                player: signer::address_of(player),
                old_level,
                new_level,
                experience: exp,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    // ============================================================================
    // 示例 5：治理投票事件
    // ============================================================================

    /// 提案创建事件
    struct ProposalCreatedEvent has drop, store {
        proposal_id: u64,
        proposer: address,
        title: String,
        voting_end_time: u64,
        timestamp: u64
    }

    /// 投票事件
    struct VoteEvent has drop, store {
        proposal_id: u64,
        voter: address,
        vote_weight: u64,
        support: bool,  // true=赞成, false=反对
        timestamp: u64
    }

    /// 提案执行事件
    struct ProposalExecutedEvent has drop, store {
        proposal_id: u64,
        executor: address,
        total_votes_for: u64,
        total_votes_against: u64,
        passed: bool,
        timestamp: u64
    }

    /// 治理系统
    struct Governance has key {
        proposal_events: event::EventHandle<ProposalCreatedEvent>,
        vote_events: event::EventHandle<VoteEvent>,
        execution_events: event::EventHandle<ProposalExecutedEvent>
    }

    /// 初始化治理
    public entry fun initialize_governance(account: &signer) {
        move_to(account, Governance {
            proposal_events: event::new_event_handle<ProposalCreatedEvent>(account),
            vote_events: event::new_event_handle<VoteEvent>(account),
            execution_events: event::new_event_handle<ProposalExecutedEvent>(account)
        });
    }

    /// 创建提案
    public entry fun create_proposal(
        proposer: &signer,
        proposal_id: u64,
        title_bytes: vector<u8>,
        voting_end_time: u64
    ) acquires Governance {
        let gov = borrow_global_mut<Governance>(@day08);
        
        event::emit_event(
            &mut gov.proposal_events,
            ProposalCreatedEvent {
                proposal_id,
                proposer: signer::address_of(proposer),
                title: string::utf8(title_bytes),
                voting_end_time,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    /// 投票
    public entry fun vote(
        voter: &signer,
        proposal_id: u64,
        vote_weight: u64,
        support: bool
    ) acquires Governance {
        let gov = borrow_global_mut<Governance>(@day08);
        
        event::emit_event(
            &mut gov.vote_events,
            VoteEvent {
                proposal_id,
                voter: signer::address_of(voter),
                vote_weight,
                support,
                timestamp: timestamp::now_seconds()
            }
        );
    }

    // ============================================================================
    // 视图函数（只读）
    // ============================================================================

    #[view]
    public fun get_balance(addr: address): u64 acquires SimpleCoin {
        borrow_global<SimpleCoin>(addr).balance
    }

    #[view]
    public fun get_total_supply(): u64 acquires GlobalSupply {
        borrow_global<GlobalSupply>(@day08).total
    }

    #[view]
    public fun get_pool_reserves(): (u64, u64) acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool>(@day08);
        (pool.token_a_reserve, pool.token_b_reserve)
    }
}

/// =============================================================================
/// 关键学习点总结
/// =============================================================================
/// 
/// 1. EventHandle 必须存储在资源中
/// 2. 每个 EventHandle 对应一种事件类型
/// 3. 使用 event::emit_event() 发射事件
/// 4. 事件数据精简，只包含关键信息
/// 5. 事件按发射顺序自动编号
/// 6. 不同业务场景使用不同的事件结构
/// 
/// =============================================================================
