// ==========================================
// MEV 策略与防护 - 代码示例
// ==========================================

module mev_examples::comprehensive {
    use std::signer;
    use std::vector;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_std::math64;
    use aptos_std::table::{Self, Table};

    // ==========================================
    // 1. MEV 检测与监控
    // ==========================================

    /// 交易信息结构
    struct TransactionInfo has store, copy, drop {
        sender: address,
        function_name: vector<u8>,
        amount: u64,
        timestamp: u64,
        gas_price: u64,
    }

    /// MEV 检测器
    struct MEVDetector has key {
        recent_transactions: vector<TransactionInfo>,
        suspicious_patterns: Table<address, u64>,
        alert_events: EventHandle<MEVAlertEvent>,
    }

    /// MEV 告警事件
    struct MEVAlertEvent has drop, store {
        attacker: address,
        victim: address,
        mev_type: u8,  // 1=front-run, 2=sandwich, 3=back-run
        estimated_profit: u64,
        timestamp: u64,
    }

    /// 初始化检测器
    public fun initialize_detector(admin: &signer) {
        move_to(admin, MEVDetector {
            recent_transactions: vector::empty(),
            suspicious_patterns: table::new(),
            alert_events: event::new_event_handle<MEVAlertEvent>(admin),
        });
    }

    /// 记录交易
    public fun record_transaction(
        detector_addr: address,
        sender: address,
        function_name: vector<u8>,
        amount: u64,
        gas_price: u64,
    ) acquires MEVDetector {
        let detector = borrow_global_mut<MEVDetector>(detector_addr);
        
        let tx_info = TransactionInfo {
            sender,
            function_name,
            amount,
            timestamp: timestamp::now_seconds(),
            gas_price,
        };
        
        // 保留最近100笔交易
        vector::push_back(&mut detector.recent_transactions, tx_info);
        if (vector::length(&detector.recent_transactions) > 100) {
            vector::remove(&mut detector.recent_transactions, 0);
        };
        
        // 检测可疑模式
        detect_suspicious_patterns(detector, &tx_info);
    }

    /// 检测可疑模式
    fun detect_suspicious_patterns(
        detector: &mut MEVDetector,
        current_tx: &TransactionInfo,
    ) {
        let len = vector::length(&detector.recent_transactions);
        if (len < 3) return;
        
        // 检查sandwich模式
        let i = len - 3;
        let front_tx = vector::borrow(&detector.recent_transactions, i);
        let middle_tx = vector::borrow(&detector.recent_transactions, i + 1);
        let back_tx = vector::borrow(&detector.recent_transactions, i + 2);
        
        if (is_sandwich_attack(front_tx, middle_tx, back_tx)) {
            // 发出告警
            event::emit_event(&mut detector.alert_events, MEVAlertEvent {
                attacker: front_tx.sender,
                victim: middle_tx.sender,
                mev_type: 2,
                estimated_profit: calculate_sandwich_profit(front_tx, back_tx),
                timestamp: timestamp::now_seconds(),
            });
            
            // 记录可疑地址
            if (!table::contains(&detector.suspicious_patterns, front_tx.sender)) {
                table::add(&mut detector.suspicious_patterns, front_tx.sender, 1);
            } else {
                let count = table::borrow_mut(&mut detector.suspicious_patterns, front_tx.sender);
                *count = *count + 1;
            };
        };
    }

    /// 判断是否为sandwich攻击
    fun is_sandwich_attack(
        front: &TransactionInfo,
        middle: &TransactionInfo,
        back: &TransactionInfo,
    ): bool {
        // 1. 同一个攻击者
        if (front.sender != back.sender) return false;
        
        // 2. 相似的金额
        let amount_diff = if (front.amount > back.amount) {
            front.amount - back.amount
        } else {
            back.amount - front.amount
        };
        if (amount_diff > front.amount / 10) return false; // 允许10%差异
        
        // 3. 高gas price
        if (front.gas_price <= middle.gas_price) return false;
        
        // 4. 时间连续
        if (back.timestamp - front.timestamp > 10) return false; // 10秒内
        
        true
    }

    /// 计算sandwich利润
    fun calculate_sandwich_profit(
        front: &TransactionInfo,
        back: &TransactionInfo,
    ): u64 {
        // 简化计算
        if (back.amount > front.amount) {
            back.amount - front.amount
        } else {
            0
        }
    }

