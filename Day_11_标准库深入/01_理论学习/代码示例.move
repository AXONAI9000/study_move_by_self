/// # Move 标准库代码示例集
/// 
/// 本文件包含 vector、Table、SmartTable、option、string 等标准库的完整示例

module stdlib_examples::vector_examples {
    use std::vector;

    // ========== 示例 1: Vector 基础操作 ==========

    /// 演示 vector 的创建和基本操作
    public fun basic_vector_operations(): vector<u64> {
        // 创建空 vector
        let v = vector::empty<u64>();
        
        // 添加元素
        vector::push_back(&mut v, 10);
        vector::push_back(&mut v, 20);
        vector::push_back(&mut v, 30);
        
        // 访问元素
        assert!(*vector::borrow(&v, 0) == 10, 0);
        assert!(*vector::borrow(&v, 1) == 20, 1);
        
        // 修改元素
        let first = vector::borrow_mut(&mut v, 0);
        *first = 15;
        
        // 移除末尾元素
        let last = vector::pop_back(&mut v);
        assert!(last == 30, 2);
        
        v
    }

    /// 演示 vector 的批量操作
    public fun batch_operations() {
        let v1 = vector[1, 2, 3];
        let v2 = vector[4, 5, 6];
        
        // 追加
        vector::append(&mut v1, v2);
        assert!(vector::length(&v1) == 6, 0);
        
        // 反转
        vector::reverse(&mut v1);
        assert!(*vector::borrow(&v1, 0) == 6, 1);
        
        // 交换
        vector::swap(&mut v1, 0, 5);
        assert!(*vector::borrow(&v1, 0) == 1, 2);
    }

    /// 演示高效的删除操作
    public fun efficient_remove() {
        let v = vector[1, 2, 3, 4, 5];
        
        // swap_remove: O(1) 但不保持顺序
        let removed = vector::swap_remove(&mut v, 1);  // 移除 2
        assert!(removed == 2, 0);
        // v 现在是 [1, 5, 3, 4]（5 移到了 2 的位置）
        
        // remove: O(n) 但保持顺序
        let v2 = vector[1, 2, 3, 4, 5];
        let removed2 = vector::remove(&mut v2, 1);  // 移除 2
        assert!(removed2 == 2, 1);
        // v2 现在是 [1, 3, 4, 5]（保持顺序）
    }

    /// 查找元素
    public fun find_elements() {
        let v = vector[10, 20, 30, 40, 50];
        
        // 检查是否包含
        assert!(vector::contains(&v, &30), 0);
        assert!(!vector::contains(&v, &100), 1);
        
        // 查找索引
        let (found, index) = vector::index_of(&v, &30);
        assert!(found && index == 2, 2);
    }

    /// 遍历 vector
    public fun iterate_vector(v: &vector<u64>): u64 {
        let sum = 0;
        let i = 0;
        let len = vector::length(v);
        
        while (i < len) {
            sum = sum + *vector::borrow(v, i);
            i = i + 1;
        };
        
        sum
    }

    /// 过滤 vector（保留满足条件的元素）
    public fun filter_vector(v: vector<u64>, threshold: u64): vector<u64> {
        let result = vector::empty<u64>();
        let i = 0;
        let len = vector::length(&v);
        
        while (i < len) {
            let value = *vector::borrow(&v, i);
            if (value > threshold) {
                vector::push_back(&mut result, value);
            };
            i = i + 1;
        };
        
        result
    }

    /// Map 操作（将每个元素乘以 2）
    public fun map_vector(v: &mut vector<u64>) {
        let i = 0;
        let len = vector::length(v);
        
        while (i < len) {
            let value = vector::borrow_mut(v, i);
            *value = *value * 2;
            i = i + 1;
        };
    }

    // ========== 示例 2: Vector 作为栈 ==========

    struct Stack<T: drop> has store {
        data: vector<T>
    }

    public fun create_stack<T: drop>(): Stack<T> {
        Stack { data: vector::empty() }
    }

    public fun push<T: drop>(stack: &mut Stack<T>, item: T) {
        vector::push_back(&mut stack.data, item);
    }

    public fun pop<T: drop>(stack: &mut Stack<T>): T {
        vector::pop_back(&mut stack.data)
    }

