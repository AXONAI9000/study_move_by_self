# 去中心化存储系统实施指南

## 项目结构设计

```
DecentralizedStorage/
├── src/
│   ├── Core/                          # 核心区块链组件
│   │   ├── Blockchain/                # 区块链核心
│   │   │   ├── Block.cs              # 区块结构
│   │   │   ├── Transaction.cs        # 交易结构
│   │   │   ├── Blockchain.cs         # 区块链管理
│   │   │   └── UTXO.cs               # UTXO管理
│   │   ├── Consensus/                 # 共识机制
│   │   │   ├── IConsensus.cs         # 共识接口
│   │   │   ├── PoSConsensus.cs       # 权益证明
│   │   │   └── Validator.cs          # 验证器
│   │   ├── Crypto/                    # 加密组件
│   │   │   ├── HashHelper.cs         # 哈希工具
│   │   │   ├── SignatureHelper.cs    # 签名工具
│   │   │   └── EncryptionHelper.cs   # 加密工具
│   │   └── Wallet/                    # 钱包组件
│   │       ├── Wallet.cs             # 钱包实现
│   │       └── Account.cs            # 账户管理
│   ├── Network/                       # 网络层
│   │   ├── P2P/                       # P2P通信
│   │   │   ├── P2PNode.cs            # P2P节点
│   │   │   ├── MessageHandler.cs     # 消息处理
│   │   │   └── NodeDiscovery.cs      # 节点发现
│   │   ├── RPC/                       # RPC服务
│   │   │   ├── GrpcService.cs        # gRPC服务
│   │   │   └── ApiService.cs         # REST API
│   │   └── Protocol/                  # 网络协议
│   │       ├── NetworkMessage.cs     # 网络消息
│   │       └── ProtocolConstants.cs  # 协议常量
│   ├── Storage/                       # 存储层
│   │   ├── Sharding/                  # 数据分片
│   │   │   ├── DataShard.cs          # 数据分片
│   │   │   ├── ReedSolomon.cs        # 纠删码
│   │   │   └── ShardManager.cs       # 分片管理
│   │   ├── Redundancy/                # 冗余管理
│   │   │   ├── ReplicationManager.cs # 副本管理
│   │   │   └── NodeSelector.cs       # 节点选择
│   │   ├── Proof/                     # 存储证明
│   │   │   ├── StorageProof.cs       # 存储证明
│   │   │   ├── ChallengeManager.cs   # 挑战管理
│   │   │   └── ProofVerifier.cs      # 证明验证
│   │   └── Database/                  # 本地存储
│   │       ├── LevelDBStore.cs       # LevelDB封装
│   │       └── MetadataStore.cs      # 元数据存储
│   ├── Token/                         # 代币经济
│   │   ├── Token.cs                   # 代币定义
│   │   ├── Economy.cs                 # 经济模型
│   │   ├── Rewards.cs                 # 奖励计算
│   │   └── Penalties.cs               # 惩罚机制
│   ├── Node/                          # 节点管理
│   │   ├── StorageNode.cs             # 存储节点
│   │   ├── ValidatorNode.cs           # 验证节点
│   │   └── NodeManager.cs             # 节点管理器
│   ├── Utils/                         # 工具类
│   │   ├── Logger.cs                  # 日志工具
│   │   ├── Config.cs                  # 配置管理
│   │   └── Helpers.cs                 # 通用助手
│   └── CLI/                           # 命令行工具
│       ├── Program.cs                 # 主程序入口
│       ├── Commands/                  # 命令实现
│       └── Services/                  # CLI服务
├── tests/                             # 测试项目
│   ├── UnitTests/                     # 单元测试
│   ├── IntegrationTests/              # 集成测试
│   └── TestNetwork/                   # 测试网络
├── docs/                              # 文档
├── scripts/                           # 部署脚本
├── docker/                            # Docker配置
└── README.md                          # 项目说明
```

## 第一阶段：区块链基础框架 (2-3周)

### 1.1 核心数据结构

#### Block.cs - 区块结构
```csharp
public class Block
{
    public int Index { get; set; }
    public string Hash { get; set; }
    public string PreviousHash { get; set; }
    public long Timestamp { get; set; }
    public List<Transaction> Transactions { get; set; }
    public string Validator { get; set; }
    public string Signature { get; set; }
    public long Nonce { get; set; }
    
    public string CalculateHash()
    {
        var blockData = $"{Index}{PreviousHash}{Timestamp}{string.Join("", Transactions.Select(t => t.Hash))}{Validator}{Nonce}";
        return HashHelper.ComputeSHA256(blockData);
    }
}
```

