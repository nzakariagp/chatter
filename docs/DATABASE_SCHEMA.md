# Database Schema Documentation

## Overview

Chatter uses PostgreSQL 18.1+ with Ecto 3.13+ for data persistence. The schema is designed to be simple, normalized, and efficient for real-time chat operations.

## Entity Relationship Diagram

```
┌─────────────────────┐
│       users         │
├─────────────────────┤
│ id (PK)             │ UUID
│ name                │ VARCHAR(255) UNIQUE NOT NULL
│ inserted_at         │ TIMESTAMP
│ updated_at          │ TIMESTAMP
└─────────────────────┘
           │
           │ 1:N
           │
           ▼
┌─────────────────────┐
│      messages       │
├─────────────────────┤
│ id (PK)             │ UUID
│ content             │ TEXT NOT NULL
│ user_id (FK)        │ UUID NOT NULL
│ inserted_at         │ TIMESTAMP
│ updated_at          │ TIMESTAMP
└─────────────────────┘
```

## Tables

### users

Stores all registered chat users.

**Columns**:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | binary_id (UUID) | PRIMARY KEY | Unique identifier |
| name | string (VARCHAR 255) | UNIQUE, NOT NULL | Username for display |
| inserted_at | utc_datetime_usec | NOT NULL | Record creation timestamp (microsecond precision) |
| updated_at | utc_datetime_usec | NOT NULL | Record update timestamp (microsecond precision) |

**Indexes**:
- `PRIMARY KEY (id)` - Clustered index on UUID
- `UNIQUE INDEX users_name_index ON users(name)` - Fast username lookups and uniqueness enforcement

**Constraints**:
- `name` must be unique (enforced at database level)
- `name` cannot be null

**Ecto Schema**:
```elixir
schema "users" do
  field :name, :string

  timestamps(type: :utc_datetime_usec)
end
```

**Sample Data**:
```sql
INSERT INTO users (id, name, inserted_at, updated_at) VALUES
  ('550e8400-e29b-41d4-a716-446655440000', 'alice', NOW(), NOW()),
  ('550e8400-e29b-41d4-a716-446655440001', 'bob', NOW(), NOW());
```

### messages

Stores all chat messages with reference to the sending user.

**Columns**:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | binary_id (UUID) | PRIMARY KEY | Unique identifier |
| content | text | NOT NULL | Message content |
| user_id | binary_id (UUID) | FOREIGN KEY, NOT NULL | Reference to users table |
| inserted_at | utc_datetime_usec | NOT NULL | Message creation timestamp (microsecond precision) |
| updated_at | utc_datetime_usec | NOT NULL | Message update timestamp (microsecond precision) |

**Indexes**:
- `PRIMARY KEY (id)` - Clustered index on UUID
- `INDEX messages_user_id_index ON messages(user_id)` - Fast user message lookups
- `INDEX messages_inserted_at_index ON messages(inserted_at)` - Chronological queries

**Foreign Keys**:
- `user_id REFERENCES users(id)` - Links message to user
- `ON DELETE: nothing` - Preserve messages if user deleted (can be changed to CASCADE)

**Ecto Schema**:
```elixir
schema "messages" do
  field :content, :string

  belongs_to :user, Chatter.Accounts.User

  timestamps(type: :utc_datetime_usec)
end
```

**Sample Data**:
```sql
INSERT INTO messages (id, content, user_id, inserted_at, updated_at) VALUES
  ('650e8400-e29b-41d4-a716-446655440000', 'Hello everyone!', '550e8400-e29b-41d4-a716-446655440000', NOW(), NOW()),
  ('650e8400-e29b-41d4-a716-446655440001', 'Hi Alice!', '550e8400-e29b-41d4-a716-446655440001', NOW(), NOW());
```

## Migrations

### Initial Migration Plan

1. **20241208000000_create_users.exs** - Create users table
2. **20241208000001_create_messages.exs** - Create messages table

### Migration: Create Users Table

```elixir
defmodule Chatter.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:name])
  end
end
```

**Run with**: `mix ecto.gen.migration create_users`

**Rollback behavior**: Drops the users table and its index

### Migration: Create Messages Table

```elixir
defmodule Chatter.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:messages, [:user_id])
    create index(:messages, [:inserted_at])
  end
end
```

**Run with**: `mix ecto.gen.migration create_messages`

**Rollback behavior**: Drops the messages table and its indexes

## Data Access Patterns

### Common Queries

#### 1. Get All Users (Ordered by Name)

```elixir
# Ecto
Chatter.Accounts.list_users()

# SQL
SELECT id, name, inserted_at, updated_at
FROM users
ORDER BY name ASC;
```

**Performance**: O(n log n) with n = total users. Uses name index for ordering.

#### 2. Get User by Name

```elixir
# Ecto
Chatter.Accounts.get_user_by_name("alice")

# SQL
SELECT id, name, inserted_at, updated_at
FROM users
WHERE name = 'alice';
```

**Performance**: O(1) - Uses unique index on name.

#### 3. Get Recent Messages with Users

```elixir
# Ecto
Chatter.Chat.list_recent_messages(100)

# SQL (with preload)
SELECT m.id, m.content, m.user_id, m.inserted_at, m.updated_at,
       u.id, u.name, u.inserted_at, u.updated_at
FROM messages m
INNER JOIN users u ON u.id = m.user_id
ORDER BY m.inserted_at DESC
LIMIT 100;
```

**Performance**: O(n) with n = 100. Uses inserted_at index for ordering, user_id index for join.

#### 4. Create User