    public fun peek<T: drop>(stack: &Stack<T>): &T {
        let len = vector::length(&stack.data);
        assert!(len > 0, 0);
        vector::borrow(&stack.data, len - 1)
    }

    public fun is_empty<T: drop>(stack: &Stack<T>): bool {
        vector::is_empty(&stack.data)
    }

    // ========== 示例 3: Vector 作为队列 ==========

    struct Queue<T: drop> has store {
        data: vector<T>
    }

    public fun create_queue<T: drop>(): Queue<T> {
        Queue { data: vector::empty() }
    }

    public fun enqueue<T: drop>(queue: &mut Queue<T>, item: T) {
        vector::push_back(&mut queue.data, item);
    }

    public fun dequeue<T: drop>(queue: &mut Queue<T>): T {
        vector::remove(&mut queue.data, 0)  // 从头部移除，O(n)
    }

    /// 更高效的队列实现（使用循环索引）
    struct EfficientQueue<T: drop> has store {
        data: vector<T>,
        head: u64,  // 队头索引
    }

    public fun create_efficient_queue<T: drop>(): EfficientQueue<T> {
        EfficientQueue { 
            data: vector::empty(),
            head: 0
        }
    }

    public fun efficient_enqueue<T: drop>(queue: &mut EfficientQueue<T>, item: T) {
        vector::push_back(&mut queue.data, item);
    }

    public fun efficient_dequeue<T: drop + copy>(queue: &mut EfficientQueue<T>): T {
        assert!(queue.head < vector::length(&queue.data), 0);
        let item = *vector::borrow(&queue.data, queue.head);
        queue.head = queue.head + 1;
        
        // 定期清理已出队的元素
        if (queue.head > 100 && queue.head * 2 > vector::length(&queue.data)) {
            let new_data = vector::empty<T>();
            let i = queue.head;
            let len = vector::length(&queue.data);
            while (i < len) {
                vector::push_back(&mut new_data, *vector::borrow(&queue.data, i));
                i = i + 1;
            };
            queue.data = new_data;
            queue.head = 0;
        };
        
        item
    }

    #[test]
    public fun test_vector_operations() {
        let v = basic_vector_operations();
        assert!(vector::length(&v) == 2, 0);
        assert!(*vector::borrow(&v, 0) == 15, 1);
    }

    #[test]
    public fun test_filter() {
        let v = vector[1, 5, 10, 15, 20];
        let filtered = filter_vector(v, 10);
        assert!(vector::length(&filtered) == 2, 0);
        assert!(*vector::borrow(&filtered, 0) == 15, 1);
    }
}

module stdlib_examples::table_examples {
    use std::signer;
    use aptos_std::table::{Self, Table};

    // ========== 示例 4: Table 基础操作 ==========

    struct UserBalance has key {
        balances: Table<address, u64>
    }

    /// 初始化用户余额系统
    public fun initialize(admin: &signer) {
        move_to(admin, UserBalance {
            balances: table::new()
        });
    }

    /// 设置用户余额
    public fun set_balance(addr: address, amount: u64) acquires UserBalance {
        let balances = &mut borrow_global_mut<UserBalance>(@stdlib_examples).balances;
        
        if (table::contains(balances, addr)) {
            let balance = table::borrow_mut(balances, addr);
            *balance = amount;
        } else {
            table::add(balances, addr, amount);
        };
    }

    /// 获取用户余额
    public fun get_balance(addr: address): u64 acquires UserBalance {
        let balances = &borrow_global<UserBalance>(@stdlib_examples).balances;
        
        if (table::contains(balances, addr)) {
            *table::borrow(balances, addr)
        } else {
            0
        }
    }

    /// 增加余额
    public fun add_balance(addr: address, amount: u64) acquires UserBalance {
        let balances = &mut borrow_global_mut<UserBalance>(@stdlib_examples).balances;
        
        // 使用 borrow_mut_with_default 简化代码
        let balance = table::borrow_mut_with_default(balances, addr, 0);
        *balance = *balance + amount;
    }

