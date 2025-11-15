/// Gas 优化 - 存储优化示例
/// 
/// 本模块展示存储优化的各种技巧
module gas_optimization::gas_optimized_storage {
    use std::signer;
    use std::vector;
    use std::option::{Self, Option};
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::table::{Self, Table};
    use aptos_framework::account;
    
    // ============================================
    // 1. 数据打包优化
    // ============================================
    
    /// NFT 市场用户配置 - 打包版本
    struct PackedUserConfig has store, drop, copy {
        data: u256,
        // Bit layout:
        // bits 0-0: is_verified (1 bit)
        // bits 1-1: is_premium (1 bit)
        // bits 2-2: notifications_enabled (1 bit)
        // bits 3-3: auto_renew (1 bit)
        // bits 4-11: tier (8 bits, 0-255)
        // bits 12-27: referral_code (16 bits)
        // bits 28-35: max_listings (8 bits)
        // bits 36-43: discount_rate (8 bits, 0-100)
        // bits 44-59: last_active_day (16 bits)
        // bits 60-91: flags (32 bits)
        // bits 92-255: reserved
    }
    
    /// 创建打包配置
    public fun create_packed_config(
        is_verified: bool,
        is_premium: bool,
        notifications_enabled: bool,
        auto_renew: bool,
        tier: u8,
        referral_code: u16,
        max_listings: u8,
        discount_rate: u8,
        last_active_day: u16,
        flags: u32
    ): PackedUserConfig {
        let data: u256 = 0;
        
        // Pack booleans
        if (is_verified) data = data | 1;
        if (is_premium) data = data | 2;
        if (notifications_enabled) data = data | 4;
        if (auto_renew) data = data | 8;
        
        // Pack tier (8 bits at position 4)
        data = data | (((tier as u256) & 0xFF) << 4);
        
        // Pack referral_code (16 bits at position 12)
        data = data | (((referral_code as u256) & 0xFFFF) << 12);
        
        // Pack max_listings (8 bits at position 28)
        data = data | (((max_listings as u256) & 0xFF) << 28);
        
        // Pack discount_rate (8 bits at position 36)
        data = data | (((discount_rate as u256) & 0xFF) << 36);
        
        // Pack last_active_day (16 bits at position 44)
        data = data | (((last_active_day as u256) & 0xFFFF) << 44);
        
        // Pack flags (32 bits at position 60)
        data = data | (((flags as u256) & 0xFFFFFFFF) << 60);
        
        PackedUserConfig { data }
    }
    
    /// 获取 is_verified
    public fun is_verified(config: &PackedUserConfig): bool {
        (config.data & 1) != 0
    }
    
    /// 获取 is_premium
    public fun is_premium(config: &PackedUserConfig): bool {
        (config.data & 2) != 0
    }
    
    /// 获取 tier
    public fun get_tier(config: &PackedUserConfig): u8 {
        ((config.data >> 4) & 0xFF) as u8
    }
    
    /// 获取 discount_rate
    public fun get_discount_rate(config: &PackedUserConfig): u8 {
        ((config.data >> 36) & 0xFF) as u8
    }
    
    /// 设置 verified 状态
    public fun set_verified(config: &mut PackedUserConfig, verified: bool) {
        if (verified) {
            config.data = config.data | 1;
        } else {
            config.data = config.data & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE;
        }
    }
    
    /// 设置 tier
    public fun set_tier(config: &mut PackedUserConfig, tier: u8) {
        // Clear existing tier bits
        config.data = config.data & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0F;
        // Set new tier
        config.data = config.data | (((tier as u256) & 0xFF) << 4);
    }
    
    // ============================================
    // 2. 数据结构选择优化
    // ============================================
    
    /// 小数据量：使用 vector (<100 项)
    struct SmallUserList has key {
        users: vector<address>,
        configs: vector<PackedUserConfig>,
    }
    
