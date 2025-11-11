/// NFT Token Standard 深入 - 完整代码示例
/// 
/// 本模块展示了 Aptos Token Standard v2 的完整实现
/// 包括 Collection 创建、Token 铸造、转移和属性管理

module nft_tutorial::nft_example {
    use std::signer;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use std::vector;
    use aptos_framework::object::{Self, Object, ConstructorRef, DeleteRef, ExtendRef};
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use aptos_token_objects::property_map;
    use aptos_token_objects::royalty;

    // ===================== 错误代码 =====================

    const ERROR_NOT_AUTHORIZED: u64 = 1;
    const ERROR_COLLECTION_NOT_FOUND: u64 = 2;
    const ERROR_TOKEN_NOT_FOUND: u64 = 3;
    const ERROR_MAX_SUPPLY_REACHED: u64 = 4;
    const ERROR_INVALID_ROYALTY: u64 = 5;
    const ERROR_NOT_OWNER: u64 = 6;
    const ERROR_TRANSFER_DISABLED: u64 = 7;

    // ===================== 数据结构 =====================

    /// Collection 配置
    struct CollectionConfig has key {
        /// Collection 对象引用
        extend_ref: ExtendRef,
        /// 可变引用（用于修改元数据）
        mutator_ref: collection::MutatorRef,
    }

    /// Token 引用集合
    struct TokenRefs has key {
        /// 删除引用
        delete_ref: DeleteRef,
        /// 扩展引用
        extend_ref: ExtendRef,
        /// 属性可变引用
        property_mutator_ref: property_map::MutatorRef,
        /// Token 可变引用
        mutator_ref: token::MutatorRef,
    }

    /// Collection 统计
    struct CollectionStats has key {
        /// 当前铸造数量
        minted_count: u64,
        /// 最大供应量（0 表示无限）
        max_supply: u64,
    }

    // ===================== 事件定义 =====================

    #[event]
    struct CollectionCreatedEvent has store, drop {
        creator: address,
        collection_address: address,
        collection_name: String,
        max_supply: u64,
    }

    #[event]
    struct TokenMintedEvent has store, drop {
        creator: address,
        collection: address,
        token_address: address,
        token_name: String,
        recipient: address,
    }

    #[event]
    struct TokenTransferredEvent has store, drop {
        token_address: address,
        from: address,
        to: address,
    }

    #[event]
    struct PropertyUpdatedEvent has store, drop {
        token_address: address,
        key: String,
        old_value: vector<u8>,
        new_value: vector<u8>,
    }

    // ===================== Collection 管理 =====================

    /// 创建固定供应量的 NFT Collection
    public entry fun create_fixed_collection(
        creator: &signer,
        description: String,
        name: String,
        uri: String,
        max_supply: u64,
        royalty_numerator: u64,      // 如 250 表示 2.5%
        royalty_denominator: u64,    // 通常 10000
    ) {
        // 验证版税参数
        assert!(
            royalty_numerator <= royalty_denominator,
            ERROR_INVALID_ROYALTY
        );

        let creator_addr = signer::address_of(creator);

        // 创建 Collection
        let constructor_ref = collection::create_fixed_collection(
            creator,
            description,
            max_supply,
            name,
            option::some(royalty::create(royalty_numerator, royalty_denominator, creator_addr)),
            uri,
        );

        // 生成引用
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = collection::generate_mutator_ref(&constructor_ref);
        let collection_signer = object::generate_signer(&constructor_ref);

        // 存储配置
        move_to(&collection_signer, CollectionConfig {
            extend_ref,
            mutator_ref,
        });

        // 存储统计
        move_to(&collection_signer, CollectionStats {
            minted_count: 0,
            max_supply,
        });

        // 发出事件
        let collection_addr = object::address_from_constructor_ref(&constructor_ref);
        event::emit(CollectionCreatedEvent {
            creator: creator_addr,
            collection_address: collection_addr,
            collection_name: name,
            max_supply,
        });
    }

    /// 创建无限供应量的 NFT Collection
    public entry fun create_unlimited_collection(
        creator: &signer,
        description: String,
        name: String,
        uri: String,
    ) {
        let creator_addr = signer::address_of(creator);

        // 创建 Collection（无版税）
        let constructor_ref = collection::create_unlimited_collection(
            creator,
            description,
            name,
            option::none(),
            uri,
        );

        // 生成引用
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = collection::generate_mutator_ref(&constructor_ref);
        let collection_signer = object::generate_signer(&constructor_ref);

        // 存储配置
        move_to(&collection_signer, CollectionConfig {
            extend_ref,
            mutator_ref,
        });

        // 存储统计（0 表示无限）
        move_to(&collection_signer, CollectionStats {
            minted_count: 0,
            max_supply: 0,
        });

        // 发出事件
        let collection_addr = object::address_from_constructor_ref(&constructor_ref);
        event::emit(CollectionCreatedEvent {
            creator: creator_addr,
            collection_address: collection_addr,
            collection_name: name,
            max_supply: 0,
        });
    }