    /// 转账
    public fun transfer(from: address, to: address, amount: u64) acquires UserBalance {
        let balances = &mut borrow_global_mut<UserBalance>(@stdlib_examples).balances;
        
        // 检查发送方余额
        assert!(table::contains(balances, from), 1);
        let from_balance = table::borrow_mut(balances, from);
        assert!(*from_balance >= amount, 2);
        *from_balance = *from_balance - amount;
        
        // 增加接收方余额
        let to_balance = table::borrow_mut_with_default(balances, to, 0);
        *to_balance = *to_balance + amount;
    }

    /// 删除余额为 0 的账户
    public fun remove_zero_balance(addr: address) acquires UserBalance {
        let balances = &mut borrow_global_mut<UserBalance>(@stdlib_examples).balances;
        
        if (table::contains(balances, addr)) {
            let balance = table::borrow(balances, addr);
            if (*balance == 0) {
                table::remove(balances, addr);
            };
        };
    }

    // ========== 示例 5: Table 高级用法 - 嵌套 Table ==========

    /// NFT 集合，每个用户可以拥有多个 NFT
    struct NFTOwnership has key {
        // 用户地址 -> (NFT ID -> 是否拥有)
        ownership: Table<address, Table<u64, bool>>
    }

    public fun initialize_nft(admin: &signer) {
        move_to(admin, NFTOwnership {
            ownership: table::new()
        });
    }

    public fun mint_nft(to: address, nft_id: u64) acquires NFTOwnership {
        let ownership = &mut borrow_global_mut<NFTOwnership>(@stdlib_examples).ownership;
        
        // 如果用户还没有 NFT 表，创建一个
        if (!table::contains(ownership, to)) {
            table::add(ownership, to, table::new<u64, bool>());
        };
        
        // 获取用户的 NFT 表并添加 NFT
        let user_nfts = table::borrow_mut(ownership, to);
        table::add(user_nfts, nft_id, true);
    }

    public fun owns_nft(owner: address, nft_id: u64): bool acquires NFTOwnership {
        let ownership = &borrow_global<NFTOwnership>(@stdlib_examples).ownership;
        
        if (!table::contains(ownership, owner)) {
            return false
        };
        
        let user_nfts = table::borrow(ownership, owner);
        table::contains(user_nfts, nft_id)
    }
}

module stdlib_examples::smart_table_examples {
    use std::signer;
    use aptos_std::smart_table::{Self, SmartTable};
    use std::vector;

    // ========== 示例 6: SmartTable 可迭代的键值存储 ==========

    struct ProductInventory has key {
        products: SmartTable<u64, Product>  // product_id -> Product
    }

    struct Product has store, drop {
        name: vector<u8>,
        price: u64,
        stock: u64
    }

    /// 初始化商品库存
    public fun initialize(admin: &signer) {
        move_to(admin, ProductInventory {
            products: smart_table::new()
        });
    }

    /// 添加商品
    public fun add_product(
        product_id: u64,
        name: vector<u8>,
        price: u64,
        stock: u64
    ) acquires ProductInventory {
        let inventory = &mut borrow_global_mut<ProductInventory>(@stdlib_examples).products;
        
        smart_table::add(inventory, product_id, Product {
            name,
            price,
            stock
        });
    }

    /// 更新库存
    public fun update_stock(product_id: u64, new_stock: u64) acquires ProductInventory {
        let inventory = &mut borrow_global_mut<ProductInventory>(@stdlib_examples).products;
        
        assert!(smart_table::contains(inventory, product_id), 1);
        let product = smart_table::borrow_mut(inventory, product_id);
        product.stock = new_stock;
    }

    /// 获取所有商品 ID
    public fun get_all_product_ids(): vector<u64> acquires ProductInventory {
        let inventory = &borrow_global<ProductInventory>(@stdlib_examples).products;
        smart_table::keys(inventory)
    }

    /// 计算库存总价值
    public fun calculate_total_value(): u64 acquires ProductInventory {
        let inventory = &borrow_global<ProductInventory>(@stdlib_examples).products;
        let product_ids = smart_table::keys(inventory);
        
        let total_value = 0;
        let i = 0;
        let len = vector::length(&product_ids);
        
        while (i < len) {
            let product_id = *vector::borrow(&product_ids, i);
            let product = smart_table::borrow(inventory, product_id);
            total_value = total_value + (product.price * product.stock);
            i = i + 1;
        };
        
        total_value
    }