    // ==========================================
    // 2. 防护机制 - 滑点保护
    // ==========================================

    /// 带滑点保护的Swap
    struct ProtectedSwap<phantom CoinIn, phantom CoinOut> has key {
        min_output_bps: u64,  // 最小输出百分比 (基点)
    }

    const ERROR_SLIPPAGE_TOO_HIGH: u64 = 1001;
    const ERROR_EXPIRED: u64 = 1002;

    /// 执行受保护的swap
    public fun swap_with_slippage_protection<CoinIn, CoinOut>(
        user: &signer,
        amount_in: u64,
        min_amount_out: u64,
        deadline: u64,
    ): Coin<CoinOut> {
        // 1. 检查截止时间
        assert!(timestamp::now_seconds() <= deadline, ERROR_EXPIRED);
        
        // 2. 计算预期输出
        let expected_output = calculate_output_amount<CoinIn, CoinOut>(amount_in);
        
        // 3. 滑点检查
        assert!(expected_output >= min_amount_out, ERROR_SLIPPAGE_TOO_HIGH);
        
        // 4. 执行swap（示例）
        let coins_in = coin::withdraw<CoinIn>(user, amount_in);
        let coins_out = execute_swap<CoinIn, CoinOut>(coins_in);
        
        coins_out
    }

    /// 计算推荐滑点
    public fun calculate_recommended_slippage(
        trade_size: u64,
        pool_liquidity: u64,
    ): u64 {
        let size_ratio = (trade_size * 10000) / pool_liquidity;
        
        if (size_ratio < 10) {          // < 0.1%
            50                           // 0.5%
        } else if (size_ratio < 100) {  // < 1%
            100                          // 1%
        } else if (size_ratio < 500) {  // < 5%
            300                          // 3%
        } else {
            500                          // 5%
        }
    }

    // 占位函数（实际实现需要连接真实DEX）
    fun calculate_output_amount<CoinIn, CoinOut>(amount_in: u64): u64 { amount_in }
    fun execute_swap<CoinIn, CoinOut>(coins_in: Coin<CoinIn>): Coin<CoinOut> {
        abort 0
    }

    // ==========================================
    // 3. 防护机制 - TWAP价格预言机
    // ==========================================

    /// TWAP价格预言机
    struct TWAPOracle has key {
        cumulative_price: u128,
        last_price: u64,
        last_update: u64,
        observations: vector<PriceObservation>,
    }

    struct PriceObservation has store, copy, drop {
        timestamp: u64,
        price: u64,
        cumulative: u128,
    }

    const MAX_OBSERVATIONS: u64 = 24; // 保存24个观察点

    /// 初始化TWAP预言机
    public fun initialize_twap(admin: &signer, initial_price: u64) {
        move_to(admin, TWAPOracle {
            cumulative_price: 0,
            last_price: initial_price,
            last_update: timestamp::now_seconds(),
            observations: vector::empty(),
        });
    }

    /// 更新价格
    public fun update_twap_price(
        oracle_addr: address,
        new_price: u64,
    ) acquires TWAPOracle {
        let oracle = borrow_global_mut<TWAPOracle>(oracle_addr);
        let now = timestamp::now_seconds();
        let elapsed = now - oracle.last_update;
        
        // 累加价格
        oracle.cumulative_price = oracle.cumulative_price + 
            (oracle.last_price as u128) * (elapsed as u128);
        
        // 记录观察点
        let observation = PriceObservation {
            timestamp: now,
            price: new_price,
            cumulative: oracle.cumulative_price,
        };
        vector::push_back(&mut oracle.observations, observation);
        
        // 保持观察点数量
        if (vector::length(&oracle.observations) > MAX_OBSERVATIONS) {
            vector::remove(&mut oracle.observations, 0);
        };
        
        // 更新状态
        oracle.last_price = new_price;
        oracle.last_update = now;
    }

    /// 获取TWAP价格
    public fun get_twap_price(
        oracle_addr: address,
        period: u64,
    ): u64 acquires TWAPOracle {
        let oracle = borrow_global<TWAPOracle>(oracle_addr);
        let now = timestamp::now_seconds();
        let target_time = now - period;
        
        // 找到最接近目标时间的观察点
        let obs = &oracle.observations;
        let len = vector::length(obs);
        
        let i = 0;
        let old_observation = vector::borrow(obs, 0);
        while (i < len) {
            let current = vector::borrow(obs, i);
            if (current.timestamp >= target_time) {
                break
            };
            old_observation = current;
            i = i + 1;
        };
        
        // 计算时间加权平均价格
        let time_elapsed = now - old_observation.timestamp;
        let price_delta = oracle.cumulative_price - old_observation.cumulative;
        
        ((price_delta / (time_elapsed as u128)) as u64)
    }

