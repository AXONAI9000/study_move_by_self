// ============================================================================
// Day 09: 错误处理与断言最佳实践 - 代码示例
// ============================================================================

// ============================================================================
// 示例 1: 基本错误处理
// ============================================================================

module 0x1::basic_errors {
    use std::signer;
    
    // 错误码定义
    const ERROR_INVALID_AMOUNT: u64 = 1;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 2;
    const ERROR_ACCOUNT_NOT_FOUND: u64 = 3;
    
    struct Account has key {
        balance: u64
    }
    
    /// 使用 assert! 进行条件检查
    public fun withdraw(account: &signer, amount: u64) acquires Account {
        // 检查金额有效性
        assert!(amount > 0, ERROR_INVALID_AMOUNT);
        
        let addr = signer::address_of(account);
        
        // 检查账户存在
        assert!(exists<Account>(addr), ERROR_ACCOUNT_NOT_FOUND);
        
        let account_ref = borrow_global_mut<Account>(addr);
        
        // 检查余额充足
        assert!(
            account_ref.balance >= amount,
            ERROR_INSUFFICIENT_BALANCE
        );
        
        account_ref.balance = account_ref.balance - amount;
    }
    
    /// 使用 abort 语句
    public fun withdraw_with_abort(
        account: &signer,
        amount: u64
    ) acquires Account {
        if (amount == 0) {
            abort ERROR_INVALID_AMOUNT
        };
        
        let addr = signer::address_of(account);
        if (!exists<Account>(addr)) {
            abort ERROR_ACCOUNT_NOT_FOUND
        };
        
        let account_ref = borrow_global_mut<Account>(addr);
        if (account_ref.balance < amount) {
            abort ERROR_INSUFFICIENT_BALANCE
        };
        
        account_ref.balance = account_ref.balance - amount;
    }
}

// ============================================================================
// 示例 2: 分类错误码系统
// ============================================================================

module 0x1::categorized_errors {
    // ========== 通用错误 (1-99) ==========
    const ERROR_INVALID_ARGUMENT: u64 = 1;
    const ERROR_OUT_OF_RANGE: u64 = 2;
    const ERROR_NOT_FOUND: u64 = 3;
    const ERROR_ALREADY_EXISTS: u64 = 4;
    
    // ========== 权限错误 (100-199) ==========
    const ERROR_NOT_AUTHORIZED: u64 = 100;
    const ERROR_NOT_OWNER: u64 = 101;
    const ERROR_NOT_ADMIN: u64 = 102;
    const ERROR_INSUFFICIENT_PRIVILEGES: u64 = 103;
    
    // ========== 资源错误 (200-299) ==========
    const ERROR_INSUFFICIENT_BALANCE: u64 = 200;
    const ERROR_INSUFFICIENT_ALLOWANCE: u64 = 201;
    const ERROR_ZERO_AMOUNT: u64 = 202;
    const ERROR_AMOUNT_TOO_LARGE: u64 = 203;
    
    // ========== 状态错误 (300-399) ==========
    const ERROR_NOT_INITIALIZED: u64 = 300;
    const ERROR_ALREADY_INITIALIZED: u64 = 301;
    const ERROR_PAUSED: u64 = 302;
    const ERROR_NOT_PAUSED: u64 = 303;
    const ERROR_EXPIRED: u64 = 304;
    
    struct Config has key {
        initialized: bool,
        paused: bool,
        admin: address,
    }
    
    public fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<Config>(addr), ERROR_ALREADY_INITIALIZED);
        
        move_to(account, Config {
            initialized: true,
            paused: false,
            admin: addr,
        });
    }
    
    public fun pause(account: &signer) acquires Config {
        let addr = signer::address_of(account);
        assert!(exists<Config>(addr), ERROR_NOT_INITIALIZED);
        
        let config = borrow_global_mut<Config>(addr);
        assert!(config.admin == addr, ERROR_NOT_ADMIN);
        assert!(!config.paused, ERROR_PAUSED);
        
        config.paused = true;
    }
}

// ============================================================================
// 示例 3: 权限验证模式
// ============================================================================

