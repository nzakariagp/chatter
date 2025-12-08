defmodule Chatter.AccountsTest do
  use Chatter.DataCase

  alias Chatter.Accounts

  describe "users" do
    alias Chatter.Accounts.User

    import Chatter.AccountsFixtures

    @invalid_attrs %{name: nil}

    test "list_users/0 returns all users" do
      user = user_fixture()
      users = Accounts.list_users()
      assert length(users) == 1
      assert Enum.at(users, 0).id == user.id
      assert Enum.at(users, 0).name == user.name
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      fetched_user = Accounts.get_user!(user.id)
      assert fetched_user.id == user.id
      assert fetched_user.name == user.name
    end

    test "get_user_by_name/1 returns the user with given name" do
      user = user_fixture(%{name: "alice"})
      assert Accounts.get_user_by_name("alice").id == user.id
    end

    test "get_user_by_name/1 returns nil when user does not exist" do
      assert Accounts.get_user_by_name("nonexistent") == nil
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{name: "alice"}

      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.name == "alice"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "create_user/1 enforces unique name constraint" do
      user_fixture(%{name: "alice"})
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.create_user(%{name: "alice"})
      assert "has already been taken" in errors_on(changeset).name
    end

    test "create_user/1 validates name is required" do
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.create_user(%{name: ""})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "create_user/1 validates name length maximum" do
      long_name = String.duplicate("a", 51)
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.create_user(%{name: long_name})
      assert "should be at most 50 character(s)" in errors_on(changeset).name
    end

    test "create_user/1 validates name format" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Accounts.create_user(%{name: "invalid name!"})

      assert "can only contain letters, numbers, underscores, and hyphens" in errors_on(changeset).name
    end

    test "create_user/1 allows valid name formats" do
      valid_names = ["alice", "bob123", "user_name", "user-name", "User_123-abc"]

      for name <- valid_names do
        assert {:ok, %User{}} = Accounts.create_user(%{name: name})
      end
    end

    test "get_or_create_user/1 returns existing user when name exists" do
      existing_user = user_fixture(%{name: "alice"})
      assert {:ok, user} = Accounts.get_or_create_user("alice")
      assert user.id == existing_user.id
    end

    test "get_or_create_user/1 creates new user when name does not exist" do
      assert {:ok, %User{} = user} = Accounts.get_or_create_user("newuser")
      assert user.name == "newuser"
    end
  end
end
