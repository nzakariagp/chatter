# Chatter Architecture

## Overview

Chatter is a real-time chat application demonstrating Elixir/OTP concepts, Phoenix LiveView reactivity, and Ecto persistence. The architecture follows Phoenix 1.8 conventions with a focus on:

1. **Real-time updates** via Phoenix LiveView and PubSub
2. **User presence tracking** using Phoenix.Presence
3. **Data persistence** with Ecto and PostgreSQL
4. **Process supervision** following OTP principles

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Browser Client                       │
│                   (LiveView Socket)                      │
└────────────────────────┬────────────────────────────────┘
                         │ WebSocket
┌────────────────────────┴────────────────────────────────┐
│                  Phoenix Endpoint                        │
│              (ChatterWeb.Endpoint)                       │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────┴────────────────────────────────┐
│                   LiveView Layer                         │
│                                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │         ChatterWeb.ChatLive                      │   │
│  │  - Renders chat UI                               │   │
│  │  - Handles user events (send message, join)      │   │
│  │  - Subscribes to PubSub topics                   │   │
│  └─────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Context   │  │   PubSub    │  │  Presence   │
│   Layer     │  │   Topics    │  │   Tracking  │
│             │  │             │  │             │
│  Chatter.   │  │  "chat:*"   │  │  Phoenix.   │
│  Chat       │  │  "users"    │  │  Presence   │
│  Chatter.   │  │             │  │             │
│  Accounts   │  │             │  │             │
└──────┬──────┘  └─────────────┘  └─────────────┘
       │
       ▼
┌─────────────┐
│    Ecto     │
│    Repo     │
│             │
│  Chatter.   │
│  Repo       │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ PostgreSQL  │
│  Database   │
└─────────────┘
```

## Core Components

### 1. Context Layer (Business Logic)

#### Chatter.Accounts
**Responsibility**: User management and queries

**Functions**:
- `list_users/0` - Get all users
- `get_user/1` - Get user by ID
- `get_user_by_name/1` - Get user by name
- `create_user/1` - Create new user
- `user_exists?/1` - Check if username exists

**Schema**: `Chatter.Accounts.User`
- `id` (UUID)
- `name` (string, unique)
- `inserted_at`, `updated_at` (timestamps)

#### Chatter.Chat
**Responsibility**: Chat message management

**Functions**:
- `list_messages/0` - Get all messages (with user preloaded)
- `list_recent_messages/1` - Get N most recent messages
- `create_message/2` - Create message for user
- `broadcast_message/1` - Broadcast new message via PubSub

**Schema**: `Chatter.Chat.Message`
- `id` (UUID)
- `content` (text)
- `user_id` (foreign key to users)
- `inserted_at`, `updated_at` (timestamps)

### 2. LiveView Layer

#### ChatterWeb.HomeLive
**Responsibility**: Landing page with username entry and user list display

**State**:
- `users` - List of all users (from database)
- `online_users` - List of online usernames (from presence)
- `username_form` - Form for username entry
- `total_users` - Count of all registered users
- `online_count` - Count of currently online users

**Subscriptions**:
- `"chat:presence"` - Track user presence changes in real-time

**Events**:
- `"set_username"` - User enters username, validates, creates/retrieves user
  - Creates user if new
  - Validates username not taken by online user
  - Tracks presence immediately
  - Navigates to chat room on success

#### ChatterWeb.ChatLive
**Responsibility**: Main chat room interface with messaging and user list

**State**:
- `current_user` - User struct (passed from session or URL params)
- `messages` - Stream of chat messages (LiveView streams)
- `users` - List of all users (from database)
- `online_users` - List of online usernames (from presence)
- `message_form` - Form for message input
- `total_users` - Count of all registered users
- `online_count` - Count of currently online users

**Subscriptions**:
- `"chat:lobby"` - New messages from all users
- `"chat:presence"` - User presence changes in real-time

**Events**:
- `"send_message"` - User sends a message
  - Creates and broadcasts message
  - Clears input field after successful send
  - Shows placeholder "type your message here..."
- `"leave_chat"` - User leaves chat room
  - Untracks presence
  - Navigates to home page

**Lifecycle**:
1. `mount/3` - Load current user, messages (500 recent), all users, online users
2. `handle_info/2` - Handle new messages and presence diffs
3. `handle_event/3` - Handle send message and leave events
4. `terminate/2` - Cleanup on disconnect (presence auto-untracks)

### 3. Presence System

#### Phoenix.Presence
**Implementation**: `ChatterWeb.Presence`

**Topic**: `"presence:lobby"`

**Tracking**:
- Track user when they join chat
- Untrack automatically on disconnect
- Broadcast presence_diff to all subscribers

**Metadata**:
- `user_id` - User's database ID
- `name` - User's display name
- `joined_at` - Timestamp

### 4. PubSub System

**Topics**:

1. **`"chat:lobby"`** - Chat message broadcasts
   - Published when: New message created
   - Payload: `{:new_message, message_struct}`
   - Subscribers: All ChatLive processes

2. **`"presence:lobby"`** - User presence updates
   - Published by: Phoenix.Presence automatically
   - Payload: `%Phoenix.Socket.Broadcast{event: "presence_diff", ...}`
   - Subscribers: All HomeLive and ChatLive processes

### 5. Database Schema

**Tables**:

1. **users**
   ```sql
   id           UUID PRIMARY KEY
   name         VARCHAR(255) UNIQUE NOT NULL
   inserted_at  TIMESTAMP NOT NULL
   updated_at   TIMESTAMP NOT NULL
   ```

2. **messages**
   ```sql
   id           UUID PRIMARY KEY
   content      TEXT NOT NULL
   user_id      UUID NOT NULL REFERENCES users(id)
   inserted_at  TIMESTAMP NOT NULL
   updated_at   TIMESTAMP NOT NULL
   ```

**Indexes**:
- `users.name` - Unique index for fast lookup
- `messages.user_id` - For joining with users
- `messages.inserted_at` - For chronological ordering

## Data Flow

### User Joins Chat
```
1. User navigates to HomeLive (landing page)
2. HomeLive mounts, loads all users, subscribes to presence topic
3. User sees list of all users with online/offline indicators
4. User enters username in form on landing page
5. System validates username availability (prevent reuse of online users)
6. User record created/retrieved (offline users can be reused)
7. User tracked in Presence immediately
8. Presence broadcasts presence_diff to all subscribers
9. HomeLive and ChatLive instances receive update and re-render user lists
10. User navigates to ChatLive automatically
11. ChatLive mounts with current user, loads messages and users
```

### Sending a Message
```
1. User types message in chat input field
2. User submits form
3. ChatLive.handle_event("send_message", ...) receives content
4. Chatter.Chat.create_message(current_user, content)
5. Message persisted to PostgreSQL
6. Chatter.Chat.broadcast_message(message)
7. All ChatLive processes receive {:new_message, message}
8. Each process streams message (via LiveView streams)
9. Sender's input field is cleared
10. Placeholder "type your message here..." is restored
```

### User Goes Offline
```
1. User clicks Leave button or WebSocket connection drops
2. If Leave button: untrack presence explicitly, navigate to home
3. If disconnect: LiveView process terminates automatically
4. Presence automatically untracks user
5. Presence broadcasts presence_diff to all subscribers
6. Both HomeLive and ChatLive instances receive update
7. User lists on all pages update to show user as offline
```

### User Reconnects After Disconnect
```
1. WebSocket reconnects, LiveView remounts
2. ChatLive retrieves messages created after latest message in state
3. Missing messages streamed to catch up
4. User continues from where they left off
```

## OTP Supervision Tree

```
Chatter.Application (Supervisor)
├── ChatterWeb.Telemetry (Supervisor)
├── Chatter.Repo (Ecto.Repo)
├── Phoenix.PubSub.PG2 (Chatter.PubSub)
├── ChatterWeb.Presence (Phoenix.Presence)
└── ChatterWeb.Endpoint (Phoenix.Endpoint)
    └── LiveView Processes (dynamic)