    /// 查找价格高于阈值的商品
    public fun find_expensive_products(min_price: u64): vector<u64> acquires ProductInventory {
        let inventory = &borrow_global<ProductInventory>(@stdlib_examples).products;
        let product_ids = smart_table::keys(inventory);
        
        let result = vector::empty<u64>();
        let i = 0;
        let len = vector::length(&product_ids);
        
        while (i < len) {
            let product_id = *vector::borrow(&product_ids, i);
            let product = smart_table::borrow(inventory, product_id);
            if (product.price >= min_price) {
                vector::push_back(&mut result, product_id);
            };
            i = i + 1;
        };
        
        result
    }

    /// 获取商品数量
    public fun get_product_count(): u64 acquires ProductInventory {
        let inventory = &borrow_global<ProductInventory>(@stdlib_examples).products;
        smart_table::length(inventory)
    }

    // ========== 示例 7: 用 Table + vector 实现可迭代映射 ==========

    use aptos_std::table::{Self, Table};

    struct IterableMap<K: copy + drop, V: store> has store {
        map: Table<K, V>,
        keys: vector<K>
    }

    public fun create_iterable_map<K: copy + drop, V: store>(): IterableMap<K, V> {
        IterableMap {
            map: table::new(),
            keys: vector::empty()
        }
    }

    public fun iterable_add<K: copy + drop, V: store>(
        imap: &mut IterableMap<K, V>,
        key: K,
        value: V
    ) {
        assert!(!table::contains(&imap.map, key), 1);
        table::add(&mut imap.map, key, value);
        vector::push_back(&mut imap.keys, key);
    }

    public fun iterable_remove<K: copy + drop, V: store>(
        imap: &mut IterableMap<K, V>,
        key: K
    ): V {
        let value = table::remove(&mut imap.map, key);
        
        // 从 keys 中移除
        let (found, index) = vector::index_of(&imap.keys, &key);
        if (found) {
            vector::swap_remove(&mut imap.keys, index);
        };
        
        value
    }

    public fun iterable_keys<K: copy + drop, V: store>(
        imap: &IterableMap<K, V>
    ): &vector<K> {
        &imap.keys
    }

    public fun iterable_size<K: copy + drop, V: store>(
        imap: &IterableMap<K, V>
    ): u64 {
        vector::length(&imap.keys)
    }
}

module stdlib_examples::option_examples {
    use std::option::{Self, Option};
    use std::vector;

    // ========== 示例 8: Option 基础用法 ==========

    /// 安全的除法
    public fun safe_divide(a: u64, b: u64): Option<u64> {
        if (b == 0) {
            option::none()
        } else {
            option::some(a / b)
        }
    }

    /// 查找第一个大于阈值的元素
    public fun find_first_greater(v: &vector<u64>, threshold: u64): Option<u64> {
        let i = 0;
        let len = vector::length(v);
        
        while (i < len) {
            let value = *vector::borrow(v, i);
            if (value > threshold) {
                return option::some(value)
            };
            i = i + 1;
        };
        
        option::none()
    }

    /// 使用 Option 的安全方式
    public fun use_option_safely(opt: Option<u64>): u64 {
        if (option::is_some(&opt)) {
            *option::borrow(&opt)
        } else {
            0  // 默认值
        }
    }

    // ========== 示例 9: Option 在结构体中的应用 ==========

    struct UserProfile has store, drop {
        name: vector<u8>,
        email: Option<vector<u8>>,  // 可选的邮箱
        age: Option<u8>,  // 可选的年龄
        bio: Option<vector<u8>>  // 可选的简介
    }

    public fun create_profile(name: vector<u8>): UserProfile {
        UserProfile {
            name,
            email: option::none(),
            age: option::none(),
            bio: option::none()
        }
    }

    public fun set_email(profile: &mut UserProfile, email: vector<u8>) {
        profile.email = option::some(email);
    }

    public fun get_email(profile: &UserProfile): Option<vector<u8>> {
        profile.email
    }

