# Testing Strategy

## Overview

This document outlines the comprehensive testing strategy for the Chatter application, covering unit tests, integration tests, and manual testing procedures.

## Testing Philosophy

1. **Test-Driven Development**: Write tests before or alongside implementation
2. **Comprehensive Coverage**: Target >80% code coverage
3. **Fast Feedback**: Tests should run quickly for rapid iteration
4. **Isolated Tests**: Each test should be independent and reproducible
5. **Meaningful Tests**: Focus on behavior, not implementation details

## Test Levels

### 1. Unit Tests (Context Layer)

**Purpose**: Test business logic in isolation

**Location**: `test/chatter/`

#### Accounts Context Tests

**File**: `test/chatter/accounts_test.exs`

**Test Cases**:
```elixir
describe "list_users/0" do
  test "returns all users ordered by name"
  test "returns empty list when no users exist"
end

describe "get_user!/1" do
  test "returns user when exists"
  test "raises Ecto.NoResultsError when user not found"
end

describe "get_user_by_name/1" do
  test "returns user when name matches"
  test "returns nil when name not found"
  test "is case-sensitive"
end

describe "create_user/1" do
  test "creates user with valid attributes"
  test "returns error with invalid name (too short)"
  test "returns error with invalid name (too long)"
  test "returns error with invalid name format (special chars)"
  test "returns error with duplicate name"
end

describe "get_or_create_user/1" do
  test "returns existing user if name exists"
  test "creates new user if name doesn't exist"
  test "returns error with invalid name"
end
```

**Setup**:
```elixir
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chatter.Repo)
end
```

#### Chat Context Tests

**File**: `test/chatter/chat_test.exs`

**Test Cases**:
```elixir
describe "list_messages/0" do
  test "returns all messages ordered by inserted_at"
  test "preloads user associations"
  test "returns empty list when no messages exist"
end

describe "list_recent_messages/1" do
  test "returns N most recent messages"
  test "defaults to 100 messages"
  test "orders messages chronologically (oldest first)"
  test "preloads user associations"
end

describe "create_message/2" do
  test "creates message with valid content"
  test "associates message with user"
  test "returns error with empty content"
  test "returns error with content too long (>1000 chars)"
  test "sets timestamps correctly"
end

describe "broadcast_message/1" do
  test "broadcasts message to PubSub topic"
  test "preloads user before broadcasting"
end

describe "subscribe/0" do
  test "subscribes current process to chat topic"
end
```

**Setup**:
```elixir
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chatter.Repo)

  {:ok, user} = Chatter.Accounts.create_user(%{name: "test_user"})
  %{user: user}
end
```

### 2. Schema Tests

**Purpose**: Test schema definitions and changesets

#### User Schema Tests

**File**: `test/chatter/accounts/user_test.exs`

**Test Cases**:
```elixir
describe "changeset/2" do
  test "valid changeset with valid attributes"
  test "invalid when name is missing"
  test "invalid when name is empty string"
  test "invalid when name is too short (0 chars)"
  test "invalid when name is too long (>50 chars)"
  test "invalid when name contains spaces"
  test "invalid when name contains special characters"
  test "valid when name contains underscores"
  test "valid when name contains hyphens"
  test "valid when name contains numbers"
  test "unique constraint on name"
end
```

#### Message Schema Tests

**File**: `test/chatter/chat/message_test.exs`

**Test Cases**:
```elixir
describe "changeset/2" do
  test "valid changeset with valid attributes"
  test "invalid when content is missing"
  test "invalid when content is empty string"
  test "invalid when content is too long (>1000 chars)"
  test "valid with content at max length (1000 chars)"
  test "requires user_id association"
end
```

### 3. Integration Tests (LiveView)

**Purpose**: Test user interactions and real-time behavior

**Location**: `test/chatter_web/live/`

#### HomeLive Tests

**File**: `test/chatter_web/live/home_live_test.exs`

**Test Cases**:
```elixir
describe "mount" do
  test "renders home page", %{conn: conn}
  test "displays list of users", %{conn: conn}
  test "shows online/offline status for users", %{conn: conn}
  test "displays join form", %{conn: conn}
end

describe "join event" do
  test "creates new user and redirects to chat", %{conn: conn}
  test "uses existing user and redirects to chat", %{conn: conn}
  test "shows error for invalid username", %{conn: conn}
  test "shows error for duplicate username", %{conn: conn}
  test "trims whitespace from username", %{conn: conn}
end

describe "presence updates" do
  test "updates online users when user joins", %{conn: conn}
  test "updates online users when user leaves", %{conn: conn}
end
```

**Setup**:
```elixir
use ChatterWeb.ConnCase
import Phoenix.LiveViewTest

setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chatter.Repo)
end
```

#### ChatLive Tests

**File**: `test/chatter_web/live/chat_live_test.exs`

