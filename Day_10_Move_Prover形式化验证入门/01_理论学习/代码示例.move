/// # Move Prover 代码示例集
/// 
/// 本文件包含了 Move Prover 的完整示例，展示从简单到复杂的验证场景。

module prover_examples::math_verified {
    /// 错误码
    const ERROR_OVERFLOW: u64 = 1;
    const ERROR_DIVISION_BY_ZERO: u64 = 2;
    const ERROR_UNDERFLOW: u64 = 3;

    // ========== 示例 1: 简单函数验证 ==========

    /// 安全的加法
    public fun safe_add(a: u64, b: u64): u64 {
        assert!(18446744073709551615 - a >= b, ERROR_OVERFLOW);
        a + b
    }

    spec safe_add {
        // 当会溢出时 abort
        aborts_if a > 18446744073709551615 - b with ERROR_OVERFLOW;
        
        // 不溢出时返回正确结果
        ensures result == a + b;
        
        // 结果大于等于两个输入
        ensures result >= a;
        ensures result >= b;
    }

    /// 安全的减法
    public fun safe_sub(a: u64, b: u64): u64 {
        assert!(a >= b, ERROR_UNDERFLOW);
        a - b
    }

    spec safe_sub {
        aborts_if a < b with ERROR_UNDERFLOW;
        ensures result == a - b;
        ensures result <= a;
    }

    /// 安全的乘法
    public fun safe_mul(a: u64, b: u64): u64 {
        if (a == 0 || b == 0) {
            return 0
        };
        let result = a * b;
        assert!(result / a == b, ERROR_OVERFLOW);
        result
    }

    spec safe_mul {
        aborts_if a != 0 && b != 0 && a * b > 18446744073709551615;
        ensures result == a * b;
    }

    /// 安全的除法
    public fun safe_div(a: u64, b: u64): u64 {
        assert!(b != 0, ERROR_DIVISION_BY_ZERO);
        a / b
    }

    spec safe_div {
        aborts_if b == 0 with ERROR_DIVISION_BY_ZERO;
        ensures result == a / b;
        ensures result * b <= a;
        ensures (result + 1) * b > a || result == a / b;
    }

    // ========== 示例 2: 使用 old() 的函数 ==========

    /// 递增函数
    public fun increment(x: &mut u64) {
        *x = *x + 1;
    }

    spec increment {
        aborts_if x + 1 > 18446744073709551615;
        ensures x == old(x) + 1;
    }

    /// 递增指定数量
    public fun increment_by(x: &mut u64, amount: u64) {
        *x = *x + amount;
    }

    spec increment_by {
        requires x + amount <= 18446744073709551615;
        ensures x == old(x) + amount;
    }

    // ========== 示例 3: 最大最小值 ==========

    /// 返回两数中的最大值
    public fun max(a: u64, b: u64): u64 {
        if (a >= b) a else b
    }

    spec max {
        ensures result == a || result == b;
        ensures result >= a && result >= b;
        ensures (a >= b ==> result == a);
        ensures (b > a ==> result == b);
    }

    /// 返回两数中的最小值
    public fun min(a: u64, b: u64): u64 {
        if (a <= b) a else b
    }

    spec min {
        ensures result == a || result == b;
        ensures result <= a && result <= b;
        ensures (a <= b ==> result == a);
        ensures (b < a ==> result == b);
    }
}

// ========== 示例 4: 资源和全局存储验证 ==========

module prover_examples::counter_verified {
    use std::signer;

    /// 错误码
    const ERROR_NOT_INITIALIZED: u64 = 1;
    const ERROR_ALREADY_EXISTS: u64 = 2;
    const ERROR_OVERFLOW: u64 = 3;

    /// 计数器资源
    struct Counter has key {
        value: u64
    }

    /// 初始化计数器
    public fun init(account: &signer) {
        let addr = signer::address_of(account);
        assert!(!exists<Counter>(addr), ERROR_ALREADY_EXISTS);
        move_to(account, Counter { value: 0 });
    }

