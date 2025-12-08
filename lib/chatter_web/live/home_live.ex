defmodule ChatterWeb.HomeLive do
  use ChatterWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="industrial-bg min-h-screen flex items-center justify-center p-6">
      <div class="max-w-5xl w-full">
        <div class="mb-12">
          <div class="mb-8">
            <div class="flex items-center gap-3 mb-3">
              <div
                class="w-1 h-12 industrial-accent-orange"
                style="background: var(--industrial-orange);"
              >
              </div>
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

          <div class="ml-7">
            <.link
              navigate={~p"/chat"}
              class="industrial-button inline-block px-8 py-3 text-sm font-semibold"
            >
              Start Chatting →
            </.link>
          </div>
        </div>

        <div class="grid md:grid-cols-3 gap-4 mt-16">
          <div class="industrial-card p-6">
            <div class="flex items-center gap-2 mb-3">
              <div class="w-2 h-2 rounded-full" style="background: var(--industrial-orange);"></div>
              <h3 class="text-sm font-semibold industrial-text-bright code-text">
                REAL_TIME_SYNC
              </h3>
            </div>
            <p class="text-sm industrial-text-dim leading-relaxed">
              Instant message delivery powered by Phoenix Channels and WebSocket connections.
            </p>
          </div>

          <div class="industrial-card p-6">
            <div class="flex items-center gap-2 mb-3">
              <div class="w-2 h-2 rounded-full" style="background: var(--industrial-blue);"></div>
              <h3 class="text-sm font-semibold industrial-text-bright code-text">
                PRESENCE_TRACKING
              </h3>
            </div>
            <p class="text-sm industrial-text-dim leading-relaxed">
              Monitor online users with Phoenix Presence for distributed state management.
            </p>
          </div>

          <div class="industrial-card p-6">
            <div class="flex items-center gap-2 mb-3">
              <div class="w-2 h-2 rounded-full" style="background: var(--industrial-green);"></div>
              <h3 class="text-sm font-semibold industrial-text-bright code-text">
                PERSISTENT_HISTORY
              </h3>
            </div>
            <p class="text-sm industrial-text-dim leading-relaxed">
              Message persistence with PostgreSQL and Ecto for reliable data storage.
            </p>
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
