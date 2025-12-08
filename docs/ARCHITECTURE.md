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
**Responsibility**: Landing page showing all users and their status

**State**:
- `users` - List of all users
- `presence` - Map of online user IDs

**Subscriptions**:
- `"presence:lobby"` - Track user presence changes

**Events**:
- `"join_chat"` - User enters name and joins chat

#### ChatterWeb.ChatLive
**Responsibility**: Main chat room interface

**State**:
- `current_user` - Logged-in user struct
- `messages` - List of chat messages
- `users` - List of all users
- `online_users` - Set of online user IDs
- `message_form` - Form changeset for new messages

**Subscriptions**:
- `"chat:lobby"` - New messages
- `"presence:lobby"` - User presence changes

**Events**:
- `"send_message"` - User sends a message
- `"leave_chat"` - User leaves chat room

**Lifecycle**:
1. `mount/3` - Load user, messages, track presence
2. `handle_info/2` - Handle PubSub broadcasts
3. `handle_event/3` - Handle user interactions
4. `terminate/2` - Cleanup on disconnect

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
1. User enters name on HomeLive
2. HomeLive validates name, creates/finds user
3. Redirect to ChatLive with user_id
4. ChatLive mounts, tracks presence
5. Presence broadcasts presence_diff
6. All clients receive update and re-render user list
```

### Sending a Message
```
1. User types message, submits form
2. ChatLive.handle_event("send_message", ...)
3. Chatter.Chat.create_message(user, content)
4. Message persisted to PostgreSQL
5. Chatter.Chat.broadcast_message(message)
6. All ChatLive processes receive {:new_message, message}
7. Each process updates state, LiveView re-renders
```

### User Goes Offline
```
1. WebSocket connection drops
2. LiveView process terminates
3. Presence automatically untracks user
4. Presence broadcasts presence_diff
5. All clients receive update and mark user offline
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

- **Message Load**: O(n) where n = number of messages displayed
- **User List**: O(m) where m = number of total users
- **Real-time Updates**: O(1) per client via PubSub
- **Database Queries**: Minimized via proper preloading and indexing

## Assumptions & Trade-offs

See `docs/ASSUMPTIONS.md` for detailed list.

Key trade-offs:
- Simplicity over advanced features
- Single shared chat room over multiple rooms
- Client-side rendering over server-side optimization
- PostgreSQL over more specialized solutions
