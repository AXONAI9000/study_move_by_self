# 去中心化存储系统架构图

## 整体系统架构

```mermaid
graph TB
    subgraph "客户端层"
        CLI[CLI工具]
        API[REST API]
        SDK[SDK库]
    end
    
    subgraph "应用层"
        Upload[文件上传服务]
        Download[文件下载服务]
        Verify[存储验证服务]
        Token[代币管理服务]
    end
    
    subgraph "区块链层"
        Blockchain[区块链核心]
        Consensus[共识引擎]
        Mempool[交易池]
        Validator[验证器]
    end
    
    subgraph "存储层"
        Sharding[数据分片]
        Redundancy[副本管理]
        Proof[存储证明]
        Recovery[数据恢复]
    end
    
    subgraph "网络层"
        P2P[P2P网络]
        Discovery[节点发现]
        Routing[消息路由]
        Security[安全通信]
    end
    
    subgraph "存储节点网络"
        Node1[存储节点1]
        Node2[存储节点2]
        Node3[存储节点3]
        NodeN[存储节点N]
    end
    
    CLI --> API
    SDK --> API
    API --> Upload
    API --> Download
    API --> Verify
    API --> Token
    
    Upload --> Sharding
    Download --> Recovery
    Verify --> Proof
    Token --> Blockchain
    
    Sharding --> Redundancy
    Redundancy --> Proof
    Proof --> Consensus
    Recovery --> Sharding
    
    Blockchain --> Consensus
    Consensus --> Mempool
    Mempool --> Validator
    Validator --> P2P
    
    P2P --> Discovery
    P2P --> Routing
    P2P --> Security
    
    Sharding --> P2P
    Redundancy --> P2P
    Proof --> P2P
    
    P2P --> Node1
    P2P --> Node2
    P2P --> Node3
    P2P --> NodeN
```

## 数据流架构

```mermaid
sequenceDiagram
    participant Client as 客户端
    participant API as API服务
    participant Blockchain as 区块链
    participant Sharding as 分片服务
    participant P2P as P2P网络
    participant Nodes as 存储节点
    
    Client->>API: 上传文件请求
    API->>Sharding: 数据分片处理
    Sharding->>Sharding: 创建数据分片和冗余
    Sharding->>Blockchain: 创建存储交易
    Blockchain->>P2P: 广播交易
    P2P->>Nodes: 分发数据分片
    Nodes->>P2P: 确认存储
    P2P->>Blockchain: 存储确认
    Blockchain->>API: 返回交易哈希
    API->>Client: 上传完成确认
    
    Note over Client,Nodes: 定期存储验证
    loop 每30分钟
        Blockchain->>Nodes: 随机挑战
        Nodes->>Blockchain: 存储证明
        Blockchain->>Blockchain: 验证证明
        Blockchain->>Blockchain: 分发奖励
    end
```

## 代币经济模型

```mermaid
graph LR
    subgraph "代币流入"
        StorageFees[存储费用]
        TransactionFees[交易费用]
        InitialSupply[初始供应]
    end
    
    subgraph "代币分配"
        StorageProviders[存储提供者 70%]
        Validators[验证者 20%]
        DevelopmentFund[开发基金 10%]
    end
    
    subgraph "代币销毁"
        Burn[手续费销毁]
        Penalties[惩罚销毁]
    end
    
    StorageFees --> StorageProviders
    TransactionFees --> Validators
    InitialSupply --> DevelopmentFund
    
    StorageProviders --> Burn
    Validators --> Burn
    StorageProviders --> Penalties
```

## 共识机制流程

```mermaid
stateDiagram-v2
    [*] --> NodeStartup
    NodeStartup --> NetworkJoin: 加入网络
    NetworkJoin --> Staking: 质押代币
    Staking --> ValidatorQueue: 进入验证者队列
    ValidatorQueue --> BlockProposal: 被选中出块
    BlockProposal --> BlockValidation: 提议区块
    BlockValidation --> BlockConfirmed: 验证通过
    BlockValidation --> BlockRejected: 验证失败
    BlockConfirmed --> RewardDistribution: 获得奖励
    BlockRejected --> ValidatorQueue: 重新排队
    RewardDistribution --> ValidatorQueue: 继续验证
    ValidatorQueue --> Slashing: 恶意行为
    Slashing --> NetworkLeave: 被惩罚离开
    NetworkLeave --> [*]
```

## 存储冗余策略

```mermaid
graph TB
    subgraph "原始数据"
        Original[原始文件 100MB]
    end
    
    subgraph "数据分片"
        Shard1[分片1 25MB]
        Shard2[分片2 25MB]
        Shard3[分片3 25MB]
        Shard4[分片4 25MB]
    end
    
    subgraph "纠删码"
        Parity1[校验码1 25MB]
        Parity2[校验码2 25MB]
    end
    
    subgraph "副本分布"
        Node1[节点A: 分片1+2]
        Node2[节点B: 分片3+4]
        Node3[节点C: 校验码1+2]
        Node4[节点D: 分片1+3]
        Node5[节点E: 分片2+4]
        Node6[节点F: 校验码1+2]
    end
    
    Original --> Shard1
    Original --> Shard2
    Original --> Shard3
    Original --> Shard4
    
    Shard1 --> Parity1
    Shard2 --> Parity1
    Shard3 --> Parity2
    Shard4 --> Parity2
    
    Shard1 --> Node1
    Shard2 --> Node1
    Shard3 --> Node2
    Shard4 --> Node2
    Parity1 --> Node3
    Parity2 --> Node3
    
    Shard1 --> Node4
    Shard3 --> Node4
    Shard2 --> Node5
    Shard4 --> Node5
    Parity1 --> Node6
    Parity2 --> Node6
```

## 技术栈架构

```mermaid
graph TB
    subgraph "前端技术"
        CSharp[C# .NET 8]
        ASPNET[ASP.NET Core]
        GRPC[gRPC]
    end
    
    subgraph "网络通信"
        LibP2P[LibP2P.NET]
        WebSocket[WebSocket]
        HTTP[HTTP/HTTPS]
    end
    
    subgraph "数据存储"
        LevelDB[LevelDB.NET]
        SQLite[SQLite]
        MemoryCache[内存缓存]
    end
    
    subgraph "加密算法"
        AES[AES-256]
        RSA[RSA-4096]
        SHA[SHA-256]
        ECDSA[ECDSA]
    end
    
    subgraph "序列化"
        MessagePack[MessagePack]
        Protobuf[Protocol Buffers]
        JSON[JSON.NET]
    end
    
    CSharp --> ASPNET
    CSharp --> GRPC
    ASPNET --> HTTP
    GRPC --> LibP2P
    LibP2P --> WebSocket
    
    CSharp --> LevelDB
    CSharp --> SQLite
    CSharp --> MemoryCache
    
    CSharp --> AES
    CSharp --> RSA
    CSharp --> SHA
    CSharp --> ECDSA
    
    CSharp --> MessagePack
    CSharp --> Protobuf
    CSharp --> JSON