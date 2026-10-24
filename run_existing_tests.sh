#!/usr/bin/env bash
# 简化测试：直接运行现有的 SQLiteTests 和 MigrationTests

echo "=== 运行现有测试套件 ==="
echo ""

echo "测试 1: 运行 MigrationTests"
echo "---------------------------"
cd /home/ubuntu/popopxmq

# 编译测试运行器
cabal exec -- ghc -o /tmp/run_migration_simple -package popopxmq -itests tests/RunMigrationTests.hs 2>&1 | tail -5

if [ -f /tmp/run_migration_simple ]; then
  echo "运行迁移测试..."
  timeout 30 /tmp/run_migration_simple 2>&1 | head -50
fi

echo ""
echo "测试 2: 检查 SQLiteTests 模块"
echo "-----------------------------"
echo "SQLiteTests 包含以下测试:"
grep "describe\|it " tests/AgentTests/SQLiteTests.hs | head -20

echo ""
echo "测试 3: 使用 cabal test 运行特定测试"
echo "------------------------------------"
echo "尝试运行 SQLite 相关测试..."
timeout 60 cabal test --test-show-details=direct 2>&1 | grep -A 10 -B 5 "SQLite\|migration\|PASS\|FAIL" | head -50

echo ""
echo "=== 测试完成 ==="
