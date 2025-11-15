/// Gas 优化代码示例
/// 
/// 本模块展示各种 Gas 优化技巧的实际应用
module gas_optimization::examples {
    use std::signer;
    use std::vector;
    use std::option::{Self, Option};
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::table::{Self, Table};
    
    // ============================================
    // 示例 1: 数据打包（Bit Packing）
    // ============================================
    
    /// ❌ 低效：每个字段独立存储
    struct UserStatusUnoptimized has store, drop {
        is_active: bool,     // 1 bit -> 1 byte + padding
        is_verified: bool,   // 1 bit -> 1 byte + padding
        is_premium: bool,    // 1 bit -> 1 byte + padding
        tier: u8,            // 8 bits -> 1 byte + padding
        flags: u8,           // 8 bits
        role: u8,            // 8 bits
        // 实际占用: ~6+ bytes
    }
    
    /// ✅ 高效：打包到 u32
    struct UserStatusOptimized has store, drop, copy {
        packed: u32,
        // bit 0: is_active
        // bit 1: is_verified
        // bit 2: is_premium
        // bits 3-10: tier (0-255)
        // bits 11-18: flags
        // bits 19-26: role
        // bits 27-31: reserved
        // 实际占用: 4 bytes
    }
    
    // 位操作辅助函数
    public fun create_user_status(
        is_active: bool,
        is_verified: bool,
        is_premium: bool,
        tier: u8,
        flags: u8,
        role: u8
    ): UserStatusOptimized {
        let packed = 0u32;
        
        if (is_active) packed = packed | 0x01;
        if (is_verified) packed = packed | 0x02;
        if (is_premium) packed = packed | 0x04;
        
        packed = packed | (((tier as u32) & 0xFF) << 3);
        packed = packed | (((flags as u32) & 0xFF) << 11);
        packed = packed | (((role as u32) & 0xFF) << 19);
        
        UserStatusOptimized { packed }
    }
    
    public fun is_active(status: &UserStatusOptimized): bool {
        (status.packed & 0x01) != 0
    }
    
    public fun is_verified(status: &UserStatusOptimized): bool {
        (status.packed & 0x02) != 0
    }
    
    public fun get_tier(status: &UserStatusOptimized): u8 {
        ((status.packed >> 3) & 0xFF) as u8
    }
    
    public fun set_active(status: &mut UserStatusOptimized, active: bool) {
        if (active) {
            status.packed = status.packed | 0x01;
        } else {
            status.packed = status.packed & 0xFFFFFFFE;
        }
    }
    
    // ============================================
    // 示例 2: 循环优化
    // ============================================
    
    /// ❌ 低效：重复调用 length()
    public fun sum_vector_unoptimized(v: &vector<u64>): u64 {
        let sum = 0;
        let i = 0;
        while (i < vector::length(v)) {  // 每次迭代都调用
            sum = sum + *vector::borrow(v, i);
            i = i + 1;
        };
        sum
    }
    
    /// ✅ 高效：缓存 length
    public fun sum_vector_optimized(v: &vector<u64>): u64 {
        let sum = 0;
        let len = vector::length(v);  // 只调用一次
        let i = 0;
        while (i < len) {
            sum = sum + *vector::borrow(v, i);
            i = i + 1;
        };
        sum
    }
    
    // ============================================
    // 示例 3: 条件分支优化
    // ============================================
    
    const TIER_BRONZE: u8 = 0;
    const TIER_SILVER: u8 = 1;
    const TIER_GOLD: u8 = 2;
    const TIER_PLATINUM: u8 = 3;
    
    /// ❌ 低效：未按概率排序
    public fun get_discount_unoptimized(tier: u8): u64 {
        if (tier == TIER_PLATINUM) {      // 1% 用户
            return 30;
        } else if (tier == TIER_GOLD) {   // 5% 用户
            return 20;
        } else if (tier == TIER_SILVER) { // 15% 用户
            return 10;
        } else {                           // 79% 用户
            return 0;
        }
    }
    
    /// ✅ 高效：按概率降序
    public fun get_discount_optimized(tier: u8): u64 {
        if (tier == TIER_BRONZE) {        // 79% 用户
            return 0;
        } else if (tier == TIER_SILVER) { // 15% 用户
            return 10;
        } else if (tier == TIER_GOLD) {   // 5% 用户
            return 20;
        } else {                           // 1% 用户
            return 30;
        }
    }
    
    // ============================================
    // 示例 4: 使用查找表
    // ============================================
    
