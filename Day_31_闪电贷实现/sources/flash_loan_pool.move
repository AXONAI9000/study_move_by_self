/// # Flash Loan Pool Module
/// 
/// 完整的闪电贷资产池实现

module flash_loan::flash_loan_pool {
    use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_framework::timestamp;

    /// 资产池
    struct Pool<phantom CoinType> has key {
        reserves: Coin<CoinType>,
        fee_rate: u64,
        admin: address,
        total_flash_loans: u64,
        total_fees: u64,
        total_volume: u64,
        paused: bool,
        flash_loan_events: EventHandle<FlashLoanEvent>,
        repay_events: EventHandle<RepayEvent>,
    }

    /// Hot Potato
    struct FlashLoan {
        amount: u64,
        fee: u64,
    }

    struct FlashLoanEvent has drop, store {
        borrower: address,
        amount: u64,
        fee: u64,
        timestamp: u64,
    }

    struct RepayEvent has drop, store {
        borrower: address,
        amount: u64,
        fee: u64,
        timestamp: u64,
    }

    const E_NOT_ADMIN: u64 = 1;
    const E_INSUFFICIENT_LIQUIDITY: u64 = 2;
    const E_INSUFFICIENT_REPAYMENT: u64 = 3;
    const E_POOL_PAUSED: u64 = 4;
    const E_ZERO_AMOUNT: u64 = 5;
    const E_INVALID_FEE_RATE: u64 = 6;
    const E_INVARIANT_VIOLATION: u64 = 7;

    const FEE_DENOMINATOR: u64 = 10000;
    const MAX_FEE_RATE: u64 = 100;

    public entry fun initialize<CoinType>(
        admin: &signer,
        initial_liquidity: u64,
        fee_rate: u64
    ) {
        assert!(fee_rate <= MAX_FEE_RATE, E_INVALID_FEE_RATE);
        
        let admin_addr = signer::address_of(admin);
        
        let pool = Pool<CoinType> {
            reserves: coin::withdraw<CoinType>(admin, initial_liquidity),
            fee_rate,
            admin: admin_addr,
            total_flash_loans: 0,
            total_fees: 0,
            total_volume: 0,
            paused: false,
            flash_loan_events: account::new_event_handle<FlashLoanEvent>(admin),
            repay_events: account::new_event_handle<RepayEvent>(admin),
        };
        
        move_to(admin, pool);
    }

    public fun flash_loan<CoinType>(
        pool_address: address,
        amount: u64
    ): (Coin<CoinType>, FlashLoan) acquires Pool {
        let pool = borrow_global_mut<Pool<CoinType>>(pool_address);
        
        assert!(!pool.paused, E_POOL_PAUSED);
        assert!(amount > 0, E_ZERO_AMOUNT);
        assert!(coin::value(&pool.reserves) >= amount, E_INSUFFICIENT_LIQUIDITY);
        
        let fee = (amount * pool.fee_rate) / FEE_DENOMINATOR;
        let coins = coin::extract(&mut pool.reserves, amount);
        let flash_loan = FlashLoan { amount, fee };
        
        pool.total_flash_loans = pool.total_flash_loans + 1;
        pool.total_volume = pool.total_volume + amount;
        
        event::emit_event(&mut pool.flash_loan_events, FlashLoanEvent {
            borrower: @0x0, // 实际应该是 tx sender
            amount,
            fee,
            timestamp: timestamp::now_seconds(),
        });
        
        (coins, flash_loan)
    }

    public fun repay<CoinType>(
        pool_address: address,
        coins: Coin<CoinType>,
        flash_loan: FlashLoan
    ) acquires Pool {
        let FlashLoan { amount, fee } = flash_loan;
        
        let repay_amount = coin::value(&coins);
        assert!(repay_amount >= amount + fee, E_INSUFFICIENT_REPAYMENT);
        
        let pool = borrow_global_mut<Pool<CoinType>>(pool_address);
        let balance_before = coin::value(&pool.reserves);
        
        coin::merge(&mut pool.reserves, coins);
        
        let balance_after = coin::value(&pool.reserves);
        assert!(balance_after >= balance_before + fee, E_INVARIANT_VIOLATION);
        
        pool.total_fees = pool.total_fees + fee;
        
        event::emit_event(&mut pool.repay_events, RepayEvent {
            borrower: @0x0,
            amount,
            fee,
            timestamp: timestamp::now_seconds(),
        });
    }

    #[test_only]
    public fun destroy_for_test(flash_loan: FlashLoan) {
        let FlashLoan { amount: _, fee: _ } = flash_loan;
    }
}