#### Transaction.cs - 交易结构
```csharp
public enum TransactionType
{
    Storage,    // 存储交易
    Challenge,  // 挑战交易
    Reward,     // 奖励交易
    Transfer    // 转账交易
}

public class Transaction
{
    public string Id { get; set; }
    public TransactionType Type { get; set; }
    public string From { get; set; }
    public string To { get; set; }
    public long Amount { get; set; }
    public long Fee { get; set; }
    public long Timestamp { get; set; }
    public string Data { get; set; }  // 存储相关数据
    public string Signature { get; set; }
    
    public string CalculateHash()
    {
        var txData = $"{Type}{From}{To}{Amount}{Fee}{Timestamp}{Data}";
        return HashHelper.ComputeSHA256(txData);
    }
}
```

### 1.2 区块链核心逻辑

#### Blockchain.cs - 区块链管理
```csharp
public class Blockchain
{
    private List<Block> _chain;
    private Dictionary<string, UTXO> _utxos;
    private readonly IConsensus _consensus;
    
    public Blockchain(IConsensus consensus)
    {
        _chain = new List<Block>();
        _utxos = new Dictionary<string, UTXO>();
        _consensus = consensus;
        CreateGenesisBlock();
    }
    
    public Block GetLatestBlock() => _chain.LastOrDefault();
    public bool AddBlock(Block block) => _consensus.ValidateBlock(block, GetLatestBlock());
    public bool AddTransaction(Transaction tx) => ValidateTransaction(tx);
    
    private void CreateGenesisBlock()
    {
        var genesisBlock = new Block
        {
            Index = 0,
            PreviousHash = "0",
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            Transactions = new List<Transaction>(),
            Validator = "genesis"
        };
        genesisBlock.Hash = genesisBlock.CalculateHash();
        _chain.Add(genesisBlock);
    }
}
```

## 第二阶段：P2P网络层 (2-3周)

### 2.1 P2P节点实现

#### P2PNode.cs - P2P节点核心
```csharp
public class P2PNode
{
    private readonly string _nodeId;
    private readonly IPEndPoint _listenAddress;
    private readonly Dictionary<string, PeerConnection> _peers;
    private readonly MessageHandler _messageHandler;
    
    public P2PNode(IPEndPoint listenAddress)
    {
        _nodeId = Guid.NewGuid().ToString();
        _listenAddress = listenAddress;
        _peers = new Dictionary<string, PeerConnection>();
        _messageHandler = new MessageHandler();
    }
    
    public async Task StartAsync()
    {
        var listener = new TcpListener(_listenAddress);
        listener.Start();
        
        while (true)
        {
            var client = await listener.AcceptTcpClientAsync();
            _ = HandleConnectionAsync(client);
        }
    }
    
    public async Task BroadcastAsync(NetworkMessage message)
    {
        var tasks = _peers.Values.Select(peer => peer.SendMessageAsync(message));
        await Task.WhenAll(tasks);
    }
}
```

### 2.2 节点发现机制

#### NodeDiscovery.cs - 节点发现
```csharp
public class NodeDiscovery
{
    private readonly Dictionary<string, NodeInfo> _knownNodes;
    private readonly P2PNode _localNode;
    
    public async Task DiscoverNodesAsync()
    {
        // 使用DHT进行节点发现
        // 或者使用硬编码的引导节点
        var bootstrapNodes = GetBootstrapNodes();
        
        foreach (var node in bootstrapNodes)
        {
            await ConnectToNodeAsync(node);
        }
    }
    
    private async Task ConnectToNodeAsync(NodeInfo nodeInfo)
    {
        try
        {
            var connection = await _localNode.ConnectAsync(nodeInfo.Address);
            _knownNodes[nodeInfo.Id] = nodeInfo;
            
            // 请求节点的对等节点列表
            var peerList = await RequestPeerListAsync(connection);
            foreach (var peer in peerList)
            {
                _knownNodes.TryAdd(peer.Id, peer);
            }
        }
        catch (Exception ex)
        {
            // 处理连接失败
        }
    }
}
```

## 第三阶段：存储协议 (3-4周)

### 3.1 数据分片实现

