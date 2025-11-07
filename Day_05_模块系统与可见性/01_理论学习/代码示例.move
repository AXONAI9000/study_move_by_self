// ============================================================================
// Day 05: 模块系统与可见性 - 代码示例
// ============================================================================

// ============================================================================
// 示例 1: 基本模块定义与可见性
// ============================================================================

/// 数学工具模块
module 0x1::math_utils {
    // 私有常量
    const MULTIPLIER: u64 = 100;
    
    // 私有函数 - 仅模块内部可访问
    fun calculate_internal(x: u64, y: u64): u64 {
        x * y + MULTIPLIER
    }
    
    // 公共函数 - 任何模块都可以调用
    public fun add(x: u64, y: u64): u64 {
        x + y
    }
    
    public fun multiply(x: u64, y: u64): u64 {
        x * y
    }
    
    // 公共函数可以调用私有函数
    public fun calculate_with_bonus(x: u64, y: u64): u64 {
        calculate_internal(x, y)
    }
}

// ============================================================================
// 示例 2: entry 函数 - 交易入口点
// ============================================================================

module 0x1::game {
    use std::signer;
    
    struct Player has key {
        name: vector<u8>,
        level: u64,
        score: u64,
    }
    
    // entry 函数：用户可以通过交易直接调用
    // 特点：无返回值，可以作为交易入口
    entry fun register_player(account: &signer, name: vector<u8>) {
        let player = Player {
            name,
            level: 1,
            score: 0,
        };
        move_to(account, player);
    }
    
    // public entry：既可以被交易调用，也可以被其他模块调用
    public entry fun level_up(account: &signer) acquires Player {
        let player_address = signer::address_of(account);
        let player = borrow_global_mut<Player>(player_address);
        player.level = player.level + 1;
    }
    
    // 普通 public 函数：可以有返回值，可以被其他模块调用
    public fun get_player_score(player_address: address): u64 acquires Player {
        let player = borrow_global<Player>(player_address);
        player.score
    }
    
    // 私有辅助函数
    fun calculate_reward(level: u64): u64 {
        level * 100
    }
    
    public entry fun add_score(account: &signer, points: u64) acquires Player {
        let player_address = signer::address_of(account);
        let player = borrow_global_mut<Player>(player_address);
        player.score = player.score + points;
    }
}

// ============================================================================
// 示例 3: 友元机制 (public(friend))
// ============================================================================

/// 银行核心模块 - 使用友元控制访问权限
module 0x1::bank_core {
    use std::signer;
    
    // 声明友元模块
    friend 0x1::bank_admin;
    friend 0x1::bank_governance;
    
    struct Vault has key {
        balance: u64,
        locked: bool,
    }
    
    const ERROR_INSUFFICIENT_BALANCE: u64 = 1;
    const ERROR_VAULT_LOCKED: u64 = 2;
    
    // 公共函数：任何人都可以创建金库
    public fun create_vault(account: &signer) {
        let vault = Vault {
            balance: 0,
            locked: false,
        };
        move_to(account, vault);
    }
    
    // 公共函数：任何人都可以存款
    public fun deposit(account: &signer, amount: u64) acquires Vault {
        let vault = borrow_global_mut<Vault>(signer::address_of(account));
        vault.balance = vault.balance + amount;
    }
    
    // 友元函数：只有友元模块可以调用
    // 用于特权操作，如应急提款
    public(friend) fun privileged_withdraw(
        addr: address, 
        amount: u64
    ): u64 acquires Vault {
        let vault = borrow_global_mut<Vault>(addr);
        assert!(!vault.locked, ERROR_VAULT_LOCKED);
        assert!(vault.balance >= amount, ERROR_INSUFFICIENT_BALANCE);
        
        vault.balance = vault.balance - amount;
        amount
    }
    
    // 友元函数：只有友元可以锁定/解锁金库
    public(friend) fun lock_vault(addr: address) acquires Vault {
        let vault = borrow_global_mut<Vault>(addr);
        vault.locked = true;
    }
    
    public(friend) fun unlock_vault(addr: address) acquires Vault {
        let vault = borrow_global_mut<Vault>(addr);
        vault.locked = false;
    }
    
    // 公共查询函数
    public fun get_balance(addr: address): u64 acquires Vault {
        let vault = borrow_global<Vault>(addr);
        vault.balance
    }
}

