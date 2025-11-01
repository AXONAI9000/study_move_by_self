/// 任务3：多重签名钱包
/// 实现需要多个所有者批准才能执行交易的钱包系统
module practice::multisig_wallet {
    use std::signer;
    use std::error;
    use std::vector;
    use aptos_std::table::{Self, Table};

    /// 多重签名钱包
    struct MultiSigWallet has key {
        owners: vector<address>,
        required_confirmations: u64,
        balance: u64,
        transaction_count: u64
    }

    /// 交易
    struct Transaction has store, drop, copy {
        id: u64,
        to: address,
        amount: u64,
        executed: bool,
        confirmations: vector<address>
    }

    /// 待处理交易列表
    struct PendingTransactions has key {
        transactions: Table<u64, Transaction>
    }

    /// 错误码
    const E_NOT_OWNER: u64 = 1;
    const E_WALLET_ALREADY_EXISTS: u64 = 2;
    const E_WALLET_NOT_FOUND: u64 = 3;
    const E_INVALID_REQUIRED_CONFIRMATIONS: u64 = 4;
    const E_TRANSACTION_NOT_FOUND: u64 = 5;
    const E_TRANSACTION_ALREADY_EXECUTED: u64 = 6;
    const E_ALREADY_CONFIRMED: u64 = 7;
    const E_INSUFFICIENT_CONFIRMATIONS: u64 = 8;
    const E_INSUFFICIENT_BALANCE: u64 = 9;

    /// 创建多重签名钱包
    public fun create_wallet(
        creator: &signer,
        owners: vector<address>,
        required: u64
    ) {
        let creator_addr = signer::address_of(creator);
        
        // 检查钱包是否已存在
        assert!(!exists<MultiSigWallet>(creator_addr), error::already_exists(E_WALLET_ALREADY_EXISTS));
        
        // 验证所需确认数
        let owners_count = vector::length(&owners);
        assert!(required > 0 && required <= owners_count, error::invalid_argument(E_INVALID_REQUIRED_CONFIRMATIONS));
        
        // 创建钱包
        let wallet = MultiSigWallet {
            owners,
            required_confirmations: required,
            balance: 0,
            transaction_count: 0
        };
        
        move_to(creator, wallet);
        
        // 创建待处理交易列表
        let pending_txs = PendingTransactions {
            transactions: table::new()
        };
        
        move_to(creator, pending_txs);
    }

    /// 存款
    public fun deposit(account: &signer, amount: u64) acquires MultiSigWallet {
        let addr = signer::address_of(account);
        assert!(exists<MultiSigWallet>(addr), error::not_found(E_WALLET_NOT_FOUND));
        
        let wallet = borrow_global_mut<MultiSigWallet>(addr);
        wallet.balance = wallet.balance + amount;
    }

    /// 提交交易
    public fun submit_transaction(
        owner: &signer,
        to: address,
        amount: u64
    ): u64 acquires MultiSigWallet, PendingTransactions {
        let wallet_addr = signer::address_of(owner);
        assert!(exists<MultiSigWallet>(wallet_addr), error::not_found(E_WALLET_NOT_FOUND));
        
        // 验证是所有者
        let wallet = borrow_global_mut<MultiSigWallet>(wallet_addr);
        assert!(is_owner_internal(&wallet.owners, wallet_addr), error::permission_denied(E_NOT_OWNER));
        
        // 创建交易
        let tx_id = wallet.transaction_count + 1;
        wallet.transaction_count = tx_id;
        
        let transaction = Transaction {
            id: tx_id,
            to,
            amount,
            executed: false,
            confirmations: vector::empty<address>()
        };
        
        // 添加到待处理列表
        let pending_txs = borrow_global_mut<PendingTransactions>(wallet_addr);
        table::add(&mut pending_txs.transactions, tx_id, transaction);
        
        tx_id
    }

    /// 确认交易
    public fun confirm_transaction(
        owner: &signer,
        tx_id: u64
    ) acquires MultiSigWallet, PendingTransactions {
        let wallet_addr = signer::address_of(owner);
        assert!(exists<MultiSigWallet>(wallet_addr), error::not_found(E_WALLET_NOT_FOUND));
        
        // 验证是所有者
        let wallet = borrow_global<MultiSigWallet>(wallet_addr);
        assert!(is_owner_internal(&wallet.owners, wallet_addr), error::permission_denied(E_NOT_OWNER));
        
        // 获取交易
        let pending_txs = borrow_global_mut<PendingTransactions>(wallet_addr);
        assert!(table::contains(&pending_txs.transactions, tx_id), error::not_found(E_TRANSACTION_NOT_FOUND));
        
        let transaction = table::borrow_mut(&mut pending_txs.transactions, tx_id);
        
        // 检查是否已执行
        assert!(!transaction.executed, error::invalid_state(E_TRANSACTION_ALREADY_EXECUTED));
        
        // 检查是否已确认
        assert!(!vector::contains(&transaction.confirmations, &wallet_addr), error::invalid_argument(E_ALREADY_CONFIRMED));
        
        // 添加确认
        vector::push_back(&mut transaction.confirmations, wallet_addr);
    }

