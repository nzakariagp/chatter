# Chatter Implementation Plan

## Overview

This document outlines the step-by-step implementation plan for building the Chatter real-time chat application. The plan is organized into phases to ensure incremental progress with testable milestones.

## Development Principles

1. **Test-Driven Development**: Write tests before implementation where practical
2. **Incremental Development**: Build features in small, testable chunks
3. **Continuous Integration**: Ensure `mix precommit` passes after each phase
4. **Documentation**: Update docs as implementation evolves

## Phase 1: Database Foundation

**Goal**: Set up database schema and contexts for data persistence

### Tasks

#### 1.1 Create Users Table and Schema
- [ ] Generate migration: `mix ecto.gen.migration create_users`
- [ ] Implement migration with:
  - UUID primary key
  - Unique name field
  - Timestamps
- [ ] Create `lib/chatter/accounts/user.ex` schema
- [ ] Implement changeset with validations:
  - Required name
  - Name length (1-50 characters)
  - Name format (alphanumeric, underscore, hyphen)
  - Unique constraint
- [ ] Run migration: `mix ecto.migrate`

**Files to create/modify**:
- `priv/repo/migrations/TIMESTAMP_create_users.exs`
- `lib/chatter/accounts/user.ex`

#### 1.2 Create Accounts Context
- [ ] Create `lib/chatter/accounts.ex`
- [ ] Implement functions:
  - `list_users/0`
  - `get_user!/1`
  - `get_user_by_name/1`
  - `create_user/1`
  - `get_or_create_user/1`
- [ ] Write tests in `test/chatter/accounts_test.exs`
  - Test user creation
  - Test unique name constraint
  - Test validations
  - Test queries

**Files to create/modify**:
- `lib/chatter/accounts.ex`
- `test/chatter/accounts_test.exs`

**Verification**:
```bash
mix test test/chatter/accounts_test.exs
```

#### 1.3 Create Messages Table and Schema
- [ ] Generate migration: `mix ecto.gen.migration create_messages`
- [ ] Implement migration with:
  - UUID primary key
  - Content field (text)
  - Foreign key to users
  - Indexes on user_id and inserted_at
  - Timestamps
- [ ] Create `lib/chatter/chat/message.ex` schema
- [ ] Implement changeset with validations:
  - Required content
  - Content length (1-1000 characters)
  - User association
- [ ] Run migration: `mix ecto.migrate`

**Files to create/modify**:
- `priv/repo/migrations/TIMESTAMP_create_messages.exs`
- `lib/chatter/chat/message.ex`

#### 1.4 Create Chat Context
- [ ] Create `lib/chatter/chat.ex`
- [ ] Implement functions:
  - `list_messages/0`
  - `list_recent_messages/1`
  - `create_message/2`
  - `subscribe/0`
  - `broadcast_message/1`
- [ ] Write tests in `test/chatter/chat_test.exs`
  - Test message creation
  - Test user association
  - Test validations
  - Test queries with preloading

**Files to create/modify**:
- `lib/chatter/chat.ex`
- `test/chatter/chat_test.exs`

**Verification**:
```bash
mix test test/chatter/chat_test.exs
```

#### 1.5 Create Seed Data
- [ ] Update `priv/repo/seeds.exs` with sample data
  - 3-5 test users
  - 10-20 test messages
- [ ] Test seeding: `mix ecto.reset`

**Files to create/modify**:
- `priv/repo/seeds.exs`

**Phase 1 Checkpoint**:
```bash
mix test
mix format
mix compile --warnings-as-errors
```

---

## Phase 2: Presence System

**Goal**: Implement Phoenix.Presence for online/offline tracking

### Tasks

#### 2.1 Set Up Presence Module
- [ ] Create `lib/chatter_web/presence.ex`
- [ ] Configure presence with PubSub
- [ ] Add to supervision tree in `lib/chatter/application.ex`

**Files to create/modify**:
- `lib/chatter_web/presence.ex`
- `lib/chatter/application.ex`

