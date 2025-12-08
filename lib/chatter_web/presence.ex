defmodule ChatterWeb.Presence do
  @moduledoc """
  Provides presence tracking for online users in the chat.
  """
  use Phoenix.Presence,
    otp_app: :chatter,
    pubsub_server: Chatter.PubSub
end
