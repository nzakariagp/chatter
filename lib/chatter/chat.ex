defmodule Chatter.Chat do
  @moduledoc """
  The Chat context for managing messages.
  """

  import Ecto.Query, warn: false
  alias Chatter.Repo
  alias Chatter.Chat.Message

  @topic "chat"
  @default_message_limit Application.compile_env(:chatter, :default_message_limit, 500)
  @pagination_message_limit Application.compile_env(:chatter, :pagination_message_limit, 50)

  @doc """
  Returns the list of all messages, ordered by insertion time (oldest first).

  ## Examples

      iex> list_messages()
      [%Message{}, ...]

  """
  def list_messages do
    Message
    |> order_by([m], asc: m.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Returns the most recent N messages, ordered from oldest to newest.
  Default limit is configured via :default_message_limit application config.

  ## Examples

      iex> list_recent_messages(100)
      [%Message{}, ...]

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
  Returns messages created before a given message ID, for infinite scroll.
  Returns messages ordered from oldest to newest.
  Default limit is configured via :pagination_message_limit application config.

  ## Examples

      iex> list_messages_before(message_id, 50)
      [%Message{}, ...]

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

  ## Examples

      iex> list_messages_after(message_id)
      [%Message{}, ...]

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
  Creates a message.

  Emits telemetry event [:chatter, :message, :created] on successful creation.

  ## Examples

      iex> create_message(user, %{content: "Hello!"})
      {:ok, %Message{}}

      iex> create_message(user, %{content: nil})
      {:error, %Ecto.Changeset{}}

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
  Subscribes to chat messages.

  ## Examples

      iex> subscribe()
      :ok

  """
  def subscribe do
    Phoenix.PubSub.subscribe(Chatter.PubSub, @topic)
  end

  @doc """
  Broadcasts a new message to all subscribers.

  ## Examples

      iex> broadcast_message(message)
      :ok

  """
  def broadcast_message(message) do
    Phoenix.PubSub.broadcast(Chatter.PubSub, @topic, {:new_message, message})
  end
end