#### DataShard.cs - 数据分片
```csharp
public class DataShard
{
    public string Id { get; set; }
    public int Index { get; set; }
    public byte[] Data { get; set; }
    public string Hash { get; set; }
    public int Size { get; set; }
    
    public static List<DataShard> CreateShards(byte[] data, int shardSize = 1024 * 1024) // 1MB
    {
        var shards = new List<DataShard>();
        var totalShards = (int)Math.Ceiling((double)data.Length / shardSize);
        
        for (int i = 0; i < totalShards; i++)
        {
            var startIndex = i * shardSize;
            var length = Math.Min(shardSize, data.Length - startIndex);
            var shardData = new byte[length];
            Array.Copy(data, startIndex, shardData, 0, length);
            
            shards.Add(new DataShard
            {
                Id = Guid.NewGuid().ToString(),
                Index = i,
                Data = shardData,
                Hash = HashHelper.ComputeSHA256(shardData),
                Size = length
            });
        }
        
        return shards;
    }
}
```

#### ReedSolomon.cs - 纠删码实现
```csharp
public class ReedSolomon
{
    private readonly int _dataShards;
    private readonly int _parityShards;
    
    public ReedSolomon(int dataShards, int parityShards)
    {
        _dataShards = dataShards;
        _parityShards = parityShards;
    }
    
    public List<byte[]> Encode(List<byte[]> dataShards)
    {
        // 使用Reed-Solomon算法生成校验码
        // 这里简化实现，实际可以使用现成的库
        var parityShards = new List<byte[]>();
        
        // 简化的XOR校验码生成
        for (int i = 0; i < _parityShards; i++)
        {
            var parity = new byte[dataShards[0].Length];
            for (int j = 0; j < dataShards.Count; j++)
            {
                for (int k = 0; k < parity.Length; k++)
                {
                    parity[k] ^= dataShards[j][k];
                }
            }
            parityShards.Add(parity);
        }
        
        return parityShards;
    }
    
    public byte[] Decode(List<byte[]> shards)
    {
        // 数据恢复逻辑
        // 当某些分片丢失时，使用校验码恢复
        var validShards = shards.Where(s => s != null).ToList();
        if (validShards.Count >= _dataShards)
        {
            return ReconstructData(validShards);
        }
        throw new InvalidOperationException("无法恢复数据：有效分片不足");
    }
}
```

### 3.2 存储证明机制

#### StorageProof.cs - 存储证明
```csharp
public class StorageProof
{
    public string ChallengeId { get; set; }
    public string NodeId { get; set; }
    public string ShardId { get; set; }
    public int ChallengeIndex { get; set; }
    public string Proof { get; set; }
    public long Timestamp { get; set; }
    public string Signature { get; set; }
    
    public static StorageProof GenerateChallenge(string nodeId, string shardId)
    {
        var random = new Random();
        var challengeIndex = random.Next(0, 1000); // 随机选择挑战位置
        
        return new StorageProof
        {
            ChallengeId = Guid.NewGuid().ToString(),
            NodeId = nodeId,
            ShardId = shardId,
            ChallengeIndex = challengeIndex,
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
        };
    }
    
    public string GenerateProof(byte[] shardData)
    {
        // 在指定位置生成证明
        var proofData = shardData.Skip(ChallengeIndex).Take(32).ToArray();
        return HashHelper.ComputeSHA256(proofData);
    }
}
```

## 第四阶段：代币经济模型 (2-3周)

### 4.1 代币定义

#### Token.cs - 代币实现
```csharp
public class Token
{
    public string Symbol { get; } = "DST";
    public string Name { get; } = "Decentralized Storage Token";
    public decimal TotalSupply { get; private set; }
    public decimal CirculatingSupply { get; private set; }
    
    private readonly Dictionary<string, decimal> _balances;
    
    public Token(decimal initialSupply)
    {
        TotalSupply = initialSupply;
        CirculatingSupply = 0;
        _balances = new Dictionary<string, decimal>();
    }
    
    public bool Transfer(string from, string to, decimal amount)
    {
        if (_balances.GetValueOrDefault(from, 0) < amount)
            return false;
            
        _balances[from] -= amount;
        _balances[to] = _balances.GetValueOrDefault(to, 0) + amount;
        return true;
    }
    
    public void Mint(string to, decimal amount)
    {
        if (CirculatingSupply + amount > TotalSupply)
            throw new InvalidOperationException("超过总供应量");
            
        _balances[to] = _balances.GetValueOrDefault(to, 0) + amount;
        CirculatingSupply += amount;
    }
    
    public void Burn(string from, decimal amount)
    {
        if (_balances.GetValueOrDefault(from, 0) < amount)
            throw new InvalidOperationException("余额不足");
            
        _balances[from] -= amount;
        CirculatingSupply -= amount;
    }
}
```