    // ==========================================
    // 4. 防护机制 - Commit-Reveal模式
    // ==========================================

    /// 提交-揭示订单
    struct CommitRevealOrder has key {
        order_hash: vector<u8>,
        commit_time: u64,
        revealed: bool,
    }

    const ERROR_ALREADY_COMMITTED: u64 = 2001;
    const ERROR_NOT_COMMITTED: u64 = 2002;
    const ERROR_ALREADY_REVEALED: u64 = 2003;
    const ERROR_TOO_EARLY: u64 = 2004;
    const ERROR_TOO_LATE: u64 = 2005;
    const ERROR_HASH_MISMATCH: u64 = 2006;

    const MIN_COMMIT_DELAY: u64 = 60;    // 最小1分钟
    const MAX_COMMIT_DELAY: u64 = 3600;  // 最大1小时

    /// 提交订单哈希
    public entry fun commit_order(
        user: &signer,
        order_hash: vector<u8>,
    ) {
        let user_addr = signer::address_of(user);
        assert!(!exists<CommitRevealOrder>(user_addr), ERROR_ALREADY_COMMITTED);
        
        move_to(user, CommitRevealOrder {
            order_hash,
            commit_time: timestamp::now_seconds(),
            revealed: false,
        });
    }

    /// 揭示并执行订单
    public entry fun reveal_and_execute_order<CoinIn, CoinOut>(
        user: &signer,
        amount_in: u64,
        min_amount_out: u64,
        nonce: vector<u8>,
    ) acquires CommitRevealOrder {
        let user_addr = signer::address_of(user);
        assert!(exists<CommitRevealOrder>(user_addr), ERROR_NOT_COMMITTED);
        
        let committed = borrow_global_mut<CommitRevealOrder>(user_addr);
        assert!(!committed.revealed, ERROR_ALREADY_REVEALED);
        
        let now = timestamp::now_seconds();
        
        // 验证时间窗口
        assert!(now >= committed.commit_time + MIN_COMMIT_DELAY, ERROR_TOO_EARLY);
        assert!(now <= committed.commit_time + MAX_COMMIT_DELAY, ERROR_TOO_LATE);
        
        // 验证哈希
        let order_data = encode_order_data(amount_in, min_amount_out, nonce);
        let computed_hash = aptos_std::aptos_hash::keccak256(order_data);
        assert!(computed_hash == committed.order_hash, ERROR_HASH_MISMATCH);
        
        // 标记已揭示
        committed.revealed = true;
        
        // 执行订单
        swap_with_slippage_protection<CoinIn, CoinOut>(
            user,
            amount_in,
            min_amount_out,
            now + 300, // 5分钟deadline
        );
    }

    /// 编码订单数据
    fun encode_order_data(
        amount_in: u64,
        min_amount_out: u64,
        nonce: vector<u8>,
    ): vector<u8> {
        let data = vector::empty<u8>();
        
        // 简化版本：连接所有字段
        vector::append(&mut data, bcs::to_bytes(&amount_in));
        vector::append(&mut data, bcs::to_bytes(&min_amount_out));
        vector::append(&mut data, nonce);
        
        data
    }

    // ==========================================
    // 5. 防护机制 - 批量拍卖
    // ==========================================

    /// 批量拍卖订单
    struct BatchAuction<phantom CoinIn, phantom CoinOut> has key {
        orders: vector<AuctionOrder>,
        batch_start: u64,
        batch_duration: u64,
        clearing_price: u64,
        executed: bool,
    }

    struct AuctionOrder has store, drop {
        user: address,
        amount_in: u64,
        limit_price: u64,  // 用户愿意接受的最差价格
    }

    const ERROR_BATCH_CLOSED: u64 = 3001;
    const ERROR_BATCH_NOT_READY: u64 = 3002;
    const ERROR_BATCH_EXECUTED: u64 = 3003;

    /// 创建新批次
    public fun create_batch_auction<CoinIn, CoinOut>(
        admin: &signer,
        duration: u64,
    ) {
        move_to(admin, BatchAuction<CoinIn, CoinOut> {
            orders: vector::empty(),
            batch_start: timestamp::now_seconds(),
            batch_duration: duration,
            clearing_price: 0,
            executed: false,
        });
    }

