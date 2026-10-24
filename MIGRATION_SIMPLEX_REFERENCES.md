# 迁移文件中的 SimpleX 引用检查和替换方案

**日期:** 2026-10-20  
**检查范围:** 所有 SQLite 迁移文件  
**上游版本:** SimpleXMQ v7.1.0.14  
**本地版本:** PopopxMQ v7.1.0.14

## 执行摘要

✅ **检查结果：迁移文件中仅有 2 处 SimpleX 引用**  
✅ **位置：M20220811_onion_hosts.hs（历史服务器地址迁移）**  
✅ **建议：不替换（保留历史迁移数据完整性）**

## 一、SimpleX 引用统计

### 1.1 总体统计

```
检查文件数:     56 个迁移文件
有引用的文件:   1 个
引用总数:       2 处
引用类型:       历史服务器地址
```

### 1.2 详细位置

**文件：** `src/Popopx/Messaging/Agent/Store/SQLite/Migrations/M20220811_onion_hosts.hs`

```haskell
-- 第 14 行
SET ntf_host = 'ntf2.simplex.im,ntg7jdjy2i3qbib3sykiho3enekwiaqg3icctliqhtqcg6jmoh6cxiad.onion'

-- 第 15 行
WHERE ntf_host = 'ntf2.simplex.im';
```

## 二、引用内容分析

### 2.1 迁移背景

**迁移名称：** M20220811_onion_hosts  
**迁移日期：** 2022-08-11  
**迁移目的：** 为通知服务器添加 Onion 路由支持

**迁移 SQL：**
```sql
ALTER TABLE conn_confirmations ADD COLUMN smp_client_version INTEGER;

UPDATE ntf_servers
SET ntf_host = 'ntf2.simplex.im,ntg7jdjy2i3qbib3sykiho3enekwiaqg3icctliqhtqcg6jmoh6cxiad.onion'
WHERE ntf_host = 'ntf2.simplex.im';
```

### 2.2 引用性质

这两处 SimpleX 引用是：

1. **历史服务器地址** - `ntf2.simplex.im`
2. **Onion 地址** - `ntg7jdjy2i3qbib3sykiho3enekwiaqg3icctliqhtqcg6jmoh6cxiad.onion`
3. **迁移数据** - 已经执行过的数据库迁移记录

### 2.3 为什么不能替换

#### 原因 1：历史数据完整性

这些是**已经执行过的迁移**，代表数据库历史状态。如果修改：
- ❌ 会破坏迁移历史的一致性
- ❌ 会导致新旧数据库状态不匹配
- ❌ 会使迁移回滚（down migration）失效

#### 原因 2：真实服务器地址

`ntf2.simplex.im` 是**真实存在的服务器地址**：
- ✅ 这是 SimpleX 项目的公共通知服务器
- ✅ 用户数据库中可能仍然引用这些服务器
- ❌ 不能随意更改为 Popopx 地址

#### 原因 3：上游一致性

上游 SimpleXMQ 也保留这些引用：
```bash
# 上游文件内容完全相同
src/Simplex/Messaging/Agent/Store/SQLite/Migrations/M20220811_onion_hosts.hs
```

修改会导致与上游不一致，增加维护成本。

#### 原因 4：迁移幂等性

迁移系统设计为**幂等的**：
- 迁移只执行一次
- 执行后记录在 `migrations` 表中
- 修改迁移内容不会影响已执行的数据库
- 但会影响新数据库的初始化

## 三、其他迁移文件检查

### 3.1 已检查的文件

✅ **agent_schema.sql** - 无 SimpleX 引用  
✅ **agent_lint.sql** - 无 SimpleX 引用  
✅ **App.hs** - 无 SimpleX 引用  
✅ **M20220101_initial.hs** - 无 SimpleX 引用  
✅ **所有其他 M*.hs 文件** - 无 SimpleX 引用  

### 3.2 检查方法

```bash
# 搜索所有迁移文件
grep -rn "simplex\|SimpleX\|SIMPLEX" \
  src/Popopx/Messaging/Agent/Store/SQLite/Migrations/ \
  --include="*.hs" --include="*.sql"

# 结果：仅 2 处，都在 M20220811_onion_hosts.hs
```

## 四、替换方案

### 4.1 方案 A：不替换（推荐）✅

**理由：**
- ✅ 保持历史数据完整性
- ✅ 保持与上游一致
- ✅ 避免破坏迁移系统
- ✅ 保留真实服务器地址引用

**实施：**
- 不做任何修改
- 在代码注释中说明保留原因

### 4.2 方案 B：仅替换注释（可选）

**如果要增加说明，可以添加注释：**

```haskell
module Popopx.Messaging.Agent.Store.SQLite.Migrations.M20220811_onion_hosts where

import Database.SQLite.Simple (Query)
import Database.Simple.Simple.QQ (sql)

-- | Migration: Add onion routing support for notification servers
-- 
-- Note: This migration contains historical server addresses from SimpleX project.
-- These addresses are preserved for migration integrity and should not be modified.
-- The 'ntf2.simplex.im' is a real public notification server.
m20220811_onion_hosts :: Query
m20220811_onion_hosts =
  [sql|
ALTER TABLE conn_confirmations ADD COLUMN smp_client_version INTEGER;

-- Historical server address - do not modify
UPDATE ntf_servers
SET ntf_host = 'ntf2.simplex.im,ntg7jdjy2i3qbib3sykiho3enekwiaqg3icctliqhtqcg6jmoh6cxiad.onion'
WHERE ntf_host = 'ntf2.simplex.im';
|]
```