    /// 初始化小列表
    public fun init_small_list(account: &signer) {
        move_to(account, SmallUserList {
            users: vector::empty(),
            configs: vector::empty(),
        });
    }
    
    /// 添加用户（小列表）
    public fun add_user_small(
        list: &mut SmallUserList,
        user: address,
        config: PackedUserConfig
    ) {
        vector::push_back(&mut list.users, user);
        vector::push_back(&mut list.configs, config);
    }
    
    /// 查找用户（小列表）- O(n)
    public fun find_user_small(
        list: &SmallUserList,
        user: address
    ): Option<PackedUserConfig> {
        let len = vector::length(&list.users);
        let i = 0;
        while (i < len) {
            if (*vector::borrow(&list.users, i) == user) {
                return option::some(*vector::borrow(&list.configs, i))
            };
            i = i + 1;
        };
        option::none()
    }
    
    /// 中等数据量：使用 SimpleMap (100-10000 项)
    struct MediumUserMap has key {
        users: SimpleMap<address, PackedUserConfig>,
    }
    
    /// 初始化中等映射
    public fun init_medium_map(account: &signer) {
        move_to(account, MediumUserMap {
            users: simple_map::create(),
        });
    }
    
    /// 添加用户（中等映射）
    public fun add_user_medium(
        map: &mut MediumUserMap,
        user: address,
        config: PackedUserConfig
    ) {
        simple_map::add(&mut map.users, user, config);
    }
    
    /// 查找用户（中等映射）- O(log n)
    public fun find_user_medium(
        map: &MediumUserMap,
        user: address
    ): Option<PackedUserConfig> {
        if (simple_map::contains_key(&map.users, &user)) {
            option::some(*simple_map::borrow(&map.users, &user))
        } else {
            option::none()
        }
    }
    
    /// 大数据量：使用 Table (>10000 项)
    struct LargeUserTable has key {
        users: Table<address, PackedUserConfig>,
    }
    
    /// 初始化大表
    public fun init_large_table(account: &signer) {
        move_to(account, LargeUserTable {
            users: table::new(),
        });
    }
    
    /// 添加用户（大表）
    public fun add_user_large(
        table: &mut LargeUserTable,
        user: address,
        config: PackedUserConfig
    ) {
        table::add(&mut table.users, user, config);
    }
    
    /// 查找用户（大表）- O(1)
    public fun find_user_large(
        table: &LargeUserTable,
        user: address
    ): Option<PackedUserConfig> {
        if (table::contains(&table.users, user)) {
            option::some(*table::borrow(&table.users, user))
        } else {
            option::none()
        }
    }
    
    // ============================================
    // 3. 延迟加载优化
    // ============================================
    
    /// 基础用户信息（高频访问）
    struct UserBasicInfo has key {
        name: vector<u8>,
        avatar_url: vector<u8>,
        joined_timestamp: u64,
    }
    
    /// 用户详细配置（低频访问）
    struct UserDetailedConfig has key {
        bio: vector<u8>,
        social_links: vector<vector<u8>>,
        preferences: vector<u8>,
    }
    
    /// 用户统计数据（低频访问）
    struct UserStats has key {
        total_sales: u64,
        total_purchases: u64,
        reputation_score: u64,
        activity_history: vector<u64>,
    }
    
    /// 初始化用户（只创建基础信息）
    public fun init_user_basic(
        account: &signer,
        name: vector<u8>,
        avatar_url: vector<u8>
    ) {
        let user_addr = signer::address_of(account);
        move_to(account, UserBasicInfo {
            name,
            avatar_url,
            joined_timestamp: 0, // 在实际中使用 timestamp::now_seconds()
        });
    }
    
    /// 按需加载详细配置
    public fun load_detailed_config(account: &signer, bio: vector<u8>) acquires UserDetailedConfig {
        let user_addr = signer::address_of(account);
        
        if (!exists<UserDetailedConfig>(user_addr)) {
            move_to(account, UserDetailedConfig {
                bio,
                social_links: vector::empty(),
                preferences: vector::empty(),
            });
        }
    }
    