/// 银行管理员模块 - bank_core 的友元
module 0x1::bank_admin {
    use 0x1::bank_core;
    use std::signer;
    
    struct AdminCap has key {}
    
    // 只有管理员可以调用此函数
    public entry fun initialize_admin(account: &signer) {
        move_to(account, AdminCap {});
    }
    
    // 管理员应急提款
    public entry fun emergency_withdraw(
        admin: &signer,
        target_addr: address,
        amount: u64
    ) acquires AdminCap {
        // 验证是否是管理员
        let admin_addr = signer::address_of(admin);
        assert!(exists<AdminCap>(admin_addr), 1);
        
        // 调用友元函数
        let _withdrawn = bank_core::privileged_withdraw(target_addr, amount);
    }
    
    // 管理员锁定账户
    public entry fun lock_account(
        admin: &signer,
        target_addr: address
    ) acquires AdminCap {
        let admin_addr = signer::address_of(admin);
        assert!(exists<AdminCap>(admin_addr), 1);
        
        bank_core::lock_vault(target_addr);
    }
}

// ============================================================================
// 示例 4: 模块导入的各种方式
// ============================================================================

module 0x1::import_examples {
    // 方式 1: 导入整个模块
    use std::vector;
    use std::signer;
    
    // 方式 2: 导入模块并设置别名
    use aptos_framework::coin as token;
    
    // 方式 3: 导入特定成员
    use std::string::{String, utf8};
    
    // 方式 4: 导入模块本身和特定成员
    use std::option::{Self, Option, some, none};
    
    public fun example_function(): vector<u64> {
        // 使用完整模块名
        let v = vector::empty<u64>();
        vector::push_back(&mut v, 1);
        vector::push_back(&mut v, 2);
        
        // 使用直接导入的函数
        let _str: String = utf8(b"Hello");
        
        // 使用别名
        // let coin_type = token::coin_type<AptosCoin>();
        
        // 使用 option
        let opt: Option<u64> = some(42);
        let _is_some = option::is_some(&opt);
        
        v
    }
}

// ============================================================================
// 示例 5: 结构体可见性与访问控制
// ============================================================================

module 0x1::user_profile {
    use std::string::String;
    
    // 私有结构体：只有本模块可以创建和销毁
    struct PrivateData {
        secret: u64,
    }
    
    // 公共结构体：其他模块可以使用但不能直接访问字段
    public struct UserProfile has key, drop {
        username: String,
        age: u64,
        private_data: PrivateData,  // 内嵌私有结构体
    }
    
    // 公共构造函数
    public fun create_profile(
        username: String, 
        age: u64, 
        secret: u64
    ): UserProfile {
        UserProfile {
            username,
            age,
            private_data: PrivateData { secret },
        }
    }
    
    // 公共访问器（Getter）
    public fun get_username(profile: &UserProfile): String {
        profile.username
    }
    
    public fun get_age(profile: &UserProfile): u64 {
        profile.age
    }
    
    // 私有数据只能通过授权方式访问
    public fun verify_secret(profile: &UserProfile, input: u64): bool {
        profile.private_data.secret == input
    }
    
    // 公共修改器（Setter）
    public fun update_age(profile: &mut UserProfile, new_age: u64) {
        profile.age = new_age;
    }
}

// ============================================================================
// 示例 6: 模块依赖与分层架构
// ============================================================================

/// 核心数据层
module 0x1::token_core {
    public struct Token has store, drop {
        value: u64,
    }
    
    public fun create(value: u64): Token {
        Token { value }
    }
    
    public fun get_value(token: &Token): u64 {
        token.value
    }
    
    public fun destroy(token: Token): u64 {
        let Token { value } = token;
        value
    }
}