#### 2.2 Test Presence Behavior
- [ ] Create `test/chatter_web/presence_test.exs`
- [ ] Test tracking users
- [ ] Test untracking users
- [ ] Test listing presences
- [ ] Test presence diffs

**Files to create/modify**:
- `test/chatter_web/presence_test.exs`

**Verification**:
```bash
mix test test/chatter_web/presence_test.exs
```

**Phase 2 Checkpoint**:
```bash
mix test
```

---

## Phase 3: Home Page (User Landing)

**Goal**: Build landing page where users can see all users and join chat

### Tasks

#### 3.1 Create HomeLive Module
- [ ] Create `lib/chatter_web/live/home_live.ex`
- [ ] Implement `mount/3`:
  - Load all users from database
  - Subscribe to presence topic
  - Initialize form state
- [ ] Implement `handle_event("join", ...)`:
  - Validate username
  - Get or create user
  - Navigate to chat page
- [ ] Implement `handle_info` for presence diffs:
  - Update online users list

**Files to create/modify**:
- `lib/chatter_web/live/home_live.ex`

#### 3.2 Create HomeLive Template
- [ ] Create `lib/chatter_web/live/home_live.html.heex`
- [ ] Display page title
- [ ] Show list of all users with online/offline indicators
- [ ] Add form for entering username
- [ ] Display validation errors if any

**Files to create/modify**:
- `lib/chatter_web/live/home_live.html.heex`

#### 3.3 Add Route
- [ ] Update `lib/chatter_web/router.ex`
- [ ] Add route: `live "/", HomeLive`

**Files to create/modify**:
- `lib/chatter_web/router.ex`

#### 3.4 Test HomeLive
- [ ] Create `test/chatter_web/live/home_live_test.exs`
- [ ] Test mounting and rendering user list
- [ ] Test joining with valid username
- [ ] Test joining with invalid username
- [ ] Test presence updates

**Files to create/modify**:
- `test/chatter_web/live/home_live_test.exs`

**Verification**:
```bash
mix test test/chatter_web/live/home_live_test.exs
mix phx.server
# Visit http://localhost:4000
```

**Phase 3 Checkpoint**:
```bash
mix test
```

---

## Phase 4: Chat Room

**Goal**: Build main chat interface with messages and real-time updates

### Tasks

#### 4.1 Create ChatLive Module
- [ ] Create `lib/chatter_web/live/chat_live.ex`
- [ ] Implement `mount/3`:
  - Get user from params
  - Load recent messages
  - Load all users
  - Subscribe to chat topic
  - Subscribe to presence topic
  - Track current user presence
  - Initialize message form
- [ ] Implement `handle_event("send_message", ...)`:
  - Validate message
  - Create message in database
  - Broadcast message to all clients
  - Reset form
- [ ] Implement `handle_info({:new_message, ...})`:
  - Append message to list
  - Re-render messages
- [ ] Implement `handle_info` for presence diffs:
  - Update online users list
- [ ] Implement `terminate/2`:
  - Cleanup (presence auto-untracks)

**Files to create/modify**:
- `lib/chatter_web/live/chat_live.ex`

#### 4.2 Create ChatLive Template
- [ ] Create `lib/chatter_web/live/chat_live.html.heex`
- [ ] Display current user name
- [ ] Show user list with online/offline indicators
- [ ] Display all messages with:
  - Username
  - Timestamp
  - Content
- [ ] Add message input form
- [ ] Add "Leave" button to return to home

**Files to create/modify**:
- `lib/chatter_web/live/chat_live.html.heex`

#### 4.3 Add Route
- [ ] Update `lib/chatter_web/router.ex`
- [ ] Add route: `live "/chat/:user_id", ChatLive`

**Files to create/modify**:
- `lib/chatter_web/router.ex`

#### 4.4 Test ChatLive
- [ ] Create `test/chatter_web/live/chat_live_test.exs`
- [ ] Test mounting and loading messages
- [ ] Test sending messages
- [ ] Test receiving broadcast messages
- [ ] Test presence tracking
- [ ] Test multiple users in same chat

