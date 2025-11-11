/// # NFT 批量操作与 Gas 优化 - 代码示例
///
/// 本文件展示了完整的 NFT 批量操作实现，包括：
/// 1. 批量铸造系统
/// 2. 批量转移功能
/// 3. Gas 优化技术
/// 4. 元数据管理优化
///
/// 学习建议：
/// - 仔细阅读每个函数的注释
/// - 对比优化前后的代码
/// - 理解每个优化技巧的原理
/// - 思考如何应用到实际项目

module nft_batch_ops::optimized_nft {
    use std::string::{Self, String};
    use std::vector;
    use std::signer;
    use std::option::{Self, Option};
    use aptos_framework::object::{Self, Object};
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_token_objects::collection;
    use aptos_token_objects::token;

    // ============================================================================
    // 错误码
    // ============================================================================

    const ERROR_NOT_AUTHORIZED: u64 = 1;
    const ERROR_BATCH_TOO_LARGE: u64 = 2;
    const ERROR_INVALID_LENGTH: u64 = 3;
    const ERROR_COLLECTION_NOT_FOUND: u64 = 4;
    const ERROR_NOT_OWNER: u64 = 5;
    const ERROR_EXCEED_MAX_SUPPLY: u64 = 6;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 7;

    // ============================================================================
    // 常量配置
    // ============================================================================

    /// 最大批次大小（避免 Gas 超限）
    const MAX_BATCH_SIZE: u64 = 50;
    
    /// 推荐批次大小（平衡效率和风险）
    const RECOMMENDED_BATCH_SIZE: u64 = 20;

    // ============================================================================
    // 数据结构
    // ============================================================================

    /// Collection 配置（存储优化版本）
    struct OptimizedCollection has key {
        /// Collection 扩展引用
        extend_ref: object::ExtendRef,
        /// 铸造权限管理
        minter_ref: token::MinterRef,
        /// 已铸造数量
        minted_count: u64,
        /// 最大供应量
        max_supply: u64,
        /// 基础 URI（模板化）
        base_uri: String,
        /// URI 后缀
        uri_suffix: String,
        /// Collection 统计
        stats: CollectionStats,
    }

    /// Collection 统计信息
    struct CollectionStats has store {
        total_minted: u64,
        total_transferred: u64,
        total_burned: u64,
        last_mint_timestamp: u64,
    }

    /// NFT Token 数据（极简版本 - Gas 优化）
    struct OptimizedTokenData has key {
        /// Token ID
        id: u64,
        /// 属性打包（位压缩）
        /// Bits 0-7: 稀有度 (0-255)
        /// Bits 8-15: 等级 (0-255)
        /// Bits 16-23: 类别 (0-255)
        /// Bits 24-31: 保留
        packed_attributes: u32,
        /// 元数据哈希（指向 IPFS）
        metadata_hash: Option<vector<u8>>,
        /// 铸造时间戳
        mint_timestamp: u64,
    }

    /// 批量操作记录（用于追踪和审计）
    struct BatchOperationRegistry has key {
        operations: SmartTable<u64, BatchOperation>,
        operation_count: u64,
    }

    /// 批量操作信息
    struct BatchOperation has store {
        operation_type: u8,  // 1: mint, 2: transfer, 3: burn
        token_count: u64,
        executor: address,
        timestamp: u64,
        gas_used: u64,
    }

    // ============================================================================
    // 事件
    // ============================================================================

    #[event]
    /// 批量铸造事件（单个事件代替多个）
    struct BatchMintEvent has drop, store {
        collection: address,
        start_token_id: u64,
        count: u64,
        recipients: vector<address>,
        total_gas_saved: u64,
        timestamp: u64,
    }

    #[event]
    /// 批量转移事件
    struct BatchTransferEvent has drop, store {
        from: address,
        token_ids: vector<u64>,
        recipients: vector<address>,
        count: u64,
        timestamp: u64,
    }

    #[event]
    /// Gas 优化统计事件
    struct GasOptimizationEvent has drop, store {
        operation: String,
        original_gas: u64,
        optimized_gas: u64,
        savings_percent: u64,
    }

    // ============================================================================
    // 初始化函数
    // ============================================================================

