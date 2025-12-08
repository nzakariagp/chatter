defmodule Chatter.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Chatter.Chat` context.
  """

  alias Chatter.AccountsFixtures

  @doc """
  Generate a message.
  """
  def message_fixture(attrs \\ %{}) do
    user = attrs[:user] || AccountsFixtures.user_fixture()

    {:ok, message} =
      attrs
      |> Enum.into(%{
        content: "some content"
      })
      |> then(&Chatter.Chat.create_message(user, &1))

    message
  end
end
