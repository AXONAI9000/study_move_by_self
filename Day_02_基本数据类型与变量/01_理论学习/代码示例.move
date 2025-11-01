/// Day 02 代码示例：基本数据类型与变量
/// 本文件包含Move语言数据类型和变量操作的完整示例
module day02::data_types {
    use std::debug;
    use std::vector;
    use std::signer;

    // ============================================
    // 第一部分：整数类型示例
    // ============================================

    /// 展示所有整数类型
    public fun integer_types() {
        // u8: 8位无符号整数 (0-255)
        let tiny: u8 = 255;
        debug::print(&tiny);

        // u64: 64位无符号整数（最常用）
        let normal: u64 = 1_000_000;
        debug::print(&normal);

        // u128: 128位无符号整数
        let large: u128 = 1_000_000_000_000;
        debug::print(&large);

        // u256: 256位无符号整数
        let huge: u256 = 1_000_000_000_000_000_000;
        debug::print(&huge);
    }

    /// 整数字面量的不同表示方法
    public fun integer_literals() {
        // 十进制
        let decimal = 100;

        // 十六进制
        let hex = 0xFF;  // 255
        let hex2 = 0x1A2B;  // 6699

        // 使用下划线提高可读性
        let million = 1_000_000;
        let billion = 1_000_000_000;

        // 类型后缀
        let explicit_u8 = 100u8;
        let explicit_u64 = 1000u64;
        let explicit_u128 = 1000u128;

        debug::print(&decimal);
        debug::print(&hex);
        debug::print(&million);
    }

    /// 整数运算
    public fun integer_operations() {
        let a: u64 = 10;
        let b: u64 = 3;

        // 基本算术运算
        let sum = a + b;        // 13
        let diff = a - b;       // 7
        let product = a * b;    // 30
        let quotient = a / b;   // 3 (整数除法，向下取整)
        let remainder = a % b;  // 1 (取余)

        debug::print(&sum);
        debug::print(&quotient);
        debug::print(&remainder);
    }

    /// 位运算
    public fun bitwise_operations() {
        let a: u8 = 0b1010;  // 10
        let b: u8 = 0b1100;  // 12

        let and = a & b;         // 0b1000 = 8
        let or = a | b;          // 0b1110 = 14
        let xor = a ^ b;         // 0b0110 = 6
        let shift_left = a << 1; // 0b10100 = 20
        let shift_right = a >> 1;// 0b0101 = 5

        debug::print(&and);
        debug::print(&or);
        debug::print(&xor);
    }

    // ============================================
    // 第二部分：布尔类型示例
    // ============================================

    /// 布尔值和逻辑运算
    public fun boolean_operations() {
        let is_true = true;
        let is_false = false;

        // 逻辑运算
        let and_result = is_true && is_false;  // false
        let or_result = is_true || is_false;   // true
        let not_result = !is_true;             // false

        debug::print(&and_result);
        debug::print(&or_result);
    }

    /// 比较运算
    public fun comparison_operations() {
        let x = 10;
        let y = 20;

        let equal = (x == y);           // false
        let not_equal = (x != y);       // true
        let less_than = (x < y);        // true
        let less_equal = (x <= y);      // true
        let greater_than = (x > y);     // false
        let greater_equal = (x >= y);   // false

        debug::print(&less_than);
    }

    /// 短路求值示例
    public fun short_circuit_evaluation(): bool {
        let x = 10;
        
        // 如果第一个条件为false，第二个不会被求值
        let result = (x > 20) && (x < 30);  // false，不检查第二个条件
        
        // 如果第一个条件为true，第二个不会被求值
        let result2 = (x < 20) || (x > 30); // true，不检查第二个条件
        
        result || result2
    }

    // ============================================
    // 第三部分：地址类型示例
    // ============================================

    /// 地址的使用
    public fun address_examples() {
        // 不同的地址表示方法
        let addr1: address = @0x1;
        let addr2: address = @0x42;
        let addr3: address = @day02;

        // 地址比较
        let is_same = (addr1 == addr2);      // false
        let is_different = (addr1 != addr2); // true

        debug::print(&addr1);
        debug::print(&is_same);
    }

    /// 从signer获取地址
    public fun get_signer_address(account: &signer): address {
        signer::address_of(account)
    }

    // ============================================
    // 第四部分：变量声明与可变性
    // ============================================

