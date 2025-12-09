defmodule Chatter.Repo.Migrations.AddCascadeDeleteAndCompositeIndex do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE messages DROP CONSTRAINT messages_user_id_fkey"

    alter table(:messages) do
      modify :user_id, references(:users, on_delete: :delete_all, type: :binary_id)
    end

    create index(:messages, [:user_id, :inserted_at])
  end

  def down do
    drop index(:messages, [:user_id, :inserted_at])

    execute "ALTER TABLE messages DROP CONSTRAINT messages_user_id_fkey"

    alter table(:messages) do
      modify :user_id, references(:users, on_delete: :nothing, type: :binary_id)
    end
  end
end
