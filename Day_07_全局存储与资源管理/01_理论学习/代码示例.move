/// Day 07 代码示例：全局存储与资源管理
/// 
/// 本文件包含完整的代码示例，展示全局存储操作的各种用法

module learning::storage_examples {
    use std::signer;
    use std::vector;
    
    //=================================================================
    // 示例 1: 基础资源操作
    //=================================================================
    
    /// 用户账户资源
    struct Account has key {
        balance: u64,
        username: vector<u8>
    }
    
    /// 创建账户
    public fun create_account(user: &signer, username: vector<u8>) {
        let account = Account {
            balance: 0,
            username
        };
        move_to(user, account);
    }
    
    /// 查询余额（不可变借用）
    public fun get_balance(addr: address): u64 acquires Account {
        borrow_global<Account>(addr).balance
    }
    
    /// 存款（可变借用）
    public fun deposit(user: &signer, amount: u64) acquires Account {
        let account = borrow_global_mut<Account>(signer::address_of(user));
        account.balance = account.balance + amount;
    }
    
    /// 删除账户（move_from）
    public fun delete_account(user: &signer) acquires Account {
        let Account { balance: _, username: _ } = move_from<Account>(signer::address_of(user));
    }
    
    //=================================================================
    // 示例 2: 多资源访问（acquires 多个资源）
    //=================================================================
    
    struct Profile has key {
        age: u8,
        country: vector<u8>
    }
    
    /// 同时访问多个资源
    public fun get_user_info(addr: address): (vector<u8>, u64, u8) 
        acquires Account, Profile 
    {
        let account = borrow_global<Account>(addr);
        let profile = borrow_global<Profile>(addr);
        
        (account.username, account.balance, profile.age)
    }
    
    /// 同时修改多个资源
    public fun update_user(user: &signer, new_balance: u64, new_age: u8)
        acquires Account, Profile
    {
        let addr = signer::address_of(user);
        
        let account = borrow_global_mut<Account>(addr);
        account.balance = new_balance;
        
        let profile = borrow_global_mut<Profile>(addr);
        profile.age = new_age;
    }
    
    //=================================================================
    // 示例 3: 资源存在性检查
    //=================================================================
    
    /// 安全的余额查询
    public fun safe_get_balance(addr: address): u64 acquires Account {
        assert!(exists<Account>(addr), 1); // ERROR_ACCOUNT_NOT_FOUND
        borrow_global<Account>(addr).balance
    }
    
    /// 懒加载模式
    public fun get_or_create_account(user: &signer): &mut Account acquires Account {
        let addr = signer::address_of(user);
        
        if (!exists<Account>(addr)) {
            create_account(user, b"default");
        };
        
        borrow_global_mut<Account>(addr)
    }
    
    //=================================================================
    // 示例 4: 转账（修改多个地址的资源）
    //=================================================================
    
    const ERROR_INSUFFICIENT_BALANCE: u64 = 100;
    const ERROR_ACCOUNT_NOT_FOUND: u64 = 101;
    
    public fun transfer(from: &signer, to: address, amount: u64) acquires Account {
        let from_addr = signer::address_of(from);
        
        // 检查两个账户都存在
        assert!(exists<Account>(from_addr), ERROR_ACCOUNT_NOT_FOUND);
        assert!(exists<Account>(to), ERROR_ACCOUNT_NOT_FOUND);
        
        // 扣除发送方余额（使用作用域避免借用冲突）
        {
            let from_account = borrow_global_mut<Account>(from_addr);
            assert!(from_account.balance >= amount, ERROR_INSUFFICIENT_BALANCE);
            from_account.balance = from_account.balance - amount;
        };
        
        // 增加接收方余额
        {
            let to_account = borrow_global_mut<Account>(to);
            to_account.balance = to_account.balance + amount;
        };
    }
    
    //=================================================================
    // 示例 5: 泛型资源
    //=================================================================
    
    struct Box<T: store> has key {
        value: T
    }
    
    public fun store_value<T: store>(user: &signer, value: T) {
        move_to(user, Box<T> { value });
    }
    
    public fun get_value<T: store>(addr: address): &T acquires Box {
        &borrow_global<Box<T>>(addr).value
    }
    
    public fun update_value<T: store>(user: &signer, new_value: T) acquires Box {
        let box_ref = borrow_global_mut<Box<T>>(signer::address_of(user));
        box_ref.value = new_value;
    }
    
    //=================================================================
    // 示例 6: 资源注册表模式
    //=================================================================
    
    use std::table::{Self, Table};
    
    struct Item has store, drop {
        id: u64,
        data: vector<u8>
    }
    
    struct Registry has key {
        items: Table<address, Item>,
        next_id: u64
    }
    
    /// 初始化注册表（通常在模块初始化时调用）
    public fun init_registry(admin: &signer) {
        move_to(admin, Registry {
            items: table::new(),
            next_id: 1
        });
    }
    