    /// 不可变变量（默认）
    public fun immutable_variables() {
        let x = 10;
        // x = 20;  // ❌ 编译错误：x是不可变的
        
        let y = x + 5;  // ✅ 可以使用x的值
        debug::print(&y);
    }

    /// 可变变量
    public fun mutable_variables() {
        let mut x = 10;
        debug::print(&x);  // 10
        
        x = 20;  // ✅ 可以修改
        debug::print(&x);  // 20
        
        x = x + 5;
        debug::print(&x);  // 25
    }

    /// 变量遮蔽
    public fun variable_shadowing() {
        let x = 5;
        debug::print(&x);  // 5
        
        let x = x + 1;  // 创建新的x，遮蔽旧的x
        debug::print(&x);  // 6
        
        let x = x * 2;  // 再次遮蔽
        debug::print(&x);  // 12
        
        // 可以改变类型
        let x = true;  // 现在x是bool类型
        debug::print(&x);
    }

    /// 作用域示例
    public fun variable_scope() {
        let x = 10;
        {
            let y = 20;
            let sum = x + y;  // 可以访问外层的x
            debug::print(&sum);  // 30
        }
        // y在这里不可见
        debug::print(&x);  // 10
    }

    // ============================================
    // 第五部分：常量
    // ============================================

    // 常量定义（模块级别）
    const MAX_SUPPLY: u64 = 1_000_000;
    const MIN_BALANCE: u64 = 100;
    const PLATFORM_FEE_PERCENT: u64 = 5;
    const ADMIN_ADDRESS: address = @0x1;
    
    // 错误码常量
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_INVALID_AMOUNT: u64 = 2;
    const E_NOT_AUTHORIZED: u64 = 3;
    const E_OVERFLOW: u64 = 4;

    /// 使用常量
    public fun use_constants(): u64 {
        MAX_SUPPLY
    }

    /// 使用常量计算
    public fun calculate_fee(amount: u64): u64 {
        amount * PLATFORM_FEE_PERCENT / 100
    }

    /// 使用错误码
    public fun check_balance(balance: u64, amount: u64) {
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(balance >= amount, E_INSUFFICIENT_BALANCE);
    }

    // ============================================
    // 第六部分：Move语义（复制 vs 移动）
    // ============================================

    /// 基本类型有Copy能力（会复制）
    public fun copy_semantics() {
        let x: u64 = 10;
        let y = x;  // x被复制给y
        let z = x;  // x仍然可用，再次复制
        
        debug::print(&x);  // ✅ x仍然可用
        debug::print(&y);
        debug::print(&z);
    }

    /// 没有Copy能力的结构体（会移动）
    struct Box has drop {
        value: u64
    }

    public fun move_semantics() {
        let box1 = Box { value: 100 };
        let box2 = box1;  // box1的所有权移动到box2
        
        // let x = box1.value;  // ❌ 编译错误：box1已被移动
        let y = box2.value;  // ✅ box2可用
        debug::print(&y);
    }

    /// 有Copy能力的结构体（会复制）
    struct CopyableData has copy, drop {
        value: u64
    }

    public fun copy_struct() {
        let data1 = CopyableData { value: 100 };
        let data2 = data1;  // data1被复制
        
        debug::print(&data1.value);  // ✅ data1仍然可用
        debug::print(&data2.value);
    }

    // ============================================
    // 第七部分：引用与借用
    // ============================================

    /// 不可变引用
    public fun immutable_reference() {
        let x = 10;
        let ref_x = &x;  // 借用不可变引用
        
        let value = *ref_x;  // 解引用读取值
        debug::print(&value);
        
        // *ref_x = 20;  // ❌ 不能通过不可变引用修改
        debug::print(&x);  // x仍然可用
    }

    /// 可变引用
    public fun mutable_reference() {
        let mut x = 10;
        let ref_x = &mut x;  // 借用可变引用
        
        *ref_x = 20;  // 解引用并修改值
        debug::print(&x);  // 20
    }

    /// 引用作为函数参数
    public fun read_value(x: &u64): u64 {
        *x  // 解引用
    }

    public fun increment(x: &mut u64) {
        *x = *x + 1;
    }

    public fun test_references() {
        let x = 100;
        let value = read_value(&x);
        debug::print(&value);
        
        let mut y = 10;
        increment(&mut y);
        debug::print(&y);  // 11
    }

    /// 结构体字段引用
    struct Person has drop {
        name: vector<u8>,
        age: u8
    }

    public fun modify_person_age(person: &mut Person, new_age: u8) {
        person.age = new_age;
    }