    /// 提交订单到批次
    public entry fun submit_to_batch<CoinIn, CoinOut>(
        user: &signer,
        auction_addr: address,
        amount_in: u64,
        limit_price: u64,
    ) acquires BatchAuction {
        let batch = borrow_global_mut<BatchAuction<CoinIn, CoinOut>>(auction_addr);
        let now = timestamp::now_seconds();
        
        // 检查批次是否仍然开放
        assert!(
            now < batch.batch_start + batch.batch_duration,
            ERROR_BATCH_CLOSED
        );
        
        // 添加订单
        vector::push_back(&mut batch.orders, AuctionOrder {
            user: signer::address_of(user),
            amount_in,
            limit_price,
        });
    }

    /// 执行批量拍卖
    public fun execute_batch_auction<CoinIn, CoinOut>(
        auction_addr: address,
    ) acquires BatchAuction {
        let batch = borrow_global_mut<BatchAuction<CoinIn, CoinOut>>(auction_addr);
        let now = timestamp::now_seconds();
        
        // 验证可以执行
        assert!(
            now >= batch.batch_start + batch.batch_duration,
            ERROR_BATCH_NOT_READY
        );
        assert!(!batch.executed, ERROR_BATCH_EXECUTED);
        
        // 计算清算价格
        let clearing_price = calculate_clearing_price(&batch.orders);
        batch.clearing_price = clearing_price;
        
        // 执行所有符合条件的订单
        let i = 0;
        let len = vector::length(&batch.orders);
        while (i < len) {
            let order = vector::borrow(&batch.orders, i);
            
            // 只执行限价满足的订单
            if (order.limit_price >= clearing_price) {
                // 实际应该执行swap
                // execute_order_at_clearing_price(order, clearing_price);
            };
            
            i = i + 1;
        };
        
        batch.executed = true;
    }

    /// 计算清算价格
    fun calculate_clearing_price(orders: &vector<AuctionOrder>): u64 {
        // 简化版本：取所有订单限价的中位数
        let len = vector::length(orders);
        if (len == 0) return 0;
        
        // 实际应该实现复杂的供需匹配算法
        let sum = 0u64;
        let i = 0;
        while (i < len) {
            let order = vector::borrow(orders, i);
            sum = sum + order.limit_price;
            i = i + 1;
        };
        
        sum / len
    }

    // ==========================================
    // 6. 合规MEV策略 - DEX套利
    // ==========================================

    /// 套利机会
    struct ArbitrageOpportunity has drop, copy {
        buy_pool: address,
        sell_pool: address,
        profit_bps: u64,  // 利润基点
        optimal_amount: u64,
    }

    /// 扫描套利机会
    public fun scan_arbitrage_opportunities(
        pools: vector<address>,
    ): vector<ArbitrageOpportunity> {
        let opportunities = vector::empty();
        
        let i = 0;
        while (i < vector::length(&pools)) {
            let j = i + 1;
            while (j < vector::length(&pools)) {
                let pool_a = *vector::borrow(&pools, i);
                let pool_b = *vector::borrow(&pools, j);
                
                // 获取价格
                let price_a = get_pool_price(pool_a);
                let price_b = get_pool_price(pool_b);
                
                // 检查是否有套利空间
                if (price_b > price_a) {
                    let profit_bps = ((price_b - price_a) * 10000) / price_a;
                    
                    // 只有利润超过阈值才考虑
                    if (profit_bps > 30) { // 0.3%
                        vector::push_back(&mut opportunities, ArbitrageOpportunity {
                            buy_pool: pool_a,
                            sell_pool: pool_b,
                            profit_bps,
                            optimal_amount: calculate_optimal_arb_amount(pool_a, pool_b),
                        });
                    };
                };
                
                j = j + 1;
            };
            i = i + 1;
        };
        
        opportunities
    }

    /// 执行套利
    public entry fun execute_arbitrage<CoinA, CoinB>(
        trader: &signer,
        buy_pool: address,
        sell_pool: address,
        amount: u64,
    ) {
        // 1. 在低价池买入
        let coins_a = coin::withdraw<CoinA>(trader, amount);
        let coins_b = swap_on_pool<CoinA, CoinB>(buy_pool, coins_a);
        
        // 2. 在高价池卖出
        let coins_a_out = swap_on_pool<CoinB, CoinA>(sell_pool, coins_b);
        
        // 3. 验证盈利
        let final_amount = coin::value(&coins_a_out);
        assert!(final_amount > amount, 9999); // 必须盈利
        
        // 4. 存入
        coin::deposit(signer::address_of(trader), coins_a_out);
    }

