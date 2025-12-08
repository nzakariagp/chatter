defmodule Chatter.Accounts do
  @moduledoc """
  The Accounts context for managing users.
  """

  import Ecto.Query, warn: false
  alias Chatter.Repo
  alias Chatter.Accounts.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by name.

  Returns `nil` if the User does not exist.

  ## Examples

      iex> get_user_by_name("alice")
      %User{}

      iex> get_user_by_name("nonexistent")
      nil

  """
  def get_user_by_name(name) when is_binary(name) do
    Repo.get_by(User, name: name)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{name: "alice"})
      {:ok, %User{}}

      iex> create_user(%{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets or creates a user by name.

  If a user with the given name exists, returns that user.
  Otherwise, creates a new user with that name.

  ## Examples

      iex> get_or_create_user("alice")
      {:ok, %User{}}

  """
  def get_or_create_user(name) when is_binary(name) do
    case get_user_by_name(name) do
      nil -> create_user(%{name: name})
      user -> {:ok, user}
    end
  end
end
