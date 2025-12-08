# Chatter Technical Design

## Technology Stack

### Runtime
- **Elixir**: 1.19.4
- **OTP**: 28
- **Phoenix**: 1.8.2
- **Phoenix LiveView**: 1.1.18
- **Ecto**: 3.13+
- **PostgreSQL**: 18.1+

### Dependencies
- `phoenix_ecto` - Ecto integration for Phoenix
- `postgrex` - PostgreSQL driver
- `phoenix_html` - HTML helpers
- `phoenix_live_view` - Real-time UI
- `phoenix_live_dashboard` - Development tools
- `telemetry_metrics` - Application metrics
- `telemetry_poller` - System metrics
- `gettext` - Internationalization
- `jason` - JSON parser
- `bandit` - HTTP server

## Module Structure

```
lib/
├── chatter/
│   ├── application.ex           # OTP Application & Supervisor
│   ├── repo.ex                   # Ecto Repository
│   │
│   ├── accounts/                 # User management context
│   │   └── user.ex              # User schema
│   ├── accounts.ex              # Accounts context API
│   │
│   ├── chat/                     # Chat context
│   │   └── message.ex           # Message schema
│   └── chat.ex                  # Chat context API
│
└── chatter_web/
    ├── endpoint.ex              # Phoenix Endpoint
    ├── router.ex                # Routes
    ├── telemetry.ex             # Telemetry setup
    │
    ├── live/                     # LiveView modules
    │   ├── home_live.ex         # Landing page
    │   └── chat_live.ex         # Chat room
    │
    ├── presence.ex              # Presence tracking
    │
    └── components/
        ├── core_components.ex   # Reusable components
        └── layouts.ex           # Layout components
```

## Detailed Module Design

### 1. Chatter.Accounts Context

#### Purpose
Encapsulates all user-related business logic and database operations.

#### Module: `Chatter.Accounts`

```elixir
defmodule Chatter.Accounts do
  @moduledoc """
  The Accounts context handles user management.
  """

  import Ecto.Query
  alias Chatter.Repo
  alias Chatter.Accounts.User

  @doc """
  Returns the list of all users.
  """
  def list_users do
    Repo.all(from u in User, order_by: [asc: u.name])
  end

  @doc """
  Gets a single user by ID.
  Raises Ecto.NoResultsError if user doesn't exist.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by name (case-sensitive).
  Returns nil if not found.
  """
  def get_user_by_name(name) do
    Repo.get_by(User, name: name)
  end

  @doc """
  Creates a user with the given attributes.
  Returns {:ok, user} or {:error, changeset}.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets or creates a user by name.
  Returns {:ok, user} or {:error, changeset}.
  """
  def get_or_create_user(name) do
    case get_user_by_name(name) do
      nil -> create_user(%{name: name})
      user -> {:ok, user}
    end
  end
end
```

#### Schema: `Chatter.Accounts.User`

```elixir
defmodule Chatter.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :name, :string

    has_many :messages, Chatter.Chat.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_format(:name, ~r/^[a-zA-Z0-9_-]+$/,
      message: "must contain only letters, numbers, underscores, and hyphens"
    )
    |> unique_constraint(:name)
  end
end
```

**Validations**:
- Name is required
- Name length: 1-50 characters
- Name format: alphanumeric, underscore, hyphen only
- Name must be unique (database constraint)

### 2. Chatter.Chat Context

#### Purpose
Encapsulates chat message operations and broadcasting.

#### Module: `Chatter.Chat`

```elixir
defmodule Chatter.Chat do
  @moduledoc """
  The Chat context handles messages and real-time communication.
  """

  import Ecto.Query
  alias Chatter.Repo
  alias Chatter.Chat.Message
  alias Chatter.Accounts.User

  @pubsub Chatter.PubSub
  @topic "chat:lobby"

  @doc """
  Returns all messages with users preloaded, ordered chronologically.
  """
  def list_messages do
    Message
    |> order_by([m], asc: m.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Returns the N most recent messages.
  """
  def list_recent_messages(limit \\ 100) do
    Message
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Creates a message for the given user.
  """
  def create_message(%User{} = user, attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  @doc """
  Broadcasts a new message to all subscribers.
  """
  def broadcast_message(%Message{} = message) do
    message = Repo.preload(message, :user)
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:new_message, message})
  end

  @doc """
  Subscribes the current process to chat messages.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end
end
```

