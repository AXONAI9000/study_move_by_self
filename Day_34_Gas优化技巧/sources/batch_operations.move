/// Gas 优化 - 批量操作示例
module gas_optimization::batch_operations {
    use std::signer;
    use std::vector;
    use std::string::String;
    
    // 错误码
    const E_INVALID_LENGTH: u64 = 1;
    const E_BATCH_TOO_LARGE: u64 = 2;
    const E_EMPTY_BATCH: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    
    // 批次大小限制
    const MAX_BATCH_SIZE: u64 = 100;
    
    // ============================================
    // 1. 批量转账
    // ============================================
    
    struct TokenBalance has key {
        balance: u64,
    }
    
    /// ❌ 单个转账
    public entry fun transfer_single(
        from: &signer,
        to: address,
        amount: u64
    ) acquires TokenBalance {
        let from_addr = signer::address_of(from);
        
        // 检查余额
        let from_balance = borrow_global_mut<TokenBalance>(from_addr);
        assert!(from_balance.balance >= amount, E_INSUFFICIENT_BALANCE);
        from_balance.balance = from_balance.balance - amount;
        
        // 存入目标账户
        if (!exists<TokenBalance>(to)) {
            move_to(&create_signer(to), TokenBalance { balance: 0 });
        };
        let to_balance = borrow_global_mut<TokenBalance>(to);
        to_balance.balance = to_balance.balance + amount;
    }
    
    /// ✅ 批量转账
    public entry fun transfer_batch(
        from: &signer,
        recipients: vector<address>,
        amounts: vector<u64>
    ) acquires TokenBalance {
        let len = vector::length(&recipients);
        
        // 验证参数
        assert!(len == vector::length(&amounts), E_INVALID_LENGTH);
        assert!(len > 0, E_EMPTY_BATCH);
        assert!(len <= MAX_BATCH_SIZE, E_BATCH_TOO_LARGE);
        
        let from_addr = signer::address_of(from);
        
        // 计算总额
        let total = 0;
        let i = 0;
        while (i < len) {
            total = total + *vector::borrow(&amounts, i);
            i = i + 1;
        };
        
        // 检查余额
        let from_balance = borrow_global_mut<TokenBalance>(from_addr);
        assert!(from_balance.balance >= total, E_INSUFFICIENT_BALANCE);
        from_balance.balance = from_balance.balance - total;
        
        // 批量转账
        i = 0;
        while (i < len) {
            let to = *vector::borrow(&recipients, i);
            let amount = *vector::borrow(&amounts, i);
            
            if (!exists<TokenBalance>(to)) {
                move_to(&create_signer(to), TokenBalance { balance: 0 });
            };
            let to_balance = borrow_global_mut<TokenBalance>(to);
            to_balance.balance = to_balance.balance + amount;
            
            i = i + 1;
        };
    }
    
    // ============================================
    // 2. 批量 Mint
    // ============================================
    
    struct MintCapability has key {
        total_minted: u64,
    }
    
    /// ❌ 单个 Mint
    public fun mint_single(
        cap: &mut MintCapability,
        to: address,
        amount: u64
    ) acquires TokenBalance {
        cap.total_minted = cap.total_minted + amount;
        
        if (!exists<TokenBalance>(to)) {
            move_to(&create_signer(to), TokenBalance { balance: 0 });
        };
        let balance = borrow_global_mut<TokenBalance>(to);
        balance.balance = balance.balance + amount;
    }
    