    spec init {
        let addr = signer::address_of(account);
        
        // 前置条件：计数器不存在
        requires !exists<Counter>(addr);
        
        // 后置条件：计数器已创建且值为 0
        ensures exists<Counter>(addr);
        ensures global<Counter>(addr).value == 0;
        
        // 中止条件
        aborts_if exists<Counter>(addr) with ERROR_ALREADY_EXISTS;
    }

    /// 递增计数器
    public fun increment(addr: address) acquires Counter {
        assert!(exists<Counter>(addr), ERROR_NOT_INITIALIZED);
        let counter = borrow_global_mut<Counter>(addr);
        assert!(counter.value < 18446744073709551615, ERROR_OVERFLOW);
        counter.value = counter.value + 1;
    }

    spec increment {
        // 前置条件
        requires exists<Counter>(addr);
        requires global<Counter>(addr).value < 18446744073709551615;
        
        // 后置条件：值增加了 1
        ensures global<Counter>(addr).value == old(global<Counter>(addr).value) + 1;
        
        // 中止条件
        aborts_if !exists<Counter>(addr);
        aborts_if global<Counter>(addr).value >= 18446744073709551615;
    }

    /// 获取计数器值
    public fun get_value(addr: address): u64 acquires Counter {
        assert!(exists<Counter>(addr), ERROR_NOT_INITIALIZED);
        borrow_global<Counter>(addr).value
    }

    spec get_value {
        requires exists<Counter>(addr);
        ensures result == global<Counter>(addr).value;
        aborts_if !exists<Counter>(addr);
    }

    /// 重置计数器
    public fun reset(account: &signer) acquires Counter {
        let addr = signer::address_of(account);
        assert!(exists<Counter>(addr), ERROR_NOT_INITIALIZED);
        let counter = borrow_global_mut<Counter>(addr);
        counter.value = 0;
    }

    spec reset {
        let addr = signer::address_of(account);
        requires exists<Counter>(addr);
        ensures global<Counter>(addr).value == 0;
        aborts_if !exists<Counter>(addr);
    }

    /// 设置计数器值
    public fun set_value(account: &signer, new_value: u64) acquires Counter {
        let addr = signer::address_of(account);
        assert!(exists<Counter>(addr), ERROR_NOT_INITIALIZED);
        let counter = borrow_global_mut<Counter>(addr);
        counter.value = new_value;
    }

    spec set_value {
        let addr = signer::address_of(account);
        requires exists<Counter>(addr);
        ensures global<Counter>(addr).value == new_value;
        aborts_if !exists<Counter>(addr);
    }
}

// ========== 示例 5: 简单银行系统（完整验证）==========

module prover_examples::simple_bank_verified {
    use std::signer;

    /// 错误码
    const ERROR_ACCOUNT_NOT_FOUND: u64 = 101;
    const ERROR_ACCOUNT_ALREADY_EXISTS: u64 = 102;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 201;
    const ERROR_INVALID_AMOUNT: u64 = 202;
    const ERROR_OVERFLOW: u64 = 203;
    const ERROR_SELF_TRANSFER: u64 = 301;

    /// 账户结构
    struct Account has key {
        balance: u64
    }

    /// 数据不变量：余额总是非负（u64 本身保证）
    spec Account {
        invariant balance >= 0;
    }

    /// 创建账户
    public fun create_account(account: &signer, initial_balance: u64) {
        let addr = signer::address_of(account);
        assert!(!exists<Account>(addr), ERROR_ACCOUNT_ALREADY_EXISTS);
        move_to(account, Account { balance: initial_balance });
    }

    spec create_account {
        let addr = signer::address_of(account);
        
        requires !exists<Account>(addr);
        ensures exists<Account>(addr);
        ensures global<Account>(addr).balance == initial_balance;
        
        aborts_if exists<Account>(addr) with ERROR_ACCOUNT_ALREADY_EXISTS;
    }

    /// 存款
    public fun deposit(addr: address, amount: u64) acquires Account {
        assert!(exists<Account>(addr), ERROR_ACCOUNT_NOT_FOUND);
        assert!(amount > 0, ERROR_INVALID_AMOUNT);
        
        let account = borrow_global_mut<Account>(addr);
        assert!(18446744073709551615 - account.balance >= amount, ERROR_OVERFLOW);
        account.balance = account.balance + amount;
    }