/// 业务逻辑层 - 依赖核心层
module 0x1::token_logic {
    use 0x1::token_core::{Self, Token};
    
    const ERROR_INSUFFICIENT_VALUE: u64 = 1;
    
    public fun merge(token1: Token, token2: Token): Token {
        let value1 = token_core::destroy(token1);
        let value2 = token_core::destroy(token2);
        token_core::create(value1 + value2)
    }
    
    public fun split(token: Token, amount: u64): (Token, Token) {
        let total = token_core::get_value(&token);
        assert!(total >= amount, ERROR_INSUFFICIENT_VALUE);
        
        token_core::destroy(token);
        
        let token1 = token_core::create(amount);
        let token2 = token_core::create(total - amount);
        
        (token1, token2)
    }
}

/// API 层 - 对外提供接口
module 0x1::token_api {
    use 0x1::token_core;
    use 0x1::token_logic;
    use std::signer;
    
    public struct TokenStore has key {
        tokens: vector<token_core::Token>,
    }
    
    public entry fun initialize(account: &signer) {
        move_to(account, TokenStore {
            tokens: vector::empty(),
        });
    }
    
    public entry fun mint_token(account: &signer, value: u64) acquires TokenStore {
        let store = borrow_global_mut<TokenStore>(signer::address_of(account));
        let token = token_core::create(value);
        vector::push_back(&mut store.tokens, token);
    }
    
    public entry fun merge_all_tokens(account: &signer) acquires TokenStore {
        let store = borrow_global_mut<TokenStore>(signer::address_of(account));
        let len = vector::length(&store.tokens);
        
        if (len < 2) return;
        
        let first = vector::pop_back(&mut store.tokens);
        let second = vector::pop_back(&mut store.tokens);
        let merged = token_logic::merge(first, second);
        
        vector::push_back(&mut store.tokens, merged);
    }
}

// ============================================================================
// 示例 7: 测试友元模式
// ============================================================================

module 0x1::production_code {
    friend 0x1::test_helpers;
    
    struct InternalState has key {
        value: u64,
    }
    
    // 生产代码
    public fun public_api(value: u64): u64 {
        value * 2
    }
    
    // 测试辅助函数 - 只对测试模块可见
    public(friend) fun test_setup(account: &signer, value: u64) {
        move_to(account, InternalState { value });
    }
    
    public(friend) fun test_teardown(addr: address) acquires InternalState {
        let InternalState { value: _ } = move_from<InternalState>(addr);
    }
    
    public(friend) fun get_internal_state(addr: address): u64 acquires InternalState {
        borrow_global<InternalState>(addr).value
    }
}

#[test_only]
module 0x1::test_helpers {
    use 0x1::production_code;
    use std::signer;
    
    #[test(account = @0x1)]
    public fun test_production_code(account: &signer) {
        // 使用友元函数设置测试环境
        production_code::test_setup(account, 100);
        
        let addr = signer::address_of(account);
        let state = production_code::get_internal_state(addr);
        assert!(state == 100, 1);
        
        // 清理
        production_code::test_teardown(addr);
    }
}

// ============================================================================
// 示例 8: 命名空间和组织最佳实践
// ============================================================================

/// 项目：去中心化交易所
/// 模块组织结构示例

module my_dex::core_types {
    // 核心数据类型定义
    public struct Pool has key {
        token_a_reserve: u64,
        token_b_reserve: u64,
    }
    
    public struct LiquidityToken has store {
        amount: u64,
    }
}

module my_dex::pool_manager {
    use my_dex::core_types::{Pool, LiquidityToken};
    friend my_dex::router;
    
    // 池子管理逻辑
    public(friend) fun create_pool(
        token_a_amount: u64,
        token_b_amount: u64
    ): Pool {
        Pool {
            token_a_reserve: token_a_amount,
            token_b_reserve: token_b_amount,
        }
    }
    
    public fun calculate_output(
        input_amount: u64,
        input_reserve: u64,
        output_reserve: u64
    ): u64 {
        // AMM 计算公式
        (input_amount * output_reserve) / (input_reserve + input_amount)
    }
}

module my_dex::router {
    use my_dex::pool_manager;
    use std::signer;
    
    // 用户交互的主要入口
    public entry fun swap(
        account: &signer,
        input_amount: u64
    ) {
        let _addr = signer::address_of(account);
        // 调用 pool_manager 的公共函数
        let _output = pool_manager::calculate_output(input_amount, 1000, 2000);
    }
}
