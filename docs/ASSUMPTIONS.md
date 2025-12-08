# Assumptions and Design Decisions

## Overview

This document outlines all assumptions made during the design and implementation of the Chatter application, along with rationale for key design decisions.

## Requirements Interpretation

### 1. User Management

**Assumption**: "No authentication required" means:
- Users join with just a username (no password)
- Usernames are persistent (stored in database)
- Same username = same user across sessions
- No email, profile, or personal information collected

**Rationale**: Simplifies implementation while meeting requirement of "a visitor can enter a name to join"

**Trade-off**: No user verification, potential for impersonation

**Alternative Considered**: Anonymous users with session-only names (rejected because requirement says "create user if doesn't exist" implies persistence)

### 2. Chat Room Structure

**Assumption**: Single shared chat room for all users

**Requirements state**:
- "Once joined, they enter a shared chat room with all other users online"
- No mention of multiple rooms or private messaging

**Rationale**: Simplifies implementation, focuses on demonstrating core concepts

**Trade-off**: Cannot support multiple conversation topics or private chats

**Future Enhancement**: Could add multiple rooms or channels

### 3. Message History

**Assumption**: All users see complete message history

**Requirements state**:
- "Show all past chat messages"
- No mention of limiting history or pagination

**Implementation Decision**: Load last 100 messages on mount, but keep all messages available via database query

**Rationale**:
- Prevents memory issues with unlimited message loading
- Provides reasonable history for demonstration
- Easy to adjust limit or add pagination later

**Trade-off**: Very long chat histories won't fully load (future: add "load more" button)

### 4. Online/Offline Status

**Assumption**: Online status is connection-based, not presence-based

**Implementation**: User is "online" when they have an active WebSocket connection in the chat room

**Behavior**:
- User becomes online when they join chat room (not just visiting home page)
- User goes offline when WebSocket disconnects
- No "away" or "idle" status

**Rationale**:
- Phoenix.Presence provides robust connection tracking
- Automatically handles disconnects and network issues
- Fits requirement of "show online/offline status"

**Alternative Considered**: Make users online on home page (rejected because requirement says "enter a shared chat room")

## Technical Decisions

### 5. Database Choice

**Decision**: PostgreSQL 18.1+

**Rationale**:
- Requirement explicitly specifies PostgreSQL
- Excellent Ecto integration
- Robust ACID guarantees
- Built-in UUID support
- Good performance for this use case

**No Alternatives Considered**: Requirement was explicit

### 6. Primary Keys

**Decision**: Use UUIDs (binary_id) for all tables

**Rationale**:
- Prevents ID enumeration attacks
- Better for distributed systems (future-proofing)
- No sequence conflicts
- Standard practice for modern Phoenix apps

**Trade-off**:
- Slightly larger indexes than integer IDs
- Not human-readable
- Acceptable for this application size

**Alternative Considered**: Auto-incrementing integers (rejected for security and scalability)

### 7. Username Validation

**Decision**: Alphanumeric, underscore, hyphen only; 1-50 characters

**Rationale**:
- Prevents special characters that could cause display issues
- Prevents SQL injection attempts (though Ecto already protects)
- Reasonable length limits
- URL-safe characters only

**Implementation**:
```elixir
validate_format(:name, ~r/^[a-zA-Z0-9_-]+$/)
validate_length(:name, min: 1, max: 50)
```

**Trade-off**: Cannot use international characters or spaces

**Future Enhancement**: Could support Unicode usernames with proper sanitization

### 8. Message Length

**Decision**: 1-1000 characters

**Rationale**:
- Prevents empty messages
- Prevents database bloat from extremely long messages
- Typical for chat applications
- Reasonable for demonstration

**Implementation**:
```elixir
validate_length(:content, min: 1, max: 1000)
```

**Trade-off**: Cannot send very long messages

**Alternative Considered**: 5000 character limit (rejected as unnecessary for chat)

### 9. Real-time Communication

**Decision**: Phoenix LiveView with PubSub (not WebSockets directly)

**Rationale**:
- Requirement specifies LiveView
- LiveView handles WebSocket management automatically
- PubSub provides efficient broadcast mechanism
- Simpler than raw WebSocket implementation
- Built-in reconnection and recovery

**No Alternatives Considered**: Requirement explicitly specified LiveView

### 10. Presence Implementation

**Decision**: Phoenix.Presence with single topic "presence:lobby"

**Rationale**:
- Built into Phoenix
- CRDT-based, eventually consistent
- Automatically handles disconnects
- Works across distributed nodes (future-proofing)
- Battle-tested in production apps

**Alternative Considered**: Manual tracking with PubSub (rejected as reinventing the wheel)

### 11. Message Ordering

**Decision**: Order by database `inserted_at` timestamp

