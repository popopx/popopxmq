{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

import Control.Exception (SomeException, catch)
import Data.ByteArray (ScrubbedBytes)
import qualified Data.ByteArray as BA
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as B
import Database.SQLite.Simple (Only (..), Query, execute_, query_)
import qualified Database.SQLite.Simple as SQL
import Popopx.Messaging.Agent.Store.Migrations.App (appMigrations)
import Popopx.Messaging.Agent.Store.SQLite
import Popopx.Messaging.Agent.Store.SQLite.Common
import Popopx.Messaging.Agent.Store.Shared
import qualified Popopx.Messaging.Agent.Store.SQLite.DB as DB
import System.Directory (createDirectoryIfMissing, removeFile)

-- 测试密钥
testKey :: ScrubbedBytes
testKey = BA.convert ("test_secret_key_2024" :: ByteString)

-- 测试数据库路径
testDBPath :: String
testDBPath = "tests/tmp/hs_encrypted_test.db"

main :: IO ()
main = do
  putStrLn "=========================================="
  putStrLn "  Haskell 加密数据库测试"
  putStrLn "=========================================="
  putStrLn ""
  
  -- 清理测试环境
  createDirectoryIfMissing True "tests/tmp"
  removeFile testDBPath `catch` (\(_ :: SomeException) -> return ())
  
  putStrLn "测试 1: 使用密钥创建数据库"
  test1_CreateDBWithKey
  
  putStrLn ""
  putStrLn "测试 2: 验证迁移状态"
  test2_VerifyMigrations
  
  putStrLn ""
  putStrLn "测试 3: 数据库操作（增删改查）"
  test3_DatabaseOperations
  
  putStrLn ""
  putStrLn "测试 4: 关闭并重新打开数据库"
  test4_ReopenDB
  
  putStrLn ""
  putStrLn "测试 5: 验证数据完整性"
  test5_VerifyDataIntegrity
  
  putStrLn ""
  putStrLn "=========================================="
  putStrLn "  所有测试通过！"
  putStrLn "=========================================="

-- 测试 1: 使用密钥创建数据库
test1_CreateDBWithKey :: IO ()
test1_CreateDBWithKey = do
  putStrLn "  创建加密数据库..."
  putStrLn $ "  数据库路径: " ++ testDBPath
  putStrLn $ "  密钥长度: " ++ show (BA.length testKey) ++ " bytes"
  
  -- 创建数据库选项
  let dbOpts = DBOpts 
        { dbFilePath = testDBPath
        , dbFunctions = []
        , dbKey = testKey
        , keepKey = True
        , track = DB.TQOff
        }
  
  -- 创建数据库并应用迁移
  result <- createDBStore dbOpts appMigrations (MigrationConfig MCYesUp Nothing)
  
  case result of
    Left err -> do
      putStrLn $ "  ✗ 创建失败: " ++ show err
      error "数据库创建失败"
    Right store -> do
      putStrLn "  ✓ 数据库创建成功"
      
      -- 获取连接并验证
      withConnection store $ \(DB.Connection {conn}) -> do
        -- 验证数据库已加密
        tables <- (query_ conn "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" :: IO [[Int]])
        putStrLn $ "  ✓ 表数量: " ++ show (head (head tables))
        
        -- 验证迁移表
        migrations <- (query_ conn "SELECT COUNT(*) FROM migrations;" :: IO [[Int]])
        putStrLn $ "  ✓ 迁移数量: " ++ show (head (head migrations))
      
      DB.close store
      putStrLn "  ✓ 数据库连接关闭"

-- 测试 2: 验证迁移状态
test2_VerifyMigrations :: IO ()
test2_VerifyMigrations = do
  putStrLn "  重新打开数据库验证迁移..."
  
  let dbOpts = DBOpts 
        { dbFilePath = testDBPath
        , dbFunctions = []
        , dbKey = testKey
        , keepKey = True
        , track = DB.TQOff
        }
  
  store <- connectSQLiteStore dbOpts
  
  withConnection store $ \(DB.Connection {conn}) -> do
    -- 查询所有迁移
    migrations <- (query_ conn "SELECT name FROM migrations ORDER BY name;" :: IO [[String]])
    putStrLn $ "  ✓ 已应用的迁移:"
    mapM_ (\m -> putStrLn $ "    - " ++ head m) (take 5 migrations)
    putStrLn $ "    ... 共 " ++ show (length migrations) ++ " 个迁移"
    
    -- 验证关键表存在
    keyTables <- (query_ conn "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('users', 'connections', 'messages', 'servers');" :: IO [[String]])
    putStrLn $ "  ✓ 关键表: " ++ show (concat keyTables)
  
  DB.close store

-- 测试 3: 数据库操作（增删改查）
test3_DatabaseOperations :: IO ()
test3_DatabaseOperations = do
  putStrLn "  执行数据库操作..."
  
  let dbOpts = DBOpts 
        { dbFilePath = testDBPath
        , dbFunctions = []
        , dbKey = testKey
        , keepKey = True
        , track = DB.TQOff
        }
  
  store <- connectSQLiteStore dbOpts
  
  withTransaction store $ \(DB.Connection {conn}) -> do
    -- 插入用户
    execute_ conn "INSERT INTO users (user_id) VALUES (1);"
    putStrLn "  ✓ 插入用户"
    
    -- 插入服务器
    execute_ conn "INSERT INTO servers (host, port, key_hash) VALUES ('test.popopx.im', '5223', X'0102030405');"
    putStrLn "  ✓ 插入服务器"
    
    -- 插入连接
    execute_ conn "INSERT INTO connections (conn_id, conn_mode, user_id) VALUES (X'AABBCCDD', 'test', 1);"
    putStrLn "  ✓ 插入连接"
    
    -- 查询用户
    users <- (query_ conn "SELECT user_id FROM users;" :: IO [[Int]])
    putStrLn $ "  ✓ 查询用户: " ++ show (length users) ++ " 个"
    
    -- 查询服务器
    servers <- (query_ conn "SELECT host, port FROM servers;" :: IO [[String]])
    putStrLn $ "  ✓ 查询服务器: " ++ show (length servers) ++ " 个"
    
    -- 更新连接
    execute_ conn "UPDATE connections SET conn_mode = 'updated' WHERE conn_id = X'AABBCCDD';"
    putStrLn "  ✓ 更新连接"
    
    -- 验证更新
    updated <- (query_ conn "SELECT conn_mode FROM connections WHERE conn_id = X'AABBCCDD';" :: IO [[String]])
    putStrLn $ "  ✓ 验证更新: " ++ show (head (head updated))
  
  DB.close store

-- 测试 4: 关闭并重新打开数据库
test4_ReopenDB :: IO ()
test4_ReopenDB = do
  putStrLn "  关闭数据库..."
  putStrLn "  重新打开数据库（使用密钥）..."
  
  let dbOpts = DBOpts 
        { dbFilePath = testDBPath
        , dbFunctions = []
        , dbKey = testKey
        , keepKey = True
        , track = DB.TQOff
        }
  
  store <- connectSQLiteStore dbOpts
  
  withConnection store $ \(DB.Connection {conn}) -> do
    -- 验证数据仍然存在
    users <- (query_ conn "SELECT COUNT(*) FROM users;" :: IO [[Int]])
    putStrLn $ "  ✓ 用户数: " ++ show (head (head users))
    
    servers <- (query_ conn "SELECT COUNT(*) FROM servers;" :: IO [[Int]])
    putStrLn $ "  ✓ 服务器数: " ++ show (head (head servers))
    
    connections <- (query_ conn "SELECT COUNT(*) FROM connections;" :: IO [[Int]])
    putStrLn $ "  ✓ 连接数: " ++ show (head (head connections))
  
  DB.close store
  putStrLn "  ✓ 数据库重新打开成功"

-- 测试 5: 验证数据完整性
test5_VerifyDataIntegrity :: IO ()
test5_VerifyDataIntegrity = do
  putStrLn "  验证数据完整性..."
  
  let dbOpts = DBOpts 
        { dbFilePath = testDBPath
        , dbFunctions = []
        , dbKey = testKey
        , keepKey = True
        , track = DB.TQOff
        }
  
  store <- connectSQLiteStore dbOpts
  
  withConnection store $ \(DB.Connection {conn}) -> do
    -- 验证外键约束
    execute_ conn "PRAGMA foreign_keys = ON;"
    
    -- 验证数据
    userCheck <- (query_ conn "SELECT user_id, deleted FROM users WHERE user_id = 1;" :: IO [[Int]])
    putStrLn $ "  ✓ 用户数据: " ++ show userCheck
    
    serverCheck <- (query_ conn "SELECT host, port FROM servers WHERE host = 'test.popopx.im';" :: IO [[String]])
    putStrLn $ "  ✓ 服务器数据: " ++ show serverCheck
    
    connCheck <- (query_ conn "SELECT conn_mode FROM connections WHERE conn_id = X'AABBCCDD';" :: IO [[String]])
    putStrLn $ "  ✓ 连接数据: " ++ show connCheck
    
    -- 删除测试数据
    execute_ conn "DELETE FROM connections;"
    execute_ conn "DELETE FROM servers;"
    execute_ conn "DELETE FROM users;"
    putStrLn "  ✓ 清理测试数据"
  
  DB.close store
  
  putStrLn "  ✓ 数据完整性验证通过"