```elixir
# Ecto
Chatter.Accounts.create_user(%{name: "charlie"})

# SQL
INSERT INTO users (id, name, inserted_at, updated_at)
VALUES (gen_random_uuid(), 'charlie', NOW(), NOW())
RETURNING id, name, inserted_at, updated_at;
```

**Performance**: O(1). Checks unique constraint on name.

#### 5. Create Message

```elixir
# Ecto
Chatter.Chat.create_message(user, %{content: "Hello!"})

# SQL
INSERT INTO messages (id, content, user_id, inserted_at, updated_at)
VALUES (gen_random_uuid(), 'Hello!', '550e8400-e29b-41d4-a716-446655440000', NOW(), NOW())
RETURNING id, content, user_id, inserted_at, updated_at;
```

**Performance**: O(1). Validates foreign key constraint.

## Data Integrity

### Constraints

1. **Primary Keys**: All tables use UUIDs to prevent enumeration attacks
2. **Unique Constraints**: Username uniqueness enforced at DB level
3. **Foreign Keys**: Messages reference valid users
4. **NOT NULL**: Critical fields cannot be null

### Validation Layers

**Application Layer (Ecto Changesets)**:
- Username format (alphanumeric, underscore, hyphen)
- Username length (1-50 characters)
- Message content length (1-1000 characters)

**Database Layer**:
- Unique constraint on username
- Foreign key constraint on user_id
- NOT NULL constraints

### Data Consistency

**Timestamps**: All tables use `:utc_datetime` for consistent timezone handling

**UUIDs**: Using binary_id (UUID v4) for:
- Prevention of ID enumeration
- Better distribution across shards (future-proofing)
- No sequence conflicts in distributed systems

**Referential Integrity**: `on_delete: :nothing` preserves messages if user is deleted (orphaned messages remain for historical purposes)

## Index Strategy

### Why These Indexes?

1. **users.name (UNIQUE)**:
   - Enforces uniqueness
   - Fast login/join lookups (O(1))
   - Used for ordering user lists

2. **messages.user_id**:
   - Fast joins between messages and users
   - Enables efficient "messages by user" queries

3. **messages.inserted_at**:
   - Chronological message ordering
   - Efficient recent message queries
   - Pagination support (future feature)

### Index Maintenance

- B-tree indexes automatically maintained by PostgreSQL
- No manual rebuilding needed for these access patterns
- VACUUM runs automatically to reclaim space

## Performance Characteristics

### Read Operations

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| List all users | O(n) | n = total users, typically small |
| Get user by name | O(1) | Uses unique index |
| Get user by ID | O(1) | Uses primary key |
| List recent N messages | O(n) | n = limit, uses inserted_at index |
| Join messages with users | O(n) | Efficient with proper indexes |

### Write Operations

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| Create user | O(log n) | Index update on name |
| Create message | O(log n) | Index updates on user_id, inserted_at |

### Storage Estimates

**Assumptions**:
- Average username: 20 bytes
- Average message: 200 bytes
- UUID: 16 bytes
- Timestamp: 8 bytes

**Per User**: ~60 bytes (plus indexes)
**Per Message**: ~240 bytes (plus indexes)

**Example**: 1000 users, 100,000 messages = ~24 MB data (excluding indexes)

## Backup and Recovery

### Recommended Strategy

1. **Daily Full Backups**: PostgreSQL pg_dump
2. **WAL Archiving**: Point-in-time recovery
3. **Replication**: Streaming replication for high availability

### Seed Data

For development/testing:

```elixir
# priv/repo/seeds.exs
alias Chatter.{Accounts, Chat, Repo}

# Create test users
{:ok, alice} = Accounts.create_user(%{name: "alice"})
{:ok, bob} = Accounts.create_user(%{name: "bob"})
{:ok, charlie} = Accounts.create_user(%{name: "charlie"})

# Create test messages
Chat.create_message(alice, %{content: "Hello everyone!"})
Chat.create_message(bob, %{content: "Hi Alice!"})
Chat.create_message(charlie, %{content: "Hey folks!"})
```

Run with: `mix run priv/repo/seeds.exs`

## Future Enhancements

### Potential Schema Changes

1. **User Authentication**:
   - Add `password_hash` to users
   - Add `email` field

2. **Multiple Chat Rooms**:
   - Add `rooms` table
   - Add `room_id` to messages
   - Many-to-many users_rooms

3. **Message Reactions**:
   - Add `reactions` table
   - Link to messages and users

4. **User Profiles**:
   - Add `avatar_url` to users
   - Add `bio` field

5. **Message Editing**:
   - Add `edited_at` to messages
   - Track edit history in separate table

6. **Soft Deletes**:
   - Add `deleted_at` to users and messages
   - Filter out in queries

### Scalability Considerations

**Current Design**: Single PostgreSQL instance, suitable for 1000s of users

**Future Scaling**:
- Add read replicas for query distribution
- Partition messages table by time range (e.g., monthly)
- Add Redis for caching user list and presence
- Consider TimescaleDB for time-series message data

## Database Configuration

### Development

```elixir
# config/dev.exs
config :chatter, Chatter.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "chatter_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

### Test

```elixir
# config/test.exs
config :chatter, Chatter.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "chatter_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
```

### Production

```elixir
# config/runtime.exs
config :chatter, Chatter.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: maybe_ipv6
```

## Maintenance Commands

```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Rollback last migration
mix ecto.rollback

# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Check migration status
mix ecto.migrations

# Generate migration
mix ecto.gen.migration migration_name
```