    /// ❌ 低效：多重条件判断
    public fun get_fee_rate_unoptimized(tier: u8): u64 {
        if (tier == 0) {
            return 100;   // 1%
        } else if (tier == 1) {
            return 75;    // 0.75%
        } else if (tier == 2) {
            return 50;    // 0.5%
        } else if (tier == 3) {
            return 25;    // 0.25%
        } else {
            return 10;    // 0.1%
        }
    }
    
    /// ✅ 高效：查找表
    struct FeeSchedule has key {
        rates: vector<u64>,
    }
    
    public fun initialize_fee_schedule(admin: &signer) {
        move_to(admin, FeeSchedule {
            rates: vector[100, 75, 50, 25, 10],
        });
    }
    
    public fun get_fee_rate_optimized(tier: u8): u64 acquires FeeSchedule {
        let schedule = borrow_global<FeeSchedule>(@gas_optimization);
        *vector::borrow(&schedule.rates, (tier as u64))
    }
    
    // ============================================
    // 示例 5: 数据结构选择
    // ============================================
    
    /// 小数据量：使用 vector
    struct SmallUserList has key {
        users: vector<address>,  // < 100 个
    }
    
    public fun add_user_small(list: &mut SmallUserList, user: address) {
        vector::push_back(&mut list.users, user);
    }
    
    public fun find_user_small(list: &SmallUserList, user: address): bool {
        vector::contains(&list.users, &user)
    }
    
    /// 中等数据量：使用 SimpleMap
    struct MediumUserMap has key {
        users: SimpleMap<address, UserStatusOptimized>,  // 100-10000 个
    }
    
    public fun add_user_medium(
        map: &mut MediumUserMap,
        user: address,
        status: UserStatusOptimized
    ) {
        simple_map::add(&mut map.users, user, status);
    }
    
    public fun find_user_medium(
        map: &MediumUserMap,
        user: address
    ): Option<UserStatusOptimized> {
        if (simple_map::contains_key(&map.users, &user)) {
            option::some(*simple_map::borrow(&map.users, &user))
        } else {
            option::none()
        }
    }
    
    /// 大数据量：使用 Table
    struct LargeUserTable has key {
        users: Table<address, UserStatusOptimized>,  // > 10000 个
    }
    
    public fun add_user_large(
        table: &mut LargeUserTable,
        user: address,
        status: UserStatusOptimized
    ) {
        table::add(&mut table.users, user, status);
    }
    
    public fun find_user_large(
        table: &LargeUserTable,
        user: address
    ): Option<UserStatusOptimized> {
        if (table::contains(&table.users, user)) {
            option::some(*table::borrow(&table.users, user))
        } else {
            option::none()
        }
    }
    
    // ============================================
    // 示例 6: 批量操作
    // ============================================
    
    struct TokenBalance has key {
        balance: u64,
    }
    
    /// ❌ 低效：单个 mint
    public fun mint_single(to: address, amount: u64) acquires TokenBalance {
        if (!exists<TokenBalance>(to)) {
            move_to(&create_signer(to), TokenBalance { balance: 0 });
        };
        
        let balance = borrow_global_mut<TokenBalance>(to);
        balance.balance = balance.balance + amount;
    }
    
    /// ✅ 高效：批量 mint
    public fun mint_batch(
        recipients: vector<address>,
        amounts: vector<u64>
    ) acquires TokenBalance {
        let len = vector::length(&recipients);
        assert!(len == vector::length(&amounts), 1);
        
        let i = 0;
        while (i < len) {
            let to = *vector::borrow(&recipients, i);
            let amount = *vector::borrow(&amounts, i);
            
            if (!exists<TokenBalance>(to)) {
                move_to(&create_signer(to), TokenBalance { balance: 0 });
            };
            
            let balance = borrow_global_mut<TokenBalance>(to);
            balance.balance = balance.balance + amount;
            
            i = i + 1;
        };
    }
    
    // ============================================
    // 示例 7: 延迟加载
    // ============================================
    
    /// ❌ 低效：一次性加载所有数据
    struct UserProfileUnoptimized has key {
        basic_info: vector<u8>,     // 100 bytes
        preferences: vector<u8>,    // 500 bytes
        statistics: vector<u8>,     // 1000 bytes
        history: vector<u8>,        // 5000 bytes
        // 即使只需要 basic_info，也要读取全部 ~6.6KB
    }
    
    /// ✅ 高效：分离存储，按需加载
    struct UserBasicProfile has key {
        basic_info: vector<u8>,     // 100 bytes
    }
    
    struct UserPreferences has key {
        preferences: vector<u8>,    // 500 bytes
    }
    
    struct UserStatistics has key {
        statistics: vector<u8>,     // 1000 bytes
    }
    
