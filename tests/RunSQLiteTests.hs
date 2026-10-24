{-# LANGUAGE OverloadedStrings #-}
module Main where

import AgentTests.SQLiteTests (storeTests)
import Test.Hspec

main :: IO ()
main = do
  putStrLn "=========================================="
  putStrLn "  运行 SQLite 数据库测试"
  putStrLn "=========================================="
  hspec storeTests