module 0x1::permission_checks {
    use std::signer;
    use std::vector;
    
    const ERROR_NOT_OWNER: u64 = 1;
    const ERROR_NOT_ADMIN: u64 = 2;
    const ERROR_UNAUTHORIZED: u64 = 3;
    
    struct Resource has key {
        owner: address,
        data: u64,
    }
    
    struct AdminList has key {
        admins: vector<address>,
    }
    
    /// 模式 1: 直接所有者检查
    public fun owner_only_operation(
        account: &signer,
        resource_addr: address
    ) acquires Resource {
        let resource = borrow_global<Resource>(resource_addr);
        let caller = signer::address_of(account);
        
        assert!(caller == resource.owner, ERROR_NOT_OWNER);
        
        // 执行特权操作...
    }
    
    /// 模式 2: 管理员检查
    public fun admin_only_operation(
        admin: &signer
    ) acquires AdminList {
        let admin_addr = signer::address_of(admin);
        let admin_list = borrow_global<AdminList>(@deployer);
        
        assert!(
            vector::contains(&admin_list.admins, &admin_addr),
            ERROR_NOT_ADMIN
        );
        
        // 执行管理员操作...
    }
    
    /// 模式 3: 使用辅助函数
    fun require_owner(account: &signer, expected: address) {
        assert!(
            signer::address_of(account) == expected,
            ERROR_NOT_OWNER
        );
    }
    
    fun require_admin(account: &signer) acquires AdminList {
        let addr = signer::address_of(account);
        let admin_list = borrow_global<AdminList>(@deployer);
        assert!(
            vector::contains(&admin_list.admins, &addr),
            ERROR_NOT_ADMIN
        );
    }
    
    public fun privileged_operation(
        account: &signer,
        resource_addr: address
    ) acquires Resource, AdminList {
        let resource = borrow_global<Resource>(resource_addr);
        
        // 必须是所有者或管理员
        let caller = signer::address_of(account);
        if (caller != resource.owner) {
            require_admin(account);
        };
        
        // 执行操作...
    }
}

// ============================================================================
// 示例 4: 资源状态验证
// ============================================================================

module 0x1::state_validation {
    use std::signer;
    
    const ERROR_NOT_INITIALIZED: u64 = 1;
    const ERROR_ALREADY_INITIALIZED: u64 = 2;
    const ERROR_PAUSED: u64 = 3;
    const ERROR_ALREADY_ACTIVE: u64 = 4;
    
    const STATE_CREATED: u8 = 0;
    const STATE_INITIALIZED: u8 = 1;
    const STATE_ACTIVE: u8 = 2;
    const STATE_PAUSED: u8 = 3;
    const STATE_CLOSED: u8 = 4;
    
    struct Contract has key {
        state: u8,
        owner: address,
    }
    
    /// 创建合约
    public fun create(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<Contract>(addr), ERROR_ALREADY_INITIALIZED);
        
        move_to(account, Contract {
            state: STATE_CREATED,
            owner: addr,
        });
    }
    
    /// 初始化合约
    public fun initialize(account: &signer) acquires Contract {
        let addr = signer::address_of(account);
        assert!(exists<Contract>(addr), ERROR_NOT_INITIALIZED);
        
        let contract = borrow_global_mut<Contract>(addr);
        assert!(contract.state == STATE_CREATED, ERROR_ALREADY_INITIALIZED);
        
        contract.state = STATE_INITIALIZED;
    }
    
    /// 激活合约
    public fun activate(account: &signer) acquires Contract {
        let addr = signer::address_of(account);
        let contract = borrow_global_mut<Contract>(addr);
        
        assert!(
            contract.state == STATE_INITIALIZED,
            ERROR_NOT_INITIALIZED
        );
        
        contract.state = STATE_ACTIVE;
    }
    
    /// 暂停合约
    public fun pause(account: &signer) acquires Contract {
        let addr = signer::address_of(account);
        let contract = borrow_global_mut<Contract>(addr);
        
        assert!(contract.state == STATE_ACTIVE, ERROR_ALREADY_ACTIVE);
        contract.state = STATE_PAUSED;
    }
    
    /// 操作只能在活跃状态执行
    public fun active_only_operation(account: &signer) acquires Contract {
        let addr = signer::address_of(account);
        let contract = borrow_global<Contract>(addr);
        
        assert!(contract.state == STATE_ACTIVE, ERROR_PAUSED);
        
        // 执行操作...
    }
}

// ============================================================================
// 示例 5: 数值范围验证
// ============================================================================

