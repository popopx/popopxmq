{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StrictData #-}
{-# LANGUAGE TupleSections #-}

module Popopx.Messaging.Agent.Store.SQLite.Migrations
  ( initialize,
    run,
    getCurrentMigrations,
  )
where

import Control.Exception (try, SomeException)
import Control.Monad (forM_, when)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe)
import Data.Text (Text, pack, take)
import Data.Text.Encoding (decodeLatin1)
import Data.Time.Clock (getCurrentTime)
import Database.SQLite.Simple (Only (..), Query (..))
import qualified Database.SQLite.Simple as SQL
import qualified Database.SQLite3 as SQLite3
import Popopx.Messaging.Agent.Protocol (extraSMPServerHosts)
import qualified Popopx.Messaging.Agent.Store.DB as DB
import Popopx.Messaging.Agent.Store.SQLite.Common
import Popopx.Messaging.Agent.Store.SQLite.Migrations.M20230110_users
import Popopx.Messaging.Agent.Store.Shared
import Popopx.Messaging.Encoding.String
import Popopx.Messaging.Transport.Client (TransportHost)
import System.IO (hPutStrLn, stderr)

getCurrentMigrations :: Maybe Query -> DB.Connection -> IO [Migration]
getCurrentMigrations migrationsTable DB.Connection {DB.conn} =
  map toMigration
    <$> SQL.query_ conn ("SELECT name, down FROM " <> table <> " ORDER BY name ASC;")
  where
    table = fromMaybe "migrations" migrationsTable
    toMigration (name, down) = Migration {name, up = "", down}

run :: DBStore -> Maybe Query -> Bool -> MigrationsToRun -> IO ()
run st migrationsTable vacuum = \case
  MTRUp [] -> pure ()
  MTRUp ms -> do
    mapM_ runUp ms
    when vacuum $ withConnection' st (`execSQL` "VACUUM;")
  MTRDown ms -> mapM_ runDown $ reverse ms
  MTRNone -> pure ()
  where
    table = fromMaybe "migrations" migrationsTable
    runUp Migration {name, up, down} = withTransaction' st $ \db -> do
      hPutStrLn stderr $ "[Migration] Running migration: " <> pack name
      when (name == "m20220811_onion_hosts") $ updateServers db
      insert db
      hPutStrLn stderr $ "[Migration] Executing SQL for: " <> pack name <> " (length=" <> pack (show $ Prelude.length sql) <> ")"
      hPutStrLn stderr $ "[Migration] SQL preview: " <> take 200 (pack sql)
      result <- try $ execSQL db sql
      case result of
        Left (e :: SomeException) -> do
          hPutStrLn stderr $ "[Migration] ERROR executing " <> pack name <> ": " <> pack (show e)
          hPutStrLn stderr $ "[Migration] Full SQL: " <> pack sql
          ioError e
        Right () -> do
          hPutStrLn stderr $ "[Migration] Migration completed: " <> pack name
      where
        sql = if dbNew st && name == "m20230110_users" then fromQuery new_m20230110_users else up
        insert db = SQL.execute db ("INSERT INTO " <> table <> " (name, down, ts) VALUES (?,?,?)") . (name,down,) =<< getCurrentTime
        updateServers db = forM_ (M.assocs extraSMPServerHosts) $ \(h, h') ->
          let hs = decodeLatin1 . strEncode $ ([h, h'] :: NonEmpty TransportHost)
           in SQL.execute db "UPDATE servers SET host = ? WHERE host = ?" (hs, decodeLatin1 $ strEncode h)
    runDown DownMigration {downName, downQuery} = withTransaction' st $ \db -> do
      hPutStrLn stderr $ "[Migration] Running down migration: " <> pack downName
      execSQL db downQuery
      SQL.execute db ("DELETE FROM " <> table <> " WHERE name = ?") (Only downName)
    execSQL db = SQLite3.exec $ SQL.connectionHandle db

initialize :: DBStore -> Maybe Query -> IO ()
initialize st migrationsTable = withTransaction' st $ \db -> do
  cs :: [Text] <- map fromOnly <$> SQL.query_ db ("SELECT name FROM pragma_table_info('" <> table <> "')")
  case cs of
    [] -> createMigrations db
    _ -> when ("down" `notElem` cs) $ SQL.execute_ db $ "ALTER TABLE " <> table <> " ADD COLUMN down TEXT"
  where
    table = fromMaybe "migrations" migrationsTable
    createMigrations db =
      SQL.execute_ db $
        "CREATE TABLE IF NOT EXISTS "
          <> table
          <> " (name TEXT NOT NULL PRIMARY KEY, ts TEXT NOT NULL, down TEXT)"
