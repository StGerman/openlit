# OpenLIT AI Engineering Platform - Copilot Instructions

## Project Overview

OpenLIT is an **OpenTelemetry-native AI observability platform** that provides monitoring, evaluation, and management capabilities for AI/ML applications. The platform consists of three main components:

1. **Client UI** (`src/client/`) - Next.js dashboard for observability and management
2. **SDK Libraries** (`sdk/`) - Python/TypeScript instrumentation libraries
3. **OTEL Collector** (`otel-gpu-collector/`) - Custom OpenTelemetry collector

## Architecture & Data Flow

### Dual Database Architecture
- **ClickHouse**: Stores telemetry data (traces, metrics, spans) from instrumented applications
- **SQLite/Prisma**: Stores application metadata (user accounts, database configs, dashboard layouts)

### Key Data Flow
1. AI applications use OpenLIT SDKs → Generate OpenTelemetry traces/metrics
2. Data flows to ClickHouse (via OTEL collector or direct)
3. Next.js UI queries ClickHouse for observability data + SQLite for app config
4. Custom dashboards built with react-grid-layout + Monaco editor for ClickHouse SQL queries

## Critical Development Patterns

### Database Operations
- **ClickHouse queries**: Use `dataCollector()` in `/src/client/src/lib/platform/common.ts`
- **Connection pooling**: Managed via `createClickhousePool()` with generic-pool
- **Migrations**: ClickHouse schema managed in `/src/client/src/clickhouse/migrations/`
- **Database configs**: Multi-tenant support via `/src/client/src/lib/db-config.ts`

### Frontend Architecture
- **State management**: Zustand with lens pattern (`@dhmk/zustand-lens`)
- **API routes**: `/src/client/src/app/api/` follows Next.js 13+ app router
- **Components**: Hierarchical spans in `/components/(playground)/request/heirarchy-display.tsx`
- **Dashboard system**: Grid-based with SQL query widgets in `/components/(playground)/manage-dashboard/`

### Key Conventions
- **Error handling**: Use `asaw()` utility for async/await error wrapping
- **Data fetching**: `useFetchWrapper()` hook for consistent API calls
- **Telemetry**: PostHog events fired via `PostHogServer.fireEvent()` on server actions
- **Type safety**: Extensive TypeScript with Prisma-generated types

## Essential Commands & Workflows

### Development Setup
```bash
# Client development
cd src/client
npm run dev              # Start Next.js dev server
npm run seed            # Seed SQLite database
npx prisma migrate dev  # Run Prisma migrations

# Full stack (Docker)
docker compose up -d     # ClickHouse + OpenLIT UI
```

### Database Operations
```bash
# ClickHouse migrations (via API)
POST /api/clickhouse/migrate

# Test ClickHouse connectivity
GET /api/clickhouse

# Multiple database configs supported - check /settings/database-config
```

### Key Development Files
- `/src/client/src/lib/platform/common.ts` - ClickHouse query interface
- `/src/client/src/clickhouse/migrations/index.ts` - Schema migrations
- `/src/client/src/app/(playground)/layout.tsx` - Main app wrapper with connectivity checks
- `/src/client/src/components/(playground)/clickhouse-connectivity-wrapper.tsx` - Connection validation

## Integration Points

### External Dependencies
- **@clickhouse/client**: Direct ClickHouse connection (not HTTP)
- **@prisma/client**: SQLite ORM for app metadata
- **react-grid-layout**: Dashboard widget positioning
- **@monaco-editor/react**: SQL editor with custom ClickHouse syntax
- **@radix-ui/***: Component library
- **generic-pool**: ClickHouse connection pooling

### SDK Integration
- SDKs instrument AI applications with OpenTelemetry
- Traces/metrics sent to ClickHouse via OTEL collector or direct HTTP
- Custom pricing data for cost tracking in `/assets/pricing.json`
- Semantic conventions follow OpenTelemetry gen-ai standards

## Dashboard & Widget System

### Widget Architecture
- **Folders/Boards**: Hierarchical dashboard organization via `/api/manage-dashboard/`
- **Widgets**: Reusable components with SQL queries + visualization config
- **Grid Layout**: Drag-drop positioning stored as JSON in ClickHouse `openlit_board_widget` table
- **Query Execution**: Monaco editor → SQL validation → ClickHouse execution via `/api/manage-dashboard/query/run`

## Common Debugging Patterns

### ClickHouse Issues
- Check connectivity with `useClickhousePing()` hook
- Database config issues: `/settings/database-config` page
- Migration failures: Check `/src/client/src/clickhouse/migrations/migration-helper.ts`
- Query errors: Use `enable_readonly: true` for safe queries

### Dashboard Problems
- Widget not loading: Check SQL syntax in Monaco editor
- Layout issues: Grid positions stored in `openlit_board_widget.position` JSON
- Import/Export: Use `/api/manage-dashboard/board/[id]/layout/export` endpoints

### Common File Patterns
- API routes: `route.ts` files in app directory
- Type definitions: `/src/client/src/types/` with strict interfaces
- Utilities: `/src/client/src/utils/` for reusable helpers
- Store: Zustand slices in `/src/client/src/store/`