module 0x1::range_validation {
    const ERROR_ZERO_AMOUNT: u64 = 1;
    const ERROR_AMOUNT_TOO_LARGE: u64 = 2;
    const ERROR_OVERFLOW: u64 = 3;
    const ERROR_PERCENTAGE_INVALID: u64 = 4;
    const ERROR_OUT_OF_RANGE: u64 = 5;
    
    const MAX_SUPPLY: u64 = 1_000_000_000;
    const MIN_TRANSFER: u64 = 100;
    const MAX_TRANSFER: u64 = 1_000_000;
    
    /// 验证金额在有效范围内
    public fun validate_transfer_amount(amount: u64) {
        assert!(amount > 0, ERROR_ZERO_AMOUNT);
        assert!(amount >= MIN_TRANSFER, ERROR_AMOUNT_TOO_LARGE);
        assert!(amount <= MAX_TRANSFER, ERROR_AMOUNT_TOO_LARGE);
    }
    
    /// 验证百分比 (0-100)
    public fun validate_percentage(percentage: u64) {
        assert!(percentage <= 100, ERROR_PERCENTAGE_INVALID);
    }
    
    /// 安全加法 (检查溢出)
    public fun safe_add(a: u64, b: u64): u64 {
        let result = a + b;
        assert!(result >= a && result >= b, ERROR_OVERFLOW);
        result
    }
    
    /// 安全乘法
    public fun safe_mul(a: u64, b: u64): u64 {
        if (a == 0 || b == 0) {
            return 0
        };
        
        let result = a * b;
        assert!(result / a == b, ERROR_OVERFLOW);
        result
    }
    
    /// 计算带验证的手续费
    public fun calculate_fee(
        amount: u64,
        fee_percentage: u64
    ): u64 {
        validate_percentage(fee_percentage);
        (amount * fee_percentage) / 100
    }
}

// ============================================================================
// 示例 6: Option 模式处理可选值
// ============================================================================

module 0x1::option_pattern {
    use std::option::{Self, Option};
    use std::signer;
    
    const ERROR_NOT_FOUND: u64 = 1;
    
    struct UserProfile has key {
        name: vector<u8>,
        age: u64,
    }
    
    /// 不使用 Option - 查询失败会 abort
    public fun get_user_age_unsafe(addr: address): u64 acquires UserProfile {
        assert!(exists<UserProfile>(addr), ERROR_NOT_FOUND);
        let profile = borrow_global<UserProfile>(addr);
        profile.age
    }
    
    /// 使用 Option - 查询失败返回 None
    public fun try_get_user_age(addr: address): Option<u64> acquires UserProfile {
        if (!exists<UserProfile>(addr)) {
            return option::none()
        };
        
        let profile = borrow_global<UserProfile>(addr);
        option::some(profile.age)
    }
    
    /// 使用 Option 处理批量查询
    public fun get_multiple_ages(
        addresses: vector<address>
    ): vector<Option<u64>> acquires UserProfile {
        let results = vector::empty<Option<u64>>();
        let i = 0;
        let len = vector::length(&addresses);
        
        while (i < len) {
            let addr = *vector::borrow(&addresses, i);
            let age_opt = try_get_user_age(addr);
            vector::push_back(&mut results, age_opt);
            i = i + 1;
        };
        
        results
    }
    
    /// 使用 Option 的链式操作
    public fun get_age_or_default(addr: address, default: u64): u64 
    acquires UserProfile {
        let age_opt = try_get_user_age(addr);
        
        if (option::is_some(&age_opt)) {
            *option::borrow(&age_opt)
        } else {
            default
        }
    }
}

// ============================================================================
// 示例 7: 复杂的转账函数(完整错误处理)
// ============================================================================

