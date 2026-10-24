{-# LANGUAGE OverloadedStrings #-}
module Main where

import AgentTests.MigrationTests (migrationTests)
import Test.Hspec

main :: IO ()
main = do
  putStrLn "=========================================="
  putStrLn "  运行迁移测试"
  putStrLn "=========================================="
  hspec migrationTests
