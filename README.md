# Chatter

A real-time chat application demonstrating Elixir/OTP concepts, Phoenix LiveView reactivity, and Ecto persistence.

## Project Overview

Chatter is a demonstration application showcasing:

- **Real-time Communication**: Phoenix LiveView and PubSub for instant message delivery
- **User Presence Tracking**: Phoenix.Presence for online/offline status
- **Data Persistence**: Ecto with PostgreSQL for message and user storage
- **OTP Principles**: Proper supervision trees and process management
- **Reactive UI**: LiveView for seamless, real-time user interface updates

## Features

### Current Features

1. **User Management**
   - Join chat with a username (no authentication required)
   - Automatic user creation on first join
   - Persistent user records

2. **Real-time Chat**
   - Shared chat room for all users
   - Instant message delivery to all connected users
   - Complete message history on join
   - Messages persisted to PostgreSQL

3. **Presence Tracking**
   - Real-time online/offline status for all users
   - Automatic presence updates when users join/leave
   - Visible on both home page and in chat room

### User Flow

1. Visit home page to see all users and their online/offline status
2. Enter a username to join (creates user if doesn't exist)
3. Enter the shared chat room
4. View all past messages
5. Send messages that appear instantly for all users
6. See users join and leave in real-time

## Technology Stack

- **Elixir**: 1.19.4
- **OTP**: 28
- **Phoenix Framework**: 1.8.2
- **Phoenix LiveView**: 1.1.18
- **Ecto**: 3.13+
- **PostgreSQL**: 18.1+
- **Tailwind CSS**: v4
- **Bandit**: Web server

## Requirements

- Elixir 1.19+ and Erlang/OTP 28+
- PostgreSQL 18.1+
- Node.js (for asset compilation)

## Getting Started

### Initial Setup

```bash
# Clone the repository
git clone https://github.com/nzakariagp/chatter.git
cd chatter

# Install dependencies, create database, run migrations
mix setup

# Start the Phoenix server
mix phx.server
```

Or start with an interactive Elixir shell:

```bash
iex -S mix phx.server
```

Now visit [`localhost:4000`](http://localhost:4000) from your browser.

### Database Operations

```bash
mix ecto.create            # Create database
mix ecto.migrate           # Run migrations
mix ecto.rollback          # Rollback last migration
mix ecto.reset             # Drop, create, migrate, and seed
```

### Testing

```bash
mix test                   # Run all tests
mix test --cover           # Run tests with coverage report
mix test test/path/to/file_test.exs  # Run specific test file
```

### Code Quality

```bash
mix format                 # Format code
mix compile --warnings-as-errors  # Strict compilation
mix precommit              # Run all quality checks
```

**Always run `mix precommit` before committing changes.**

## Project Structure

```
lib/
├── chatter/                    # Business logic contexts
│   ├── accounts/              # User management
│   │   └── user.ex           # User schema
│   ├── accounts.ex           # User context API
│   ├── chat/                 # Chat functionality
│   │   └── message.ex        # Message schema
│   └── chat.ex               # Chat context API
│
└── chatter_web/               # Web interface
    ├── live/                 # LiveView modules
    │   ├── home_live.ex      # Landing page
    │   └── chat_live.ex      # Chat room
    ├── presence.ex           # Presence tracking
    └── components/           # Reusable UI components
```

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)**: System architecture, component design, and data flow
- **[TECHNICAL_DESIGN.md](docs/TECHNICAL_DESIGN.md)**: Detailed module design and implementation details
- **[DATABASE_SCHEMA.md](docs/DATABASE_SCHEMA.md)**: Database schema, migrations, and query patterns
- **[IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)**: Step-by-step implementation guide and development workflow
- **[ASSUMPTIONS.md](docs/ASSUMPTIONS.md)**: All design decisions, assumptions, and trade-offs

## Key Design Decisions

### Simplicity First
- Single shared chat room (no multiple rooms or private messaging)
- Minimal UI focused on functionality over aesthetics
- No authentication system (username only)

### Real-time Architecture
- Phoenix LiveView handles WebSocket connections automatically
- Phoenix.Presence provides distributed, fault-tolerant user tracking
- Phoenix.PubSub enables efficient message broadcasting

### Data Model
- UUIDs for primary keys (security and scalability)
- Simple normalized schema (users and messages)
- Indexed for common query patterns

### OTP Principles
- Proper supervision tree with `:one_for_one` strategy
- Each LiveView connection is an isolated process
- Automatic cleanup on disconnection

## Assumptions and Limitations

### Key Assumptions
- Expected scale: 100-1000 concurrent users
- Single-node deployment (though design supports clustering)
- Modern browsers with WebSocket support
- All messages are public to all users

### Current Limitations
- No message editing or deletion
- No private messaging
- No file uploads (text only)
- No search functionality
- No rate limiting

See [ASSUMPTIONS.md](docs/ASSUMPTIONS.md) for complete list and rationale.

## Development

### Claude Code Integration

This project uses the `claude` hex package for enhanced development:

```bash
mix claude.install          # Setup hooks, subagents, and MCP servers
```

Custom slash commands available:
- `/memory:*` - Memory management
- `/mix:deps*` - Dependency management
- `/elixir:*` - Elixir version management
- `/claude:*` - Claude configuration

See [CLAUDE.md](CLAUDE.md) for full details.

### HTTP Client

Use the `Req` library (included) for HTTP requests. Do not install HTTPoison or Tesla.

## Deployment

Ready to run in production? See the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

### Environment Variables

Required for production:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Secret key for encryption (generate with `mix phx.gen.secret`)
- `PHX_HOST` - Hostname for URL generation

### Production Checklist

1. Compile assets: `mix assets.deploy`
2. Run migrations: `mix ecto.migrate`
3. Generate release: `mix release`
4. Set environment variables
5. Start the release

## Testing Real-time Features

To test real-time functionality:

1. Open multiple browser windows/tabs to `http://localhost:4000`
2. Join chat with different usernames in each window
3. Send messages from one window, observe instant updates in others
4. Close a window/tab, observe online status change in remaining windows

## Contributing

This is a demonstration project, but improvements are welcome:

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run `mix precommit` to ensure quality
5. Submit a pull request

## Learn More

### Phoenix Framework
* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

### Phoenix LiveView
* Docs: https://hexdocs.pm/phoenix_live_view
* Guide: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html

### Phoenix Presence
* Docs: https://hexdocs.pm/phoenix/Phoenix.Presence.html
* Guide: https://hexdocs.pm/phoenix/presence.html

## License

This project is available as open source under the terms of the MIT License.

## Acknowledgments

Built with Elixir and Phoenix to demonstrate real-time web application development with OTP principles.
