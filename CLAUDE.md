# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chatter is a Phoenix LiveView web application built with Elixir 1.15+. It uses:
- **Phoenix Framework 1.8.2** for web interface
- **Phoenix LiveView 1.1** for real-time, interactive UI
- **Ecto & PostgreSQL** for database operations
- **Tailwind CSS v4** for styling
- **Bandit** web server adapter
- **Tidewave** for development tools integration

## Development Commands

### Initial Setup
```bash
mix setup  # Install dependencies, create DB, setup assets
```

### Running the Application
```bash
mix phx.server              # Start Phoenix server
iex -S mix phx.server       # Start with interactive Elixir shell
```
Visit http://localhost:4000 after starting the server.

### Database Operations
```bash
mix ecto.create            # Create database
mix ecto.migrate           # Run migrations
mix ecto.rollback          # Rollback last migration
mix ecto.reset             # Drop, create, and migrate database
mix ecto.gen.migration migration_name_using_underscores  # Generate migration
```

### Testing
```bash
mix test                   # Run all tests
mix test test/path/to/file_test.exs  # Run specific test file
mix test --failed          # Run previously failed tests
```
Tests use Ecto sandbox mode (`Ecto.Adapters.SQL.Sandbox.mode(Chatter.Repo, :manual)`) for database isolation.

### Asset Management
```bash
mix assets.setup           # Install Tailwind and esbuild
mix assets.build           # Compile assets
mix assets.deploy          # Compile and minify for production
```

### Code Quality
```bash
mix format                 # Format code
mix compile --warnings-as-errors  # Strict compilation
mix deps.unlock --unused   # Remove unused dependencies
mix precommit              # Run all quality checks (compile, format, test)
```
**Always run `mix precommit` before committing changes.**

## Architecture

### Application Structure

The application follows Phoenix 1.8 conventions:

```
lib/
├── chatter/                    # Business logic & contexts
│   ├── application.ex         # OTP application supervisor
│   ├── repo.ex                # Ecto repository
│   └── mailer.ex              # Email functionality
└── chatter_web/               # Web interface layer
    ├── components/            # Reusable UI components
    │   ├── core_components.ex # Standard Phoenix components
    │   └── layouts.ex         # Layout components
    ├── controllers/           # Traditional HTTP controllers
    ├── endpoint.ex            # Phoenix endpoint configuration
    ├── router.ex              # Route definitions
    ├── telemetry.ex           # Metrics and monitoring
    └── gettext.ex             # Internationalization
```

### Key Architectural Patterns

1. **ChatterWeb Module** (`lib/chatter_web.ex`):
   - Defines `__using__/1` macros for controllers, LiveViews, LiveComponents, and HTML modules
   - Centralizes imports via `html_helpers/0` - modify this for app-wide template imports
   - All web modules should `use ChatterWeb, :controller` (or `:live_view`, `:html`, etc.)

2. **Router Scopes** (`lib/chatter_web/router.ex`):
   - `:browser` pipeline: HTML requests with CSRF protection, sessions, flash
   - `:api` pipeline: JSON API requests (currently commented out)
   - Dev routes (LiveDashboard, Swoosh mailbox) only available in development

3. **Application Supervision Tree** (`lib/chatter/application.ex`):
   ```
   Chatter.Supervisor
   ├── ChatterWeb.Telemetry
   ├── Chatter.Repo
   ├── DNSCluster (for distributed systems)
   ├── Phoenix.PubSub
   └── ChatterWeb.Endpoint
   ```

4. **Endpoint Configuration** (`lib/chatter_web/endpoint.ex`):
   - Integrates Tidewave plug when available (development)
   - LiveView socket at `/live`
   - Static files served from `priv/static`
   - Code reloading and LiveDashboard in development only

### Configuration Files

- `config/config.exs` - Base configuration (Ecto repos, endpoint, esbuild, tailwind)
- `config/dev.exs` - Development environment settings
- `config/test.exs` - Test environment settings
- `config/runtime.exs` - Runtime configuration (production secrets, database URLs)
- `config/prod.exs` - Production-specific settings

### Assets Pipeline

- **Tailwind CSS v4**: Uses new import syntax in `assets/css/app.css` with `@import "tailwindcss"` and `@source` directives
- **esbuild**: Bundles JavaScript from `assets/js/app.js`
- **Static assets**: Placed in `priv/static/` (images, fonts, etc.)
- **No external vendor scripts**: All dependencies must be imported into `app.js` or `app.css`

## Claude Code Integration

This project uses the `claude` hex package for enhanced Claude Code integration:

### Configuration
- Hooks defined in `.claude.exs`: compile, format, and unused_deps checks
- MCP server: Tidewave integration
- Custom subagents available in `.claude/agents/`
- Custom slash commands in `.claude/commands/` including:
  - Memory management (`/memory:*`)
  - Dependency management (`/mix:deps*`)
  - Elixir version management (`/elixir:*`)
  - Claude configuration (`/claude:*`)

### Installing/Updating Claude Integration
```bash
mix claude.install          # Setup hooks, subagents, and MCP servers
mix claude.install --with-auto-memories  # Also configure nested memories
```

## HTTP Client

**Always use `Req` library** (already included) for HTTP requests. Do not install HTTPoison, Tesla, or use `:httpc`. Req is the preferred HTTP client for Phoenix applications.

<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->

<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

[usage_rules usage rules](deps/usage_rules/usage-rules.md)
<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
[usage_rules:elixir usage rules](deps/usage_rules/usage-rules/elixir.md)
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
[usage_rules:otp usage rules](deps/usage_rules/usage-rules/otp.md)
<!-- usage_rules:otp-end -->
<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

[igniter usage rules](deps/igniter/usage-rules.md)
<!-- igniter-end -->
<!-- phoenix:ecto-start -->
## phoenix:ecto usage
[phoenix:ecto usage rules](deps/phoenix/usage-rules/ecto.md)
<!-- phoenix:ecto-end -->
<!-- phoenix:elixir-start -->
## phoenix:elixir usage
[phoenix:elixir usage rules](deps/phoenix/usage-rules/elixir.md)
<!-- phoenix:elixir-end -->
<!-- phoenix:html-start -->
## phoenix:html usage
[phoenix:html usage rules](deps/phoenix/usage-rules/html.md)
<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## phoenix:liveview usage
[phoenix:liveview usage rules](deps/phoenix/usage-rules/liveview.md)
<!-- phoenix:liveview-end -->
<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
[phoenix:phoenix usage rules](deps/phoenix/usage-rules/phoenix.md)
<!-- phoenix:phoenix-end -->
<!-- claude-start -->
## claude usage
_Batteries-included Claude Code integration for Elixir projects_

[claude usage rules](deps/claude/usage-rules.md)
<!-- claude-end -->
<!-- claude:subagents-start -->
## claude:subagents usage
[claude:subagents usage rules](deps/claude/usage-rules/subagents.md)
<!-- claude:subagents-end -->
<!-- usage-rules-end -->