**Files to create/modify**:
- `test/chatter_web/live/chat_live_test.exs`

**Verification**:
```bash
mix test test/chatter_web/live/chat_live_test.exs
mix phx.server
# Open multiple browser tabs, test real-time updates
```

**Phase 4 Checkpoint**:
```bash
mix test
```

---

## Phase 5: UI Styling

**Goal**: Add minimal CSS for usable interface

### Tasks

#### 5.1 Add Custom Styles
- [ ] Update `assets/css/app.css`
- [ ] Add styles for:
  - User list container
  - Online/offline indicators (green/gray dots)
  - Message list (scrollable)
  - Message items (username, timestamp, content)
  - Input form
  - Buttons
  - Layout (flexbox/grid)

**Files to create/modify**:
- `assets/css/app.css`

#### 5.2 Update Components
- [ ] Use core_components where appropriate
- [ ] Ensure proper semantic HTML
- [ ] Add ARIA labels for accessibility

**Files to create/modify**:
- `lib/chatter_web/live/home_live.html.heex`
- `lib/chatter_web/live/chat_live.html.heex`

**Verification**:
```bash
mix phx.server
# Manually test UI in browser
```

**Phase 5 Checkpoint**:
```bash
mix assets.build
```

---

## Phase 6: Testing & Documentation

**Goal**: Ensure comprehensive test coverage and documentation

### Tasks

#### 6.1 Complete Test Suite
- [ ] Review test coverage
- [ ] Add missing test cases
- [ ] Test edge cases:
  - Empty message submission
  - Duplicate usernames
  - Long messages
  - Special characters in usernames
  - WebSocket disconnects

**Files to create/modify**:
- `test/chatter/**/*_test.exs`

#### 6.2 Integration Testing
- [ ] Test complete user flow:
  - Join chat
  - Send messages
  - See other users join
  - See other users' messages
  - Leave chat
- [ ] Test concurrent users

**Verification**:
```bash
mix test
mix test --cover
```

#### 6.3 Update Documentation
- [ ] Create `docs/ASSUMPTIONS.md` with all assumptions
- [ ] Create `docs/TESTING.md` with testing strategy
- [ ] Update `README.md` with:
  - Project description
  - Requirements
  - Setup instructions
  - Running the app
  - Running tests
  - Technology stack
- [ ] Update `CLAUDE.md` if needed

**Files to create/modify**:
- `docs/ASSUMPTIONS.md`
- `docs/TESTING.md`
- `README.md`

#### 6.4 Code Quality
- [ ] Run formatter: `mix format`
- [ ] Check warnings: `mix compile --warnings-as-errors`
- [ ] Run Credo (if installed): `mix credo`
- [ ] Check for unused dependencies: `mix deps.unlock --unused`

**Phase 6 Checkpoint**:
```bash
mix precommit
```

---

## Phase 7: Final Polish & Deployment Prep

**Goal**: Prepare application for demonstration/deployment

### Tasks

#### 7.1 Manual Testing Checklist
- [ ] User can join chat with valid name
- [ ] User sees all existing users on home page
- [ ] Online/offline status updates in real-time
- [ ] User sees all past messages on joining chat
- [ ] User can send messages
- [ ] All connected users see new messages instantly
- [ ] User list updates when users join/leave
- [ ] Multiple browser tabs work correctly
- [ ] WebSocket reconnection works
- [ ] Page refresh works correctly

#### 7.2 Performance Testing
- [ ] Test with 10+ concurrent users
- [ ] Test with 100+ messages
- [ ] Check memory usage
- [ ] Check database query performance

#### 7.3 Error Handling
- [ ] Test database connection errors
- [ ] Test invalid user IDs in URL
- [ ] Test network disconnects
- [ ] Ensure graceful error messages

#### 7.4 Deployment Documentation
- [ ] Document environment variables needed
- [ ] Document database setup
- [ ] Document asset compilation
- [ ] Create deployment guide

**Files to create/modify**:
- `docs/DEPLOYMENT.md`