#### Schema: `Chatter.Chat.Message`

```elixir
defmodule Chatter.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :content, :string

    belongs_to :user, Chatter.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content])
    |> validate_required([:content])
    |> validate_length(:content, min: 1, max: 1000)
  end
end
```

**Validations**:
- Content is required
- Content length: 1-1000 characters

### 3. Phoenix Presence

#### Module: `ChatterWeb.Presence`

```elixir
defmodule ChatterWeb.Presence do
  @moduledoc """
  Provides presence tracking for chat users.
  """
  use Phoenix.Presence,
    otp_app: :chatter,
    pubsub_server: Chatter.PubSub
end
```

**Configuration**:
- OTP app: `:chatter`
- PubSub server: `Chatter.PubSub`
- Topic: `"presence:lobby"`

**Usage Pattern**:
```elixir
# Track user
ChatterWeb.Presence.track(self(), "presence:lobby", user.id, %{
  user_id: user.id,
  name: user.name,
  joined_at: System.system_time(:second)
})

# List presences
ChatterWeb.Presence.list("presence:lobby")

# Handle presence diff
def handle_info(%{event: "presence_diff"}, socket) do
  # Update online users
end
```

### 4. LiveView Modules

#### ChatterWeb.HomeLive

**Purpose**: Landing page showing all users and join functionality

**Route**: `/`

**Template**: `home_live.html.heex`

```elixir
defmodule ChatterWeb.HomeLive do
  use ChatterWeb, :live_view

  alias Chatter.Accounts
  alias ChatterWeb.Presence

  @presence_topic "presence:lobby"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Chatter.PubSub, @presence_topic)
    end

    users = Accounts.list_users()
    presences = get_online_user_ids()

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:online_users, presences)
     |> assign(:name, "")
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("join", %{"name" => name}, socket) do
    name = String.trim(name)

    case Accounts.get_or_create_user(name) do
      {:ok, user} ->
        {:noreply, push_navigate(socket, to: ~p"/chat/#{user.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        error = translate_errors(changeset)
        {:noreply, assign(socket, :error, error)}
    end
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    online_users = get_online_user_ids()
    {:noreply, assign(socket, :online_users, online_users)}
  end

  defp get_online_user_ids do
    @presence_topic
    |> Presence.list()
    |> Map.keys()
    |> MapSet.new()
  end

  defp translate_errors(changeset) do
    # Extract first error message
  end
end
```

**State**:
- `users` - All registered users
- `online_users` - Set of online user IDs (from Presence)
- `name` - Form input value
- `error` - Validation error message

**Events**:
- `join` - User submits name to join chat

#### ChatterWeb.ChatLive

**Purpose**: Main chat room with messages and user list

**Route**: `/chat/:user_id`

**Template**: `chat_live.html.heex`

