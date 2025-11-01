/// 任务1：用户账户系统
/// 实现完整的用户账户管理功能
module practice::user_account {
    use std::signer;
    use std::error;
    use aptos_framework::timestamp;

    /// 用户账户资源
    struct UserAccount has key {
        username: vector<u8>,
        email: vector<u8>,
        age: u8,
        balance: u64,
        created_at: u64
    }

    /// 错误码定义
    const E_ACCOUNT_ALREADY_EXISTS: u64 = 1;
    const E_ACCOUNT_NOT_FOUND: u64 = 2;
    const E_INSUFFICIENT_BALANCE: u64 = 3;
    const E_NOT_OWNER: u64 = 4;
    const E_BALANCE_NOT_ZERO: u64 = 5;
    const E_SELF_TRANSFER: u64 = 6;

    /// 注册新用户账户
    public fun register(
        account: &signer,
        username: vector<u8>,
        email: vector<u8>,
        age: u8
    ) {
        let addr = signer::address_of(account);
        
        // 检查账户是否已存在
        assert!(!exists<UserAccount>(addr), error::already_exists(E_ACCOUNT_ALREADY_EXISTS));
        
        // 创建新账户
        let user_account = UserAccount {
            username,
            email,
            age,
            balance: 0,
            created_at: timestamp::now_seconds()
        };
        
        move_to(account, user_account);
    }

    /// 更新用户资料
    public fun update_profile(
        account: &signer,
        new_email: vector<u8>,
        new_age: u8
    ) acquires UserAccount {
        let addr = signer::address_of(account);
        assert!(exists<UserAccount>(addr), error::not_found(E_ACCOUNT_NOT_FOUND));
        
        let user_account = borrow_global_mut<UserAccount>(addr);
        user_account.email = new_email;
        user_account.age = new_age;
    }

    /// 获取用户信息
    public fun get_user_info(addr: address): (vector<u8>, vector<u8>, u8, u64) acquires UserAccount {
        assert!(exists<UserAccount>(addr), error::not_found(E_ACCOUNT_NOT_FOUND));
        
        let user_account = borrow_global<UserAccount>(addr);
        (user_account.username, user_account.email, user_account.age, user_account.balance)
    }

    /// 存款
    public fun deposit_balance(account: &signer, amount: u64) acquires UserAccount {
        let addr = signer::address_of(account);
        assert!(exists<UserAccount>(addr), error::not_found(E_ACCOUNT_NOT_FOUND));
        
        let user_account = borrow_global_mut<UserAccount>(addr);
        user_account.balance = user_account.balance + amount;
    }

