// Day 28 代码示例：Indexer 与 GraphQL 查询
// 本文件展示如何在 Move 合约中定义事件，以及如何通过 Indexer 查询这些数据

module indexer_demo::events_for_indexer {
    use std::string::{Self, String};
    use std::signer;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    // ==================== 错误码 ====================
    const ERROR_NOT_INITIALIZED: u64 = 1;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 2;
    const ERROR_INVALID_AMOUNT: u64 = 3;

    // ==================== 事件定义 ====================
    
    /// 用户注册事件
    /// 这个事件会被 Indexer 捕获，可以用来追踪新用户
    struct UserRegisteredEvent has drop, store {
        user_address: address,
        username: String,
        timestamp: u64,
    }

    /// 存款事件
    /// 用于追踪用户的存款历史
    struct DepositEvent has drop, store {
        user_address: address,
        amount: u64,
        new_balance: u64,
        timestamp: u64,
    }

    /// 提款事件
    struct WithdrawEvent has drop, store {
        user_address: address,
        amount: u64,
        new_balance: u64,
        timestamp: u64,
    }

    /// 转账事件
    /// 包含发送者和接收者信息
    struct TransferEvent has drop, store {
        from: address,
        to: address,
        amount: u64,
        timestamp: u64,
        memo: String,
    }

    // ==================== 数据结构 ====================

    /// 用户账户信息
    /// 存储在用户地址下
    struct UserAccount has key {
        username: String,
        balance: u64,
        created_at: u64,
        
        // 事件句柄
        deposit_events: EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
        transfer_events: EventHandle<TransferEvent>,
    }

    /// 全局注册表
    /// 存储在合约地址下
    struct GlobalRegistry has key {
        total_users: u64,
        total_deposits: u64,
        total_withdrawals: u64,
        
        // 全局事件句柄
        user_registered_events: EventHandle<UserRegisteredEvent>,
    }

    // ==================== 初始化函数 ====================

    /// 初始化全局注册表
    /// 只能由合约部署者调用一次
    public entry fun initialize(account: &signer) {
        let account_addr = signer::address_of(account);
        
        if (!exists<GlobalRegistry>(account_addr)) {
            move_to(account, GlobalRegistry {
                total_users: 0,
                total_deposits: 0,
                total_withdrawals: 0,
                user_registered_events: account::new_event_handle<UserRegisteredEvent>(account),
            });
        };
    }

    // ==================== 用户操作函数 ====================

    /// 注册用户
    /// 创建用户账户并发出注册事件
    public entry fun register_user(
        account: &signer,
        username: String
    ) acquires GlobalRegistry {
        let user_addr = signer::address_of(account);
        
        // 确保用户未注册
        assert!(!exists<UserAccount>(user_addr), ERROR_NOT_INITIALIZED);
        
        let timestamp = aptos_framework::timestamp::now_seconds();
        
        // 创建用户账户
        move_to(account, UserAccount {
            username,
            balance: 0,
            created_at: timestamp,
            deposit_events: account::new_event_handle<DepositEvent>(account),
            withdraw_events: account::new_event_handle<WithdrawEvent>(account),
            transfer_events: account::new_event_handle<TransferEvent>(account),
        });
        
        // 发出注册事件
        let registry = borrow_global_mut<GlobalRegistry>(@indexer_demo);
        registry.total_users = registry.total_users + 1;
        
        event::emit_event(
            &mut registry.user_registered_events,
            UserRegisteredEvent {
                user_address: user_addr,
                username,
                timestamp,
            }
        );
    }

    /// 存款
    /// 从 AptosCoin 余额转入合约，并更新用户余额
    public entry fun deposit(
        account: &signer,
        amount: u64
    ) acquires UserAccount, GlobalRegistry {
        let user_addr = signer::address_of(account);
        
        // 确保用户已注册
        assert!(exists<UserAccount>(user_addr), ERROR_NOT_INITIALIZED);
        assert!(amount > 0, ERROR_INVALID_AMOUNT);
        
        // 转移 Coin 到合约（这里简化处理）
        // 实际应用中需要实现真实的资金管理
        
        let user_account = borrow_global_mut<UserAccount>(user_addr);
        user_account.balance = user_account.balance + amount;
        
        let timestamp = aptos_framework::timestamp::now_seconds();
        
        // 发出存款事件
        event::emit_event(
            &mut user_account.deposit_events,
            DepositEvent {
                user_address: user_addr,
                amount,
                new_balance: user_account.balance,
                timestamp,
            }
        );
        
        // 更新全局统计
        let registry = borrow_global_mut<GlobalRegistry>(@indexer_demo);
        registry.total_deposits = registry.total_deposits + amount;
    }