```

**Restart Strategies**:
- Application: `:one_for_one` - If one child crashes, restart only that child
- Each LiveView process is isolated; crashes don't affect other users

## Scalability Considerations

### Current Design (Single Node)
- Phoenix.PubSub uses PG2 (process groups)
- Phoenix.Presence uses PubSub for distributed presence
- Works for single-node deployment

### Future Multi-Node Support
- PubSub automatically distributes across nodes
- Presence automatically syncs across nodes
- No code changes needed for basic scaling
- May need Redis for session storage if using sticky sessions

## Security Considerations

1. **No Authentication**: Per requirements, intentional design decision
2. **Input Validation**:
   - Username length limits
   - Message content sanitization
   - XSS prevention via Phoenix.HTML escaping
3. **Rate Limiting**: Not implemented (future consideration)
4. **SQL Injection**: Prevented by Ecto parameterized queries

## Testing Strategy

1. **Context Tests** (`test/chatter/accounts_test.exs`, `test/chatter/chat_test.exs`)
   - Unit tests for business logic
   - Database interactions via sandbox

2. **LiveView Tests** (`test/chatter_web/live/*_test.exs`)
   - Integration tests for UI interactions
   - Presence and PubSub behavior
   - Message rendering and form submissions

3. **Presence Tests** (`test/chatter_web/presence_test.exs`)
   - Track/untrack behavior
   - Presence diff handling

## Performance Characteristics

- **Message Load**: O(n) where n = 500 initial messages, infinite scroll for older
- **User List**: O(m) where m = number of total users (acceptable for expected scale)
  - **Alternative**: GenServer-based cache for larger scale
- **Real-time Updates**: O(1) per client via PubSub
- **Database Queries**: Minimized via proper preloading and indexing
- **LiveView Streams**: Memory-efficient collection handling
- **Client-side Throttling**: Prevents message spam

## Assumptions & Trade-offs

See `docs/ASSUMPTIONS.md` for detailed list.

Key trade-offs:
- Simplicity over advanced features
- Single shared chat room over multiple rooms
- Client-side rendering over server-side optimization
- PostgreSQL over more specialized solutions