    /// 创建优化的 NFT Collection
    public entry fun create_optimized_collection(
        creator: &signer,
        description: String,
        collection_name: String,
        uri: String,
        max_supply: u64,
        base_uri: String,
        uri_suffix: String,
    ) {
        // 创建 Collection
        let constructor_ref = collection::create_unlimited_collection(
            creator,
            description,
            collection_name,
            option::none(),
            uri,
        );

        // 获取必要的引用
        let object_signer = object::generate_signer(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let minter_ref = token::generate_minter_ref(&constructor_ref);

        // 初始化 Collection 数据
        move_to(&object_signer, OptimizedCollection {
            extend_ref,
            minter_ref,
            minted_count: 0,
            max_supply,
            base_uri,
            uri_suffix,
            stats: CollectionStats {
                total_minted: 0,
                total_transferred: 0,
                total_burned: 0,
                last_mint_timestamp: 0,
            },
        });

        // 初始化批量操作注册表
        move_to(creator, BatchOperationRegistry {
            operations: smart_table::new(),
            operation_count: 0,
        });
    }

    // ============================================================================
    // 批量铸造功能
    // ============================================================================

    /// 批量铸造 NFT（优化版本）
    /// 
    /// Gas 优化技巧：
    /// 1. 预计算所有常量
    /// 2. 批量处理事件
    /// 3. 最小化存储写入
    /// 4. 使用位压缩
    public entry fun batch_mint_optimized(
        creator: &signer,
        collection_name: String,
        recipients: vector<address>,
        count_per_recipient: u64,
        rarity_levels: vector<u8>,  // 每个 NFT 的稀有度
    ) acquires OptimizedCollection, BatchOperationRegistry {
        let creator_addr = signer::address_of(creator);
        
        // === 验证阶段（一次性验证，避免重复） ===
        let total_count = vector::length(&recipients) * count_per_recipient;
        assert!(total_count <= MAX_BATCH_SIZE, ERROR_BATCH_TOO_LARGE);
        assert!(
            vector::length(&rarity_levels) == total_count,
            ERROR_INVALID_LENGTH
        );

        // 获取 Collection 地址和数据
        let collection_addr = collection::create_collection_address(
            &creator_addr,
            &collection_name
        );
        let collection_obj = object::address_to_object<OptimizedCollection>(collection_addr);
        let collection_data = borrow_global_mut<OptimizedCollection>(
            object::object_address(&collection_obj)
        );

        // 检查供应量限制
        assert!(
            collection_data.minted_count + total_count <= collection_data.max_supply,
            ERROR_EXCEED_MAX_SUPPLY
        );

        // === 预计算阶段（减少重复计算） ===
        let start_token_id = collection_data.minted_count;
        let base_uri = collection_data.base_uri;
        let uri_suffix = collection_data.uri_suffix;
        let current_timestamp = aptos_framework::timestamp::now_seconds();

        // === 批量铸造循环 ===
        let global_index = 0;
        let recipient_index = 0;
        let recipient_count = vector::length(&recipients);

        while (recipient_index < recipient_count) {
            let recipient = *vector::borrow(&recipients, recipient_index);
            
            let mint_count = 0;
            while (mint_count < count_per_recipient) {
                let token_id = start_token_id + global_index;
                let rarity = *vector::borrow(&rarity_levels, global_index);
                
                // 创建 Token（使用 minter_ref）
                mint_single_optimized(
                    &collection_data.minter_ref,
                    collection_name,
                    token_id,
                    recipient,
                    &base_uri,
                    &uri_suffix,
                    rarity,
                    current_timestamp,
                );

                mint_count = mint_count + 1;
                global_index = global_index + 1;
            };

            recipient_index = recipient_index + 1;
        };

        // === 更新统计（批量更新，而非每次铸造都更新） ===
        collection_data.minted_count = collection_data.minted_count + total_count;
        collection_data.stats.total_minted = collection_data.stats.total_minted + total_count;
        collection_data.stats.last_mint_timestamp = current_timestamp;

        // === 记录批量操作 ===
        let registry = borrow_global_mut<BatchOperationRegistry>(creator_addr);
        smart_table::add(
            &mut registry.operations,
            registry.operation_count,
            BatchOperation {
                operation_type: 1,  // mint
                token_count: total_count,
                executor: creator_addr,
                timestamp: current_timestamp,
                gas_used: 0,  // 实际项目中可以通过 gas profiler 获取
            }
        );
        registry.operation_count = registry.operation_count + 1;

        // === 发射批量事件（单个事件，而非 N 个事件） ===
        event::emit(BatchMintEvent {
            collection: collection_addr,
            start_token_id,
            count: total_count,
            recipients,
            total_gas_saved: calculate_gas_savings(total_count),
            timestamp: current_timestamp,
        });
    }

    /// 单个 NFT 铸造的内部函数（高度优化）
    inline fun mint_single_optimized(
        minter_ref: &token::MinterRef,
        collection_name: String,
        token_id: u64,
        recipient: address,
        base_uri: &String,
        uri_suffix: &String,
        rarity: u8,
        timestamp: u64,
    ) {
        // 构造 Token 名称（动态生成，不存储）
        let token_name = generate_token_name(token_id);
        
        // 构造 URI（模板化，减少存储）
        let token_uri = construct_uri(base_uri, token_id, uri_suffix);

        // 创建 Token
        let constructor_ref = token::create(
            minter_ref,
            collection_name,
            string::utf8(b"Optimized NFT"),  // 描述
            token_name,
            option::none(),  // 无版税
            token_uri,
        );

        // 获取 Token signer
        let token_signer = object::generate_signer(&constructor_ref);

        // 打包属性（位压缩优化）
        let packed_attributes = pack_attributes(
            rarity,
            1,   // 初始等级
            0,   // 类别
        );

        // 存储极简的 Token 数据
        move_to(&token_signer, OptimizedTokenData {
            id: token_id,
            packed_attributes,
            metadata_hash: option::none(),  // 可选的 IPFS 哈希
            mint_timestamp: timestamp,
        });

        // 转移给接收者
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, recipient);
    }