    /// ✅ 批量 Mint
    public fun mint_batch(
        cap: &mut MintCapability,
        recipients: vector<address>,
        amounts: vector<u64>
    ) acquires TokenBalance {
        let len = vector::length(&recipients);
        
        // 验证参数
        assert!(len == vector::length(&amounts), E_INVALID_LENGTH);
        assert!(len > 0, E_EMPTY_BATCH);
        assert!(len <= MAX_BATCH_SIZE, E_BATCH_TOO_LARGE);
        
        // 计算总额
        let total = 0;
        let i = 0;
        while (i < len) {
            total = total + *vector::borrow(&amounts, i);
            i = i + 1;
        };
        
        // 更新总铸造量
        cap.total_minted = cap.total_minted + total;
        
        // 批量 mint
        i = 0;
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
    // 3. 批量状态更新
    // ============================================
    
    const STATUS_PENDING: u8 = 0;
    const STATUS_ACTIVE: u8 = 1;
    const STATUS_SUSPENDED: u8 = 2;
    const STATUS_BANNED: u8 = 3;
    
    struct UserStatus has key {
        status: u8,
        updated_at: u64,
    }
    
    /// ❌ 单个更新
    public fun update_status_single(
        admin: &signer,
        user: address,
        new_status: u8,
        timestamp: u64
    ) acquires UserStatus {
        // 验证权限（简化）
        assert!(signer::address_of(admin) == @gas_optimization, 0);
        
        if (!exists<UserStatus>(user)) {
            move_to(&create_signer(user), UserStatus {
                status: STATUS_PENDING,
                updated_at: 0,
            });
        };
        
        let status = borrow_global_mut<UserStatus>(user);
        status.status = new_status;
        status.updated_at = timestamp;
    }
    
    /// ✅ 批量更新
    public fun update_status_batch(
        admin: &signer,
        users: vector<address>,
        statuses: vector<u8>,
        timestamp: u64
    ) acquires UserStatus {
        let len = vector::length(&users);
        
        // 验证参数
        assert!(len == vector::length(&statuses), E_INVALID_LENGTH);
        assert!(len > 0, E_EMPTY_BATCH);
        assert!(len <= MAX_BATCH_SIZE, E_BATCH_TOO_LARGE);
        
        // 验证权限（只需一次）
        assert!(signer::address_of(admin) == @gas_optimization, 0);
        
        // 批量更新
        let i = 0;
        while (i < len) {
            let user = *vector::borrow(&users, i);
            let new_status = *vector::borrow(&statuses, i);
            
            if (!exists<UserStatus>(user)) {
                move_to(&create_signer(user), UserStatus {
                    status: STATUS_PENDING,
                    updated_at: 0,
                });
            };
            
            let status = borrow_global_mut<UserStatus>(user);
            status.status = new_status;
            status.updated_at = timestamp;
            
            i = i + 1;
        };
    }
    
    // ============================================
    // 4. 批量空投
    // ============================================
    
    /// ✅ 优化的批量空投（相同金额）
    public fun airdrop_equal_amount(
        admin: &signer,
        recipients: vector<address>,
        amount_per_user: u64
    ) acquires TokenBalance, MintCapability {
        let len = vector::length(&recipients);
        
        // 验证参数
        assert!(len > 0, E_EMPTY_BATCH);
        assert!(len <= MAX_BATCH_SIZE, E_BATCH_TOO_LARGE);
        
        // 验证权限
        assert!(signer::address_of(admin) == @gas_optimization, 0);
        
        // 获取 mint capability
        let cap = borrow_global_mut<MintCapability>(@gas_optimization);
        
        // 计算总额（一次性）
        let total = amount_per_user * len;
        cap.total_minted = cap.total_minted + total;
        
        // 批量分发
        let i = 0;
        while (i < len) {
            let to = *vector::borrow(&recipients, i);
            
            if (!exists<TokenBalance>(to)) {
                move_to(&create_signer(to), TokenBalance { balance: 0 });
            };
            let balance = borrow_global_mut<TokenBalance>(to);
            balance.balance = balance.balance + amount_per_user;
            
            i = i + 1;
        };
    }
    
    /// ✅ 批量空投（不同金额）
    public fun airdrop_custom_amounts(
        admin: &signer,
        recipients: vector<address>,
        amounts: vector<u64>
    ) acquires TokenBalance, MintCapability {
        // 复用 mint_batch
        let cap = borrow_global_mut<MintCapability>(@gas_optimization);
        mint_batch(cap, recipients, amounts);
    }
    
    // ============================================
    // 5. 批量查询优化
    // ============================================
    
    /// 批量获取余额
    public fun get_balances_batch(
        users: vector<address>
    ): vector<u64> acquires TokenBalance {
        let len = vector::length(&users);
        let balances = vector::empty<u64>();
        
        let i = 0;
        while (i < len) {
            let user = *vector::borrow(&users, i);
            let balance = if (exists<TokenBalance>(user)) {
                borrow_global<TokenBalance>(user).balance
            } else {
                0
            };
            vector::push_back(&mut balances, balance);
            i = i + 1;
        };
        
        balances
    }
    
    /// 批量获取状态
    public fun get_statuses_batch(
        users: vector<address>
    ): vector<u8> acquires UserStatus {
        let len = vector::length(&users);
        let statuses = vector::empty<u8>();
        
        let i = 0;
        while (i < len) {
            let user = *vector::borrow(&users, i);
            let status = if (exists<UserStatus>(user)) {
                borrow_global<UserStatus>(user).status
            } else {
                STATUS_PENDING
            };
            vector::push_back(&mut statuses, status);
            i = i + 1;
        };
        
        statuses
    }
    
    // ============================================
    // 辅助函数
    // ============================================
    
    native fun create_signer(addr: address): signer;
    
    // ============================================
    // 测试函数
    // ============================================
    
    #[test(admin = @gas_optimization)]
    public fun test_batch_transfer(admin: &signer) acquires TokenBalance {
        // 初始化发送者余额
        move_to(admin, TokenBalance { balance: 10000 });
        
        // 批量转账
        let recipients = vector::empty<address>();
        let amounts = vector::empty<u64>();
        
        vector::push_back(&mut recipients, @0x1);
        vector::push_back(&mut recipients, @0x2);
        vector::push_back(&mut recipients, @0x3);
        
        vector::push_back(&mut amounts, 1000);
        vector::push_back(&mut amounts, 2000);
        vector::push_back(&mut amounts, 3000);
        
        transfer_batch(admin, recipients, amounts);
        
        // 验证结果
        let admin_balance = borrow_global<TokenBalance>(@gas_optimization);
        assert!(admin_balance.balance == 4000, 0);
    }
    
    #[test(admin = @gas_optimization)]
    public fun test_batch_mint(admin: &signer) acquires TokenBalance, MintCapability {
        // 初始化 capability
        move_to(admin, MintCapability { total_minted: 0 });
        
        let cap = borrow_global_mut<MintCapability>(@gas_optimization);
        
        let recipients = vector::empty<address>();
        let amounts = vector::empty<u64>();
        
        vector::push_back(&mut recipients, @0x1);
        vector::push_back(&mut recipients, @0x2);
        
        vector::push_back(&mut amounts, 500);
        vector::push_back(&mut amounts, 1500);
        
        mint_batch(cap, recipients, amounts);
        
        // 验证 total_minted
        let cap = borrow_global<MintCapability>(@gas_optimization);
        assert!(cap.total_minted == 2000, 0);
    }
}
