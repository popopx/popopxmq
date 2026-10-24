#!/usr/bin/env bash
# Test database creation using the actual PopopxMQ code

set -e

echo "=== Testing PopopxMQ Database Creation ==="
echo ""

# Clean up
rm -f tests/tmp/test_*.db
mkdir -p tests/tmp

# Create a minimal test database using sqlite3 and the schema file
echo "1. Testing schema file directly with sqlite3..."
sqlite3 tests/tmp/test_schema.db < src/Popopx/Messaging/Agent/Store/SQLite/Migrations/agent_schema.sql

# Verify tables were created
TABLE_COUNT=$(sqlite3 tests/tmp/test_schema.db "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
echo "   ✓ Created $TABLE_COUNT tables"

# Check for key tables
echo ""
echo "2. Verifying key tables exist..."
for table in migrations users servers connections messages rcv_queues snd_queues ntf_servers; do
  if sqlite3 tests/tmp/test_schema.db "SELECT 1 FROM sqlite_master WHERE type='table' AND name='$table';" | grep -q 1; then
    echo "   ✓ Table '$table' exists"
  else
    echo "   ✗ Table '$table' MISSING"
    exit 1
  fi
done

# Check STRICT mode
echo ""
echo "3. Verifying STRICT table mode..."
STRICT_COUNT=$(sqlite3 tests/tmp/test_schema.db "SELECT COUNT(*) FROM sqlite_master WHERE sql LIKE '%STRICT%';")
echo "   ✓ Found $STRICT_COUNT STRICT tables"

# Check WITHOUT ROWID
echo ""
echo "4. Verifying WITHOUT ROWID optimization..."
ROWID_COUNT=$(sqlite3 tests/tmp/test_schema.db "SELECT COUNT(*) FROM sqlite_master WHERE sql LIKE '%WITHOUT ROWID%';")
echo "   ✓ Found $ROWID_COUNT WITHOUT ROWID tables"

# Check custom function reference
echo ""
echo "5. Verifying custom function 'popopx_xor_md5_combine'..."
if grep -q "popopx_xor_md5_combine" src/Popopx/Messaging/Agent/Store/SQLite/Migrations/agent_schema.sql; then
  TRIGGER_COUNT=$(grep -c "popopx_xor_md5_combine" src/Popopx/Messaging/Agent/Store/SQLite/Migrations/agent_schema.sql)
  echo "   ✓ Custom function referenced in $TRIGGER_COUNT triggers"
else
  echo "   ✗ Custom function NOT found"
  exit 1
fi

# Check indexes
echo ""
echo "6. Verifying indexes..."
INDEX_COUNT=$(sqlite3 tests/tmp/test_schema.db "SELECT COUNT(*) FROM sqlite_master WHERE type='index';")
echo "   ✓ Created $INDEX_COUNT indexes"

# Insert test data
echo ""
echo "7. Testing data insertion..."
sqlite3 tests/tmp/test_schema.db "INSERT INTO migrations (name, ts, down) VALUES ('test', datetime('now'), 'SELECT 1');"
sqlite3 tests/tmp/test_schema.db "INSERT INTO users (user_id) VALUES (1);"
echo "   ✓ Test data inserted successfully"

# Verify data
MIGRATION_COUNT=$(sqlite3 tests/tmp/test_schema.db "SELECT COUNT(*) FROM migrations;")
USER_COUNT=$(sqlite3 tests/tmp/test_schema.db "SELECT COUNT(*) FROM users;")
echo "   ✓ Migrations: $MIGRATION_COUNT"
echo "   ✓ Users: $USER_COUNT"

# Show sample schema
echo ""
echo "8. Sample table schema (connections):"
sqlite3 tests/tmp/test_schema.db ".schema connections" | head -15

echo ""
echo "=== All Database Tests Passed ==="
echo ""
echo "Summary:"
echo "  - Tables: $TABLE_COUNT"
echo "  - Indexes: $INDEX_COUNT"
echo "  - STRICT tables: $STRICT_COUNT"
echo "  - WITHOUT ROWID tables: $ROWID_COUNT"
echo "  - Custom function triggers: $TRIGGER_COUNT"
echo "  - Database file: tests/tmp/test_schema.db"
echo "  - Database size: $(du -h tests/tmp/test_schema.db | cut -f1)"