**Rationale**:
- Server timestamp is authoritative
- Prevents client clock issues
- Simple and reliable
- Database index on inserted_at for performance

**Trade-off**: Messages might arrive out of order if database clock skews

**Alternative Considered**: Client-side timestamps (rejected as less reliable)

### 12. User List Display

**Decision**: Show all users (not just online ones) on home page

**Requirement**: "Show all users and their online/offline status"

**Rationale**:
- Explicit requirement to show all users
- Demonstrates both database queries and presence tracking
- Shows which users have participated before

**Trade-off**: Could be cluttered with many users (acceptable for demonstration)

## Scalability Assumptions

### 13. Expected Scale

**Assumption**:
- 100-1000 concurrent users
- 1000-10000 total users
- 10000-100000 total messages

**Rationale**: Appropriate for demonstration and small production deployment

**Design Implications**:
- Single database instance sufficient
- No caching layer needed
- Simple queries without optimization
- No partitioning or sharding

**If Scale Exceeds Assumptions**:
- Add read replicas
- Implement Redis caching for user list
- Add pagination for messages
- Consider message archival strategy

### 14. Deployment Model

**Assumption**: Single-node deployment initially

**Rationale**:
- Simpler to set up and demonstrate
- Phoenix.Presence and PubSub work across nodes if needed
- Easy to scale to multiple nodes later

**Design Supports**: Multi-node clustering without code changes

## Security Assumptions

### 15. Input Sanitization

**Decision**: Rely on Phoenix.HTML automatic escaping

**Rationale**:
- Phoenix.HTML escapes all interpolated values by default
- Prevents XSS attacks
- Standard practice for Phoenix applications

**Additional Validation**:
- Length limits on all text fields
- Format validation on usernames
- Ecto parameterized queries prevent SQL injection

**Not Implemented**:
- Rate limiting (could add with Hammer library)
- IP-based blocking
- Content filtering/profanity detection

**Assumption**: This is for demonstration, not production without additional hardening

### 16. No Authentication

**Assumption**: This is acceptable per requirements

**Implications**:
- Anyone can impersonate any username (unless it's taken)
- No user verification
- No password protection
- No session management beyond LiveView socket

**Future Enhancement**: Add optional authentication with email/password

### 17. Data Privacy

**Assumption**: All messages are public to all users

**Implications**:
- No private messaging
- No message deletion
- No editing messages
- Chat history is permanent

**Rationale**: Requirement doesn't mention privacy features

## UI/UX Assumptions

### 18. Minimal UI

**Requirement**: "A minimal UI is fine as long as it demonstrates proper flow and updates"

**Interpretation**:
- Focus on functionality, not aesthetics
- Use basic HTML/CSS
- Leverage Phoenix core_components where appropriate
- No JavaScript beyond LiveView's built-in JS
- No external UI frameworks (no need for React, Vue, etc.)

**Design Approach**:
- Clean, readable layout
- Clear visual indicators for online/offline
- Obvious user interactions (buttons, forms)
- Responsive but not mobile-optimized

### 19. Browser Support

**Assumption**: Modern browsers with WebSocket support

**Supported**:
- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)

**Not Tested**:
- Internet Explorer
- Older mobile browsers
- Text-based browsers

**Rationale**: WebSocket requirement implies modern browser

### 20. Accessibility

**Basic Accessibility**:
- Semantic HTML
- Proper heading hierarchy
- Form labels

**Not Implemented**:
- Full ARIA support
- Keyboard navigation optimization
- Screen reader testing
- High contrast mode

**Assumption**: Accessibility is not a primary requirement for this demonstration

## Testing Assumptions

### 21. Test Coverage Goals

**Target**: >80% code coverage

**Focus Areas**:
- Business logic (contexts)
- LiveView interactions
- Presence behavior
- Database operations

**Lower Priority**:
- UI rendering details
- Error page rendering
- Configuration loading

### 22. Testing Environment

**Assumption**: Tests run in isolation using Ecto.Adapters.SQL.Sandbox

**Implications**:
- Each test gets clean database
- Tests can run in parallel
- No shared state between tests

**Configuration**: Set in `config/test.exs`

### 23. Integration Testing

**Decision**: Focus on LiveView integration tests over E2E

**Rationale**:
- LiveView tests can verify full user flow
- Faster than browser-based E2E
- More maintainable
- Sufficient for requirements

**Not Implemented**: Cypress or Playwright tests (acceptable for demonstration)

## Performance Assumptions

### 24. Message Load Strategy

**Decision**: Load last 100 messages on mount

**Rationale**:
- Balances history visibility with performance
- Prevents memory issues with thousands of messages
- Fast initial page load
- Sufficient for demonstration

**Alternative**: Could implement infinite scroll or pagination