    public fun has_email(profile: &UserProfile): bool {
        option::is_some(&profile.email)
    }

    // ========== 示例 10: Option 链式操作 ==========

    /// 链式查找：先找到大于阈值的，然后检查是否是偶数
    public fun chain_find(v: &vector<u64>, threshold: u64): Option<u64> {
        let first_opt = find_first_greater(v, threshold);
        
        if (option::is_some(&first_opt)) {
            let value = *option::borrow(&first_opt);
            if (value % 2 == 0) {
                option::some(value)
            } else {
                option::none()
            }
        } else {
            option::none()
        }
    }

    #[test]
    public fun test_safe_divide() {
        let result1 = safe_divide(10, 2);
        assert!(option::is_some(&result1), 0);
        assert!(*option::borrow(&result1) == 5, 1);
        
        let result2 = safe_divide(10, 0);
        assert!(option::is_none(&result2), 2);
    }

    #[test]
    public fun test_find() {
        let v = vector[1, 5, 10, 15, 20];
        let result = find_first_greater(&v, 10);
        assert!(option::is_some(&result), 0);
        assert!(*option::borrow(&result) == 15, 1);
    }
}

module stdlib_examples::string_examples {
    use std::string::{Self, String};
    use std::vector;

    // ========== 示例 11: String 基础操作 ==========

    /// 创建和操作字符串
    public fun basic_string_ops(): String {
        // 从字节创建
        let s = string::utf8(b"Hello");
        
        // 追加
        let s2 = string::utf8(b" World");
        string::append(&mut s, s2);
        
        // 返回 "Hello World"
        s
    }

    /// 字符串比较
    public fun compare_strings(s1: String, s2: String): bool {
        s1 == s2
    }

    /// 检查是否为空
    public fun is_empty_string(s: &String): bool {
        string::is_empty(s)
    }

    /// 获取字符串长度（字节数）
    public fun get_string_length(s: &String): u64 {
        string::length(s)
    }

    /// 获取子字符串
    public fun get_substring(s: &String, start: u64, end: u64): String {
        string::sub_string(s, start, end)
    }

    // ========== 示例 12: String 在实际中的应用 ==========

    struct Token has store, drop {
        name: String,
        symbol: String,
        decimals: u8
    }

    public fun create_token(
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8
    ): Token {
        Token {
            name: string::utf8(name),
            symbol: string::utf8(symbol),
            decimals
        }
    }

    /// 格式化代币信息（简单版）
    public fun format_token_info(token: &Token): String {
        let info = token.name;
        string::append(&mut info, string::utf8(b" ("));
        string::append(&mut info, token.symbol);
        string::append(&mut info, string::utf8(b")"));
        info
    }

    #[test]
    public fun test_string_operations() {
        let s = basic_string_ops();
        assert!(string::length(&s) == 11, 0);  // "Hello World" 有 11 个字节
        
        let sub = get_substring(&s, 0, 5);
        assert!(sub == string::utf8(b"Hello"), 1);
    }

    #[test]
    public fun test_token() {
        let token = create_token(b"My Token", b"MTK", 8);
        let info = format_token_info(&token);
        assert!(info == string::utf8(b"My Token (MTK)"), 0);
    }
}

/// 💡 关键学习点总结：
///
/// 1. **Vector**：
///    - 末尾操作高效（push_back, pop_back）
///    - swap_remove 比 remove 快但不保持顺序
///    - 适合小型数据集和顺序访问
///
/// 2. **Table**：
///    - O(1) 随机访问
///    - 不可迭代
///    - borrow_mut_with_default 简化代码
///
/// 3. **SmartTable**：
///    - 可迭代的键值存储
///    - 删除操作较慢 O(n)
///    - 适合需要遍历的大数据集
///
/// 4. **Option**：
///    - 类型安全的可选值
///    - 总是先检查 is_some
///    - 使用 borrow_with_default 避免 panic
///
/// 5. **String**：
///    - UTF-8 编码保证
///    - 用于用户可见文本
///    - 操作产生新对象
///
/// 🎯 实践建议：
/// - 根据数据大小和访问模式选择数据结构
/// - 优先使用标准库提供的高效操作
/// - 注意 Gas 成本，避免不必要的复制和遍历