    spec deposit {
        requires exists<Account>(addr);
        requires amount > 0;
        requires global<Account>(addr).balance + amount <= 18446744073709551615;
        
        ensures global<Account>(addr).balance == old(global<Account>(addr).balance) + amount;
        
        aborts_if !exists<Account>(addr);
        aborts_if amount == 0;
        aborts_if global<Account>(addr).balance + amount > 18446744073709551615;
    }

    /// 取款
    public fun withdraw(account: &signer, amount: u64) acquires Account {
        let addr = signer::address_of(account);
        assert!(exists<Account>(addr), ERROR_ACCOUNT_NOT_FOUND);
        assert!(amount > 0, ERROR_INVALID_AMOUNT);
        
        let acc = borrow_global_mut<Account>(addr);
        assert!(acc.balance >= amount, ERROR_INSUFFICIENT_BALANCE);
        acc.balance = acc.balance - amount;
    }

    spec withdraw {
        let addr = signer::address_of(account);
        
        requires exists<Account>(addr);
        requires amount > 0;
        requires global<Account>(addr).balance >= amount;
        
        ensures global<Account>(addr).balance == old(global<Account>(addr).balance) - amount;
        
        aborts_if !exists<Account>(addr);
        aborts_if amount == 0;
        aborts_if global<Account>(addr).balance < amount;
    }

    /// 查询余额
    public fun balance_of(addr: address): u64 acquires Account {
        assert!(exists<Account>(addr), ERROR_ACCOUNT_NOT_FOUND);
        borrow_global<Account>(addr).balance
    }

    spec balance_of {
        requires exists<Account>(addr);
        ensures result == global<Account>(addr).balance;
        aborts_if !exists<Account>(addr);
    }

    /// 转账
    public fun transfer(from: &signer, to: address, amount: u64) acquires Account {
        let from_addr = signer::address_of(from);
        
        // 验证参数
        assert!(from_addr != to, ERROR_SELF_TRANSFER);
        assert!(amount > 0, ERROR_INVALID_AMOUNT);
        
        // 验证账户存在
        assert!(exists<Account>(from_addr), ERROR_ACCOUNT_NOT_FOUND);
        assert!(exists<Account>(to), ERROR_ACCOUNT_NOT_FOUND);
        
        // 验证余额
        let from_account = borrow_global_mut<Account>(from_addr);
        assert!(from_account.balance >= amount, ERROR_INSUFFICIENT_BALANCE);
        
        // 验证不会溢出
        let to_balance = borrow_global<Account>(to).balance;
        assert!(18446744073709551615 - to_balance >= amount, ERROR_OVERFLOW);
        
        // 执行转账
        from_account.balance = from_account.balance - amount;
        let to_account = borrow_global_mut<Account>(to);
        to_account.balance = to_account.balance + amount;
    }

    spec transfer {
        let from_addr = signer::address_of(from);
        
        // === 前置条件 ===
        requires from_addr != to;
        requires amount > 0;
        requires exists<Account>(from_addr);
        requires exists<Account>(to);
        requires global<Account>(from_addr).balance >= amount;
        requires global<Account>(to).balance + amount <= 18446744073709551615;
        
        // === 后置条件 ===
        // 发送方余额减少
        ensures global<Account>(from_addr).balance == 
                old(global<Account>(from_addr).balance) - amount;
        
        // 接收方余额增加
        ensures global<Account>(to).balance == 
                old(global<Account>(to).balance) + amount;
        
        // 总量守恒（关键性质！）
        ensures global<Account>(from_addr).balance + global<Account>(to).balance ==
                old(global<Account>(from_addr).balance + global<Account>(to).balance);
        
        // === 中止条件 ===
        aborts_if from_addr == to;
        aborts_if amount == 0;
        aborts_if !exists<Account>(from_addr);
        aborts_if !exists<Account>(to);
        aborts_if global<Account>(from_addr).balance < amount;
        aborts_if global<Account>(to).balance + amount > 18446744073709551615;
    }
}

