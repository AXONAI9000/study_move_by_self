/// 任务2：资源注册表
/// 实现中心化的资源管理系统
module practice::registry {
    use std::signer;
    use std::error;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;

    /// 数据项
    struct DataItem has store, drop, copy {
        id: u64,
        owner: address,
        content: vector<u8>,
        timestamp: u64
    }

    /// 注册表
    struct Registry has key {
        items: Table<u64, DataItem>,
        owner_items: Table<address, vector<u64>>,
        next_id: u64,
        admin: address
    }

    /// 错误码
    const E_NOT_ADMIN: u64 = 1;
    const E_REGISTRY_ALREADY_EXISTS: u64 = 2;
    const E_REGISTRY_NOT_FOUND: u64 = 3;
    const E_ITEM_NOT_FOUND: u64 = 4;
    const E_NOT_OWNER: u64 = 5;

    /// 初始化注册表（只有管理员可以调用）
    public fun initialize_registry(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // 检查是否已经初始化
        assert!(!exists<Registry>(admin_addr), error::already_exists(E_REGISTRY_ALREADY_EXISTS));
        
        // 创建注册表
        let registry = Registry {
            items: table::new(),
            owner_items: table::new(),
            next_id: 1,
            admin: admin_addr
        };
        
        move_to(admin, registry);
    }

    /// 注册新项目
    public fun register_item(
        user: &signer,
        registry_addr: address,
        content: vector<u8>
    ): u64 acquires Registry {
        assert!(exists<Registry>(registry_addr), error::not_found(E_REGISTRY_NOT_FOUND));
        
        let registry = borrow_global_mut<Registry>(registry_addr);
        let item_id = registry.next_id;
        let user_addr = signer::address_of(user);
        
        // 创建数据项
        let item = DataItem {
            id: item_id,
            owner: user_addr,
            content,
            timestamp: timestamp::now_seconds()
        };
        
        // 添加到 items 表
        table::add(&mut registry.items, item_id, item);
        
        // 更新用户的项目列表
        if (!table::contains(&registry.owner_items, user_addr)) {
            table::add(&mut registry.owner_items, user_addr, vector::empty<u64>());
        };
        
        let user_items = table::borrow_mut(&mut registry.owner_items, user_addr);
        vector::push_back(user_items, item_id);
        
        // 增加下一个ID
        registry.next_id = registry.next_id + 1;
        
        item_id
    }

    /// 获取项目
    public fun get_item(registry_addr: address, item_id: u64): DataItem acquires Registry {
        assert!(exists<Registry>(registry_addr), error::not_found(E_REGISTRY_NOT_FOUND));
        
        let registry = borrow_global<Registry>(registry_addr);
        assert!(table::contains(&registry.items, item_id), error::not_found(E_ITEM_NOT_FOUND));
        
        *table::borrow(&registry.items, item_id)
    }

    /// 更新项目
    public fun update_item(
        user: &signer,
        registry_addr: address,
        item_id: u64,
        new_content: vector<u8>
    ) acquires Registry {
        assert!(exists<Registry>(registry_addr), error::not_found(E_REGISTRY_NOT_FOUND));
        
        let registry = borrow_global_mut<Registry>(registry_addr);
        assert!(table::contains(&registry.items, item_id), error::not_found(E_ITEM_NOT_FOUND));
        
        let item = table::borrow_mut(&mut registry.items, item_id);
        let user_addr = signer::address_of(user);
        
        // 验证是所有者
        assert!(item.owner == user_addr, error::permission_denied(E_NOT_OWNER));
        
        // 更新内容
        item.content = new_content;
        item.timestamp = timestamp::now_seconds();
    }

    /// 删除项目
    public fun delete_item(
        user: &signer,
        registry_addr: address,
        item_id: u64
    ) acquires Registry {
        assert!(exists<Registry>(registry_addr), error::not_found(E_REGISTRY_NOT_FOUND));
        
        let registry = borrow_global_mut<Registry>(registry_addr);
        assert!(table::contains(&registry.items, item_id), error::not_found(E_ITEM_NOT_FOUND));
        
        let user_addr = signer::address_of(user);
        let item = table::borrow(&registry.items, item_id);
        
        // 验证是所有者
        assert!(item.owner == user_addr, error::permission_denied(E_NOT_OWNER));
        
        // 从 items 表中删除
        table::remove(&mut registry.items, item_id);
        
        // 从用户的项目列表中删除
        if (table::contains(&registry.owner_items, user_addr)) {
            let user_items = table::borrow_mut(&mut registry.owner_items, user_addr);
            let (found, index) = vector::index_of(user_items, &item_id);
            if (found) {
                vector::remove(user_items, index);
            };
        };
    }