### 25. Database Query Optimization

**Implemented**:
- Indexes on foreign keys
- Indexes on timestamp columns
- Proper use of `preload` to avoid N+1 queries

**Not Implemented**:
- Database caching
- Materialized views
- Query result caching

**Assumption**: Query performance is adequate for expected scale

### 26. Real-time Update Performance

**Assumption**: LiveView and PubSub can handle expected message volume

**Expected Load**:
- 1-10 messages per second
- 100-1000 concurrent connections

**Rationale**: Well within Phoenix's proven capabilities

**If Load Exceeds**: Consider rate limiting per user

## Data Persistence Assumptions

### 27. Message Retention

**Assumption**: Keep all messages indefinitely

**Rationale**:
- Requirement says "persist in Postgres"
- No retention policy mentioned
- Acceptable for demonstration

**Future Enhancement**: Could add archival or deletion policy

### 28. User Deletion

**Assumption**: Users are never deleted

**Foreign Key**: `on_delete: :nothing` preserves messages if user deleted

**Rationale**:
- No user management features required
- Preserve chat history
- Simple implementation

**Future Enhancement**: Could add user management with soft deletes

### 29. Backup Strategy

**Not Implemented**: Automated backups

**Assumption**: For demonstration, manual backups sufficient

**Production Recommendation**:
- Daily full backups
- WAL archiving
- Point-in-time recovery

## OTP Assumptions

### 30. Supervision Strategy

**Decision**: `:one_for_one` restart strategy

**Rationale**:
- Each child process is independent
- Failure of one shouldn't affect others
- Standard for Phoenix applications

**Supervised Processes**:
- Repo (database connection pool)
- PubSub (message broker)
- Presence (user tracking)
- Endpoint (web server)

### 31. Process Architecture

**Assumption**: Each LiveView connection is a separate process

**Implications**:
- Isolation between users
- One user's crash doesn't affect others
- Memory per connection (acceptable overhead)
- Automatically cleaned up on disconnect

**Rationale**: This is LiveView's standard behavior

## Development Workflow Assumptions

### 32. Code Quality Tools

**Required**:
- `mix format` - Code formatting
- `mix compile --warnings-as-errors` - Strict compilation
- `mix test` - Test suite

**Defined in**: `mix precommit` task (if implemented)

### 33. Documentation Standards

**Assumption**: Living documentation is key

**Approach**:
- Architecture documented in `docs/ARCHITECTURE.md`
- Technical design in `docs/TECHNICAL_DESIGN.md`
- Database schema in `docs/DATABASE_SCHEMA.md`
- Implementation plan in `docs/IMPLEMENTATION_PLAN.md`
- Assumptions in `docs/ASSUMPTIONS.md` (this file)

**Rationale**: Demonstrates thought process and decision-making

### 34. Git Workflow

**Assumption**: Feature-based commits

**Approach**:
- Commit after each working feature
- Clear, descriptive commit messages
- Commit passing code only

**Rationale**: Shows development progression

## Constraints and Limitations

### 35. Known Limitations

1. **No message editing**: Messages cannot be edited after sending
2. **No message deletion**: Messages cannot be deleted
3. **No private messaging**: All messages are public
4. **No multiple rooms**: Single shared chat room only
5. **No file uploads**: Text-only messages
6. **No emojis**: Basic text only (unless using Unicode)
7. **No notifications**: No browser notifications for new messages
8. **No typing indicators**: Cannot see when others are typing
9. **No read receipts**: Cannot see who has read messages
10. **No search**: Cannot search message history

**Rationale**: These are not required for the demonstration and would add significant complexity

### 36. Future Enhancements

If expanding beyond demonstration:

1. **User Authentication**: Email/password login
2. **User Profiles**: Avatars, bios, preferences
3. **Multiple Rooms**: Topic-based channels
4. **Private Messaging**: Direct messages between users
5. **Message Editing**: Edit within time limit
6. **Message Reactions**: Emoji reactions to messages
7. **File Sharing**: Image and file uploads
8. **Search**: Full-text search of messages
9. **Notifications**: Browser and email notifications
10. **Mobile App**: Native mobile clients
11. **Admin Panel**: User management, moderation
12. **Rate Limiting**: Prevent spam and abuse

## Summary

This document captures all assumptions and decisions made during the design phase. Key themes:

1. **Simplicity**: Prefer simple solutions that meet requirements
2. **Standards**: Follow Phoenix and Elixir best practices
3. **Functionality**: Prioritize working features over polish
4. **Scalability**: Design allows for growth without rewrites
5. **Demonstration**: Focus on showing OTP, LiveView, and Ecto concepts

All assumptions are documented to make explicit what might otherwise be implicit, facilitating discussion and potential adjustments.
