/// Day 06 代码示例：泛型编程与能力系统
/// 本文件包含所有核心概念的可运行示例
module day06::examples {
    use std::signer;
    use std::vector;

    // ============================================
    // 第一部分：泛型示例
    // ============================================

    /// 示例 1：泛型结构体 - 通用容器
    struct Box<T> {
        value: T
    }

    /// 创建一个 Box
    public fun create_box<T>(value: T): Box<T> {
        Box { value }
    }

    /// 从 Box 中取出值（需要 T 有 copy 能力才能复制）
    public fun peek<T: copy>(box: &Box<T>): T {
        box.value
    }

    /// 解构 Box 并返回值
    public fun unbox<T>(box: Box<T>): T {
        let Box { value } = box;
        value
    }

    /// 示例 2：泛型函数 - 交换两个值
    public fun swap<T>(a: T, b: T): (T, T) {
        (b, a)
    }

    /// 示例 3：多个泛型参数
    struct Pair<T1, T2> {
        first: T1,
        second: T2
    }

    public fun create_pair<T1, T2>(first: T1, second: T2): Pair<T1, T2> {
        Pair { first, second }
    }

    public fun get_first<T1: copy, T2>(pair: &Pair<T1, T2>): T1 {
        pair.first
    }

    /// 示例 4：泛型约束
    /// T 必须具有 copy 能力才能复制
    public fun duplicate<T: copy>(value: T): (T, T) {
        (value, value)
    }

    /// T 必须具有 drop 能力才能被丢弃
    public fun discard<T: drop>(value: T) {
        // value 会在函数结束时自动丢弃
    }

    /// T 需要同时具有 copy 和 drop
    public fun process<T: copy + drop>(value: T): T {
        let copy = value;  // 复制
        copy  // 返回副本，原值被丢弃
    }

    // ============================================
    // 第二部分：能力系统示例
    // ============================================

    /// 示例 5：copy 能力
    /// 具有 copy 能力的结构体可以被复制
    struct Point has copy, drop {
        x: u64,
        y: u64
    }

    public fun use_point_multiple_times() {
        let p1 = Point { x: 1, y: 2 };
        let p2 = p1;  // p1 被复制
        let p3 = p1;  // 可以再次使用 p1
        // p1, p2, p3 都是独立的副本
    }

    /// 示例 6：没有 copy 能力的资源类型
    /// 代币类型不应该有 copy 能力，防止双花
    struct Coin has store {
        value: u64
    }

    public fun use_coin_once_only() {
        let coin1 = Coin { value: 100 };
        let coin2 = coin1;  // coin1 被移动
        // let coin3 = coin1;  // 错误！coin1 已经不存在了
        
        // 必须显式销毁 coin2
        destroy_coin(coin2);
    }

    /// 销毁代币（通过解构）
    fun destroy_coin(coin: Coin) {
        let Coin { value: _ } = coin;
    }

    /// 示例 7：drop 能力
    struct Config has copy, drop {
        max_value: u64,
        min_value: u64
    }

    public fun use_config() {
        let config = Config { max_value: 1000, min_value: 0 };
        // config 会在函数结束时自动丢弃
    }

    /// 没有 drop 能力的类型必须显式处理
    struct MustHandle {
        value: u64
    }

    public fun must_handle_explicitly() {
        let item = MustHandle { value: 42 };
        // 不能让 item 自动丢弃，必须显式处理
        handle(item);
    }

    fun handle(item: MustHandle) {
        let MustHandle { value: _ } = item;  // 解构销毁
    }

    /// 示例 8：store 能力
    /// 具有 store 能力可以存储在全局存储或其他结构体中
    struct Token has store {
        amount: u64
    }

    struct Wallet has key {
        tokens: vector<Token>  // Token 有 store 能力
    }

    public fun create_wallet(account: &signer) {
        move_to(account, Wallet {
            tokens: vector::empty()
        });
    }

    /// 示例 9：key 能力
    /// 具有 key 能力的结构体可以作为全局存储的顶层对象
    struct UserAccount has key {
        balance: u64,
        is_active: bool
    }

    public fun create_account(account: &signer) {
        let addr = signer::address_of(account);
        if (!exists<UserAccount>(addr)) {
            move_to(account, UserAccount {
                balance: 0,
                is_active: true
            });
        }
    }

    public fun get_balance(addr: address): u64 acquires UserAccount {
        borrow_global<UserAccount>(addr).balance
    }

    public fun deposit(account: &signer, amount: u64) acquires UserAccount {
        let addr = signer::address_of(account);
        let account_ref = borrow_global_mut<UserAccount>(addr);
        account_ref.balance = account_ref.balance + amount;
    }