    /// 提款
    public entry fun withdraw(
        account: &signer,
        amount: u64
    ) acquires UserAccount, GlobalRegistry {
        let user_addr = signer::address_of(account);
        
        assert!(exists<UserAccount>(user_addr), ERROR_NOT_INITIALIZED);
        assert!(amount > 0, ERROR_INVALID_AMOUNT);
        
        let user_account = borrow_global_mut<UserAccount>(user_addr);
        assert!(user_account.balance >= amount, ERROR_INSUFFICIENT_BALANCE);
        
        user_account.balance = user_account.balance - amount;
        
        let timestamp = aptos_framework::timestamp::now_seconds();
        
        // 发出提款事件
        event::emit_event(
            &mut user_account.withdraw_events,
            WithdrawEvent {
                user_address: user_addr,
                amount,
                new_balance: user_account.balance,
                timestamp,
            }
        );
        
        // 更新全局统计
        let registry = borrow_global_mut<GlobalRegistry>(@indexer_demo);
        registry.total_withdrawals = registry.total_withdrawals + amount;
    }

    /// 转账
    public entry fun transfer(
        from: &signer,
        to: address,
        amount: u64,
        memo: String
    ) acquires UserAccount {
        let from_addr = signer::address_of(from);
        
        assert!(exists<UserAccount>(from_addr), ERROR_NOT_INITIALIZED);
        assert!(exists<UserAccount>(to), ERROR_NOT_INITIALIZED);
        assert!(amount > 0, ERROR_INVALID_AMOUNT);
        
        // 从发送者扣除
        let from_account = borrow_global_mut<UserAccount>(from_addr);
        assert!(from_account.balance >= amount, ERROR_INSUFFICIENT_BALANCE);
        from_account.balance = from_account.balance - amount;
        
        // 给接收者增加
        let to_account = borrow_global_mut<UserAccount>(to);
        to_account.balance = to_account.balance + amount;
        
        let timestamp = aptos_framework::timestamp::now_seconds();
        
        // 发出转账事件（从发送者账户发出）
        event::emit_event(
            &mut from_account.transfer_events,
            TransferEvent {
                from: from_addr,
                to,
                amount,
                timestamp,
                memo,
            }
        );
    }

    // ==================== 查询函数 ====================
    
    /// 查询用户余额
    /// 虽然可以直接通过 Indexer 查询，但提供链上查询函数仍有价值
    #[view]
    public fun get_balance(user_addr: address): u64 acquires UserAccount {
        assert!(exists<UserAccount>(user_addr), ERROR_NOT_INITIALIZED);
        borrow_global<UserAccount>(user_addr).balance
    }

    /// 查询用户信息
    #[view]
    public fun get_user_info(user_addr: address): (String, u64, u64) acquires UserAccount {
        assert!(exists<UserAccount>(user_addr), ERROR_NOT_INITIALIZED);
        let account = borrow_global<UserAccount>(user_addr);
        (account.username, account.balance, account.created_at)
    }

    /// 查询全局统计
    #[view]
    public fun get_global_stats(): (u64, u64, u64) acquires GlobalRegistry {
        let registry = borrow_global<GlobalRegistry>(@indexer_demo);
        (registry.total_users, registry.total_deposits, registry.total_withdrawals)
    }

    // ==================== 测试函数 ====================
    
    #[test_only]
    public fun init_for_test(account: &signer) {
        initialize(account);
    }
}

