/// Day 01 代码示例：Move语言基础
/// 本文件包含最基础的Move语法示例，帮助你熟悉语言特性
module day01::hello_world {
    use std::debug;
    use std::signer;
    use std::string::{Self, String};

    // ============================================
    // 第一部分：Hello World
    // ============================================

    /// 最简单的函数：打印 Hello World
    public fun hello_world() {
        debug::print(&string::utf8(b"Hello, Move!"));
    }

    /// 带参数的问候函数
    public fun greet(name: vector<u8>) {
        let greeting = string::utf8(b"Hello, ");
        string::append(&mut greeting, string::utf8(name));
        debug::print(&greeting);
    }

    // ============================================
    // 第二部分：基本数据类型
    // ============================================

    /// 整数类型示例
    public fun integer_examples() {
        let small: u8 = 255;        // 8位无符号整数 (0-255)
        let medium: u64 = 1000000;  // 64位无符号整数
        let large: u128 = 1000000000000;  // 128位无符号整数
        let huge: u256 = 1000000000000000000;  // 256位无符号整数
        
        debug::print(&small);
        debug::print(&medium);
        debug::print(&large);
        debug::print(&huge);
    }

    /// 布尔类型示例
    public fun boolean_examples() {
        let is_active: bool = true;
        let is_completed: bool = false;
        
        debug::print(&is_active);
        debug::print(&is_completed);
    }

    /// 地址类型示例
    public fun address_examples() {
        let addr1: address = @0x1;
        let addr2: address = @0x42;
        let addr3: address = @day01;
        
        debug::print(&addr1);
        debug::print(&addr2);
        debug::print(&addr3);
    }

    // ============================================
    // 第三部分：结构体基础
    // ============================================

    /// 简单的用户结构体
    struct User has copy, drop {
        name: String,
        age: u8,
        is_active: bool
    }

    /// 创建用户
    public fun create_user(name: vector<u8>, age: u8): User {
        User {
            name: string::utf8(name),
            age,
            is_active: true
        }
    }

    /// 获取用户信息
    public fun get_user_info(user: &User): (String, u8, bool) {
        (user.name, user.age, user.is_active)
    }

    // ============================================
    // 第四部分：函数基础
    // ============================================

    /// 无参数无返回值
    public fun simple_function() {
        debug::print(&string::utf8(b"Simple function called"));
    }

    /// 有参数无返回值
    public fun function_with_params(x: u64, y: u64) {
        let sum = x + y;
        debug::print(&sum);
    }

    /// 有参数有返回值
    public fun add(x: u64, y: u64): u64 {
        x + y
    }

    /// 多个返回值
    public fun swap(x: u64, y: u64): (u64, u64) {
        (y, x)
    }

    /// 引用参数（不可变引用）
    public fun read_value(x: &u64): u64 {
        *x
    }

    /// 可变引用参数
    public fun increment(x: &mut u64) {
        *x = *x + 1;
    }

    // ============================================
    // 第五部分：控制流
    // ============================================

    /// if-else 条件语句
    public fun max(x: u64, y: u64): u64 {
        if (x > y) {
            x
        } else {
            y
        }
    }

    /// while 循环
    public fun sum_to_n(n: u64): u64 {
        let sum = 0;
        let i = 1;
        while (i <= n) {
            sum = sum + i;
            i = i + 1;
        };
        sum
    }

    /// loop 循环
    public fun countdown(n: u64) {
        let i = n;
        loop {
            if (i == 0) break;
            debug::print(&i);
            i = i - 1;
        }
    }

    // ============================================
    // 第六部分：向量（Vector）基础
    // ============================================

    /// 创建和操作向量
    public fun vector_examples() {
        use std::vector;
        
        // 创建空向量
        let v = vector::empty<u64>();
        
        // 添加元素
        vector::push_back(&mut v, 1);
        vector::push_back(&mut v, 2);
        vector::push_back(&mut v, 3);
        
        // 获取长度
        let len = vector::length(&v);
        debug::print(&len);  // 3
        
        // 访问元素
        let first = *vector::borrow(&v, 0);
        debug::print(&first);  // 1
        
        // 修改元素
        let elem = vector::borrow_mut(&mut v, 0);
        *elem = 10;
        
        // 弹出最后一个元素
        let last = vector::pop_back(&mut v);
        debug::print(&last);  // 3
    }

    // ============================================
    // 第七部分：全局存储基础
    // ============================================

    /// 可以存储到全局存储的资源
    struct Counter has key {
        value: u64
    }

    /// 创建并存储计数器
    public fun create_counter(account: &signer) {
        let counter = Counter { value: 0 };
        move_to(account, counter);
    }

    /// 检查计数器是否存在
    public fun counter_exists(addr: address): bool {
        exists<Counter>(addr)
    }

    /// 获取计数器的值
    public fun get_counter_value(addr: address): u64 acquires Counter {
        borrow_global<Counter>(addr).value
    }

    /// 增加计数器的值
    public fun increment_counter(account: &signer) acquires Counter {
        let addr = signer::address_of(account);
        let counter = borrow_global_mut<Counter>(addr);
        counter.value = counter.value + 1;
    }

    // ============================================
    // 第八部分：常量
    // ============================================

    /// 定义常量
    const MAX_SUPPLY: u64 = 1000000;
    const MIN_BALANCE: u64 = 100;
    const PLATFORM_FEE: u64 = 5;  // 5%

    public fun get_max_supply(): u64 {
        MAX_SUPPLY
    }