module 0x1::safe_transfer {
    use std::signer;
    use aptos_framework::timestamp;
    
    // 错误码定义
    const ERROR_ACCOUNT_NOT_FOUND: u64 = 101;
    const ERROR_INVALID_AMOUNT: u64 = 201;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 202;
    const ERROR_SELF_TRANSFER: u64 = 203;
    const ERROR_ACCOUNT_FROZEN: u64 = 301;
    const ERROR_RECIPIENT_BLOCKED: u64 = 302;
    const ERROR_DAILY_LIMIT_EXCEEDED: u64 = 401;
    const ERROR_RATE_LIMITED: u64 = 402;
    
    struct Account has key {
        balance: u64,
        frozen: bool,
        blocked: bool,
        daily_transferred: u64,
        last_transfer_day: u64,
        last_transfer_time: u64,
    }
    
    const DAILY_LIMIT: u64 = 10000;
    const MIN_TRANSFER_INTERVAL: u64 = 60; // 秒
    
    /// 完整的安全转账函数
    public fun safe_transfer(
        from: &signer,
        to: address,
        amount: u64
    ) acquires Account {
        // 1. 基本参数验证
        assert!(amount > 0, ERROR_INVALID_AMOUNT);
        
        let from_addr = signer::address_of(from);
        assert!(from_addr != to, ERROR_SELF_TRANSFER);
        
        // 2. 账户存在性检查
        assert!(exists<Account>(from_addr), ERROR_ACCOUNT_NOT_FOUND);
        assert!(exists<Account>(to), ERROR_ACCOUNT_NOT_FOUND);
        
        // 3. 发送方验证
        {
            let from_account = borrow_global<Account>(from_addr);
            assert!(!from_account.frozen, ERROR_ACCOUNT_FROZEN);
            assert!(
                from_account.balance >= amount,
                ERROR_INSUFFICIENT_BALANCE
            );
            
            // 速率限制检查
            let now = timestamp::now_seconds();
            let time_since_last = now - from_account.last_transfer_time;
            assert!(
                time_since_last >= MIN_TRANSFER_INTERVAL,
                ERROR_RATE_LIMITED
            );
            
            // 每日限额检查
            let today = now / 86400;
            if (from_account.last_transfer_day == today) {
                assert!(
                    from_account.daily_transferred + amount <= DAILY_LIMIT,
                    ERROR_DAILY_LIMIT_EXCEEDED
                );
            };
        };
        
        // 4. 接收方验证
        {
            let to_account = borrow_global<Account>(to);
            assert!(!to_account.frozen, ERROR_ACCOUNT_FROZEN);
            assert!(!to_account.blocked, ERROR_RECIPIENT_BLOCKED);
        };
        
        // 5. 执行转账
        {
            let from_account = borrow_global_mut<Account>(from_addr);
            from_account.balance = from_account.balance - amount;
            
            let now = timestamp::now_seconds();
            from_account.last_transfer_time = now;
            
            let today = now / 86400;
            if (from_account.last_transfer_day != today) {
                from_account.daily_transferred = amount;
                from_account.last_transfer_day = today;
            } else {
                from_account.daily_transferred = 
                    from_account.daily_transferred + amount;
            };
        };
        
        {
            let to_account = borrow_global_mut<Account>(to);
            to_account.balance = to_account.balance + amount;
        };
    }
}

// ============================================================================
// 示例 8: 自定义 Result 类型
// ============================================================================

module 0x1::custom_result {
    struct Result<T> has drop, copy {
        success: bool,
        value: T,
        error_code: u64,
    }
    
    public fun ok<T: drop + copy>(value: T): Result<T> {
        Result {
            success: true,
            value,
            error_code: 0,
        }
    }
    
    public fun err<T: drop + copy>(
        default_value: T,
        error_code: u64
    ): Result<T> {
        Result {
            success: false,
            value: default_value,
            error_code,
        }
    }
    
    public fun is_ok<T>(result: &Result<T>): bool {
        result.success
    }
    
    public fun unwrap<T: copy>(result: &Result<T>): T {
        assert!(result.success, result.error_code);
        result.value
    }
    
    public fun unwrap_or<T: copy>(result: &Result<T>, default: T): T {
        if (result.success) {
            result.value
        } else {
            default
        }
    }
    
    // 使用示例
    const ERROR_DIVISION_BY_ZERO: u64 = 1;
    
    public fun safe_divide(a: u64, b: u64): Result<u64> {
        if (b == 0) {
            return err(0, ERROR_DIVISION_BY_ZERO)
        };
        ok(a / b)
    }
    
    public fun calculate() {
        let result = safe_divide(100, 5);
        if (is_ok(&result)) {
            let value = unwrap(&result);
            // 使用 value (20)
        } else {
            // 处理错误
        };
    }
}

// ============================================================================
// 示例 9: 测试错误处理
// ============================================================================

#[test_only]
module 0x1::error_tests {
    use 0x1::basic_errors;
    
    const ERROR_INVALID_AMOUNT: u64 = 1;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 2;
    
    #[test]
    #[expected_failure(abort_code = ERROR_INVALID_AMOUNT)]
    public fun test_zero_amount_fails() {
        let account = create_test_account();
        basic_errors::withdraw(&account, 0);
    }
    
    #[test]
    #[expected_failure(abort_code = ERROR_INSUFFICIENT_BALANCE)]
    public fun test_insufficient_balance_fails() {
        let account = create_test_account();
        // 假设账户余额为 100
        basic_errors::withdraw(&account, 200);
    }
    
    #[test]
    public fun test_valid_withdrawal() {
        let account = create_test_account();
        // 这个应该成功
        basic_errors::withdraw(&account, 50);
    }
    
    fun create_test_account(): signer {
        // 创建测试账户的辅助函数
        account::create_account_for_test(@0x1)
    }
}
