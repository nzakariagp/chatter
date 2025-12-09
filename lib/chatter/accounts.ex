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

  Emits telemetry event [:chatter, :user, :created] on successful creation.

  ## Examples

      iex> create_user(%{name: "alice"})
      {:ok, %User{}}

      iex> create_user(%{name: nil})
      {:error, %Ecto.Changeset{}}

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
  Gets or creates a user by name.

  If a user with the given name exists, returns that user.
  Otherwise, creates a new user with that name.

  This function is safe from race conditions by using the database
  unique constraint on the name field.

  ## Examples

      iex> get_or_create_user("alice")
      {:ok, %User{}}

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

  @doc """
  Gets a single user by ID.

  Returns `nil` if the User does not exist.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user(456)
      nil

  """
  def get_user(id), do: Repo.get(User, id)
end
