defmodule ChatterWeb.ChatLive do
  use ChatterWeb, :live_view

  alias Chatter.{Accounts, Chat}
  alias ChatterWeb.Presence

  @impl true
  def mount(params, _session, socket) do
    # Get user from params or redirect to home
    user_id = params["user_id"]

    case user_id && Accounts.get_user!(user_id) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/")}

      user ->
        if connected?(socket) do
          Chat.subscribe()
          Phoenix.PubSub.subscribe(Chatter.PubSub, "chat:presence")

          Presence.track(self(), "chat:presence", user.id, %{
            name: user.name,
            joined_at: System.system_time(:second)
          })
        end

        recent_messages = Chat.list_recent_messages(500)
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
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86400)}d ago"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="industrial-bg flex h-screen">
      <div class="industrial-sidebar w-64 flex flex-col">
        <div class="p-4 border-b" style="border-color: var(--industrial-border);">
          <div class="flex items-center gap-2 mb-1">
            <div class="w-1 h-8" style="background: var(--industrial-orange);"></div>
            <h2
              class="text-xl font-bold industrial-text-bright"
              style="font-family: 'IBM Plex Sans', sans-serif;"
            >
              Chatter
            </h2>
          </div>
          <p class="text-xs industrial-text-dim code-text ml-3">
            // chat.session
          </p>
        </div>

        <div class="flex-1 overflow-y-auto p-4">
          <div class="mb-3">
            <div class="flex items-center justify-between mb-2">
              <h3 class="text-xs font-semibold industrial-text-dim code-text uppercase tracking-wider">
                Users
              </h3>
              <div class="flex items-center gap-2 text-xs code-text">
                <div class="flex items-center gap-1">
                  <div class="status-indicator"></div>
                  <span class="industrial-accent-green">{@online_count}</span>
                </div>
                <span class="industrial-text-dim">/ {@total_users}</span>
              </div>
            </div>
            <p class="text-xs industrial-text-dim code-text">
              Real-time presence
            </p>
          </div>
          <div class="space-y-1">
            <%= if @users == [] do %>
              <p class="text-xs industrial-text-dim code-text italic py-2">
                No users yet
              </p>
            <% else %>
              <%= for user <- @users do %>
                <div
                  class="flex items-center gap-2 p-2 rounded transition-all"
                  style="background: var(--industrial-elevated);"
                >
                  <%= if user.name in @online_users do %>
                    <div class="status-indicator"></div>
                    <span class={"text-sm code-text #{if @current_user.name == user.name, do: "industrial-accent-orange font-semibold", else: "industrial-text"}"}>
                      {user.name}
                      <%= if @current_user.name == user.name do %>
                        <span class="text-xs industrial-text-dim ml-1">(you)</span>
                      <% end %>
                    </span>
                  <% else %>
                    <div
                      class="w-2 h-2 rounded-full"
                      style="background: var(--industrial-text-dim); opacity: 0.3;"
                    >
                    </div>
                    <span class="text-sm code-text industrial-text-dim">{user.name}</span>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <div class="p-4 border-t" style="border-color: var(--industrial-border);">
          <button
            phx-click="leave"
            class="w-full py-2 px-4 text-sm font-semibold industrial-text transition-all border code-text"
            style="background: var(--industrial-elevated); border-color: var(--industrial-border);"
            onmouseover="this.style.borderColor='var(--industrial-red)'; this.style.color='var(--industrial-red)'"
            onmouseout="this.style.borderColor='var(--industrial-border)'; this.style.color='var(--industrial-text)'"
          >
            ← Leave Chat
          </button>
        </div>
      </div>

      <div class="flex-1 flex flex-col">
        <div
          class="flex-1 overflow-y-auto p-5 space-y-3"
          id="messages-container"
          phx-hook="ScrollToBottom"
          style="background: var(--industrial-bg);"
        >
          <div id="messages" phx-update="stream">
            <%= for {dom_id, message} <- @streams.messages do %>
              <div
                id={dom_id}
                class="message-fade-in flex gap-3 p-3 rounded transition-all industrial-card"
              >
                <div class="flex-shrink-0">
                  <div
                    class="w-9 h-9 flex items-center justify-center font-bold text-sm border"
                    style="background: var(--industrial-elevated); border-color: var(--industrial-border); color: var(--industrial-orange); font-family: 'IBM Plex Mono', monospace;"
                  >
                    {String.first(message.user.name) |> String.upcase()}
                  </div>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-baseline gap-2 mb-1">
                    <span
                      class="font-semibold industrial-text-bright text-sm"
                      style="font-family: 'IBM Plex Sans', sans-serif;"
                    >
                      {message.user.name}
                    </span>
                    <span class="text-xs industrial-text-dim code-text">
                      {format_timestamp(message.inserted_at)}
                    </span>
                  </div>
                  <p
                    class="break-words leading-relaxed industrial-text text-sm"
                    style="font-family: 'IBM Plex Sans', sans-serif;"
                  >
                    {message.content}
                  </p>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="industrial-surface p-4 border-t" style="border-color: var(--industrial-border);">
          <.form for={@message_form} phx-submit="send_message" class="flex gap-2">
            <input
              id="message-input"
              type="text"
              name="content"
              value=""
              phx-hook="ClearOnSubmit"
              placeholder="type your message here..."
              autocomplete="off"
              class="industrial-input flex-1 px-4 py-2.5 text-sm"
              required
            />
            <button type="submit" class="industrial-button py-2.5 px-6 text-sm">
              Send →
            </button>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
