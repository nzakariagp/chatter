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
  Emits telemetry event [:chatter, :user, :created] on successful creation.
  Returns {:ok, user} or {:error, changeset}.
  """
  def create_user(attrs \\ %{}) do
    result =
      %User{}
      |> User.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, user} ->
        :telemetry.execute(
          [:chatter, :user, :created],
          %{count: 1},
          %{user_id: user.id}
        )
        {:ok, user}

      error ->
        error
    end
  end

  @doc """
  Gets a single user by ID.
  Returns nil if user doesn't exist.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets or creates a user by name.
  Handles race conditions via database unique constraint.
  Always returns {:ok, user}.
  """
  def get_or_create_user(name) when is_binary(name) do
    case get_user_by_name(name) do
      nil ->
        case create_user(%{name: name}) do
          {:ok, user} -> {:ok, user}
          {:error, changeset} -> handle_create_user_error(changeset, name)
        end

      user ->
        {:ok, user}
    end
  end

  defp handle_create_user_error(changeset, name) do
    if unique_constraint_violated?(changeset, :name) do
      {:ok, get_user_by_name(name)}
    else
      {:error, changeset}
    end
  end

  defp unique_constraint_violated?(changeset, field) do
    Enum.any?(changeset.errors, fn {f, {_msg, opts}} ->
      f == field && Keyword.get(opts, :constraint) == :unique
    end)
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

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_format(:name, ~r/^[a-zA-Z0-9_-]+$/,
      message: "can only contain letters, numbers, underscores, and hyphens"
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

  @topic "chat"
  @default_message_limit Application.compile_env(:chatter, :default_message_limit, 500)
  @pagination_message_limit Application.compile_env(:chatter, :pagination_message_limit, 50)

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
  Default limit is configured via :default_message_limit application config.
  """
  def list_recent_messages(limit \\ @default_message_limit) do
    Message
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Returns messages older than the given message ID for infinite scroll.
  Returns messages ordered from oldest to newest.
  Default limit is configured via :pagination_message_limit application config.
  """
  def list_messages_before(message_id, limit \\ @pagination_message_limit)
      when is_binary(message_id) do
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
  Returns messages created after a given message ID, for reconnection recovery.
  Returns messages ordered from oldest to newest.
  """
  def list_messages_after(message_id) when is_binary(message_id) do
    message = Repo.get!(Message, message_id)

    Message
    |> where([m], m.inserted_at > ^message.inserted_at)
    |> order_by([m], asc: m.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Creates a message for the given user.
  Emits telemetry event [:chatter, :message, :created] on successful creation.
  """
  def create_message(user, attrs \\ %{}) do
    result =
      %Message{}
      |> Message.changeset(Map.put(attrs, :user_id, user.id))
      |> Repo.insert()

    case result do
      {:ok, message} ->
        :telemetry.execute(
          [:chatter, :message, :created],
          %{count: 1},
          %{user_id: user.id}
        )
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Broadcasts a new message to all subscribers.
  """
  def broadcast_message(message) do
    Phoenix.PubSub.broadcast(Chatter.PubSub, @topic, {:new_message, message})
  end

  @doc """
  Subscribes the current process to chat messages.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Chatter.PubSub, @topic)
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

    timestamps(type: :utc_datetime_usec)
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
- Topic: `"chat:presence"`

**Usage Pattern**:
```elixir
# Track user
ChatterWeb.Presence.track(self(), "chat:presence", user.id, %{
  name: user.name,
  joined_at: System.system_time(:second)
})

# List presences
ChatterWeb.Presence.list("chat:presence")

# Handle presence diff
def handle_info(%{event: "presence_diff"}, socket) do
  # Update online users
end
```

### 4. LiveView Modules

#### ChatterWeb.HomeLive

**Purpose**: Landing page with username entry and user list display

**Route**: `/`

**Template**: `home_live.html.heex`

```elixir
defmodule ChatterWeb.HomeLive do
  use ChatterWeb, :live_view

  alias Chatter.Accounts
  alias ChatterWeb.Presence

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Chatter.PubSub, "chat:presence")
    end

    users = Accounts.list_users()
    online_users = get_online_usernames()
    sorted_users = sort_users(users, online_users)

    {:ok,
     socket
     |> assign(:users, sorted_users)
     |> assign(:online_users, online_users)
     |> assign(:total_users, length(users))
     |> assign(:online_count, length(online_users))
     |> assign(:username_form, to_form(%{"name" => ""}))}
  end

  @impl true
  def handle_event("set_username", %{"name" => name}, socket) do
    name = String.trim(name)

    case validate_and_create_user(name, socket.assigns.online_users) do
      {:ok, user} ->
        Presence.track(self(), "chat:presence", user.id, %{
          name: user.name,
          joined_at: System.system_time(:second)
        })

        {:noreply, push_navigate(socket, to: ~p"/chat?user_id=#{user.id}")}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    online_users = get_online_usernames()
    users = Accounts.list_users()
    sorted_users = sort_users(users, online_users)

    {:noreply,
     socket
     |> assign(:users, sorted_users)
     |> assign(:online_users, online_users)
     |> assign(:total_users, length(users))
     |> assign(:online_count, length(online_users))}
  end

  defp get_online_usernames do
    Presence.list("chat:presence")
    |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta.name end)
    |> Enum.sort()
  end

  defp sort_users(users, online_users) do
    Enum.sort_by(users, fn user ->
      is_online = user.name in online_users
      {!is_online, user.name}
    end)
  end

  defp validate_and_create_user(name, online_users) do
    cond do
      name == "" ->
        {:error, "Username cannot be empty"}

      name in online_users ->
        {:error, "Username '#{name}' is currently online. Please choose a different name."}

      true ->
        Accounts.get_or_create_user(name)
    end
  end
end
```

**State**:
- `users` - All registered users from database
- `online_users` - Currently online usernames from presence
- `total_users` - Count of all users
- `online_count` - Count of online users
- `username_form` - Form for username entry

**Features**:
- Real-time user list with online/offline indicators
- Username validation before entry
- Automatic presence tracking on successful username entry
- Dynamic updates when users come online or go offline
- User count displays

#### ChatterWeb.ChatLive

**Purpose**: Main chat room with messages and user list

**Route**: `/chat` (with query parameter `?user_id=<uuid>`)

**Template**: Inline render function

```elixir
defmodule ChatterWeb.ChatLive do
  use ChatterWeb, :live_view

  alias Chatter.{Accounts, Chat}
  alias ChatterWeb.Presence

  @impl true
  def mount(params, _session, socket) do
    with user_id when not is_nil(user_id) <- params["user_id"],
         user when not is_nil(user) <- Accounts.get_user(user_id) do
      if connected?(socket) do
        Chat.subscribe()
        Phoenix.PubSub.subscribe(Chatter.PubSub, "chat:presence")

        Presence.track(self(), "chat:presence", user.id, %{
          name: user.name,
          joined_at: System.system_time(:second)
        })
      end

      recent_messages = Chat.list_recent_messages()
      users = Accounts.list_users()
      online_users = get_online_usernames()
      sorted_users = sort_users(users, online_users)

      {:ok,
       socket
       |> assign(:current_user, user)
       |> assign(:users, sorted_users)
       |> assign(:online_users, online_users)
       |> assign(:total_users, length(users))
       |> assign(:online_count, length(online_users))
       |> assign(:message_form, to_form(%{"content" => ""}))
       |> stream(:messages, recent_messages)}
    else
      _ -> {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    content = String.trim(content)

    if content != "" do
      case Chat.create_message(socket.assigns.current_user, %{content: content}) do
        {:ok, message} ->
          message = Chatter.Repo.preload(message, :user)
          Chat.broadcast_message(message)
          {:noreply, assign(socket, :message_form, to_form(%{"content" => ""}))}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to send message")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("leave", _params, socket) do
    Presence.untrack(self(), "chat:presence", socket.assigns.current_user.id)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    online_users = get_online_usernames()
    users = Accounts.list_users()
    sorted_users = sort_users(users, online_users)

    {:noreply,
     socket
     |> assign(:users, sorted_users)
     |> assign(:online_users, online_users)
     |> assign(:total_users, length(users))
     |> assign(:online_count, length(online_users))}
  end

  defp get_online_usernames do
    Presence.list("chat:presence")
    |> Enum.map(fn {_id, %{metas: [meta | _]}} -> meta.name end)
    |> Enum.sort()
  end

  defp sort_users(users, online_users) do
    Enum.sort_by(users, fn user ->
      is_online = user.name in online_users
      {!is_online, user.name}
    end)
  end

  defp format_timestamp(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86_400)}d ago"
    end
  end
end
```

**State**:
- `current_user` - User struct retrieved from query parameter user_id
- `messages` - Stream of chat messages (LiveView streams)
- `users` - All registered users from database, sorted (online first)
- `online_users` - List of online usernames from presence
- `total_users` - Count of all registered users
- `online_count` - Count of currently online users
- `message_form` - Form for message input

**Events**:
- `send_message` - User sends message
  - Creates message in database
  - Preloads user association
  - Broadcasts to all connected clients
  - Clears input field after successful send
- `leave` - User explicitly leaves chat
  - Untracks presence
  - Navigates to home page

**Info Messages**:
- `{:new_message, message}` - From PubSub when anyone sends a message
- `%{event: "presence_diff"}` - From Presence when users join/leave
  - Updates both user list and online count dynamically

**Features**:
- Real-time message delivery via streams
- Dynamic user list with online/offline indicators
- User count displays (total and online)
- Input field cleared after each message
- Placeholder text for better UX

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
    live "/chat", ChatLive
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

      timestamps(type: :utc_datetime_usec)
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

      timestamps(type: :utc_datetime_usec)
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