    // ============================================================================
    // 批量转移功能
    // ============================================================================

    /// 批量转移 NFT（优化版本）
    public entry fun batch_transfer_optimized(
        sender: &signer,
        token_addresses: vector<address>,
        recipients: vector<address>,
    ) acquires OptimizedTokenData, BatchOperationRegistry {
        let sender_addr = signer::address_of(sender);
        let token_count = vector::length(&token_addresses);

        // 验证
        assert!(token_count == vector::length(&recipients), ERROR_INVALID_LENGTH);
        assert!(token_count <= MAX_BATCH_SIZE, ERROR_BATCH_TOO_LARGE);

        // === 批量所有权验证（优化：一次性验证） ===
        batch_verify_ownership(sender_addr, &token_addresses);

        // === 批量转移 ===
        let i = 0;
        let token_ids = vector::empty<u64>();
        
        while (i < token_count) {
            let token_addr = *vector::borrow(&token_addresses, i);
            let recipient = *vector::borrow(&recipients, i);
            
            // 获取 Token 对象
            let token_obj = object::address_to_object<OptimizedTokenData>(token_addr);
            
            // 执行转移
            object::transfer(sender, token_obj, recipient);
            
            // 记录 Token ID（用于事件）
            let token_data = borrow_global<OptimizedTokenData>(token_addr);
            vector::push_back(&mut token_ids, token_data.id);
            
            i = i + 1;
        };

        // === 记录操作 ===
        if (exists<BatchOperationRegistry>(sender_addr)) {
            let registry = borrow_global_mut<BatchOperationRegistry>(sender_addr);
            let current_timestamp = aptos_framework::timestamp::now_seconds();
            
            smart_table::add(
                &mut registry.operations,
                registry.operation_count,
                BatchOperation {
                    operation_type: 2,  // transfer
                    token_count,
                    executor: sender_addr,
                    timestamp: current_timestamp,
                    gas_used: 0,
                }
            );
            registry.operation_count = registry.operation_count + 1;
        };

        // === 发射批量转移事件 ===
        event::emit(BatchTransferEvent {
            from: sender_addr,
            token_ids,
            recipients,
            count: token_count,
            timestamp: aptos_framework::timestamp::now_seconds(),
        });
    }

    /// 批量验证所有权（优化：避免重复读取）
    fun batch_verify_ownership(
        owner: address,
        token_addresses: &vector<address>,
    ) {
        let i = 0;
        let len = vector::length(token_addresses);
        
        while (i < len) {
            let token_addr = *vector::borrow(token_addresses, i);
            let token_obj = object::address_to_object<OptimizedTokenData>(token_addr);
            
            // 验证所有权
            assert!(object::owner(token_obj) == owner, ERROR_NOT_OWNER);
            
            i = i + 1;
        };
    }

    // ============================================================================
    // 元数据管理优化
    // ============================================================================

    /// 批量更新元数据哈希（IPFS CID）
    /// 只更新哈希引用，实际元数据存储在 IPFS
    public entry fun batch_update_metadata_hash(
        creator: &signer,
        token_addresses: vector<address>,
        metadata_hashes: vector<vector<u8>>,
    ) acquires OptimizedTokenData {
        let creator_addr = signer::address_of(creator);
        let count = vector::length(&token_addresses);

        assert!(count == vector::length(&metadata_hashes), ERROR_INVALID_LENGTH);
        assert!(count <= MAX_BATCH_SIZE, ERROR_BATCH_TOO_LARGE);

        let i = 0;
        while (i < count) {
            let token_addr = *vector::borrow(&token_addresses, i);
            let metadata_hash = *vector::borrow(&metadata_hashes, i);
            
            // 获取 Token 数据
            let token_data = borrow_global_mut<OptimizedTokenData>(token_addr);
            
            // 更新哈希（极小的存储写入）
            token_data.metadata_hash = option::some(metadata_hash);
            
            i = i + 1;
        };
    }

