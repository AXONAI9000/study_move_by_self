// ===================================================================
// Day 04: 结构体与资源概念 - 代码示例
// ===================================================================

module day04::struct_examples {
    use std::signer;
    use std::vector;
    
    // ===================================================================
    // 1. 基础结构体定义
    // ===================================================================
    
    // 简单结构体 - 具有 copy 和 drop 能力
    struct Point has copy, drop {
        x: u64,
        y: u64,
    }
    
    // 复杂结构体 - 多种类型的字段
    struct UserProfile has copy, drop, store {
        username: vector<u8>,
        age: u8,
        score: u64,
        is_active: bool,
    }
    
    // 空结构体 - 常用作见证（Witness）
    struct Witness has drop {}
    
    // ===================================================================
    // 2. 不同能力组合的结构体
    // ===================================================================
    
    // 只有 store - 可以存储但不可复制或丢弃
    struct Token has store {
        value: u64,
    }
    
    // key + store - 典型的资源类型
    struct Account has key, store {
        balance: u64,
        tokens: vector<Token>,
    }
    
    // copy + drop + store - 配置类型
    struct Config has copy, drop, store {
        max_users: u64,
        fee_rate: u64,
        is_paused: bool,
    }
    
    // 无能力 - "热土豆"模式，必须被处理
    struct Receipt {
        id: u64,
        amount: u64,
    }
    
    // ===================================================================
    // 3. 结构体的创建和使用
    // ===================================================================
    
    // 创建和返回结构体
    public fun create_point(x: u64, y: u64): Point {
        Point { x, y }
    }
    
    // 访问字段
    public fun get_coordinates(point: &Point): (u64, u64) {
        (point.x, point.y)
    }
    
    // 修改字段
    public fun move_point(point: &mut Point, dx: u64, dy: u64) {
        point.x = point.x + dx;
        point.y = point.y + dy;
    }
    
    // 解构结构体
    public fun distance_from_origin(point: Point): u64 {
        let Point { x, y } = point;
        // 简化：使用勾股定理的近似
        if (x > y) { x } else { y }
    }
    
    // ===================================================================
    // 4. 嵌套结构体
    // ===================================================================
    
    struct Address has copy, drop, store {
        street: vector<u8>,
        city: vector<u8>,
        country: vector<u8>,
    }
    
    struct Company has copy, drop, store {
        name: vector<u8>,
        address: Address,
        employee_count: u64,
    }
    
    // 创建嵌套结构体
    public fun create_company(
        name: vector<u8>,
        street: vector<u8>,
        city: vector<u8>,
        country: vector<u8>,
        employees: u64
    ): Company {
        Company {
            name,
            address: Address { street, city, country },
            employee_count: employees,
        }
    }
    
    // 访问嵌套字段
    public fun get_company_city(company: &Company): vector<u8> {
        *&company.address.city
    }
    
    // ===================================================================
    // 5. 资源管理示例
    // ===================================================================
    
    struct Coin has key {
        value: u64,
    }
    
    // 创建资源并存储到账户
    public fun create_account(account: &signer, initial_balance: u64) {
        let coin = Coin { value: initial_balance };
        move_to(account, coin);
    }
    
    // 检查账户是否存在
    public fun account_exists(addr: address): bool {
        exists<Coin>(addr)
    }
    
    // 查询余额（只读借用）
    public fun balance(addr: address): u64 acquires Coin {
        assert!(exists<Coin>(addr), 1); // 账户不存在
        let coin = borrow_global<Coin>(addr);
        coin.value
    }
    
    // 存款（可变借用）
    public fun deposit(addr: address, amount: u64) acquires Coin {
        assert!(exists<Coin>(addr), 1); // 账户不存在
        let coin = borrow_global_mut<Coin>(addr);
        coin.value = coin.value + amount;
    }
    
    // 取款（可变借用 + 断言）
    public fun withdraw(account: &signer, amount: u64) acquires Coin {
        let addr = signer::address_of(account);
        assert!(exists<Coin>(addr), 1); // 账户不存在
        
        let coin = borrow_global_mut<Coin>(addr);
        assert!(coin.value >= amount, 2); // 余额不足
        
        coin.value = coin.value - amount;
    }
    