    /// 执行交易
    public fun execute_transaction(
        owner: &signer,
        tx_id: u64
    ) acquires MultiSigWallet, PendingTransactions {
        let wallet_addr = signer::address_of(owner);
        assert!(exists<MultiSigWallet>(wallet_addr), error::not_found(E_WALLET_NOT_FOUND));
        
        // 验证是所有者
        let wallet = borrow_global_mut<MultiSigWallet>(wallet_addr);
        assert!(is_owner_internal(&wallet.owners, wallet_addr), error::permission_denied(E_NOT_OWNER));
        
        // 获取交易
        let pending_txs = borrow_global_mut<PendingTransactions>(wallet_addr);
        assert!(table::contains(&pending_txs.transactions, tx_id), error::not_found(E_TRANSACTION_NOT_FOUND));
        
        let transaction = table::borrow_mut(&mut pending_txs.transactions, tx_id);
        
        // 检查是否已执行
        assert!(!transaction.executed, error::invalid_state(E_TRANSACTION_ALREADY_EXECUTED));
        
        // 检查确认数
        let confirmation_count = vector::length(&transaction.confirmations);
        assert!(confirmation_count >= wallet.required_confirmations, error::invalid_state(E_INSUFFICIENT_CONFIRMATIONS));
        
        // 检查余额
        assert!(wallet.balance >= transaction.amount, error::invalid_state(E_INSUFFICIENT_BALANCE));
        
        // 执行交易
        wallet.balance = wallet.balance - transaction.amount;
        transaction.executed = true;
    }

    /// 获取余额
    public fun get_balance(wallet_addr: address): u64 acquires MultiSigWallet {
        assert!(exists<MultiSigWallet>(wallet_addr), error::not_found(E_WALLET_NOT_FOUND));
        borrow_global<MultiSigWallet>(wallet_addr).balance
    }

    /// 检查是否为所有者
    public fun is_owner(wallet_addr: address, addr: address): bool acquires MultiSigWallet {
        assert!(exists<MultiSigWallet>(wallet_addr), error::not_found(E_WALLET_NOT_FOUND));
        let wallet = borrow_global<MultiSigWallet>(wallet_addr);
        is_owner_internal(&wallet.owners, addr)
    }

    /// 内部函数：检查是否为所有者
    fun is_owner_internal(owners: &vector<address>, addr: address): bool {
        vector::contains(owners, &addr)
    }

    /// 获取交易信息
    public fun get_transaction(wallet_addr: address, tx_id: u64): Transaction acquires PendingTransactions {
        assert!(exists<PendingTransactions>(wallet_addr), error::not_found(E_WALLET_NOT_FOUND));
        let pending_txs = borrow_global<PendingTransactions>(wallet_addr);
        assert!(table::contains(&pending_txs.transactions, tx_id), error::not_found(E_TRANSACTION_NOT_FOUND));
        *table::borrow(&pending_txs.transactions, tx_id)
    }

    #[test(owner1 = @0x1, owner2 = @0x2, owner3 = @0x3, recipient = @0x99)]
    fun test_multisig_wallet(
        owner1: &signer,
        owner2: &signer,
        owner3: &signer,
        recipient: &signer
    ) acquires MultiSigWallet, PendingTransactions {
        // 创建所有者列表
        let owners = vector::empty<address>();
        vector::push_back(&mut owners, signer::address_of(owner1));
        vector::push_back(&mut owners, signer::address_of(owner2));
        vector::push_back(&mut owners, signer::address_of(owner3));
        
        // 创建钱包（需要2个确认）
        create_wallet(owner1, owners, 2);
        let wallet_addr = signer::address_of(owner1);
        
        // 存款
        deposit(owner1, 1000);
        assert!(get_balance(wallet_addr) == 1000, 0);
        
        // 提交交易
        let tx_id = submit_transaction(owner1, signer::address_of(recipient), 300);
        assert!(tx_id == 1, 1);
        
        // 第一个确认
        confirm_transaction(owner1, tx_id);
        
        // 第二个确认
        confirm_transaction(owner2, tx_id);
        
        // 执行交易
        execute_transaction(owner1, tx_id);
        
        // 验证余额
        assert!(get_balance(wallet_addr) == 700, 2);
        
        // 验证交易已执行
        let tx = get_transaction(wallet_addr, tx_id);
        assert!(tx.executed, 3);
    }

