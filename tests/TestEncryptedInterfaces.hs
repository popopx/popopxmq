{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
module Main where

import qualified Data.ByteArray as BA
import Data.ByteString (ByteString)
import Database.SQLite.Simple (query_, execute_)
import Popopx.Messaging.Agent.Store.Migrations.App (appMigrations)
import Popopx.Messaging.Agent.Store.SQLite
import Popopx.Messaging.Agent.Store.SQLite.Common
import Popopx.Messaging.Agent.Store.Shared
import qualified Popopx.Messaging.Agent.Store.SQLite.DB as DB
import System.Directory (createDirectoryIfMissing, removeFile)
import Control.Exception (catch, SomeException)

main :: IO ()
main = do
  putStrLn "=========================================="
  putStrLn "  加密数据库初始化和迁移测试"
  putStrLn "=========================================="
  putStrLn ""
  
  createDirectoryIfMissing True "tests/tmp"
  
  let key = BA.convert ("test_secret_key_2024" :: ByteString)
  let dbPath = "tests/tmp/encrypted_interface_test.db"
  
  removeFile dbPath `catch` (\(_ :: SomeException) -> return ())
  
  putStrLn "测试 1: 使用 createDBStore 创建加密数据库"
  putStrLn "------------------------------------------"
  let dbFilePath = dbPath
      dbFunctions = []
      opts = DBOpts { dbFilePath, dbFunctions, dbKey = key, keepKey = True, vacuum = True, track = DB.TQOff }
  result <- createDBStore opts appMigrations (MigrationConfig MCYesUp Nothing)
  
  case result of
    Left err -> do
      putStrLn $ "✗ 创建失败: " ++ show err
      error "测试失败"
    Right store -> do
      putStrLn "✓ 数据库创建成功"
      
      withConnection store $ \dbConn -> do
        let conn = DB.conn dbConn
        tables <- query_ conn "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" :: IO [[Int]]
        putStrLn $ "✓ 表数量: " ++ show (head (head tables))
        
        migrations <- query_ conn "SELECT COUNT(*) FROM migrations;" :: IO [[Int]]
        putStrLn $ "✓ 迁移数量: " ++ show (head (head migrations))
      
      putStrLn ""
      putStrLn "测试 2: 数据库操作（增删改查）"
      putStrLn "------------------------------"
      
      withTransaction store $ \dbConn -> do
        let conn = DB.conn dbConn
        execute_ conn "INSERT INTO users (user_id) VALUES (1);"
        putStrLn "✓ 插入用户"
        
        execute_ conn "INSERT INTO servers (host, port, key_hash) VALUES ('test.popopx.im', '5223', X'0102030405');"
        putStrLn "✓ 插入服务器"
        
        users <- query_ conn "SELECT user_id FROM users;" :: IO [[Int]]
        putStrLn $ "✓ 查询用户: " ++ show users
        
        servers <- query_ conn "SELECT host, port FROM servers;" :: IO [[String]]
        putStrLn $ "✓ 查询服务器: " ++ show servers
      
      closeDBStore store
      putStrLn "✓ 数据库关闭"
  
  putStrLn ""
  putStrLn "测试 3: 使用 connectSQLiteStore 重新打开"
  putStrLn "----------------------------------------"
  
  store2 <- connectSQLiteStore opts
  putStrLn "✓ 数据库重新打开"
  
  withConnection store2 $ \dbConn -> do
    let conn = DB.conn dbConn
    users <- query_ conn "SELECT COUNT(*) FROM users;" :: IO [[Int]]
    putStrLn $ "✓ 用户数: " ++ show (head (head users))
    
    servers <- query_ conn "SELECT COUNT(*) FROM servers;" :: IO [[Int]]
    putStrLn $ "✓ 服务器数: " ++ show (head (head servers))
    
    migrations <- query_ conn "SELECT name FROM migrations ORDER BY name LIMIT 5;" :: IO [[String]]
    putStrLn "✓ 迁移列表（前5个）:"
    mapM_ (\m -> putStrLn $ "  - " ++ head m) migrations
  
  closeDBStore store2
  putStrLn "✓ 数据库关闭"
  
  putStrLn ""
  putStrLn "=========================================="
  putStrLn "  所有测试通过！"
  putStrLn "=========================================="
  putStrLn ""
  putStrLn "使用的接口:"
  putStrLn "  - createDBStore: 创建加密数据库并应用迁移"
  putStrLn "  - connectSQLiteStore: 使用密钥重新打开数据库"
  putStrLn "  - withConnection: 获取数据库连接"
  putStrLn "  - withTransaction: 事务操作"
  putStrLn "  - appMigrations: 迁移列表"
  putStrLn "  - MigrationConfig: 迁移配置"