    public fun calculate_fee(amount: u64): u64 {
        amount * PLATFORM_FEE / 100
    }

    // ============================================
    // 第九部分：断言和错误处理
    // ============================================

    /// 错误码常量
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_INVALID_AMOUNT: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;

    /// 使用断言验证条件
    public fun withdraw(balance: &mut u64, amount: u64) {
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(*balance >= amount, E_INSUFFICIENT_BALANCE);
        *balance = *balance - amount;
    }

    // ============================================
    // 第十部分：完整示例 - 简单银行
    // ============================================

    /// 银行账户
    struct BankAccount has key {
        balance: u64,
        owner: address
    }

    /// 创建银行账户
    public fun create_bank_account(account: &signer, initial_balance: u64) {
        let addr = signer::address_of(account);
        assert!(!exists<BankAccount>(addr), 100);  // 账户已存在
        
        move_to(account, BankAccount {
            balance: initial_balance,
            owner: addr
        });
    }

    /// 查询余额
    public fun check_balance(addr: address): u64 acquires BankAccount {
        assert!(exists<BankAccount>(addr), 101);  // 账户不存在
        borrow_global<BankAccount>(addr).balance
    }

    /// 存款
    public fun deposit_to_bank(account: &signer, amount: u64) acquires BankAccount {
        let addr = signer::address_of(account);
        assert!(exists<BankAccount>(addr), 101);
        assert!(amount > 0, 102);  // 金额必须大于0
        
        let bank_account = borrow_global_mut<BankAccount>(addr);
        bank_account.balance = bank_account.balance + amount;
    }

    /// 取款
    public fun withdraw_from_bank(account: &signer, amount: u64) acquires BankAccount {
        let addr = signer::address_of(account);
        assert!(exists<BankAccount>(addr), 101);
        assert!(amount > 0, 102);
        
        let bank_account = borrow_global_mut<BankAccount>(addr);
        assert!(bank_account.balance >= amount, 103);  // 余额不足
        
        bank_account.balance = bank_account.balance - amount;
    }

    /// 转账
    public fun transfer(
        from_account: &signer,
        to_addr: address,
        amount: u64
    ) acquires BankAccount {
        let from_addr = signer::address_of(from_account);
        
        assert!(exists<BankAccount>(from_addr), 101);
        assert!(exists<BankAccount>(to_addr), 101);
        assert!(amount > 0, 102);
        
        // 从发送方扣款
        let from_bank = borrow_global_mut<BankAccount>(from_addr);
        assert!(from_bank.balance >= amount, 103);
        from_bank.balance = from_bank.balance - amount;
        
        // 给接收方加款
        let to_bank = borrow_global_mut<BankAccount>(to_addr);
        to_bank.balance = to_bank.balance + amount;
    }

    // ============================================
    // 测试函数
    // ============================================

    #[test]
    fun test_hello_world() {
        hello_world();
        greet(b"Alice");
    }

    #[test]
    fun test_add() {
        let result = add(2, 3);
        assert!(result == 5, 0);
    }

    #[test]
    fun test_swap() {
        let (a, b) = swap(1, 2);
        assert!(a == 2 && b == 1, 0);
    }

    #[test]
    fun test_max() {
        assert!(max(5, 3) == 5, 0);
        assert!(max(2, 8) == 8, 0);
    }

    #[test]
    fun test_sum_to_n() {
        assert!(sum_to_n(5) == 15, 0);  // 1+2+3+4+5 = 15
        assert!(sum_to_n(10) == 55, 0);
    }

    #[test]
    fun test_user() {
        let user = create_user(b"Alice", 25);
        let (name, age, active) = get_user_info(&user);
        assert!(age == 25, 0);
        assert!(active == true, 0);
    }

    #[test(account = @0x1)]
    fun test_counter(account: &signer) acquires Counter {
        create_counter(account);
        let addr = signer::address_of(account);
        
        assert!(counter_exists(addr), 0);
        assert!(get_counter_value(addr) == 0, 0);
        
        increment_counter(account);
        assert!(get_counter_value(addr) == 1, 0);
        
        increment_counter(account);
        assert!(get_counter_value(addr) == 2, 0);
    }

    #[test(alice = @0x1, bob = @0x2)]
    fun test_bank_account(alice: &signer, bob: &signer) acquires BankAccount {
        // Alice 创建账户并存入 1000
        create_bank_account(alice, 1000);
        let alice_addr = signer::address_of(alice);
        assert!(check_balance(alice_addr) == 1000, 0);
        
        // Alice 存款 500
        deposit_to_bank(alice, 500);
        assert!(check_balance(alice_addr) == 1500, 0);
        
        // Alice 取款 300
        withdraw_from_bank(alice, 300);
        assert!(check_balance(alice_addr) == 1200, 0);
        
        // Bob 创建账户
        create_bank_account(bob, 500);
        let bob_addr = signer::address_of(bob);
        
        // Alice 转账 200 给 Bob
        transfer(alice, bob_addr, 200);
        assert!(check_balance(alice_addr) == 1000, 0);
        assert!(check_balance(bob_addr) == 700, 0);
    }

    #[test]
    #[expected_failure(abort_code = E_INVALID_AMOUNT)]
    fun test_withdraw_zero() {
        let mut balance = 1000;
        withdraw(&mut balance, 0);  // 应该失败
    }

    #[test]
    #[expected_failure(abort_code = E_INSUFFICIENT_BALANCE)]
    fun test_withdraw_insufficient() {
        let mut balance = 100;
        withdraw(&mut balance, 200);  // 应该失败
    }
}