    // 转账
    public fun transfer(
        from: &signer,
        to: address,
        amount: u64
    ) acquires Coin {
        let from_addr = signer::address_of(from);
        
        // 检查账户存在
        assert!(exists<Coin>(from_addr), 1);
        assert!(exists<Coin>(to), 3);
        
        // 从发送者扣除
        let from_coin = borrow_global_mut<Coin>(from_addr);
        assert!(from_coin.value >= amount, 2);
        from_coin.value = from_coin.value - amount;
        
        // 给接收者增加
        let to_coin = borrow_global_mut<Coin>(to);
        to_coin.value = to_coin.value + amount;
    }
    
    // 销毁账户
    public fun close_account(account: &signer) acquires Coin {
        let addr = signer::address_of(account);
        assert!(exists<Coin>(addr), 1);
        
        // 移出资源
        let Coin { value } = move_from<Coin>(addr);
        
        // 确保余额为0才能销毁
        assert!(value == 0, 4); // 余额不为0，不能销毁
    }
    
    // ===================================================================
    // 6. Token 管理示例（存储类型）
    // ===================================================================
    
    struct Wallet has key {
        tokens: vector<Token>,
    }
    
    // 创建钱包
    public fun create_wallet(account: &signer) {
        let wallet = Wallet {
            tokens: vector::empty<Token>(),
        };
        move_to(account, wallet);
    }
    
    // 铸造 Token
    public fun mint_token(value: u64): Token {
        Token { value }
    }
    
    // 添加 Token 到钱包
    public fun add_token(addr: address, token: Token) acquires Wallet {
        assert!(exists<Wallet>(addr), 1);
        let wallet = borrow_global_mut<Wallet>(addr);
        vector::push_back(&mut wallet.tokens, token);
    }
    
    // 获取钱包中 Token 数量
    public fun token_count(addr: address): u64 acquires Wallet {
        assert!(exists<Wallet>(addr), 1);
        let wallet = borrow_global<Wallet>(addr);
        vector::length(&wallet.tokens)
    }
    
    // 从钱包中取出 Token
    public fun remove_token(account: &signer): Token acquires Wallet {
        let addr = signer::address_of(account);
        assert!(exists<Wallet>(addr), 1);
        
        let wallet = borrow_global_mut<Wallet>(addr);
        assert!(!vector::is_empty(&wallet.tokens), 2); // 钱包为空
        
        vector::pop_back(&mut wallet.tokens)
    }
    
    // 销毁 Token
    public fun burn_token(token: Token): u64 {
        let Token { value } = token;
        value
    }
    
    // ===================================================================
    // 7. 热土豆（Hot Potato）模式
    // ===================================================================
    
    // Receipt 没有任何能力，必须被处理
    public fun create_receipt(id: u64, amount: u64): Receipt {
        Receipt { id, amount }
    }
    
    // 必须调用此函数来"消费"Receipt
    public fun process_receipt(receipt: Receipt): u64 {
        let Receipt { id: _, amount } = receipt;
        amount
    }
    
    // 错误示例：如果不处理 Receipt，编译器会报错
    // public fun wrong_usage() {
    //     let receipt = create_receipt(1, 100);
    //     // 编译错误：receipt 未被使用或销毁
    // }
    
    // ===================================================================
    // 8. 复杂数据结构示例
    // ===================================================================
    
    struct Item has store, drop {
        id: u64,
        name: vector<u8>,
        quantity: u64,
    }
    
    struct Inventory has key {
        owner: address,
        items: vector<Item>,
        capacity: u64,
    }
    
    // 创建库存
    public fun create_inventory(account: &signer, capacity: u64) {
        let inventory = Inventory {
            owner: signer::address_of(account),
            items: vector::empty<Item>(),
            capacity,
        };
        move_to(account, inventory);
    }
    
    // 添加物品
    public fun add_item(
        account: &signer,
        id: u64,
        name: vector<u8>,
        quantity: u64
    ) acquires Inventory {
        let addr = signer::address_of(account);
        assert!(exists<Inventory>(addr), 1);
        
        let inventory = borrow_global_mut<Inventory>(addr);
        assert!(vector::length(&inventory.items) < inventory.capacity, 2); // 超出容量
        
        let item = Item { id, name, quantity };
        vector::push_back(&mut inventory.items, item);
    }
    
