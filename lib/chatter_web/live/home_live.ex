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
      name == "" -> {:error, "Username cannot be empty"}
      name in online_users -> {:error, "Username '#{name}' is already taken"}
      true -> Accounts.get_or_create_user(name)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="industrial-bg min-h-screen flex items-center justify-center p-6">
      <div class="max-w-6xl w-full">
        <div class="grid md:grid-cols-3 gap-6">
          <%!-- Left column: Branding and username entry --%>
          <div class="md:col-span-2">
            <div class="mb-8">
              <div class="flex items-center gap-3 mb-3">
                <div class="w-1 h-12" style="background: var(--industrial-orange);"></div>
                <h1
                  class="text-6xl font-bold industrial-text-bright"
                  style="font-family: 'IBM Plex Sans', sans-serif; letter-spacing: -0.02em;"
                >
                  Chatter
                </h1>
              </div>
              <p
                class="text-lg industrial-text-dim ml-7"
                style="font-family: 'IBM Plex Mono', monospace; font-size: 0.875rem;"
              >
                // Real-time communication platform
              </p>
            </div>

            <p
              class="text-xl mb-8 ml-7 industrial-text"
              style="font-family: 'IBM Plex Sans', sans-serif; max-width: 600px;"
            >
              A professional-grade chat application built with Phoenix LiveView and Elixir OTP for reliable, real-time messaging.
            </p>

            <%!-- Username Entry Form --%>
            <div class="ml-7 mb-8">
              <.form for={@username_form} phx-submit="set_username" class="space-y-4">
                <div>
                  <label class="block text-sm font-semibold mb-2 industrial-text code-text uppercase tracking-wider">
                    Enter Your Username
                  </label>
                  <input
                    type="text"
                    name="name"
                    placeholder="Choose a username..."
                    autocomplete="off"
                    class="industrial-input w-full max-w-md px-4 py-2.5 text-sm"
                    required
                  />
                </div>
                <button type="submit" class="industrial-button py-2.5 px-8 text-sm">
                  Join Chat →
                </button>
              </.form>
            </div>

            <%!-- Feature highlights --%>
            <div class="grid md:grid-cols-3 gap-4 ml-7 mt-12">
              <div class="industrial-card p-4">
                <div class="flex items-center gap-2 mb-2">
                  <div class="w-2 h-2 rounded-full" style="background: var(--industrial-orange);">
                  </div>
                  <h3 class="text-xs font-semibold industrial-text-bright code-text">
                    REAL_TIME
                  </h3>
                </div>
                <p class="text-xs industrial-text-dim leading-relaxed">
                  Instant message delivery
                </p>
              </div>

              <div class="industrial-card p-4">
                <div class="flex items-center gap-2 mb-2">
                  <div class="w-2 h-2 rounded-full" style="background: var(--industrial-blue);"></div>
                  <h3 class="text-xs font-semibold industrial-text-bright code-text">
                    PRESENCE
                  </h3>
                </div>
                <p class="text-xs industrial-text-dim leading-relaxed">
                  Online user tracking
                </p>
              </div>

              <div class="industrial-card p-4">
                <div class="flex items-center gap-2 mb-2">
                  <div class="w-2 h-2 rounded-full" style="background: var(--industrial-green);">
                  </div>
                  <h3 class="text-xs font-semibold industrial-text-bright code-text">
                    PERSISTENT
                  </h3>
                </div>
                <p class="text-xs industrial-text-dim leading-relaxed">
                  PostgreSQL storage
                </p>
              </div>
            </div>
          </div>
          <%!-- Right column: User list --%>
          <div class="industrial-card p-6">
            <div class="mb-4">
              <div class="flex items-center justify-between mb-3">
                <h2
                  class="text-lg font-bold industrial-text-bright"
                  style="font-family: 'IBM Plex Sans', sans-serif;"
                >
                  Users
                </h2>
                <div class="flex items-center gap-3 text-xs code-text">
                  <div class="flex items-center gap-1">
                    <div class="status-indicator"></div>
                    <span class="industrial-accent-green">{@online_count}</span>
                  </div>
                  <span class="industrial-text-dim">/ {@total_users} total</span>
                </div>
              </div>
              <p class="text-xs industrial-text-dim code-text">
                Real-time user presence
              </p>
            </div>

            <div class="space-y-2 max-h-96 overflow-y-auto">
              <%= if @users == [] do %>
                <p class="text-sm industrial-text-dim code-text italic py-4 text-center">
                  No users yet. Be the first to join!
                </p>
              <% else %>
                <%= for user <- @users do %>
                  <div
                    class="flex items-center gap-3 p-2 rounded transition-all"
                    style="background: var(--industrial-elevated);"
                  >
                    <%= if user.name in @online_users do %>
                      <div class="status-indicator"></div>
                      <span class="text-sm code-text industrial-accent-green font-semibold">
                        {user.name}
                      </span>
                      <span class="text-xs industrial-text-dim ml-auto">online</span>
                    <% else %>
                      <div
                        class="w-2 h-2 rounded-full"
                        style="background: var(--industrial-text-dim); opacity: 0.3;"
                      >
                      </div>
                      <span class="text-sm code-text industrial-text-dim">
                        {user.name}
                      </span>
                      <span class="text-xs industrial-text-dim ml-auto">offline</span>
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <div
          class="mt-6 industrial-surface p-4 border border-opacity-50"
          style="border-color: var(--industrial-border);"
        >
          <div class="flex items-center justify-between text-xs code-text">
            <div class="flex items-center gap-6 industrial-text-dim">
              <span>Phoenix 1.8.2</span>
              <span>LiveView 1.1</span>
              <span>Elixir 1.19</span>
            </div>
            <div class="flex items-center gap-2">
              <div class="status-indicator"></div>
              <span class="industrial-accent-green">System Online</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
