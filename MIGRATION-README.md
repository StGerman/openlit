# OpenLIT Migration Scripts

This directory contains scripts for managing ClickHouse database migrations for the OpenLIT platform.

## Current Migration Scripts

### ✅ Working Script: `clickhouse-migrations.js`
**Location**: `/src/client/clickhouse-migrations.js`
**Status**: ✅ ACTIVE - Successfully tested and working
**Purpose**: Direct ClickHouse migration runner that bypasses web authentication

**Usage**:
```bash
cd src/client
node clickhouse-migrations.js
```

**Features**:
- Direct ClickHouse Cloud connection using `@clickhouse/client`
- Loads configuration from `.env` file
- Creates all 7 OpenLIT database tables:
  - `openlit_prompt` - Prompts repository
  - `openlit_vault` - Secrets management
  - `openlit_evaluation` - LLM evaluations
  - `openlit_cron_log` - Scheduled tasks
  - `openlit_folder` - Dashboard organization
  - `openlit_board` - Custom dashboards
  - `openlit_board_widget` - Dashboard widgets
- Comprehensive error handling and logging
- Production-ready with proper connection cleanup

### 📚 Reference Script: `simple-migration.js`
**Location**: `/simple-migration.js`
**Status**: ❌ DEPRECATED - For reference only
**Purpose**: Authentication-based migration attempt (obsolete due to complexity)

**Why deprecated**:
- Complex NextAuth.js session handling
- HTTP request authentication issues
- Unreliable cookie management
- Superseded by direct database approach

## Migration History

### Successfully Completed (August 2024)
✅ All 7 ClickHouse migrations executed successfully on cloud instance
✅ Database schema fully created
✅ OpenLIT platform fully functional and deployed### Migration Execution Log
```
📝 Running migration 1/7: openlit_prompt - ✅ Completed
📝 Running migration 2/7: openlit_vault - ✅ Completed
📝 Running migration 3/7: openlit_evaluation - ✅ Completed
📝 Running migration 4/7: openlit_cron_log - ✅ Completed
📝 Running migration 5/7: openlit_folder - ✅ Completed
📝 Running migration 6/7: openlit_board - ✅ Completed
📝 Running migration 7/7: openlit_board_widget - ✅ Completed
```

## Environment Setup

Ensure your `.env` file in `/src/client/` contains the required ClickHouse Cloud connection variables:
```env
INIT_DB_HOST=<your_clickhouse_cloud_host_url>
INIT_DB_USERNAME=<your_clickhouse_username>
INIT_DB_PASSWORD=<your_clickhouse_password>
INIT_DB_DATABASE=<your_database_name>
```

**Note**: Replace the placeholder values with your actual ClickHouse Cloud credentials.

## Dependencies

The working migration script requires:
```bash
npm install @clickhouse/client dotenv
```

## Troubleshooting

### Common Issues:
1. **Connection failures**: Check `.env` file configuration
2. **Authentication errors**: Verify ClickHouse Cloud credentials
3. **Table exists errors**: Normal - migrations use `IF NOT EXISTS`

### Debug Commands:
```bash
# Test ClickHouse connectivity (will show your configured host)
cd src/client
node -e "console.log(require('dotenv').config()); console.log('Host:', process.env.INIT_DB_HOST)"

# Verify migration status
node clickhouse-migrations.js
```

## Best Practices

1. **Always use the direct approach** (`clickhouse-migrations.js`)
2. **Never run multiple migrations simultaneously** - ClickHouse handles concurrency
3. **Check `.env` configuration first** before troubleshooting
4. **Migrations are idempotent** - safe to run multiple times

---

*Last updated: August 2024*
*Migration status: ✅ Complete*