    struct UserHistory has key {
        history: vector<u8>,        // 5000 bytes
    }
    
    // 只读取需要的部分
    public fun get_basic_info(user: address): vector<u8> acquires UserBasicProfile {
        *&borrow_global<UserBasicProfile>(user).basic_info
    }
    
    public fun get_statistics(user: address): vector<u8> acquires UserStatistics {
        *&borrow_global<UserStatistics>(user).statistics
    }
    
    // ============================================
    // 示例 8: 数学运算优化
    // ============================================
    
    /// ❌ 低效：常规除法
    public fun divide_by_power_of_2_unoptimized(x: u64, divisor: u64): u64 {
        x / divisor
    }
    
    /// ✅ 高效：位运算
    public fun divide_by_8(x: u64): u64 {
        x >> 3  // 除以 2^3 = 8
    }
    
    public fun divide_by_16(x: u64): u64 {
        x >> 4  // 除以 2^4 = 16
    }
    
    public fun multiply_by_8(x: u64): u64 {
        x << 3  // 乘以 2^3 = 8
    }
    
    /// 合并多个除法运算
    public fun calculate_fee_unoptimized(amount: u64): u64 {
        (amount * 3) / 100 / 10  // 两次除法
    }
    
    public fun calculate_fee_optimized(amount: u64): u64 {
        (amount * 3) / 1000      // 一次除法
    }
    
    // ============================================
    // 示例 9: 避免重复计算
    // ============================================
    
    /// ❌ 低效：重复计算
    public fun process_transactions_unoptimized(
        amounts: &vector<u64>,
        fee_rate: u64
    ): (u64, u64) {
        let total = 0;
        let total_fees = 0;
        let i = 0;
        let len = vector::length(amounts);
        
        while (i < len) {
            let amount = *vector::borrow(amounts, i);
            let fee = (amount * fee_rate) / 10000;
            total = total + amount;
            total_fees = total_fees + fee;
            i = i + 1;
        };
        
        (total, total_fees)
    }
    
    /// ✅ 高效：减少计算
    public fun process_transactions_optimized(
        amounts: &vector<u64>,
        fee_rate: u64
    ): (u64, u64) {
        let total = 0;
        let len = vector::length(amounts);
        let i = 0;
        
        // 先计算总额
        while (i < len) {
            total = total + *vector::borrow(amounts, i);
            i = i + 1;
        };
        
        // 一次性计算总手续费
        let total_fees = (total * fee_rate) / 10000;
        
        (total, total_fees)
    }
    
    // ============================================
    // 示例 10: 资源共享
    // ============================================
    
    /// 全局默认配置
    struct GlobalConfig has key {
        default_slippage: u64,
        default_deadline: u64,
        default_router: address,
    }
    
    /// 用户自定义配置（仅在需要时存储）
    struct UserCustomConfig has key {
        custom_slippage: Option<u64>,
        custom_deadline: Option<u64>,
        custom_router: Option<address>,
    }
    
    /// 获取用户配置（优先使用自定义，否则使用默认）
    public fun get_user_slippage(user: address): u64 
        acquires GlobalConfig, UserCustomConfig 
    {
        if (exists<UserCustomConfig>(user)) {
            let custom = borrow_global<UserCustomConfig>(user);
            if (option::is_some(&custom.custom_slippage)) {
                return *option::borrow(&custom.custom_slippage);
            }
        };
        
        // 使用全局默认值
        let global = borrow_global<GlobalConfig>(@gas_optimization);
        global.default_slippage
    }
    
    // ============================================
    // 辅助函数
    // ============================================
    
    // 注意：这是一个简化的示例函数
    // 实际上 Move 不允许随意创建 signer
    native fun create_signer(addr: address): signer;
    
    #[test_only]
    use std::string;
    
    #[test_only]
    public fun test_packed_storage() {
        let status = create_user_status(
            true,   // is_active
            false,  // is_verified
            true,   // is_premium
            5,      // tier
            0xFF,   // flags
            2       // role
        );
        
        assert!(is_active(&status), 0);
        assert!(!is_verified(&status), 1);
        assert!(get_tier(&status) == 5, 2);
        
        set_active(&mut status, false);
        assert!(!is_active(&status), 3);
    }
    
    #[test_only]
    public fun test_loop_optimization() {
        let v = vector::empty<u64>();
        vector::push_back(&mut v, 10);
        vector::push_back(&mut v, 20);
        vector::push_back(&mut v, 30);
        
        let sum1 = sum_vector_unoptimized(&v);
        let sum2 = sum_vector_optimized(&v);
        
        assert!(sum1 == sum2, 0);
        assert!(sum1 == 60, 1);
    }
}