// ========== 示例 6: 代币系统（总量不变性）==========

module prover_examples::simple_token_verified {
    use std::signer;

    /// 错误码
    const ERROR_NOT_ADMIN: u64 = 1;
    const ERROR_ALREADY_INITIALIZED: u64 = 2;
    const ERROR_NOT_INITIALIZED: u64 = 3;
    const ERROR_BALANCE_NOT_FOUND: u64 = 4;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 5;
    const ERROR_OVERFLOW: u64 = 6;

    /// 代币信息（全局唯一）
    struct TokenInfo has key {
        total_supply: u64,
        admin: address
    }

    /// 用户余额
    struct Balance has key {
        value: u64
    }

    /// 初始化代币
    public fun initialize(admin: &signer, initial_supply: u64) {
        let admin_addr = signer::address_of(admin);
        assert!(!exists<TokenInfo>(@prover_examples), ERROR_ALREADY_INITIALIZED);
        
        move_to(admin, TokenInfo {
            total_supply: initial_supply,
            admin: admin_addr
        });
        
        move_to(admin, Balance { value: initial_supply });
    }

    spec initialize {
        let admin_addr = signer::address_of(admin);
        
        requires !exists<TokenInfo>(@prover_examples);
        requires !exists<Balance>(admin_addr);
        
        ensures exists<TokenInfo>(@prover_examples);
        ensures global<TokenInfo>(@prover_examples).total_supply == initial_supply;
        ensures global<TokenInfo>(@prover_examples).admin == admin_addr;
        ensures exists<Balance>(admin_addr);
        ensures global<Balance>(admin_addr).value == initial_supply;
        
        aborts_if exists<TokenInfo>(@prover_examples);
    }

    /// 铸造代币
    public fun mint(admin: &signer, to: address, amount: u64) acquires TokenInfo, Balance {
        let admin_addr = signer::address_of(admin);
        
        assert!(exists<TokenInfo>(@prover_examples), ERROR_NOT_INITIALIZED);
        let token_info = borrow_global_mut<TokenInfo>(@prover_examples);
        assert!(token_info.admin == admin_addr, ERROR_NOT_ADMIN);
        assert!(18446744073709551615 - token_info.total_supply >= amount, ERROR_OVERFLOW);
        
        token_info.total_supply = token_info.total_supply + amount;
        
        if (!exists<Balance>(to)) {
            move_to(admin, Balance { value: amount });
        } else {
            let balance = borrow_global_mut<Balance>(to);
            assert!(18446744073709551615 - balance.value >= amount, ERROR_OVERFLOW);
            balance.value = balance.value + amount;
        };
    }

    spec mint {
        let admin_addr = signer::address_of(admin);
        
        requires exists<TokenInfo>(@prover_examples);
        requires global<TokenInfo>(@prover_examples).admin == admin_addr;
        requires global<TokenInfo>(@prover_examples).total_supply + amount <= 18446744073709551615;
        
        // 总供应量增加
        ensures global<TokenInfo>(@prover_examples).total_supply == 
                old(global<TokenInfo>(@prover_examples).total_supply) + amount;
        
        // 接收方余额增加
        ensures exists<Balance>(to);
        ensures global<Balance>(to).value >= old(
            if (exists<Balance>(to)) global<Balance>(to).value else 0
        ) + amount;
        
        aborts_if !exists<TokenInfo>(@prover_examples);
        aborts_if global<TokenInfo>(@prover_examples).admin != admin_addr;
        aborts_if global<TokenInfo>(@prover_examples).total_supply + amount > 18446744073709551615;
    }

    /// 转账
    public fun transfer(from: &signer, to: address, amount: u64) acquires Balance {
        let from_addr = signer::address_of(from);
        
        assert!(exists<Balance>(from_addr), ERROR_BALANCE_NOT_FOUND);
        assert!(exists<Balance>(to), ERROR_BALANCE_NOT_FOUND);
        
        let from_balance = borrow_global_mut<Balance>(from_addr);
        assert!(from_balance.value >= amount, ERROR_INSUFFICIENT_BALANCE);
        from_balance.value = from_balance.value - amount;
        
        let to_balance = borrow_global_mut<Balance>(to);
        assert!(18446744073709551615 - to_balance.value >= amount, ERROR_OVERFLOW);
        to_balance.value = to_balance.value + amount;
    }