    // ============================================
    // 第三部分：高级模式
    // ============================================

    /// 示例 10：Hot Potato 模式
    /// 没有任何能力的结构体，必须被消费
    struct Receipt {
        amount: u64,
        borrower: address
    }

    /// 借出资金，返回一个必须被处理的 Receipt
    public fun flash_borrow(amount: u64, borrower: address): Receipt {
        // 实际实现中会给出代币
        Receipt { amount, borrower }
    }

    /// 归还资金，消费 Receipt
    public fun flash_repay(receipt: Receipt) {
        let Receipt { amount: _, borrower: _ } = receipt;
        // 实际实现中会收回代币
        // Receipt 被解构，强制用户完成了借还流程
    }

    /// 用户必须这样使用：
    /// let receipt = flash_borrow(1000, @user);
    /// // 使用借来的资金做套利...
    /// flash_repay(receipt);  // 必须归还，否则编译错误！

    /// 示例 11：泛型钱包
    /// 可以存储任何具有 store 能力的代币类型
    struct GenericWallet<CoinType: store> has key {
        coins: vector<CoinType>
    }

    public fun create_generic_wallet<CoinType: store>(account: &signer) {
        move_to(account, GenericWallet<CoinType> {
            coins: vector::empty()
        });
    }

    public fun deposit_to_wallet<CoinType: store>(
        account: &signer,
        coin: CoinType
    ) acquires GenericWallet {
        let addr = signer::address_of(account);
        let wallet = borrow_global_mut<GenericWallet<CoinType>>(addr);
        vector::push_back(&mut wallet.coins, coin);
    }

    public fun wallet_balance<CoinType: store>(addr: address): u64 
        acquires GenericWallet 
    {
        let wallet = borrow_global<GenericWallet<CoinType>>(addr);
        vector::length(&wallet.coins)
    }

    /// 示例 12：能力组合的实际应用
    
    // 配置数据：可以自由复制和丢弃
    struct SystemConfig has copy, drop, store {
        fee_rate: u64,
        max_supply: u64
    }

    // 资产类型：只能存储，不能复制和丢弃
    struct Asset has store {
        id: u64,
        value: u64
    }

    // 全局资源：可以作为键和存储
    struct Registry has key, store {
        configs: vector<SystemConfig>,
        assets: vector<Asset>
    }

    // Witness 模式：用于一次性授权
    struct Witness has drop {
        // 只有 drop，可以在使用后立即丢弃
    }

    /// 示例 13：泛型约束的实际应用
    
    /// 只能交换可复制的值
    public fun safe_swap<T: copy + drop>(a: T, b: T): (T, T) {
        (b, a)
    }

    /// 只能存储具有 store 能力的值
    public fun store_value<T: store>(storage: &mut vector<T>, value: T) {
        vector::push_back(storage, value);
    }

    // ============================================
    // 第四部分：测试函数
    // ============================================

    #[test]
    fun test_generic_box() {
        let box = create_box<u64>(42);
        let value = unbox(box);
        assert!(value == 42, 0);
    }

    #[test]
    fun test_swap() {
        let (a, b) = swap<u64>(1, 2);
        assert!(a == 2 && b == 1, 0);
    }

    #[test]
    fun test_duplicate() {
        let (a, b) = duplicate<u64>(100);
        assert!(a == 100 && b == 100, 0);
    }

    #[test]
    fun test_point_copy() {
        let p1 = Point { x: 1, y: 2 };
        let p2 = p1;
        let p3 = p1;
        assert!(p2.x == 1 && p3.x == 1, 0);
    }

    #[test(account = @0x1)]
    fun test_account_creation(account: &signer) {
        create_account(account);
        let addr = signer::address_of(account);
        assert!(exists<UserAccount>(addr), 0);
    }

    #[test(account = @0x1)]
    fun test_deposit(account: &signer) acquires UserAccount {
        create_account(account);
        deposit(account, 100);
        let addr = signer::address_of(account);
        assert!(get_balance(addr) == 100, 0);
    }

    #[test]
    fun test_hot_potato() {
        let receipt = flash_borrow(1000, @0x1);
        // 必须归还
        flash_repay(receipt);
        // 如果不归还，编译会报错：
        // "local `receipt` still contains a value. The value does not have the `drop` ability"
    }

    #[test(account = @0x1)]
    fun test_generic_wallet(account: &signer) acquires GenericWallet {
        create_generic_wallet<Coin>(account);
        let coin = Coin { value: 50 };
        deposit_to_wallet(account, coin);
        
        let addr = signer::address_of(account);
        assert!(wallet_balance<Coin>(addr) == 1, 0);
    }
}