**Test Cases**:
```elixir
describe "mount" do
  test "renders chat room with user", %{conn: conn}
  test "displays all messages", %{conn: conn}
  test "displays user list", %{conn: conn}
  test "shows online/offline status", %{conn: conn}
  test "tracks user presence on mount", %{conn: conn}
  test "redirects if user not found", %{conn: conn}
end

describe "send_message event" do
  test "creates and broadcasts new message", %{conn: conn}
  test "clears message form after send", %{conn: conn}
  test "ignores empty messages", %{conn: conn}
  test "trims whitespace from message", %{conn: conn}
end

describe "message broadcasts" do
  test "receives and displays new messages from other users", %{conn: conn}
  test "appends messages to existing list", %{conn: conn}
  test "displays message with username and timestamp", %{conn: conn}
end

describe "presence updates" do
  test "updates online status when user joins", %{conn: conn}
  test "updates online status when user leaves", %{conn: conn}
  test "handles presence_diff messages", %{conn: conn}
end

describe "concurrent users" do
  test "multiple users can send messages simultaneously", %{conn: conn}
  test "all users receive all messages", %{conn: conn}
  test "presence tracks multiple users correctly", %{conn: conn}
end
```

**Setup**:
```elixir
use ChatterWeb.ConnCase
import Phoenix.LiveViewTest

setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chatter.Repo)

  {:ok, user} = Chatter.Accounts.create_user(%{name: "test_user"})
  %{user: user}
end
```

### 4. Presence Tests

**Purpose**: Test Phoenix.Presence behavior

**File**: `test/chatter_web/presence_test.exs`

**Test Cases**:
```elixir
describe "track/3" do
  test "tracks user in presence"
  test "allows tracking same user multiple times (multiple sessions)"
  test "stores metadata correctly"
end

describe "list/1" do
  test "returns all tracked presences"
  test "returns empty map when no presences"
  test "aggregates multiple sessions for same user"
end

describe "untrack/2" do
  test "removes user from presence"
  test "only removes specific session"
end

describe "presence_diff" do
  test "broadcasts when user joins"
  test "broadcasts when user leaves"
  test "includes joins and leaves in diff"
end
```

**Setup**:
```elixir
use ChatterWeb.ConnCase
alias ChatterWeb.Presence

setup do
  topic = "presence:test"
  %{topic: topic}
end
```

### 5. Controller Tests (Error Pages)

**Purpose**: Test error handling

**Files**:
- `test/chatter_web/controllers/error_html_test.exs`
- `test/chatter_web/controllers/error_json_test.exs`

**Test Cases**:
```elixir
test "renders 404.html"
test "renders 500.html"
```

## Test Configuration

### Test Environment Setup

**File**: `config/test.exs`

```elixir
config :chatter, Chatter.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "chatter_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :chatter, ChatterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base...",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
```

### Test Helper

**File**: `test/test_helper.exs`

```elixir
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Chatter.Repo, :manual)
```

### Support Files

**DataCase** (`test/support/data_case.ex`):
- Sets up sandbox for database tests
- Provides helpers for data operations
- Imports Ecto.Changeset and Ecto.Query

**ConnCase** (`test/support/conn_case.ex`):
- Sets up connection for controller/LiveView tests
- Provides helpers for HTTP operations
- Imports Phoenix.ConnTest and Phoenix.LiveViewTest

## Running Tests

### Basic Commands

```bash
# Run all tests
mix test

# Run specific file
mix test test/chatter/accounts_test.exs

# Run specific test
mix test test/chatter/accounts_test.exs:42

# Run with coverage
mix test --cover

# Run only failed tests
mix test --failed

# Run tests matching a pattern
mix test --only focus

# Run tests with trace (no async)
mix test --trace
```

### Test Output

**Success**:
```
.........................
Finished in 0.5 seconds
25 tests, 0 failures
```

**Failure**:
```
  1) test create_user/1 validates name format (Chatter.AccountsTest)
     test/chatter/accounts_test.exs:42
     Assertion with == failed
     code:  assert {:error, changeset} = Accounts.create_user(%{name: "invalid name!"})
     left:  {:error, changeset}
     right: {:ok, %User{}}
```

### Coverage Report

```bash
mix test --cover

# View coverage report
open cover/excoveralls.html
```

**Target**: >80% coverage

## Test Data Factories

### Manual Fixtures

```elixir
defmodule Chatter.AccountsFixtures do
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{name: "user_#{System.unique_integer()}"})
      |> Chatter.Accounts.create_user()

    user
  end
end

defmodule Chatter.ChatFixtures do
  alias Chatter.AccountsFixtures

  def message_fixture(user \\ nil, attrs \\ %{}) do
    user = user || AccountsFixtures.user_fixture()

    {:ok, message} =
      attrs
      |> Enum.into(%{content: "test message"})
      |> then(&Chatter.Chat.create_message(user, &1))

    message
  end
end
```