    spec transfer {
        let from_addr = signer::address_of(from);
        
        requires exists<Balance>(from_addr);
        requires exists<Balance>(to);
        requires global<Balance>(from_addr).value >= amount;
        requires global<Balance>(to).value + amount <= 18446744073709551615;
        
        // 发送方余额减少
        ensures global<Balance>(from_addr).value == 
                old(global<Balance>(from_addr).value) - amount;
        
        // 接收方余额增加
        ensures global<Balance>(to).value == 
                old(global<Balance>(to).value) + amount;
        
        // 总量守恒（关键！）
        ensures global<Balance>(from_addr).value + global<Balance>(to).value ==
                old(global<Balance>(from_addr).value + global<Balance>(to).value);
        
        // 总供应量不变
        ensures global<TokenInfo>(@prover_examples).total_supply == 
                old(global<TokenInfo>(@prover_examples).total_supply);
        
        aborts_if !exists<Balance>(from_addr);
        aborts_if !exists<Balance>(to);
        aborts_if global<Balance>(from_addr).value < amount;
        aborts_if global<Balance>(to).value + amount > 18446744073709551615;
    }

    /// 查询余额
    public fun balance_of(addr: address): u64 acquires Balance {
        if (!exists<Balance>(addr)) {
            0
        } else {
            borrow_global<Balance>(addr).value
        }
    }

    spec balance_of {
        ensures result == if (exists<Balance>(addr)) {
            global<Balance>(addr).value
        } else {
            0
        };
        aborts_if false;  // 永不 abort
    }

    /// 查询总供应量
    public fun total_supply(): u64 acquires TokenInfo {
        assert!(exists<TokenInfo>(@prover_examples), ERROR_NOT_INITIALIZED);
        borrow_global<TokenInfo>(@prover_examples).total_supply
    }

    spec total_supply {
        requires exists<TokenInfo>(@prover_examples);
        ensures result == global<TokenInfo>(@prover_examples).total_supply;
        aborts_if !exists<TokenInfo>(@prover_examples);
    }
}

// ========== 示例 7: 使用量词的全局不变量 ==========

module prover_examples::global_invariants {
    use std::signer;

    struct Value has key {
        amount: u64
    }

    /// 模块级不变量：所有 Value 的 amount 都小于 1000
    spec module {
        invariant forall addr: address where exists<Value>(addr):
            global<Value>(addr).amount < 1000;
    }

    /// 创建值
    public fun create_value(account: &signer, amount: u64) {
        assert!(amount < 1000, 1);
        move_to(account, Value { amount });
    }

    spec create_value {
        let addr = signer::address_of(account);
        requires amount < 1000;
        ensures exists<Value>(addr);
        ensures global<Value>(addr).amount == amount;
    }

    /// 更新值
    public fun update_value(account: &signer, new_amount: u64) acquires Value {
        assert!(new_amount < 1000, 1);
        let addr = signer::address_of(account);
        let value = borrow_global_mut<Value>(addr);
        value.amount = new_amount;
    }

    spec update_value {
        let addr = signer::address_of(account);
        requires new_amount < 1000;
        requires exists<Value>(addr);
        ensures global<Value>(addr).amount == new_amount;
    }
}

/// 💡 关键学习点：
///
/// 1. **前置条件（requires）**：函数执行前必须满足的条件
/// 2. **后置条件（ensures）**：函数执行后必须满足的条件
/// 3. **中止条件（aborts_if）**：什么情况下函数会 abort
/// 4. **old() 表达式**：引用函数执行前的值
/// 5. **global<T>(addr)**：访问全局存储的资源
/// 6. **不变量（invariant）**：数据结构必须保持的性质
/// 7. **量词（forall/exists）**：对集合的全称或存在性断言
///
/// 🎯 验证这些代码：
/// ```bash
/// aptos move prove --dev
/// ```