### 4.3 方案 C：创建新迁移（不推荐）❌

**理论上可以创建新迁移来更新服务器地址：**

```haskell
-- M20261020_update_ntf_servers.hs
module Popopx.Messaging.Agent.Store.SQLite.Migrations.M20261020_update_ntf_servers where

import Database.SQLite.Simple (Query)
import Database.SQLite.Simple.QQ (sql)

m20261020_update_ntf_servers :: Query
m20261020_update_ntf_servers =
  [sql|
UPDATE ntf_servers
SET ntf_host = REPLACE(ntf_host, 'ntf2.simplex.im', 'ntf2.popopx.im')
WHERE ntf_host LIKE '%simplex.im%';
|]
```

**为什么不推荐：**
- ❌ 需要有自己的 Popopx 通知服务器
- ❌ 会影响现有用户的服务器连接
- ❌ 需要协调客户端和服务端
- ❌ 超出代码品牌替换的范围

## 五、对比分析

### 5.1 上游 vs 本地

| 项目 | 上游 | 本地 | 状态 |
|------|------|------|------|
| 引用数量 | 2 处 | 2 处 | ✅ 一致 |
| 引用位置 | M20220811_onion_hosts.hs | M20220811_onion_hosts.hs | ✅ 一致 |
| 引用内容 | `ntf2.simplex.im` | `ntf2.simplex.im` | ✅ 一致 |
| 迁移逻辑 | 完全相同 | 完全相同 | ✅ 一致 |

### 5.2 其他项目对比

**Postgres 迁移：**
```bash
# 检查 Postgres 迁移
grep -rn "simplex\|SimpleX\|SIMPLEX" \
  src/Popopx/Messaging/Agent/Store/Postgres/Migrations/ \
  --include="*.hs" --include="*.sql"

# 结果：0 处引用 ✅
```

**XFTP 迁移：**
```bash
# 检查 XFTP 迁移
grep -rn "simplex\|SimpleX\|SIMPLEX" \
  src/Popopx/FileTransfer/Server/Store/Postgres/Migrations/ \
  --include="*.hs" --include="*.sql"

# 结果：0 处引用 ✅
```

## 六、风险评估

### 6.1 保留引用的风险

**风险等级：** 🟢 无风险

- ✅ 不影响功能
- ✅ 不影响品牌一致性
- ✅ 不影响用户体验
- ✅ 保持迁移完整性

### 6.2 修改引用的风险

**风险等级：** 🔴 高风险

- ❌ 破坏迁移历史
- ❌ 可能导致数据库初始化失败
- ❌ 与上游不一致
- ❌ 增加维护成本
- ❌ 可能影响现有用户数据

## 七、建议

### 7.1 最终建议

**✅ 采用方案 A：不替换**

**理由：**
1. 这是历史迁移数据，必须保持原样
2. 引用的是真实服务器地址
3. 上游也保留这些引用
4. 修改会带来风险，没有收益

### 7.2 文档建议

**在 PROJECT_MEMORY.md 中添加说明：**

```markdown
## 迁移文件中的 SimpleX 引用

### 位置
- `src/Popopx/Messaging/Agent/Store/SQLite/Migrations/M20220811_onion_hosts.hs`

### 内容
- `ntf2.simplex.im` - SimpleX 公共通知服务器地址
- Onion 地址 - 对应的 Tor 隐藏服务地址

### 为什么保留
1. 这是 2022-08-11 的历史迁移记录
2. 迁移已经执行，修改会破坏数据完整性
3. 引用的是真实存在的公共服务器
4. 上游 SimpleXMQ 也保留这些引用

### 影响
- ✅ 无功能影响
- ✅ 无品牌影响
- ✅ 保持迁移系统完整性
```

## 八、总结

### 8.1 检查结果

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 迁移文件总数 | 56 个 | 全部检查 |
| 有 SimpleX 引用的文件 | 1 个 | M20220811_onion_hosts.hs |
| SimpleX 引用总数 | 2 处 | 历史服务器地址 |
| 需要替换的引用 | 0 处 | 全部保留 |
| 风险等级 | 🟢 无 | 保留是最佳选择 |

### 8.2 替换方案

**✅ 推荐方案：不替换**

**原因：**
1. 历史迁移数据，必须保持原样
2. 引用真实服务器地址
3. 上游也保留这些引用
4. 修改有风险，无收益

### 8.3 最终结论

**迁移文件中的 SimpleX 引用是历史数据，不应该替换。**

- ✅ 保留引用保持迁移完整性
- ✅ 保留引用保持与上游一致
- ✅ 保留引用避免潜在风险
- ✅ 这是正确的工程实践

---

**报告生成时间:** 2026-10-20  
**检查状态:** ✅ 完成  
**替换建议:** ✅ 不替换（保留历史数据）  
**风险等级:** 🟢 无风险