```elixir
defmodule ChatterWeb.ChatLive do
  use ChatterWeb, :live_view

  alias Chatter.{Accounts, Chat}
  alias ChatterWeb.Presence

  @presence_topic "presence:lobby"

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    user = Accounts.get_user!(user_id)

    if connected?(socket) do
      Chat.subscribe()
      Phoenix.PubSub.subscribe(Chatter.PubSub, @presence_topic)

      {:ok, _} = Presence.track(self(), @presence_topic, user.id, %{
        user_id: user.id,
        name: user.name,
        joined_at: System.system_time(:second)
      })
    end

    messages = Chat.list_recent_messages(100)
    users = Accounts.list_users()
    online_users = get_online_user_ids()

    {:ok,
     socket
     |> assign(:current_user, user)
     |> assign(:messages, messages)
     |> assign(:users, users)
     |> assign(:online_users, online_users)
     |> assign_new(:form, fn ->
       to_form(%{"content" => ""})
     end)}
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    content = String.trim(content)

    case Chat.create_message(socket.assigns.current_user, %{content: content}) do
      {:ok, message} ->
        Chat.broadcast_message(message)
        {:noreply, assign(socket, :form, to_form(%{"content" => ""}))}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    {:noreply, update(socket, :messages, fn messages -> messages ++ [message] end)}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    online_users = get_online_user_ids()
    {:noreply, assign(socket, :online_users, online_users)}
  end

  defp get_online_user_ids do
    @presence_topic
    |> Presence.list()
    |> Map.keys()
    |> MapSet.new()
  end
end
```

**State**:
- `current_user` - The logged-in user
- `messages` - List of chat messages (with user preloaded)
- `users` - All registered users
- `online_users` - Set of online user IDs
- `form` - Form for message input

**Events**:
- `send_message` - User sends a new message

**Info Messages**:
- `{:new_message, message}` - From PubSub when anyone sends a message
- `%{event: "presence_diff"}` - From Presence when users join/leave

### 5. Router Configuration

```elixir
defmodule ChatterWeb.Router do
  use ChatterWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ChatterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", ChatterWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/chat/:user_id", ChatLive
  end

  # Development routes
  if Application.compile_env(:chatter, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ChatterWeb.Telemetry
    end
  end
end
```

## Database Design

### Migration: Create Users

```elixir
defmodule Chatter.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:name])
  end
end
```

### Migration: Create Messages

```elixir
defmodule Chatter.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:user_id])
    create index(:messages, [:inserted_at])
  end
end
```

## UI Components

### User List Component

Displays all users with online/offline indicators.

```heex
<div class="user-list">
  <h3>Users</h3>
  <ul>
    <%= for user <- @users do %>
      <li>
        <span class={if user.id in @online_users, do: "online", else: "offline"}>
          ●
        </span>
        <%= user.name %>
      </li>
    <% end %>
  </ul>
</div>
```

### Message List Component

Displays chat messages with timestamps and usernames.

```heex
<div class="messages">
  <%= for message <- @messages do %>
    <div class="message">
      <span class="author"><%= message.user.name %></span>
      <span class="timestamp"><%= format_timestamp(message.inserted_at) %></span>
      <p class="content"><%= message.content %></p>
    </div>
  <% end %>
</div>
```

### Message Form Component

Input form for sending new messages.

```heex
<.form for={@form} phx-submit="send_message">
  <.input field={@form[:content]} type="text" placeholder="Type a message..." />
  <.button>Send</.button>
</.form>
```

## Error Handling

### User Join Errors
- Invalid username format → Show error message on form
- Username too long/short → Show error message on form
- Database error → Show generic error message

### Message Send Errors
- Empty message → Silently ignore
- Message too long → Show error (or prevent via maxlength)
- Database error → Log error, show user-friendly message

### Connection Errors
- WebSocket disconnect → Presence automatically untracks
- Reconnection → LiveView automatically remounts and resubscribes

## Performance Optimizations

1. **Message Limiting**: Only load most recent 100 messages on mount
2. **Efficient Queries**: Use indexes and preloading
3. **Minimal Re-renders**: LiveView diffs only changed content
4. **PubSub**: O(1) broadcast to all subscribers
5. **Presence**: Efficient CRDT-based presence tracking

## Testing Approach

See `docs/TESTING.md` for detailed testing strategy.

## Deployment Considerations

1. **Database**: Ensure PostgreSQL 18.1+ is available
2. **Environment Variables**: Configure DATABASE_URL, SECRET_KEY_BASE
3. **Migrations**: Run `mix ecto.migrate` before starting server
4. **Assets**: Compile with `mix assets.deploy`
5. **Release**: Use `mix release` for production deployment
