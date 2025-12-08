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
  Queries in DESC order with limit for efficiency, then reverses for chronological display.
  """
  def list_recent_messages(limit \\ 500) do
    Message
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Returns messages older than the given message ID for infinite scroll.
  """
  def list_messages_before(message_id, limit \\ 100) do
    message = Repo.get!(Message, message_id)

    Message
    |> where([m], m.inserted_at < ^message.inserted_at)
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

**Purpose**: Landing page with link to chat room

**Route**: `/`

**Template**: `home_live.html.heex`

```elixir
defmodule ChatterWeb.HomeLive do
  use ChatterWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
```

**State**: Minimal - just a landing page with navigation to chat

**Notes**:
- Users are not tracked or created until they post their first message in chat
- No user list on home page since users don't exist until first message

#### ChatterWeb.ChatLive

**Purpose**: Main chat room with messages and user list

**Route**: `/chat`

**Template**: `chat_live.html.heex`

```elixir
defmodule ChatterWeb.ChatLive do
  use ChatterWeb, :live_view

  alias Chatter.{Accounts, Chat}
  alias ChatterWeb.Presence

  @presence_topic "presence:lobby"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Chat.subscribe()
      Phoenix.PubSub.subscribe(Chatter.PubSub, @presence_topic)
    end

    messages = Chat.list_recent_messages(500)
    users = Accounts.list_users()
    online_users = get_online_user_ids()

    {:ok,
     socket
     |> assign(:current_user, nil)
     |> assign(:users, users)
     |> assign(:online_users, online_users)
     |> assign(:latest_message_id, get_latest_message_id(messages))
     |> stream(:messages, messages)
     |> assign(:form, to_form(%{"username" => "", "content" => ""}))}
  end

  @impl true
  def handle_event("send_message", %{"username" => username, "content" => content}, socket) do
    # Client-side throttling applied in JavaScript
    username = String.trim(username)
    content = String.trim(content)

    # First message: establish identity
    cond do
      socket.assigns.current_user == nil ->
        # Validate username not in use by online user
        case validate_and_create_user(username, socket.assigns.online_users) do
          {:ok, user} ->
            case Chat.create_message(user, %{content: content}) do
              {:ok, message} ->
                # Track presence for this user
                Presence.track(self(), @presence_topic, user.id, %{
                  user_id: user.id,
                  name: user.name,
                  joined_at: System.system_time(:second)
                })
                Chat.broadcast_message(message)
                {:noreply,
                 socket
                 |> assign(:current_user, user)
                 |> assign(:form, to_form(%{"username" => username, "content" => ""}))}
              {:error, _changeset} ->
                {:noreply, put_flash(socket, :error, "Message too long or invalid")}
            end
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, reason)}
        end

      true ->
        # Subsequent messages from identified user
        case Chat.create_message(socket.assigns.current_user, %{content: content}) do
          {:ok, message} ->
            Chat.broadcast_message(message)
            {:noreply, assign(socket, :form, to_form(%{"username" => username, "content" => ""}))}
          {:error, _changeset} ->
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    # Infinite scroll: load older messages
    oldest_message_id = get_oldest_message_id_from_stream(socket)
    older_messages = Chat.list_messages_before(oldest_message_id, 100)

    {:noreply, stream(socket, :messages, older_messages, at: 0)}
  end

  @impl true
  def handle_event("leave", _params, socket) do
    # Untrack presence and navigate home
    if socket.assigns.current_user do
      Presence.untrack(self(), @presence_topic, socket.assigns.current_user.id)
    end
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    {:noreply,
     socket
     |> stream_insert(:messages, message)
     |> assign(:latest_message_id, message.id)}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    online_users = get_online_user_ids()
    {:noreply, assign(socket, :online_users, online_users)}
  end

  @impl true
  def handle_info(:check_reconnect, socket) do
    # After reconnect, fetch any missed messages
    if socket.assigns.latest_message_id do
      new_messages = Chat.list_messages_after(socket.assigns.latest_message_id)
      {:noreply, stream(socket, :messages, new_messages)}
    else
      {:noreply, socket}
    end
  end

  defp validate_and_create_user(username, online_user_ids) do
    case Accounts.get_user_by_name(username) do
      nil ->
        # New user
        Accounts.create_user(%{name: username})

      user ->
        # Existing user - check if online
        if user.id in online_user_ids do
          {:error, "Username already in use by online user"}
        else
          # Offline user, allow reuse (returning user)
          {:ok, user}
        end
    end
  end

  defp get_online_user_ids do
    @presence_topic
    |> Presence.list()
    |> Map.keys()
    |> MapSet.new()
  end

  defp get_latest_message_id([]), do: nil
  defp get_latest_message_id(messages), do: List.last(messages).id
end
```

**State**:
- `current_user` - The identified user (nil until first message)
- `messages` - Stream of chat messages (LiveView streams)
- `users` - All registered users (stream for larger scale)
- `online_users` - Set of online user IDs
- `latest_message_id` - For reconnection recovery
- `form` - Form for username + message input

**Events**:
- `send_message` - User sends message (validates username on first message only)
- `load_more` - Infinite scroll trigger
- `leave` - User explicitly leaves chat

**Info Messages**:
- `{:new_message, message}` - From PubSub when anyone sends a message
- `%{event: "presence_diff"}` - From Presence when users join/leave
- `:check_reconnect` - Triggered after reconnection to fetch missed messages

**Validation**:
- Minimal validation on submit only
- Client-side throttling to prevent spam

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

Displays chat messages with timestamps and usernames using LiveView streams.

```heex
<div id="messages" phx-update="stream" phx-hook="InfiniteScroll" class="messages">
  <%= if Enum.empty?(@streams.messages) do %>
    <div class="empty-state">
      No messages yet. Start the conversation!
    </div>
  <% end %>

  <div :for={{dom_id, message} <- @streams.messages} id={dom_id} class="message">
    <span class="author"><%= message.user.name %></span>
    <span class="timestamp"><%= relative_time(message.inserted_at) %></span>
    <p class="content"><%= message.content %></p>
  </div>
</div>

<%= if @online_users |> MapSet.size() == 1 do %>
  <p class="text-gray-500 text-sm">
    You're the only one here. Tell your friends about this chat!
  </p>
<% end %>
```

**Helper Function**:
```elixir
defp relative_time(datetime) do
  diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

  cond do
    diff < 60 -> "just now"
    diff < 3600 -> "#{div(diff, 60)} minutes ago"
    diff < 86400 -> "#{div(diff, 3600)} hours ago"
    true -> "#{div(diff, 86400)} days ago"
  end
end
```

### Message Form Component

Input form for username (first message) and message content.

```heex
<.form for={@form} phx-submit="send_message" id="message-form">
  <%= if @current_user == nil do %>
    <.input field={@form[:username]} type="text" placeholder="Enter username..." required />
  <% end %>
  <.input
    field={@form[:content]}
    type="text"
    placeholder="Type a message..."
    phx-hook="MessageThrottle"
    required
  />
  <.button>Send</.button>
</.form>
```

**Client-side Throttling Hook**:
```javascript
// assets/js/app.js
Hooks.MessageThrottle = {
  mounted() {
    let lastSubmit = 0;
    const throttleMs = 500; // 500ms between messages

    this.el.closest('form').addEventListener('submit', (e) => {
      const now = Date.now();
      if (now - lastSubmit < throttleMs) {
        e.preventDefault();
        return false;
      }
      lastSubmit = now;
    });
  }
}
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