    // ============================================================================
    // 辅助函数
    // ============================================================================

    /// 生成 Token 名称（模板化）
    fun generate_token_name(token_id: u64): String {
        let name = string::utf8(b"NFT #");
        string::append(&mut name, u64_to_string(token_id));
        name
    }

    /// 构造 Token URI（模板化）
    /// 示例：base_uri + token_id + suffix
    /// "ipfs://QmXxx.../" + "12345" + ".json"
    fun construct_uri(base_uri: &String, token_id: u64, suffix: &String): String {
        let uri = *base_uri;
        string::append(&mut uri, u64_to_string(token_id));
        string::append(&mut uri, *suffix);
        uri
    }

    /// 打包属性（位压缩）
    /// 将多个小整数打包到一个 u32 中
    fun pack_attributes(rarity: u8, level: u8, category: u8): u32 {
        let packed: u32 = 0;
        packed = packed | ((rarity as u32) << 0);   // Bits 0-7
        packed = packed | ((level as u32) << 8);    // Bits 8-15
        packed = packed | ((category as u32) << 16); // Bits 16-23
        packed
    }

    /// 解包属性 - 获取稀有度
    public fun get_rarity(token_addr: address): u8 acquires OptimizedTokenData {
        let token_data = borrow_global<OptimizedTokenData>(token_addr);
        ((token_data.packed_attributes >> 0) & 0xFF) as u8
    }

    /// 解包属性 - 获取等级
    public fun get_level(token_addr: address): u8 acquires OptimizedTokenData {
        let token_data = borrow_global<OptimizedTokenData>(token_addr);
        ((token_data.packed_attributes >> 8) & 0xFF) as u8
    }

    /// 解包属性 - 获取类别
    public fun get_category(token_addr: address): u8 acquires OptimizedTokenData {
        let token_data = borrow_global<OptimizedTokenData>(token_addr);
        ((token_data.packed_attributes >> 16) & 0xFF) as u8
    }

    /// 计算 Gas 节省（估算）
    fun calculate_gas_savings(batch_size: u64): u64 {
        // 估算：单个铸造 ~1000 Gas，批量铸造固定成本 500 + 变动成本 400/个
        let individual_cost = batch_size * 1000;
        let batch_cost = 500 + batch_size * 400;
        if (individual_cost > batch_cost) {
            individual_cost - batch_cost
        } else {
            0
        }
    }

    /// u64 转 String（辅助函数）
    fun u64_to_string(value: u64): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        
        let buffer = vector::empty<u8>();
        while (value > 0) {
            let digit = ((value % 10) as u8) + 48;  // ASCII '0' = 48
            vector::push_back(&mut buffer, digit);
            value = value / 10;
        };
        
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }

    // ============================================================================
    // 查询函数
    // ============================================================================

    /// 获取 Collection 统计
    public fun get_collection_stats(collection_addr: address): (u64, u64, u64, u64) 
        acquires OptimizedCollection {
        let collection_data = borrow_global<OptimizedCollection>(collection_addr);
        (
            collection_data.stats.total_minted,
            collection_data.stats.total_transferred,
            collection_data.stats.total_burned,
            collection_data.stats.last_mint_timestamp,
        )
    }

    /// 获取批量操作统计
    public fun get_batch_operation_count(addr: address): u64 
        acquires BatchOperationRegistry {
        if (!exists<BatchOperationRegistry>(addr)) {
            return 0
        };
        borrow_global<BatchOperationRegistry>(addr).operation_count
    }

    /// 获取 Token 完整信息
    public fun get_token_info(token_addr: address): (u64, u8, u8, u8, u64) 
        acquires OptimizedTokenData {
        let token_data = borrow_global<OptimizedTokenData>(token_addr);
        (
            token_data.id,
            get_rarity(token_addr),
            get_level(token_addr),
            get_category(token_addr),
            token_data.mint_timestamp,
        )
    }

    // ============================================================================
    // 测试辅助函数
    // ============================================================================

    #[test_only]
    public fun get_recommended_batch_size(): u64 {
        RECOMMENDED_BATCH_SIZE
    }

    #[test_only]
    public fun get_max_batch_size(): u64 {
        MAX_BATCH_SIZE
    }
}
