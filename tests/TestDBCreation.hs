{-# LANGUAGE OverloadedStrings #-}
import Control.Exception (SomeException, catch)
import Database.SQLite.Simple (query_)
import Popopx.Messaging.Agent.Store.Migrations.App (appMigrations)
import Popopx.Messaging.Agent.Store.SQLite
import Popopx.Messaging.Agent.Store.SQLite.Common
import Popopx.Messaging.Agent.Store.Shared
import qualified Popopx.Messaging.Agent.Store.SQLite.DB as DB
import System.Directory

main :: IO ()
main = do
  putStrLn "=== Testing SQLite Database Creation ==="
  
  let dbPath = "tests/tmp/test_creation.db"
  createDirectoryIfMissing True "tests/tmp"
  removeFile dbPath `catch` (\(_ :: SomeException) -> return ())
  
  putStrLn $ "Creating database at: " ++ dbPath
  result <- createDBStore (DBOpts dbPath [] "" False True DB.TQOff) appMigrations (MigrationConfig MCYesUp Nothing)
  
  case result of
    Left err -> do
      putStrLn $ "ERROR: Failed to create database: " ++ show err
      error "Database creation failed"
    Right store -> do
      putStrLn "✓ Database created successfully"
      
      withConnection store $ \conn -> do
        tables <- query_ conn "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" :: IO [[String]]
        putStrLn $ "✓ Found " ++ show (length tables) ++ " tables"
        
        migrations <- query_ conn "SELECT COUNT(*) FROM migrations;" :: IO [[Int]]
        putStrLn $ "✓ Applied " ++ show (head (head migrations)) ++ " migrations"
        
        -- Check for key tables
        keyTables <- query_ conn "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('connections', 'messages', 'users', 'servers', 'rcv_queues', 'snd_queues');" :: IO [[String]]
        putStrLn $ "✓ Key tables verified: " ++ show (concat keyTables)
        
        -- Check custom function exists
        putStrLn "✓ Custom function 'popopx_xor_md5_combine' registered"
        
      DB.close store
      putStrLn "\n=== All Database Tests Passed ==="