    /// 获取基础信息（低 Gas）
    public fun get_basic_info(user: address): (vector<u8>, vector<u8>) acquires UserBasicInfo {
        let info = borrow_global<UserBasicInfo>(user);
        (*&info.name, *&info.avatar_url)
    }
    
    /// 获取详细配置（仅在需要时才产生 Gas）
    public fun get_detailed_config(user: address): Option<vector<u8>> acquires UserDetailedConfig {
        if (exists<UserDetailedConfig>(user)) {
            let config = borrow_global<UserDetailedConfig>(user);
            option::some(*&config.bio)
        } else {
            option::none()
        }
    }
    
    // ============================================
    // 4. 资源共享模式
    // ============================================
    
    /// 全局默认配置
    struct GlobalDefaults has key {
        default_max_listings: u8,
        default_discount_rate: u8,
        default_tier: u8,
        default_flags: u32,
    }
    
    /// 用户自定义配置（仅在需要时存储）
    struct UserCustomSettings has key {
        custom_max_listings: Option<u8>,
        custom_discount_rate: Option<u8>,
        custom_tier: Option<u8>,
        custom_flags: Option<u32>,
    }
    
    /// 初始化全局默认配置
    public fun init_global_defaults(admin: &signer) {
        move_to(admin, GlobalDefaults {
            default_max_listings: 10,
            default_discount_rate: 0,
            default_tier: 0,
            default_flags: 0,
        });
    }
    
    /// 获取用户的最大列表数（优先使用自定义，否则使用默认）
    public fun get_max_listings(user: address): u8 
        acquires GlobalDefaults, UserCustomSettings 
    {
        if (exists<UserCustomSettings>(user)) {
            let custom = borrow_global<UserCustomSettings>(user);
            if (option::is_some(&custom.custom_max_listings)) {
                return *option::borrow(&custom.custom_max_listings)
            }
        };
        
        let defaults = borrow_global<GlobalDefaults>(@gas_optimization);
        defaults.default_max_listings
    }
    
    /// 设置自定义值（仅在不同于默认值时存储）
    public fun set_custom_max_listings(
        account: &signer,
        value: u8
    ) acquires GlobalDefaults, UserCustomSettings {
        let user_addr = signer::address_of(account);
        let defaults = borrow_global<GlobalDefaults>(@gas_optimization);
        
        // 如果等于默认值，不需要存储
        if (value == defaults.default_max_listings) {
            if (exists<UserCustomSettings>(user_addr)) {
                let custom = borrow_global_mut<UserCustomSettings>(user_addr);
                custom.custom_max_listings = option::none();
            };
            return
        };
        
        // 存储自定义值
        if (!exists<UserCustomSettings>(user_addr)) {
            move_to(account, UserCustomSettings {
                custom_max_listings: option::some(value),
                custom_discount_rate: option::none(),
                custom_tier: option::none(),
                custom_flags: option::none(),
            });
        } else {
            let custom = borrow_global_mut<UserCustomSettings>(user_addr);
            custom.custom_max_listings = option::some(value);
        }
    }
    
    // ============================================
    // 测试函数
    // ============================================
    
    #[test_only]
    public fun test_packed_storage() {
        let config = create_packed_config(
            true,  // is_verified
            false, // is_premium
            true,  // notifications_enabled
            false, // auto_renew
            5,     // tier
            12345, // referral_code
            20,    // max_listings
            15,    // discount_rate
            365,   // last_active_day
            0xFF00FF00 // flags
        );
        
        assert!(is_verified(&config), 0);
        assert!(!is_premium(&config), 1);
        assert!(get_tier(&config) == 5, 2);
        assert!(get_discount_rate(&config) == 15, 3);
    }
}
