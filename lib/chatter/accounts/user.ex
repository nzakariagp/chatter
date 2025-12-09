defmodule Chatter.Accounts.User do
  @moduledoc """
  Schema for user accounts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :name, :string

    timestamps(type: :utc_datetime_usec)
  end

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
