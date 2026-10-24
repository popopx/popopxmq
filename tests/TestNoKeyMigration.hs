{-# LANGUAGE OverloadedStrings #-}
module Main where

import Popopx.Messaging.Agent.Store.Migrations.App (appMigrations)
import Popopx.Messaging.Agent.Store.SQLite
import Popopx.Messaging.Agent.Store.SQLite.Common
import Popopx.Messaging.Agent.Store.Shared
import qualified Popopx.Messaging.Agent.Store.SQLite.DB as DB
import Database.SQLite.Simple (query_)
import System.Directory (createDirectoryIfMissing, removeFile)
import Control.Exception (catch, SomeException)

main :: IO ()
main = do
  putStrLn "=========================================="
  putStrLn "  测试无密钥数据库迁移"
  putStrLn "=========================================="
  putStrLn ""
  
  createDirectoryIfMissing True "tests/tmp"
  
  let dbPath = "tests/tmp/no_key_test.db"
  
  removeFile dbPath `catch` (\(_ :: SomeException) -> return ())
  
  putStrLn "创建无密钥数据库..."
  let dbFilePath = dbPath
      dbFunctions = []
      opts = DBOpts { dbFilePath, dbFunctions, dbKey = "", keepKey = False, vacuum = True, track = DB.TQOff }
  
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
      
      closeDBStore store
      putStrLn "✓ 测试完成"
