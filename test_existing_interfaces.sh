#!/usr/bin/env bash
# 使用现有接口测试加密数据库的初始化和迁移

set -e

echo "=== 使用现有接口测试加密数据库 ==="
echo ""

# 清理
rm -f tests/tmp/encrypted_*.db
mkdir -p tests/tmp

echo "测试 1: 使用 createDBStore 接口创建加密数据库"
echo "----------------------------------------------"

# 使用 cabal 运行一个简单的 Haskell 程序来测试
cat > /tmp/test_encrypted_init.hs << 'EOF'
{-# LANGUAGE OverloadedStrings #-}
import qualified Data.ByteArray as BA
import Data.ByteString (ByteString)
import Popopx.Messaging.Agent.Store.SQLite
import Popopx.Messaging.Agent.Store.SQLite.Common
import Popopx.Messaging.Agent.Store.Migrations.App (appMigrations)
import Popopx.Messaging.Agent.Store.Shared
import qualified Popopx.Messaging.Agent.Store.SQLite.DB as DB
import Database.SQLite.Simple (query_)
import System.Directory (removeFile)
import Control.Exception (catch, SomeException)

main :: IO ()
main = do
  let key = BA.convert ("test_secret_key_2024" :: ByteString)
  let dbPath = "tests/tmp/encrypted_init_test.db"
  
  removeFile dbPath `catch` (\(_ :: SomeException) -> return ())
  
  putStrLn "创建加密数据库..."
  let opts = DBOpts dbPath [] key True True DB.TQOff
  
  result <- createDBStore opts appMigrations (MigrationConfig MCYesUp Nothing)
  
  case result of
    Left err -> error $ "创建失败: " ++ show err
    Right store -> do
      putStrLn "✓ 数据库创建成功"
      
      withConnection store $ \(DB.Connection {conn}) -> do
        tables <- query_ conn "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" :: IO [[Int]]
        putStrLn $ "✓ 表数量: " ++ show (head (head tables))
        
        migrations <- query_ conn "SELECT COUNT(*) FROM migrations;" :: IO [[Int]]
        putStrLn $ "✓ 迁移数量: " ++ show (head (head migrations))
        
        -- 插入测试数据
        DB.execute_ conn "INSERT INTO users (user_id) VALUES (1);"
        putStrLn "✓ 插入测试数据"
      
      DB.close store
      putStrLn "✓ 数据库关闭"
EOF

cabal exec -- runhaskell /tmp/test_encrypted_init.hs

echo ""
echo "测试 2: 使用 connectSQLiteStore 重新打开加密数据库"
echo "--------------------------------------------------"

cat > /tmp/test_encrypted_reopen.hs << 'EOF'
{-# LANGUAGE OverloadedStrings #-}
import qualified Data.ByteArray as BA
import Data.ByteString (ByteString)
import Popopx.Messaging.Agent.Store.SQLite
import Popopx.Messaging.Agent.Store.SQLite.Common
import qualified Popopx.Messaging.Agent.Store.SQLite.DB as DB
import Database.SQLite.Simple (query_)

main :: IO ()
main = do
  let key = BA.convert ("test_secret_key_2024" :: ByteString)
  let dbPath = "tests/tmp/encrypted_init_test.db"
  
  putStrLn "重新打开加密数据库..."
  let opts = DBOpts dbPath [] key True True DB.TQOff
  
  store <- connectSQLiteStore opts
  putStrLn "✓ 数据库重新打开"
  
  withConnection store $ \(DB.Connection {conn}) -> do
    users <- query_ conn "SELECT COUNT(*) FROM users;" :: IO [[Int]]
    putStrLn $ "✓ 用户数: " ++ show (head (head users))
    
    migrations <- query_ conn "SELECT COUNT(*) FROM migrations;" :: IO [[Int]]
    putStrLn $ "✓ 迁移数: " ++ show (head (head migrations))
  
  DB.close store
  putStrLn "✓ 数据库关闭"
EOF

cabal exec -- runhaskell /tmp/test_encrypted_reopen.hs

echo ""
echo "测试 3: 验证迁移系统"
echo "--------------------"

cat > /tmp/test_migrations.hs << 'EOF'
{-# LANGUAGE OverloadedStrings #-}
import qualified Data.ByteArray as BA
import Data.ByteString (ByteString)
import Popopx.Messaging.Agent.Store.SQLite
import Popopx.Messaging.Agent.Store.SQLite.Common
import qualified Popopx.Messaging.Agent.Store.SQLite.DB as DB
import Database.SQLite.Simple (query_)

main :: IO ()
main = do
  let key = BA.convert ("test_secret_key_2024" :: ByteString)
  let dbPath = "tests/tmp/encrypted_init_test.db"
  
  let opts = DBOpts dbPath [] key True True DB.TQOff
  store <- connectSQLiteStore opts
  
  withConnection store $ \(DB.Connection {conn}) -> do
    migrations <- query_ conn "SELECT name FROM migrations ORDER BY name LIMIT 10;" :: IO [[String]]
    putStrLn "已应用的迁移（前10个）:"
    mapM_ (\m -> putStrLn $ "  - " ++ head m) migrations
    
    tables <- query_ conn "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('users', 'connections', 'messages', 'servers', 'rcv_queues');" :: IO [[String]]
    putStrLn $ "✓ 关键表: " ++ show (concat tables)
  
  DB.close store
EOF

cabal exec -- runhaskell /tmp/test_migrations.hs

echo ""
echo "测试 4: 数据库操作测试"
echo "----------------------"

cat > /tmp/test_operations.hs << 'EOF'
{-# LANGUAGE OverloadedStrings #-}
import qualified Data.ByteArray as BA
import Data.ByteString (ByteString)
import Popopx.Messaging.Agent.Store.SQLite
import Popopx.Messaging.Agent.Store.SQLite.Common
import qualified Popopx.Messaging.Agent.Store.SQLite.DB as DB
import Database.SQLite.Simple (query_, execute_)

main :: IO ()
main = do
  let key = BA.convert ("test_secret_key_2024" :: ByteString)
  let dbPath = "tests/tmp/encrypted_ops_test.db"
  
  let opts = DBOpts dbPath [] key True True DB.TQOff
  
  -- 创建新数据库
  putStrLn "创建新数据库..."
  result <- createDBStore opts appMigrations (MigrationConfig MCYesUp Nothing)
  
  case result of
    Left err -> error $ "创建失败: " ++ show err
    Right store -> do
      putStrLn "✓ 数据库创建成功"
      
      withTransaction store $ \(DB.Connection {conn}) -> do
        -- 插入数据
        execute_ conn "INSERT INTO users (user_id) VALUES (1);"
        execute_ conn "INSERT INTO servers (host, port, key_hash) VALUES ('test.popopx.im', '5223', X'0102030405');"
        putStrLn "✓ 插入数据"
        
        -- 查询数据
        users <- query_ conn "SELECT user_id FROM users;" :: IO [[Int]]
        putStrLn $ "✓ 查询用户: " ++ show users
        
        servers <- query_ conn "SELECT host, port FROM servers;" :: IO [[String]]
        putStrLn $ "✓ 查询服务器: " ++ show servers
        
        -- 更新数据
        execute_ conn "UPDATE users SET deleted = 0 WHERE user_id = 1;"
        putStrLn "✓ 更新数据"
        
        -- 删除数据
        execute_ conn "DELETE FROM servers;"
        putStrLn "✓ 删除数据"
      
      DB.close store
      putStrLn "✓ 操作完成"
EOF

cabal exec -- runhaskell /tmp/test_operations.hs

echo ""
echo "=== 测试总结 ==="
echo ""
echo "使用现有接口测试完成:"
echo "  ✓ createDBStore - 创建加密数据库"
echo "  ✓ connectSQLiteStore - 重新打开加密数据库"
echo "  ✓ 迁移系统 - 自动应用所有迁移"
echo "  ✓ 数据库操作 - 增删改查"
echo ""
echo "接口使用方式:"
echo "  1. DBOpts { dbKey = key, keepKey = True, ... }"
echo "  2. createDBStore opts appMigrations config"
echo "  3. connectSQLiteStore opts"
echo "  4. withTransaction / withConnection"
echo ""
echo "所有测试通过！"