    /// 取款
    public fun withdraw_balance(account: &signer, amount: u64) acquires UserAccount {
        let addr = signer::address_of(account);
        assert!(exists<UserAccount>(addr), error::not_found(E_ACCOUNT_NOT_FOUND));
        
        let user_account = borrow_global_mut<UserAccount>(addr);
        assert!(user_account.balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
        
        user_account.balance = user_account.balance - amount;
    }

    /// 转账
    public fun transfer_balance(from: &signer, to: address, amount: u64) acquires UserAccount {
        let from_addr = signer::address_of(from);
        
        // 防止自己转给自己
        assert!(from_addr != to, error::invalid_argument(E_SELF_TRANSFER));
        
        // 检查双方账户都存在
        assert!(exists<UserAccount>(from_addr), error::not_found(E_ACCOUNT_NOT_FOUND));
        assert!(exists<UserAccount>(to), error::not_found(E_ACCOUNT_NOT_FOUND));
        
        // 使用作用域避免借用冲突
        // 第一步：从发送者扣款
        {
            let from_account = borrow_global_mut<UserAccount>(from_addr);
            assert!(from_account.balance >= amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
            from_account.balance = from_account.balance - amount;
        };
        
        // 第二步：给接收者加款
        {
            let to_account = borrow_global_mut<UserAccount>(to);
            to_account.balance = to_account.balance + amount;
        };
    }

    /// 删除账户
    public fun delete_account(account: &signer) acquires UserAccount {
        let addr = signer::address_of(account);
        assert!(exists<UserAccount>(addr), error::not_found(E_ACCOUNT_NOT_FOUND));
        
        let UserAccount { username: _, email: _, age: _, balance, created_at: _ } = 
            move_from<UserAccount>(addr);
        
        // 只有余额为0才能删除
        assert!(balance == 0, error::invalid_state(E_BALANCE_NOT_ZERO));
    }

    /// 检查账户是否存在
    public fun account_exists(addr: address): bool {
        exists<UserAccount>(addr)
    }

    #[test_only]
    use std::vector;

    #[test(user1 = @0x1, user2 = @0x2)]
    fun test_account_system(user1: &signer, user2: &signer) acquires UserAccount {
        // 初始化时间戳
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        // 注册
        register(user1, b"Alice", b"alice@example.com", 25);
        register(user2, b"Bob", b"bob@example.com", 30);
        
        // 验证注册成功
        assert!(account_exists(signer::address_of(user1)), 0);
        assert!(account_exists(signer::address_of(user2)), 1);
        
        // 存款
        deposit_balance(user1, 1000);
        deposit_balance(user2, 500);
        
        // 转账
        transfer_balance(user1, signer::address_of(user2), 300);
        
        // 验证余额
        let (_, _, _, balance1) = get_user_info(signer::address_of(user1));
        let (_, _, _, balance2) = get_user_info(signer::address_of(user2));
        assert!(balance1 == 700, 2);
        assert!(balance2 == 800, 3);
    }

    #[test(user = @0x1)]
    fun test_update_profile(user: &signer) acquires UserAccount {
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        register(user, b"Alice", b"alice@example.com", 25);
        
        // 更新资料
        update_profile(user, b"newalice@example.com", 26);
        
        let (_, email, age, _) = get_user_info(signer::address_of(user));
        assert!(email == b"newalice@example.com", 0);
        assert!(age == 26, 1);
    }

    #[test(user = @0x1)]
    #[expected_failure(abort_code = E_ACCOUNT_ALREADY_EXISTS)]
    fun test_duplicate_register(user: &signer) {
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        register(user, b"Alice", b"alice@example.com", 25);
        register(user, b"Bob", b"bob@example.com", 30);  // 应该失败
    }

    #[test(user = @0x1)]
    #[expected_failure(abort_code = E_INSUFFICIENT_BALANCE)]
    fun test_insufficient_balance(user: &signer) acquires UserAccount {
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        register(user, b"Alice", b"alice@example.com", 25);
        deposit_balance(user, 100);
        withdraw_balance(user, 200);  // 应该失败
    }

    #[test(user1 = @0x1, user2 = @0x2)]
    #[expected_failure(abort_code = E_SELF_TRANSFER)]
    fun test_self_transfer(user1: &signer, user2: &signer) acquires UserAccount {
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        register(user1, b"Alice", b"alice@example.com", 25);
        deposit_balance(user1, 1000);
        transfer_balance(user1, signer::address_of(user1), 100);  // 应该失败
    }

    #[test(user = @0x1)]
    fun test_delete_account(user: &signer) acquires UserAccount {
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        register(user, b"Alice", b"alice@example.com", 25);
        
        // 余额为0，可以删除
        delete_account(user);
        assert!(!account_exists(signer::address_of(user)), 0);
    }

    #[test(user = @0x1)]
    #[expected_failure(abort_code = E_BALANCE_NOT_ZERO)]
    fun test_delete_account_with_balance(user: &signer) acquires UserAccount {
        timestamp::set_time_has_started_for_testing(&aptos_framework::account::create_signer_for_test(@0x1));
        
        register(user, b"Alice", b"alice@example.com", 25);
        deposit_balance(user, 100);
        delete_account(user);  // 应该失败，余额不为0
    }
}