    // 占位函数
    fun get_pool_price(pool: address): u64 { 1000 }
    fun calculate_optimal_arb_amount(pool_a: address, pool_b: address): u64 { 10000 }
    fun swap_on_pool<CoinIn, CoinOut>(pool: address, coins: Coin<CoinIn>): Coin<CoinOut> {
        abort 0
    }

    // ==========================================
    // 7. 合规MEV策略 - 清算机器人
    // ==========================================

    /// 健康因子计算
    public fun calculate_health_factor(
        collateral_value: u64,
        debt_value: u64,
        liquidation_threshold: u64, // 如80% = 8000基点
    ): u64 {
        if (debt_value == 0) return 10000; // 无债务，健康
        
        // health_factor = (collateral * threshold) / debt
        (collateral_value * liquidation_threshold) / (debt_value * 10000)
    }

    /// 扫描不健康仓位
    public fun scan_unhealthy_positions(
        borrowers: vector<address>,
        liquidation_threshold: u64,
    ): vector<address> {
        let unhealthy = vector::empty();
        
        let i = 0;
        while (i < vector::length(&borrowers)) {
            let borrower = *vector::borrow(&borrowers, i);
            
            // 获取借款人状态
            let (collateral, debt) = get_borrower_position(borrower);
            let health = calculate_health_factor(
                collateral,
                debt,
                liquidation_threshold
            );
            
            // 健康因子 < 1.0 = 可清算
            if (health < 10000) {
                vector::push_back(&mut unhealthy, borrower);
            };
            
            i = i + 1;
        };
        
        unhealthy
    }

    /// 计算清算奖励
    public fun calculate_liquidation_bonus(
        debt_amount: u64,
        bonus_bps: u64, // 如5% = 500基点
    ): u64 {
        (debt_amount * bonus_bps) / 10000
    }

    // 占位函数
    fun get_borrower_position(borrower: address): (u64, u64) {
        (100000, 80000) // (抵押品, 债务)
    }

    // ==========================================
    // 8. MEV利润计算与优化
    // ==========================================

    /// MEV机会评估
    struct MEVOpportunity has drop, copy {
        strategy_type: u8,  // 1=套利, 2=清算, 3=其他
        expected_profit: u64,
        gas_cost: u64,
        execution_risk: u8, // 0-100
        net_profit: u64,
    }

    /// 评估MEV机会
    public fun evaluate_mev_opportunity(
        strategy_type: u8,
        expected_revenue: u64,
        gas_cost: u64,
        capital_required: u64,
        execution_risk: u8,
    ): MEVOpportunity {
        let net_profit = if (expected_revenue > gas_cost) {
            expected_revenue - gas_cost
        } else {
            0
        };
        
        MEVOpportunity {
            strategy_type,
            expected_profit: expected_revenue,
            gas_cost,
            execution_risk,
            net_profit,
        }
    }

    /// 比较两个MEV机会
    public fun compare_opportunities(
        opp1: &MEVOpportunity,
        opp2: &MEVOpportunity,
    ): bool {
        // 考虑风险调整后的收益
        let score1 = (opp1.net_profit * (100 - (opp1.execution_risk as u64))) / 100;
        let score2 = (opp2.net_profit * (100 - (opp2.execution_risk as u64))) / 100;
        
        score1 > score2
    }

    // ==========================================
    // 9. 测试辅助函数
    // ==========================================

    #[test_only]
    public fun test_sandwich_detection(): bool {
        let front = TransactionInfo {
            sender: @0x123,
            function_name: b"buy",
            amount: 10000,
            timestamp: 1000,
            gas_price: 200,
        };
        
        let middle = TransactionInfo {
            sender: @0x456,
            function_name: b"buy",
            amount: 50000,
            timestamp: 1001,
            gas_price: 100,
        };
        
        let back = TransactionInfo {
            sender: @0x123,
            function_name: b"sell",
            amount: 10000,
            timestamp: 1002,
            gas_price: 200,
        };
        
        is_sandwich_attack(&front, &middle, &back)
    }
}