    public fun test_struct_reference() {
        let mut person = Person {
            name: b"Alice",
            age: 25
        };
        
        modify_person_age(&mut person, 26);
        debug::print(&person.age);  // 26
    }

    // ============================================
    // 第八部分：类型转换
    // ============================================

    /// 整数类型转换
    public fun type_casting() {
        // 小类型转大类型（安全）
        let small: u8 = 255;
        let medium: u64 = (small as u64);
        let large: u128 = (medium as u128);
        
        debug::print(&medium);  // 255u64
        debug::print(&large);   // 255u128
        
        // 大类型转小类型（可能截断）
        let big: u64 = 1000;
        let tiny: u8 = (big as u8);  // 232 (1000 % 256)
        debug::print(&tiny);
    }

    /// 安全的类型转换
    const MAX_U8: u64 = 255;
    const E_VALUE_TOO_LARGE: u64 = 100;

    public fun safe_convert_to_u8(value: u64): u8 {
        assert!(value <= MAX_U8, E_VALUE_TOO_LARGE);
        (value as u8)
    }

    // ============================================
    // 第九部分：元组
    // ============================================

    /// 元组基础
    public fun tuple_basics() {
        // 创建元组
        let pair: (u64, bool) = (100, true);
        let triple: (u8, address, bool) = (10, @0x1, false);
        
        // 元组解构
        let (x, y) = pair;
        debug::print(&x);  // 100
        debug::print(&y);  // true
        
        // 部分解构（忽略某些值）
        let (a, _, c) = triple;
        debug::print(&a);  // 10
        debug::print(&c);  // false
    }

    /// 函数返回多个值
    public fun swap(x: u64, y: u64): (u64, u64) {
        (y, x)
    }

    public fun test_swap() {
        let (a, b) = swap(1, 2);
        debug::print(&a);  // 2
        debug::print(&b);  // 1
    }

    /// 返回结构化数据
    public fun get_user_info(): (u64, bool, address) {
        let age: u64 = 25;
        let verified = true;
        let addr = @0x123;
        (age, verified, addr)
    }

    // ============================================
    // 第十部分：实战示例 - 代币余额管理
    // ============================================

    struct Balance has key {
        amount: u64,
        locked: u64,  // 锁定金额
        is_frozen: bool
    }

    const E_ACCOUNT_FROZEN: u64 = 10;
    const E_INSUFFICIENT_UNLOCKED_BALANCE: u64 = 11;

    /// 创建余额账户
    public fun create_balance(account: &signer, initial_amount: u64) {
        let addr = signer::address_of(account);
        assert!(!exists<Balance>(addr), 1);
        
        move_to(account, Balance {
            amount: initial_amount,
            locked: 0,
            is_frozen: false
        });
    }

    /// 查询可用余额
    public fun get_available_balance(addr: address): u64 acquires Balance {
        let balance = borrow_global<Balance>(addr);
        balance.amount - balance.locked
    }

    /// 存款
    public fun deposit(account: &signer, amount: u64) acquires Balance {
        let addr = signer::address_of(account);
        let balance = borrow_global_mut<Balance>(addr);
        
        assert!(!balance.is_frozen, E_ACCOUNT_FROZEN);
        assert!(amount > 0, E_INVALID_AMOUNT);
        
        // 检查溢出
        assert!(balance.amount <= MAX_SUPPLY - amount, E_OVERFLOW);
        
        balance.amount = balance.amount + amount;
    }

    /// 取款
    public fun withdraw(account: &signer, amount: u64) acquires Balance {
        let addr = signer::address_of(account);
        let balance = borrow_global_mut<Balance>(addr);
        
        assert!(!balance.is_frozen, E_ACCOUNT_FROZEN);
        assert!(amount > 0, E_INVALID_AMOUNT);
        
        let available = balance.amount - balance.locked;
        assert!(available >= amount, E_INSUFFICIENT_UNLOCKED_BALANCE);
        
        balance.amount = balance.amount - amount;
    }

    /// 锁定余额
    public fun lock_balance(account: &signer, amount: u64) acquires Balance {
        let addr = signer::address_of(account);
        let balance = borrow_global_mut<Balance>(addr);
        
        let available = balance.amount - balance.locked;
        assert!(available >= amount, E_INSUFFICIENT_UNLOCKED_BALANCE);
        
        balance.locked = balance.locked + amount;
    }