    // 获取物品数量
    public fun item_count(addr: address): u64 acquires Inventory {
        assert!(exists<Inventory>(addr), 1);
        let inventory = borrow_global<Inventory>(addr);
        vector::length(&inventory.items)
    }
    
    // ===================================================================
    // 9. 泛型结构体预览（将在 Day 06 详细讲解）
    // ===================================================================
    
    struct Box<T: store> has store {
        value: T,
    }
    
    // 创建不同类型的盒子
    public fun create_u64_box(value: u64): Box<u64> {
        Box { value }
    }
    
    public fun create_bool_box(value: bool): Box<bool> {
        Box { value }
    }
    
    // 提取盒子中的值
    public fun unbox<T: store>(box: Box<T>): T {
        let Box { value } = box;
        value
    }
    
    // ===================================================================
    // 10. 实用工具函数
    // ===================================================================
    
    // 批量创建 Points
    public fun create_points(count: u64): vector<Point> {
        let points = vector::empty<Point>();
        let i = 0;
        while (i < count) {
            vector::push_back(&mut points, Point { x: i, y: i * 2 });
            i = i + 1;
        };
        points
    }
    
    // 计算所有 Points 的总和
    public fun sum_points(points: &vector<Point>): (u64, u64) {
        let sum_x = 0;
        let sum_y = 0;
        let i = 0;
        let len = vector::length(points);
        
        while (i < len) {
            let point = vector::borrow(points, i);
            sum_x = sum_x + point.x;
            sum_y = sum_y + point.y;
            i = i + 1;
        };
        
        (sum_x, sum_y)
    }
    
    // ===================================================================
    // 11. 测试函数
    // ===================================================================
    
    #[test]
    public fun test_point_creation() {
        let point = create_point(10, 20);
        let (x, y) = get_coordinates(&point);
        assert!(x == 10 && y == 20, 0);
    }
    
    #[test]
    public fun test_point_movement() {
        let point = create_point(5, 5);
        move_point(&mut point, 3, 7);
        let (x, y) = get_coordinates(&point);
        assert!(x == 8 && y == 12, 0);
    }
    
    #[test(account = @0x1)]
    public fun test_coin_operations(account: &signer) acquires Coin {
        // 创建账户
        create_account(account, 1000);
        
        // 检查余额
        let addr = signer::address_of(account);
        assert!(balance(addr) == 1000, 0);
        
        // 存款
        deposit(addr, 500);
        assert!(balance(addr) == 1500, 1);
        
        // 取款
        withdraw(account, 300);
        assert!(balance(addr) == 1200, 2);
    }
    
    #[test(from = @0x1, to = @0x2)]
    public fun test_transfer(from: &signer, to: &signer) acquires Coin {
        // 创建两个账户
        create_account(from, 1000);
        create_account(to, 500);
        
        let from_addr = signer::address_of(from);
        let to_addr = signer::address_of(to);
        
        // 转账
        transfer(from, to_addr, 300);
        
        // 验证余额
        assert!(balance(from_addr) == 700, 0);
        assert!(balance(to_addr) == 800, 1);
    }
    
    #[test]
    public fun test_hot_potato() {
        let receipt = create_receipt(1, 100);
        let amount = process_receipt(receipt);
        assert!(amount == 100, 0);
    }
    
    #[test(account = @0x1)]
    public fun test_wallet_operations(account: &signer) acquires Wallet {
        create_wallet(account);
        
        let addr = signer::address_of(account);
        assert!(token_count(addr) == 0, 0);
        
        // 添加 tokens
        let token1 = mint_token(100);
        let token2 = mint_token(200);
        add_token(addr, token1);
        add_token(addr, token2);
        
        assert!(token_count(addr) == 2, 1);
        
        // 移除 token
        let token = remove_token(account);
        let value = burn_token(token);
        assert!(value == 200, 2);
        assert!(token_count(addr) == 1, 3);
    }
}