**Phase 7 Checkpoint**:
```bash
mix precommit
mix phx.server
# Complete manual testing
```

---

## Implementation Schedule

### Estimated Timeline

| Phase | Estimated Time | Dependencies |
|-------|---------------|--------------|
| Phase 1: Database | 2-3 hours | None |
| Phase 2: Presence | 1 hour | Phase 1 |
| Phase 3: Home Page | 2 hours | Phase 1, 2 |
| Phase 4: Chat Room | 3-4 hours | Phase 1, 2 |
| Phase 5: UI Styling | 1-2 hours | Phase 3, 4 |
| Phase 6: Testing | 2-3 hours | All phases |
| Phase 7: Polish | 1-2 hours | All phases |
| **Total** | **12-17 hours** | |

*Note: Times are estimates and may vary based on experience level*

---

## Development Workflow

### For Each Task:

1. **Create/Update Files**: Implement the required code
2. **Write Tests**: Add corresponding test cases
3. **Run Tests**: `mix test path/to/test_file.exs`
4. **Format Code**: `mix format`
5. **Check Compilation**: `mix compile --warnings-as-errors`
6. **Git Commit**: Commit working code with descriptive message

### After Each Phase:

1. **Run Full Test Suite**: `mix test`
2. **Run Precommit**: `mix precommit`
3. **Manual Testing**: Test in browser if UI changes
4. **Git Commit**: "Complete Phase X: [description]"
5. **Update Progress**: Check off completed tasks

---

## Risk Mitigation

### Potential Issues and Solutions

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Presence not syncing | High | Test presence thoroughly, use proper topic naming |
| Messages out of order | Medium | Rely on database ordering by inserted_at |
| Memory leaks from LiveView | High | Ensure proper cleanup in terminate/2 |
| Race conditions in tests | Medium | Use Ecto sandbox mode, avoid async where needed |
| WebSocket disconnects | Medium | Rely on LiveView auto-reconnection |
| Database migration errors | High | Test migrations on fresh database first |

---

## Success Criteria

The implementation is complete when:

1. ✅ All tests pass: `mix test`
2. ✅ No compilation warnings: `mix compile --warnings-as-errors`
3. ✅ Code is formatted: `mix format --check-formatted`
4. ✅ All requirements met:
   - Users can join chat with a name
   - Chat shows all past messages
   - Real-time message updates work
   - Online/offline status tracks correctly
   - Data persists in PostgreSQL
5. ✅ Manual testing successful with multiple concurrent users
6. ✅ Documentation complete and accurate
7. ✅ Code is clean, readable, and follows conventions

---

## Next Steps After Implementation

1. **Code Review**: Self-review against requirements
2. **Performance Profiling**: Use LiveDashboard to check metrics
3. **Security Audit**: Review for common vulnerabilities
4. **User Acceptance Testing**: Have others test the application
5. **Documentation Review**: Ensure all docs are up-to-date
6. **Deployment**: Follow deployment guide to production

---

## Development Commands Reference

```bash
# Database
mix ecto.create          # Create database
mix ecto.migrate         # Run migrations
mix ecto.rollback        # Rollback last migration
mix ecto.reset           # Drop, create, migrate, seed
mix ecto.gen.migration   # Generate new migration

# Testing
mix test                 # Run all tests
mix test path/to/file    # Run specific test file
mix test --cover         # Run with coverage report
mix test --failed        # Run only failed tests

# Development
mix phx.server           # Start server
iex -S mix phx.server    # Start with IEx shell
mix format               # Format code
mix compile --warnings-as-errors  # Strict compile

# Quality
mix precommit            # Run all checks (custom task)
mix deps.unlock --unused # Remove unused deps
```

---

## Notes

- **Focus on functionality first, then optimize**
- **Write tests as you go, not after**
- **Commit frequently with clear messages**
- **Document assumptions and decisions**
- **Ask questions when uncertain**
- **Keep the UI minimal but functional**
- **Prioritize real-time behavior and correctness**