**Usage**:
```elixir
test "lists messages" do
  user = user_fixture()
  message = message_fixture(user, %{content: "Hello!"})

  assert [^message] = Chat.list_messages()
end
```

## Manual Testing

### Test Scenarios

#### Scenario 1: Basic Chat Flow

1. Start server: `mix phx.server`
2. Open browser to `http://localhost:4000`
3. Verify user list is empty or shows existing users
4. Enter username "alice" and click "Join Chat"
5. Verify redirect to `/chat/:user_id`
6. Verify message list shows (empty or with history)
7. Type message "Hello everyone!" and submit
8. Verify message appears in list
9. Verify message shows username "alice"

**Expected**: All steps succeed without errors

#### Scenario 2: Multiple Users

1. Open two browser windows side-by-side
2. Window 1: Join as "alice"
3. Window 2: Verify "alice" shows as online on home page
4. Window 2: Join as "bob"
5. Window 1: Verify "bob" appears as online in user list
6. Window 1: Send message "Hi Bob!"
7. Window 2: Verify message appears instantly
8. Window 2: Send message "Hi Alice!"
9. Window 1: Verify message appears instantly
10. Close Window 2 (disconnect bob)
11. Window 1: Verify "bob" shows as offline

**Expected**: Real-time updates work correctly

#### Scenario 3: Message Persistence

1. Join chat as "charlie"
2. Send several messages
3. Close browser completely
4. Reopen browser and join as "charlie" again
5. Verify all previous messages are visible

**Expected**: Messages persist across sessions

#### Scenario 4: Username Validation

1. Try to join with empty username
2. Verify error message
3. Try to join with "user name" (space)
4. Verify error message
5. Try to join with "user@name" (special char)
6. Verify error message
7. Try to join with valid username "user_123"
8. Verify successful join

**Expected**: Validation works correctly

#### Scenario 5: Presence Tracking

1. Open 5 browser windows
2. Join with different usernames in each
3. Verify all users show as online in each window
4. Close windows one by one
5. Verify online count decreases in remaining windows
6. Verify offline indicator appears for closed sessions

**Expected**: Presence accurately tracks all users

### Performance Testing

#### Load Test: 10 Concurrent Users

```bash
# Install wrk or similar load testing tool
# Run load test (requires custom script)
```

**Expected**:
- Server responds in <100ms
- No memory leaks
- All messages delivered
- Presence updates correctly

### Browser Compatibility

Test in:
- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

**Expected**: Works in all modern browsers

## Continuous Integration

### Pre-commit Checks

```bash
mix precommit
```

Should run:
1. `mix format --check-formatted`
2. `mix compile --warnings-as-errors`
3. `mix test`

### CI Pipeline (GitHub Actions)

```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:18
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v2
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: 1.19
          otp-version: 28
      - run: mix deps.get
      - run: mix format --check-formatted
      - run: mix compile --warnings-as-errors
      - run: mix test
```

## Test Maintenance

### When Adding New Features

1. Write test cases first (TDD approach)
2. Implement feature
3. Verify all tests pass
4. Add integration tests
5. Update manual test scenarios

### When Fixing Bugs

1. Write failing test that reproduces bug
2. Fix the bug
3. Verify test now passes
4. Ensure no regressions

### Test Code Quality

- Keep tests readable and well-organized
- Use descriptive test names
- Avoid test interdependencies
- Keep setup minimal and relevant
- Use helper functions to reduce duplication

## Debugging Failed Tests

### Common Issues

**Database not cleaned between tests**:
```elixir
# Ensure sandbox mode is set
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chatter.Repo)
end
```

**Async test failures**:
```elixir
# Disable async if tests interfere
use ChatterWeb.ConnCase, async: false
```

**Presence not updating**:
```elixir
# Ensure proper process communication
:timer.sleep(100)  # Allow time for presence sync
```

**PubSub not receiving messages**:
```elixir
# Subscribe in setup
setup do
  Chatter.Chat.subscribe()
  :ok
end
```

## Metrics

### Coverage Goals

- **Overall**: >80%
- **Contexts**: >90%
- **LiveViews**: >80%
- **Schemas**: >90%

### Test Execution Time

- **Total suite**: <5 seconds
- **Unit tests**: <2 seconds
- **Integration tests**: <3 seconds

### Test Count (Estimated)

- Accounts context: ~15 tests
- Chat context: ~12 tests
- User schema: ~10 tests
- Message schema: ~8 tests
- HomeLive: ~8 tests
- ChatLive: ~12 tests
- Presence: ~8 tests
- **Total**: ~75 tests

## Summary

A comprehensive testing strategy ensures:
- Code correctness and reliability
- Confidence when making changes
- Documentation of expected behavior
- Prevention of regressions
- Fast feedback during development

**Key Principle**: If it's not tested, it's broken.