### 4.2 奖励计算

#### Rewards.cs - 奖励系统
```csharp
public class RewardCalculator
{
    private readonly decimal _baseReward = 10.0m; // 基础奖励
    private readonly decimal _storageRewardRate = 0.001m; // 每MB每小时的奖励
    
    public decimal CalculateStorageReward(StorageNode node, long hours)
    {
        var storageGB = node.UsedStorage / (1024.0 * 1024.0 * 1024.0);
        var uptimeBonus = node.UptimePercentage / 100.0m;
        var qualityBonus = node.QualityScore / 100.0m;
        
        return _baseReward * storageGB * hours * _storageRewardRate * uptimeBonus * qualityBonus;
    }
    
    public decimal CalculateValidationReward(ValidatorNode validator, int blocksValidated)
    {
        return blocksValidated * _baseReward * 0.5m; // 验证奖励是基础奖励的一半
    }
    
    public decimal CalculatePenalty(StorageNode node, PenaltyReason reason)
    {
        return reason switch
        {
            PenaltyReason.Downtime => _baseReward * 0.1m,
            PenaltyReason.DataLoss => _baseReward * 1.0m,
            PenaltyReason.MaliciousBehavior => _baseReward * 5.0m,
            _ => 0
        };
    }
}
```

## 开发环境配置

### 必需的NuGet包
```xml
<PackageReference Include="Microsoft.Extensions.Logging" Version="8.0.0" />
<PackageReference Include="Microsoft.Extensions.Configuration" Version="8.0.0" />
<PackageReference Include="Grpc.AspNetCore" Version="2.57.0" />
<PackageReference Include="LevelDB.NET" Version="1.0.0" />
<PackageReference Include="BouncyCastle" Version="1.8.9" />
<PackageReference Include="MessagePack" Version="2.5.168" />
<PackageReference Include="System.Net.Sockets" Version="4.3.0" />
<PackageReference Include="xunit" Version="2.4.2" />
<PackageReference Include="Moq" Version="4.20.69" />
```

### Docker配置
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/DecentralizedStorage.csproj", "src/"]
RUN dotnet restore "src/DecentralizedStorage.csproj"
COPY . .
WORKDIR "/src/src"
RUN dotnet build "DecentralizedStorage.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "DecentralizedStorage.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "DecentralizedStorage.dll"]
```

## 测试策略

### 单元测试示例
```csharp
[Test]
public void Block_CalculateHash_ReturnsCorrectHash()
{
    var block = new Block
    {
        Index = 1,
        PreviousHash = "0",
        Timestamp = 1234567890,
        Transactions = new List<Transaction>(),
        Validator = "test"
    };
    
    var expectedHash = HashHelper.ComputeSHA256("10" + "0" + "1234567890" + "test" + "0");
    block.Hash = block.CalculateHash();
    
    Assert.AreEqual(expectedHash, block.Hash);
}
```

### 集成测试示例
```csharp
[Test]
public async Task P2PNetwork_BroadcastMessage_ReceivesByAllNodes()
{
    var network = new TestNetwork(3);
    await network.StartAsync();
    
    var message = new NetworkMessage { Type = MessageType.Test, Data = "Hello" };
    await network.Nodes[0].BroadcastAsync(message);
    
    await Task.Delay(1000); // 等待消息传播
    
    foreach (var node in network.Nodes.Skip(1))
    {
        Assert.IsTrue(node.ReceivedMessages.Contains(message));
    }
}
```

## 部署和运维

### 启动脚本
```bash
#!/bin/bash
# 启动节点脚本

NODE_ID=$1
PORT=$2
BOOTSTRAP_NODE=$3

dotnet run --project src/DecentralizedStorage.csproj -- \
  --node-id $NODE_ID \
  --port $PORT \
  --bootstrap-node $BOOTSTRAP_NODE \
  --data-dir ./data/$NODE_ID
```

### 监控配置
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'decentralized-storage'
    static_configs:
      - targets: ['localhost:5000', 'localhost:5001', 'localhost:5002']
```

这个实施指南提供了详细的代码结构和实现步骤，单人开发者可以按照这个计划逐步实现去中心化存储系统。