    /// 注册项目
    public fun register_item(
        user: &signer, 
        data: vector<u8>,
        registry_addr: address
    ) acquires Registry {
        let registry = borrow_global_mut<Registry>(registry_addr);
        let item = Item {
            id: registry.next_id,
            data
        };
        registry.next_id = registry.next_id + 1;
        
        table::add(&mut registry.items, signer::address_of(user), item);
    }
    
    /// 查询项目
    public fun get_item(user_addr: address, registry_addr: address): &Item acquires Registry {
        let registry = borrow_global<Registry>(registry_addr);
        table::borrow(&registry.items, user_addr)
    }
    
    //=================================================================
    // 示例 7: 权限控制模式
    //=================================================================
    
    struct AdminCapability has key, store {}
    
    struct Config has key {
        max_supply: u64,
        is_paused: bool
    }
    
    /// 初始化管理员（部署时调用）
    public fun initialize(admin: &signer) {
        move_to(admin, AdminCapability {});
        move_to(admin, Config {
            max_supply: 1000000,
            is_paused: false
        });
    }
    
    /// 只有管理员可以调用
    public fun admin_set_max_supply(admin: &signer, new_max: u64) 
        acquires AdminCapability, Config 
    {
        let admin_addr = signer::address_of(admin);
        // 验证管理员权限
        assert!(exists<AdminCapability>(admin_addr), 403);
        
        let config = borrow_global_mut<Config>(admin_addr);
        config.max_supply = new_max;
    }
    
    /// 任何人都可以读取配置
    public fun get_max_supply(config_addr: address): u64 acquires Config {
        borrow_global<Config>(config_addr).max_supply
    }
    
    //=================================================================
    // 示例 8: 资源生命周期完整示例
    //=================================================================
    
    struct Wallet has key {
        coins: vector<u64>
    }
    
    /// 1. 创建
    public fun create_wallet(user: &signer) {
        move_to(user, Wallet { coins: vector::empty() });
    }
    
    /// 2. 读取
    public fun wallet_size(addr: address): u64 acquires Wallet {
        vector::length(&borrow_global<Wallet>(addr).coins)
    }
    
    /// 3. 修改
    public fun add_coin(user: &signer, amount: u64) acquires Wallet {
        let wallet = borrow_global_mut<Wallet>(signer::address_of(user));
        vector::push_back(&mut wallet.coins, amount);
    }
    
    /// 4. 销毁
    public fun destroy_wallet(user: &signer) acquires Wallet {
        let addr = signer::address_of(user);
        let Wallet { coins } = move_from<Wallet>(addr);
        // coins 会被自动丢弃（因为 vector 有 drop 能力）
        vector::destroy_empty(coins); // 确保为空
    }
    
    //=================================================================
    // 示例 9: 复杂的借用场景
    //=================================================================
    
    /// 错误示例：借用冲突
    // public fun borrow_conflict(addr: address) acquires Account {
    //     let account_ref = borrow_global<Account>(addr);
    //     let account_mut = borrow_global_mut<Account>(addr); // 编译错误！
    // }
    
    /// 正确：使用作用域分离
    public fun borrow_correctly(addr: address): (vector<u8>, u64) acquires Account {
        let username = {
            let account = borrow_global<Account>(addr);
            account.username
        };
        
        let new_balance = {
            let account = borrow_global_mut<Account>(addr);
            account.balance = account.balance + 10;
            account.balance
        };
        
        (username, new_balance)
    }
    
    //=================================================================
    // 示例 10: 数据迁移
    //=================================================================
    
    struct DataV1 has key {
        value: u64
    }
    
    struct DataV2 has key {
        value: u64,
        version: u8,
        extra: vector<u8>
    }
    
    /// 从 V1 迁移到 V2
    public fun migrate_to_v2(user: &signer) acquires DataV1 {
        let addr = signer::address_of(user);
        
        // 移除旧数据
        let DataV1 { value } = move_from<DataV1>(addr);
        
        // 存储新数据
        move_to(user, DataV2 {
            value,
            version: 2,
            extra: b"migrated"
        });
    }
    
    //=================================================================
    // 测试函数
    //=================================================================
    
    #[test(user1 = @0x1, user2 = @0x2)]
    public fun test_basic_operations(user1: &signer, user2: &signer) acquires Account {
        // 创建账户
        create_account(user1, b"Alice");
        create_account(user2, b"Bob");
        
        // 存款
        deposit(user1, 1000);
        deposit(user2, 500);
        
        // 查询余额
        assert!(get_balance(signer::address_of(user1)) == 1000, 0);
        assert!(get_balance(signer::address_of(user2)) == 500, 1);
        
        // 转账
        transfer(user1, signer::address_of(user2), 300);
        
        // 验证转账后余额
        assert!(get_balance(signer::address_of(user1)) == 700, 2);
        assert!(get_balance(signer::address_of(user2)) == 800, 3);
    }
    
    #[test(admin = @0x100)]
    public fun test_registry(admin: &signer) acquires Registry {
        // 初始化注册表
        init_registry(admin);
        
        // 注册项目
        register_item(admin, b"item1", signer::address_of(admin));
        
        // 查询
        let item = get_item(signer::address_of(admin), signer::address_of(admin));
        assert!(item.id == 1, 0);
    }
}