    /// 获取用户的所有项目ID
    public fun get_user_items(registry_addr: address, user_addr: address): vector<u64> acquires Registry {
        assert!(exists<Registry>(registry_addr), error::not_found(E_REGISTRY_NOT_FOUND));
        
        let registry = borrow_global<Registry>(registry_addr);
        
        if (table::contains(&registry.owner_items, user_addr)) {
            *table::borrow(&registry.owner_items, user_addr)
        } else {
            vector::empty<u64>()
        }
    }

    /// 获取总项目数
    public fun get_total_items(registry_addr: address): u64 acquires Registry {
        assert!(exists<Registry>(registry_addr), error::not_found(E_REGISTRY_NOT_FOUND));
        
        let registry = borrow_global<Registry>(registry_addr);
        registry.next_id - 1
    }

    #[test(admin = @0x100, user1 = @0x1, user2 = @0x2)]
    fun test_registry(admin: &signer, user1: &signer, user2: &signer) acquires Registry {
        // 初始化时间戳
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        // 初始化注册表
        initialize_registry(admin);
        let registry_addr = signer::address_of(admin);
        
        // 注册项目
        let id1 = register_item(user1, registry_addr, b"data1");
        let id2 = register_item(user1, registry_addr, b"data2");
        let id3 = register_item(user2, registry_addr, b"data3");
        
        assert!(id1 == 1 && id2 == 2 && id3 == 3, 0);
        
        // 查询用户项目
        let user1_items = get_user_items(registry_addr, signer::address_of(user1));
        assert!(vector::length(&user1_items) == 2, 1);
        
        // 获取项目
        let item1 = get_item(registry_addr, id1);
        assert!(item1.content == b"data1", 2);
        
        // 更新项目
        update_item(user1, registry_addr, id1, b"updated_data");
        let updated_item = get_item(registry_addr, id1);
        assert!(updated_item.content == b"updated_data", 3);
        
        // 删除项目
        delete_item(user1, registry_addr, id2);
        let user1_items_after = get_user_items(registry_addr, signer::address_of(user1));
        assert!(vector::length(&user1_items_after) == 1, 4);
        
        // 总数检查
        assert!(get_total_items(registry_addr) == 3, 5);
    }

    #[test(admin = @0x100)]
    #[expected_failure(abort_code = E_REGISTRY_ALREADY_EXISTS)]
    fun test_duplicate_init(admin: &signer) {
        initialize_registry(admin);
        initialize_registry(admin);  // 应该失败
    }

    #[test(admin = @0x100, user1 = @0x1, user2 = @0x2)]
    #[expected_failure(abort_code = E_NOT_OWNER)]
    fun test_update_not_owner(admin: &signer, user1: &signer, user2: &signer) acquires Registry {
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        initialize_registry(admin);
        let registry_addr = signer::address_of(admin);
        
        let id1 = register_item(user1, registry_addr, b"data1");
        
        // user2 尝试更新 user1 的项目，应该失败
        update_item(user2, registry_addr, id1, b"hacked");
    }

    #[test(admin = @0x100, user1 = @0x1, user2 = @0x2)]
    #[expected_failure(abort_code = E_NOT_OWNER)]
    fun test_delete_not_owner(admin: &signer, user1: &signer, user2: &signer) acquires Registry {
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        initialize_registry(admin);
        let registry_addr = signer::address_of(admin);
        
        let id1 = register_item(user1, registry_addr, b"data1");
        
        // user2 尝试删除 user1 的项目，应该失败
        delete_item(user2, registry_addr, id1);
    }

    #[test(admin = @0x100, user1 = @0x1)]
    fun test_multiple_items_per_user(admin: &signer, user1: &signer) acquires Registry {
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        initialize_registry(admin);
        let registry_addr = signer::address_of(admin);
        
        // 同一用户注册多个项目
        let id1 = register_item(user1, registry_addr, b"item1");
        let id2 = register_item(user1, registry_addr, b"item2");
        let id3 = register_item(user1, registry_addr, b"item3");
        
        let user_items = get_user_items(registry_addr, signer::address_of(user1));
        assert!(vector::length(&user_items) == 3, 0);
        assert!(vector::contains(&user_items, &id1), 1);
        assert!(vector::contains(&user_items, &id2), 2);
        assert!(vector::contains(&user_items, &id3), 3);
    }
}
