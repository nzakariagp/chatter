defmodule Chatter.ChatTest do
  use Chatter.DataCase

  alias Chatter.Chat

  describe "messages" do
    alias Chatter.Chat.Message

    import Chatter.ChatFixtures
    import Chatter.AccountsFixtures

    @invalid_attrs %{content: nil}

    test "list_messages/0 returns all messages in ascending order" do
      message1 = message_fixture()
      Process.sleep(10)
      message2 = message_fixture()

      messages = Chat.list_messages()
      assert length(messages) == 2
      assert Enum.at(messages, 0).id == message1.id
      assert Enum.at(messages, 1).id == message2.id
    end

    test "list_recent_messages/1 returns recent messages in ascending order" do
      for _ <- 1..10 do
        message_fixture()
        Process.sleep(5)
      end

      messages = Chat.list_recent_messages(5)
      assert length(messages) == 5

      for {msg1, msg2} <- Enum.zip(messages, Enum.drop(messages, 1)) do
        assert DateTime.compare(msg1.inserted_at, msg2.inserted_at) in [:lt, :eq]
      end
    end

    test "list_recent_messages/1 defaults to 500 messages" do
      message_fixture()
      assert length(Chat.list_recent_messages()) == 1
    end

    test "list_recent_messages/0 preloads user" do
      message = message_fixture()
      [loaded_message] = Chat.list_recent_messages()
      assert loaded_message.user.id == message.user_id
    end

    test "list_messages_before/2 returns messages with older timestamps" do
      user = user_fixture()

      {:ok, _msg1} = Chat.create_message(user, %{content: "first"})
      Process.sleep(10)
      {:ok, _msg2} = Chat.create_message(user, %{content: "second"})
      Process.sleep(10)
      {:ok, msg3} = Chat.create_message(user, %{content: "third"})

      messages = Chat.list_messages_before(msg3.id, 10)

      assert is_list(messages)

      assert Enum.all?(messages, fn msg ->
               DateTime.compare(msg.inserted_at, msg3.inserted_at) == :lt
             end)
    end

    test "list_messages_before/2 respects limit parameter" do
      user = user_fixture()

      for i <- 1..10 do
        Chat.create_message(user, %{content: "message #{i}"})
        Process.sleep(5)
      end

      all_messages = Chat.list_messages()
      last_message = List.last(all_messages)

      messages = Chat.list_messages_before(last_message.id, 5)
      assert length(messages) <= 5
    end

    test "list_messages_after/1 returns messages with newer timestamps" do
      user = user_fixture()

      {:ok, msg1} = Chat.create_message(user, %{content: "first"})
      Process.sleep(10)
      {:ok, _msg2} = Chat.create_message(user, %{content: "second"})
      Process.sleep(10)
      {:ok, _msg3} = Chat.create_message(user, %{content: "third"})

      messages = Chat.list_messages_after(msg1.id)

      assert is_list(messages)

      assert Enum.all?(messages, fn msg ->
               DateTime.compare(msg.inserted_at, msg1.inserted_at) == :gt
             end)
    end

    test "create_message/2 with valid data creates a message" do
      user = user_fixture()
      valid_attrs = %{content: "Hello, world!"}

      assert {:ok, %Message{} = message} = Chat.create_message(user, valid_attrs)
      assert message.content == "Hello, world!"
      assert message.user_id == user.id
    end

    test "create_message/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.create_message(user, @invalid_attrs)
    end

    test "create_message/2 validates content length minimum" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{} = changeset} = Chat.create_message(user, %{content: ""})
      assert "can't be blank" in errors_on(changeset).content
    end

    test "create_message/2 validates content length maximum" do
      user = user_fixture()
      long_content = String.duplicate("a", 1001)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Chat.create_message(user, %{content: long_content})

      assert "should be at most 1000 character(s)" in errors_on(changeset).content
    end

    test "subscribe/0 subscribes to chat topic" do
      assert :ok = Chat.subscribe()
    end

    test "broadcast_message/1 sends message to subscribers" do
      Chat.subscribe()
      message = message_fixture()

      Chat.broadcast_message(message)
      assert_receive {:new_message, ^message}
    end
  end
end
