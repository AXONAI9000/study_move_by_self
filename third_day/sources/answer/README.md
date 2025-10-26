# Move投票系统实现

这是一个基于Move语言的模块化投票系统实现，展示了第三天学习的函数和模块系统的应用。

## 系统架构

### 模块设计

1. **simple_voting.move** - 核心投票系统模块
   - 包含投票创建、管理和操作的所有功能
   - 定义了必要的数据结构和枚举
   - 实现了完整的投票生命周期

2. **usage_example.move** - 使用示例模块
   - 展示如何使用投票系统的各项功能
   - 包含完整的投票流程示例
   - 提供验证和状态检查的示例

### 核心组件

#### 数据结构

1. **VotingInfo** - 投票信息结构
   ```move
   public struct VotingInfo has key {
       title: string::String,           // 投票标题
       description: string::String,     // 投票描述
       candidates: vector<Candidate>,    // 候选人列表
       start_time: u64,              // 开始时间
       end_time: u64,                // 结束时间
       status: VotingStatus,           // 投票状态
       creator: address,               // 创建者地址
       voters: vector<address>,        // 投票者列表
   }
   ```

2. **Candidate** - 候选人结构
   ```move
   public struct Candidate has store, drop {
       id: u64,                     // 候选人ID
       name: string::String,           // 候选人名称
       vote_count: u64,              // 得票数
   }
   ```

3. **VotingStatus** - 投票状态枚举
   ```move
   public enum VotingStatus has store, drop, copy {
       NotStarted,    // 未开始
       Active,        // 进行中
       Ended,         // 已结束
   }
   ```

4. **AdminCapability** - 管理员权限结构
   ```move
   public struct AdminCapability has key {
       owner: address,    // 管理员地址
   }
   ```

#### 核心功能

1. **投票管理**
   - `create_voting()` - 创建新投票
   - `add_candidate()` - 添加候选人
   - `start_voting()` - 开始投票
   - `end_voting()` - 结束投票

2. **投票操作**
   - `cast_vote()` - 投票
   - `get_voting_results()` - 获取投票结果
   - `get_candidate_votes()` - 获取候选人得票数

3. **信息查询**
   - `get_voting_details()` - 获取投票详情
   - `get_candidates()` - 获取候选人列表
   - `get_voting_status()` - 获取投票状态
   - `get_participant_count()` - 获取参与人数

4. **验证功能**
   - `validate_voting_info()` - 验证投票信息
   - `is_voting_active()` - 检查投票是否在有效期内
   - `is_voting_started()` - 检查投票是否已开始
   - `is_voting_ended()` - 检查投票是否已结束

## 设计特点

### 1. 模块化设计
- 单一职责原则：每个模块有明确的功能职责
- 清晰的接口：公共函数提供明确的API
- 封装内部实现：私有函数隐藏实现细节

### 2. 安全性考虑
- 权限控制：使用AdminCapability确保只有管理员能执行管理操作
- 状态验证：确保操作在正确的状态下执行
- 重复投票防护：记录投票者地址防止重复投票

### 3. 错误处理
- 定义明确的错误码
- 使用assert进行条件检查
- 提供有意义的错误信息

### 4. 函数设计
- 合理的参数设计
- 清晰的返回值
- 适当的引用和值传递

## 使用示例

### 创建投票流程

```move
// 1. 创建投票
create_voting(
    admin,
    title,
    description,
    start_time,
    end_time
);

// 2. 添加候选人
add_candidate(admin, candidate_name);

// 3. 开始投票
start_voting(admin);

// 4. 投票
cast_vote(voter, admin_addr, candidate_id);

// 5. 结束投票
end_voting(admin);

// 6. 查看结果
let results = get_voting_results(admin_addr);
```

### 验证示例

```move
// 验证投票信息
let is_valid = validate_voting_info(&title, &description);

// 检查投票状态
let is_active = is_voting_active(start_time, end_time);
let is_started = is_voting_started(start_time);
let is_ended = is_voting_ended(end_time);
```

## 学习要点

这个投票系统实现展示了第三天学习的以下关键概念：

1. **模块系统**
   - 模块的声明和组织
   - 公共和私有函数的使用
   - 模块间的导入和依赖

2. **函数设计**
   - 函数参数和返回值
   - 引用和值传递
   - 函数可见性控制

3. **数据结构**
   - 结构体的定义和使用
   - 枚举类型的定义
   - 能力的使用（key, store, drop, copy）

4. **错误处理**
   - 错误码的定义和使用
   - 条件检查和断言
   - 异常情况的处理

5. **最佳实践**
   - 代码组织和模块化
   - 命名规范
   - 安全编程实践

这个实现为第三天的学习提供了一个完整的实践案例，展示了如何将理论知识应用到实际项目中。