    #[test(owner1 = @0x1, owner2 = @0x2, owner3 = @0x3)]
    fun test_is_owner(owner1: &signer, owner2: &signer, owner3: &signer) acquires MultiSigWallet {
        let owners = vector::empty<address>();
        vector::push_back(&mut owners, signer::address_of(owner1));
        vector::push_back(&mut owners, signer::address_of(owner2));
        vector::push_back(&mut owners, signer::address_of(owner3));
        
        create_wallet(owner1, owners, 2);
        let wallet_addr = signer::address_of(owner1);
        
        assert!(is_owner(wallet_addr, signer::address_of(owner1)), 0);
        assert!(is_owner(wallet_addr, signer::address_of(owner2)), 1);
        assert!(is_owner(wallet_addr, signer::address_of(owner3)), 2);
        assert!(!is_owner(wallet_addr, @0x999), 3);
    }

    #[test(owner1 = @0x1, owner2 = @0x2, owner3 = @0x3, recipient = @0x99)]
    #[expected_failure(abort_code = E_INSUFFICIENT_CONFIRMATIONS)]
    fun test_insufficient_confirmations(
        owner1: &signer,
        owner2: &signer,
        owner3: &signer,
        recipient: &signer
    ) acquires MultiSigWallet, PendingTransactions {
        let owners = vector::empty<address>();
        vector::push_back(&mut owners, signer::address_of(owner1));
        vector::push_back(&mut owners, signer::address_of(owner2));
        vector::push_back(&mut owners, signer::address_of(owner3));
        
        create_wallet(owner1, owners, 2);
        deposit(owner1, 1000);
        
        let tx_id = submit_transaction(owner1, signer::address_of(recipient), 300);
        confirm_transaction(owner1, tx_id);  // 只有1个确认
        
        execute_transaction(owner1, tx_id);  // 应该失败
    }

    #[test(owner1 = @0x1, owner2 = @0x2, owner3 = @0x3, recipient = @0x99)]
    #[expected_failure(abort_code = E_ALREADY_CONFIRMED)]
    fun test_double_confirmation(
        owner1: &signer,
        owner2: &signer,
        owner3: &signer,
        recipient: &signer
    ) acquires MultiSigWallet, PendingTransactions {
        let owners = vector::empty<address>();
        vector::push_back(&mut owners, signer::address_of(owner1));
        vector::push_back(&mut owners, signer::address_of(owner2));
        vector::push_back(&mut owners, signer::address_of(owner3));
        
        create_wallet(owner1, owners, 2);
        deposit(owner1, 1000);
        
        let tx_id = submit_transaction(owner1, signer::address_of(recipient), 300);
        confirm_transaction(owner1, tx_id);
        confirm_transaction(owner1, tx_id);  // 应该失败，重复确认
    }

    #[test(owner1 = @0x1, owner2 = @0x2, owner3 = @0x3, recipient = @0x99)]
    #[expected_failure(abort_code = E_INSUFFICIENT_BALANCE)]
    fun test_insufficient_balance(
        owner1: &signer,
        owner2: &signer,
        owner3: &signer,
        recipient: &signer
    ) acquires MultiSigWallet, PendingTransactions {
        let owners = vector::empty<address>();
        vector::push_back(&mut owners, signer::address_of(owner1));
        vector::push_back(&mut owners, signer::address_of(owner2));
        vector::push_back(&mut owners, signer::address_of(owner3));
        
        create_wallet(owner1, owners, 2);
        deposit(owner1, 100);
        
        let tx_id = submit_transaction(owner1, signer::address_of(recipient), 300);
        confirm_transaction(owner1, tx_id);
        confirm_transaction(owner2, tx_id);
        
        execute_transaction(owner1, tx_id);  // 应该失败，余额不足
    }

    #[test(owner1 = @0x1, owner2 = @0x2, owner3 = @0x3, recipient = @0x99)]
    #[expected_failure(abort_code = E_TRANSACTION_ALREADY_EXECUTED)]
    fun test_double_execution(
        owner1: &signer,
        owner2: &signer,
        owner3: &signer,
        recipient: &signer
    ) acquires MultiSigWallet, PendingTransactions {
        let owners = vector::empty<address>();
        vector::push_back(&mut owners, signer::address_of(owner1));
        vector::push_back(&mut owners, signer::address_of(owner2));
        vector::push_back(&mut owners, signer::address_of(owner3));
        
        create_wallet(owner1, owners, 2);
        deposit(owner1, 1000);
        
        let tx_id = submit_transaction(owner1, signer::address_of(recipient), 300);
        confirm_transaction(owner1, tx_id);
        confirm_transaction(owner2, tx_id);
        
        execute_transaction(owner1, tx_id);
        execute_transaction(owner1, tx_id);  // 应该失败，已经执行过
    }
}