    // ===================== Token 铸造 =====================

    /// 基础铸造功能
    public entry fun mint_nft(
        creator: &signer,
        collection_name: String,
        description: String,
        name: String,
        uri: String,
    ) acquires CollectionStats {
        let creator_addr = signer::address_of(creator);
        
        // 获取 Collection 地址
        let collection_addr = collection::create_collection_address(&creator_addr, &collection_name);
        
        // 检查供应量限制
        let stats = borrow_global_mut<CollectionStats>(collection_addr);
        if (stats.max_supply > 0) {
            assert!(stats.minted_count < stats.max_supply, ERROR_MAX_SUPPLY_REACHED);
        };
        stats.minted_count = stats.minted_count + 1;

        // 创建 Token
        let constructor_ref = token::create_named_token(
            creator,
            collection_name,
            description,
            name,
            option::none(),  // 使用 Collection 的版税
            uri,
        );

        // 生成引用
        let delete_ref = object::generate_delete_ref(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let property_mutator_ref = property_map::generate_mutator_ref(&constructor_ref);
        let mutator_ref = token::generate_mutator_ref(&constructor_ref);
        let token_signer = object::generate_signer(&constructor_ref);

        // 存储引用
        move_to(&token_signer, TokenRefs {
            delete_ref,
            extend_ref,
            property_mutator_ref,
            mutator_ref,
        });

        // 发出事件
        let token_addr = object::address_from_constructor_ref(&constructor_ref);
        event::emit(TokenMintedEvent {
            creator: creator_addr,
            collection: collection_addr,
            token_address: token_addr,
            token_name: name,
            recipient: creator_addr,
        });
    }

    /// 铸造并转移给接收者
    public entry fun mint_and_transfer(
        creator: &signer,
        collection_name: String,
        description: String,
        name: String,
        uri: String,
        recipient: address,
    ) acquires CollectionStats {
        let creator_addr = signer::address_of(creator);
        
        // 获取 Collection 地址
        let collection_addr = collection::create_collection_address(&creator_addr, &collection_name);
        
        // 检查供应量
        let stats = borrow_global_mut<CollectionStats>(collection_addr);
        if (stats.max_supply > 0) {
            assert!(stats.minted_count < stats.max_supply, ERROR_MAX_SUPPLY_REACHED);
        };
        stats.minted_count = stats.minted_count + 1;

        // 创建 Token
        let constructor_ref = token::create_named_token(
            creator,
            collection_name,
            description,
            name,
            option::none(),
            uri,
        );

        // 生成引用
        let delete_ref = object::generate_delete_ref(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let property_mutator_ref = property_map::generate_mutator_ref(&constructor_ref);
        let mutator_ref = token::generate_mutator_ref(&constructor_ref);
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let token_signer = object::generate_signer(&constructor_ref);

        // 存储引用
        move_to(&token_signer, TokenRefs {
            delete_ref,
            extend_ref,
            property_mutator_ref,
            mutator_ref,
        });

        // 转移给接收者
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, recipient);

        // 发出事件
        let token_addr = object::address_from_constructor_ref(&constructor_ref);
        event::emit(TokenMintedEvent {
            creator: creator_addr,
            collection: collection_addr,
            token_address: token_addr,
            token_name: name,
            recipient,
        });
    }

    /// 批量铸造
    public entry fun batch_mint(
        creator: &signer,
        collection_name: String,
        descriptions: vector<String>,
        names: vector<String>,
        uris: vector<String>,
    ) acquires CollectionStats {
        let len = vector::length(&names);
        assert!(len == vector::length(&descriptions), 1);
        assert!(len == vector::length(&uris), 2);

        let i = 0;
        while (i < len) {
            let description = *vector::borrow(&descriptions, i);
            let name = *vector::borrow(&names, i);
            let uri = *vector::borrow(&uris, i);

            mint_nft(creator, collection_name, description, name, uri);
            i = i + 1;
        };
    }

    // ===================== Token 转移 =====================

    /// 转移 Token
    public entry fun transfer_token(
        owner: &signer,
        token: Object<token::Token>,
        to: address,
    ) {
        let owner_addr = signer::address_of(owner);
        
        // 验证所有权
        assert!(object::is_owner(token, owner_addr), ERROR_NOT_OWNER);
        
        // 转移
        object::transfer(owner, token, to);
        
        // 发出事件
        event::emit(TokenTransferredEvent {
            token_address: object::object_address(&token),
            from: owner_addr,
            to,
        });
    }

    // ===================== 属性管理 =====================

    /// 添加/更新 Token 属性（u64）
    public entry fun set_property_u64(
        creator: &signer,
        token: Object<token::Token>,
        key: String,
        value: u64,
    ) acquires TokenRefs {
        let creator_addr = signer::address_of(creator);
        let token_addr = object::object_address(&token);
        
        // 获取引用
        let refs = borrow_global<TokenRefs>(token_addr);
        
        // 更新属性
        property_map::update_typed(&refs.property_mutator_ref, &key, value);
    }

    /// 添加/更新 Token 属性（String）
    public entry fun set_property_string(
        creator: &signer,
        token: Object<token::Token>,
        key: String,
        value: String,
    ) acquires TokenRefs {
        let creator_addr = signer::address_of(creator);
        let token_addr = object::object_address(&token);
        
        // 获取引用
        let refs = borrow_global<TokenRefs>(token_addr);
        
        // 更新属性
        property_map::update_typed(&refs.property_mutator_ref, &key, value);
    }

    /// 读取 u64 属性
    public fun read_property_u64(
        token: Object<token::Token>,
        key: &String,
    ): u64 {
        property_map::read_u64(&token, key)
    }

    /// 读取 String 属性
    public fun read_property_string(
        token: Object<token::Token>,
        key: &String,
    ): String {
        property_map::read_string(&token, key)
    }

    /// 移除属性
    public entry fun remove_property(
        creator: &signer,
        token: Object<token::Token>,
        key: String,
    ) acquires TokenRefs {
        let token_addr = object::object_address(&token);
        let refs = borrow_global<TokenRefs>(token_addr);
        
        property_map::remove(&refs.property_mutator_ref, &key);
    }

    // ===================== Token 销毁 =====================

    /// 销毁 Token
    public entry fun burn(
        owner: &signer,
        token: Object<token::Token>,
    ) acquires TokenRefs, CollectionStats {
        let owner_addr = signer::address_of(owner);
        
        // 验证所有权
        assert!(object::is_owner(token, owner_addr), ERROR_NOT_OWNER);
        
        // 获取 Token 信息
        let token_addr = object::object_address(&token);
        let collection_obj = token::collection_object(token);
        let collection_addr = object::object_address(&collection_obj);
        
        // 更新统计
        let stats = borrow_global_mut<CollectionStats>(collection_addr);
        stats.minted_count = stats.minted_count - 1;
        
        // 获取 DeleteRef 并删除
        let TokenRefs { delete_ref, extend_ref: _, property_mutator_ref: _, mutator_ref: _ } 
            = move_from<TokenRefs>(token_addr);
        object::delete(delete_ref);
    }

    // ===================== 查询函数 =====================

    /// 获取 Collection 统计信息
    public fun get_collection_stats(collection: Object<collection::Collection>): (u64, u64) acquires CollectionStats {
        let collection_addr = object::object_address(&collection);
        let stats = borrow_global<CollectionStats>(collection_addr);
        (stats.minted_count, stats.max_supply)
    }

    /// 检查是否可以铸造
    public fun can_mint(collection: Object<collection::Collection>): bool acquires CollectionStats {
        let collection_addr = object::object_address(&collection);
        let stats = borrow_global<CollectionStats>(collection_addr);
        
        if (stats.max_supply == 0) {
            true  // 无限供应
        } else {
            stats.minted_count < stats.max_supply
        }
    }

    /// 获取 Token 所有者
    public fun get_token_owner(token: Object<token::Token>): address {
        object::owner(token)
    }

    /// 检查是否拥有 Token
    public fun owns_token(account: address, token: Object<token::Token>): bool {
        object::is_owner(token, account)
    }

    // ===================== 测试辅助函数 =====================

    #[test_only]
    use aptos_framework::account::create_account_for_test;

    #[test_only]
    public fun create_test_collection(creator: &signer): Object<collection::Collection> {
        create_fixed_collection(
            creator,
            string::utf8(b"Test NFT Collection"),
            string::utf8(b"Test NFTs"),
            string::utf8(b"https://example.com/collection"),
            100,  // max supply
            250,  // 2.5% royalty
            10000
        );

        let creator_addr = signer::address_of(creator);
        let collection_name = string::utf8(b"Test NFTs");
        let collection_addr = collection::create_collection_address(&creator_addr, &collection_name);
        object::address_to_object<collection::Collection>(collection_addr)
    }

    #[test(creator = @0x123)]
    public fun test_create_collection(creator: &signer) acquires CollectionStats {
        create_account_for_test(signer::address_of(creator));
        
        let collection = create_test_collection(creator);
        let (minted, max) = get_collection_stats(collection);
        
        assert!(minted == 0, 1);
        assert!(max == 100, 2);
    }

    #[test(creator = @0x123)]
    public fun test_mint_nft(creator: &signer) acquires CollectionStats {
        create_account_for_test(signer::address_of(creator));
        
        let collection = create_test_collection(creator);
        
        mint_nft(
            creator,
            string::utf8(b"Test NFTs"),
            string::utf8(b"A cool NFT"),
            string::utf8(b"NFT #1"),
            string::utf8(b"https://example.com/nft/1")
        );
        
        let (minted, _) = get_collection_stats(collection);
        assert!(minted == 1, 1);
    }
}