/*
==================== GraphQL 查询示例 ====================

上述 Move 合约部署后，可以通过以下 GraphQL 查询来获取数据：

1. 查询所有用户注册事件：

query GetUserRegistrations {
  events(
    where: {
      type: {_eq: "0x[合约地址]::events_for_indexer::UserRegisteredEvent"}
    }
    order_by: {transaction_version: desc}
    limit: 20
  ) {
    transaction_version
    sequence_number
    data
    transaction {
      timestamp
      sender
      success
    }
  }
}

2. 查询特定用户的存款事件：

query GetUserDeposits($userAddress: String!) {
  events(
    where: {
      type: {_eq: "0x[合约地址]::events_for_indexer::DepositEvent"}
      account_address: {_eq: $userAddress}
    }
    order_by: {sequence_number: desc}
  ) {
    data
    sequence_number
    transaction {
      timestamp
    }
  }
}

3. 查询所有转账事件：

query GetAllTransfers {
  events(
    where: {
      type: {_eq: "0x[合约地址]::events_for_indexer::TransferEvent"}
    }
    order_by: {transaction_version: desc}
    limit: 50
  ) {
    data
    transaction_version
    transaction {
      sender
      timestamp
      success
    }
  }
}

4. 订阅新的注册事件（实时）：

subscription NewUserRegistrations {
  events(
    where: {
      type: {_eq: "0x[合约地址]::events_for_indexer::UserRegisteredEvent"}
    }
    order_by: {transaction_version: desc}
    limit: 1
  ) {
    data
    transaction_version
    transaction {
      timestamp
      sender
    }
  }
}

5. 聚合查询 - 统计总存款金额：

query TotalDeposits {
  events_aggregate(
    where: {
      type: {_eq: "0x[合约地址]::events_for_indexer::DepositEvent"}
    }
  ) {
    aggregate {
      count
    }
  }
}

6. 查询账户的资源状态（不是事件）：

query GetAccountResource($address: String!) {
  account_transactions(
    where: {
      account_address: {_eq: $address}
    }
    limit: 1
  ) {
    account_address
  }
  
  # 注意：直接查询资源状态需要使用 REST API
  # GraphQL Indexer 主要用于查询历史数据和事件
}

==================== TypeScript 客户端示例 ====================

import { ApolloClient, InMemoryCache, gql } from '@apollo/client';

// 创建客户端
const client = new ApolloClient({
  uri: 'https://indexer.mainnet.aptoslabs.com/v1/graphql',
  cache: new InMemoryCache()
});

// 查询示例
async function getUserDeposits(userAddress: string) {
  const { data } = await client.query({
    query: gql`
      query GetUserDeposits($userAddress: String!) {
        events(
          where: {
            type: {_eq: "0x[合约地址]::events_for_indexer::DepositEvent"}
            account_address: {_eq: $userAddress}
          }
          order_by: {sequence_number: desc}
        ) {
          data
          sequence_number
          transaction {
            timestamp
          }
        }
      }
    `,
    variables: { userAddress }
  });
  
  return data.events.map((event: any) => ({
    amount: event.data.amount,
    newBalance: event.data.new_balance,
    timestamp: event.transaction.timestamp,
    sequenceNumber: event.sequence_number
  }));
}

// 订阅示例
function subscribeToNewRegistrations(callback: (event: any) => void) {
  const subscription = client.subscribe({
    query: gql`
      subscription NewUserRegistrations {
        events(
          where: {
            type: {_eq: "0x[合约地址]::events_for_indexer::UserRegisteredEvent"}
          }
          order_by: {transaction_version: desc}
          limit: 1
        ) {
          data
          transaction_version
          transaction {
            timestamp
            sender
          }
        }
      }
    `
  }).subscribe({
    next: (result) => {
      callback(result.data.events[0]);
    },
    error: (error) => {
      console.error('Subscription error:', error);
    }
  });
  
  return subscription;
}

==================== 最佳实践 ====================

1. 事件设计：
   - 包含所有必要的上下文信息
   - 添加时间戳字段
   - 使用有意义的事件名称
   - 考虑事件的可查询性

2. 数据建模：
   - 设计时考虑查询模式
   - 避免过度嵌套
   - 使用合适的数据类型

3. 查询优化：
   - 使用索引字段（如 transaction_version, account_address）
   - 总是添加 limit
   - 避免查询过多字段
   - 使用游标分页

4. 错误处理：
   - 处理网络错误
   - 处理查询超时
   - 验证返回的数据
   - 实现重试机制

5. 缓存策略：
   - 缓存不常变化的数据
   - 设置合理的 TTL
   - 使用 Apollo Client 的缓存机制

*/
