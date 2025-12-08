defmodule Chatter.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Chatter.Accounts` context.
  """

  @doc """
  Generate a unique user name.
  """
  def unique_user_name, do: "user#{System.unique_integer([:positive])}"

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        name: unique_user_name()
      })
      |> Chatter.Accounts.create_user()

    user
  end
end