    /// 解锁余额
    public fun unlock_balance(account: &signer, amount: u64) acquires Balance {
        let addr = signer::address_of(account);
        let balance = borrow_global_mut<Balance>(addr);
        
        assert!(balance.locked >= amount, E_INVALID_AMOUNT);
        balance.locked = balance.locked - amount;
    }

    // ============================================
    // 第十一部分：高级示例 - 类型安全的配置管理
    // ============================================

    struct Config has key {
        min_deposit: u64,
        max_deposit: u64,
        fee_percent: u8,  // 0-100
        is_enabled: bool,
        admin: address
    }

    const E_CONFIG_EXISTS: u64 = 20;
    const E_INVALID_FEE: u64 = 21;
    const E_INVALID_DEPOSIT_RANGE: u64 = 22;

    /// 初始化配置
    public fun init_config(
        admin: &signer,
        min_deposit: u64,
        max_deposit: u64,
        fee_percent: u8
    ) {
        let addr = signer::address_of(admin);
        assert!(!exists<Config>(addr), E_CONFIG_EXISTS);
        assert!(fee_percent <= 100, E_INVALID_FEE);
        assert!(min_deposit < max_deposit, E_INVALID_DEPOSIT_RANGE);
        
        move_to(admin, Config {
            min_deposit,
            max_deposit,
            fee_percent,
            is_enabled: true,
            admin: addr
        });
    }

    /// 验证存款金额
    public fun validate_deposit(config_addr: address, amount: u64): bool acquires Config {
        let config = borrow_global<Config>(config_addr);
        
        config.is_enabled &&
        amount >= config.min_deposit &&
        amount <= config.max_deposit
    }

    /// 计算手续费
    public fun calculate_deposit_fee(config_addr: address, amount: u64): u64 acquires Config {
        let config = borrow_global<Config>(config_addr);
        let fee_percent_u64 = (config.fee_percent as u64);
        (amount * fee_percent_u64) / 100
    }

    // ============================================
    // 测试函数
    // ============================================

    #[test]
    fun test_integers() {
        integer_types();
        integer_operations();
    }

    #[test]
    fun test_booleans() {
        boolean_operations();
        comparison_operations();
    }

    #[test]
    fun test_variables() {
        mutable_variables();
        variable_shadowing();
    }

    #[test]
    fun test_move_copy() {
        copy_semantics();
        move_semantics();
        copy_struct();
    }

    #[test]
    fun test_refs() {
        test_references();
        test_struct_reference();
    }

    #[test]
    fun test_tuples() {
        tuple_basics();
        test_swap();
    }

    #[test]
    fun test_casting() {
        type_casting();
        assert!(safe_convert_to_u8(100) == 100, 0);
    }

    #[test]
    #[expected_failure(abort_code = E_VALUE_TOO_LARGE)]
    fun test_casting_fail() {
        safe_convert_to_u8(300);  // 应该失败
    }

    #[test(account = @0x1)]
    fun test_balance(account: &signer) acquires Balance {
        create_balance(account, 1000);
        let addr = signer::address_of(account);
        
        // 存款
        deposit(account, 500);
        assert!(get_available_balance(addr) == 1500, 0);
        
        // 锁定
        lock_balance(account, 200);
        assert!(get_available_balance(addr) == 1300, 1);
        
        // 取款
        withdraw(account, 100);
        assert!(get_available_balance(addr) == 1200, 2);
        
        // 解锁
        unlock_balance(account, 200);
        assert!(get_available_balance(addr) == 1400, 3);
    }

    #[test(admin = @0x1)]
    fun test_config(admin: &signer) acquires Config {
        init_config(admin, 100, 10000, 5);
        let addr = signer::address_of(admin);
        
        assert!(validate_deposit(addr, 500) == true, 0);
        assert!(validate_deposit(addr, 50) == false, 1);  // 太少
        assert!(validate_deposit(addr, 20000) == false, 2);  // 太多
        
        let fee = calculate_deposit_fee(addr, 1000);
        assert!(fee == 50, 3);  // 5% of 1000
    }

    #[test(account = @0x1)]
    #[expected_failure(abort_code = E_ACCOUNT_FROZEN)]
    fun test_frozen_account(account: &signer) acquires Balance {
        create_balance(account, 1000);
        let addr = signer::address_of(account);
        
        let balance = borrow_global_mut<Balance>(addr);
        balance.is_frozen = true;
        
        deposit(account, 100);  // 应该失败
    }
}
