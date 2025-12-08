# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Chatter.Repo.insert!(%Chatter.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Query
alias Chatter.Repo
alias Chatter.Accounts
alias Chatter.Chat

# Create test users
users = [
  "alice",
  "bob",
  "charlie",
  "diana",
  "eve"
]

IO.puts("Creating users...")

created_users =
  Enum.map(users, fn name ->
    {:ok, user} = Accounts.create_user(%{name: name})
    IO.puts("  Created user: #{user.name}")
    user
  end)

# Create test messages
IO.puts("\nCreating messages...")

messages = [
  {"alice", "Hello everyone! Welcome to Chatter!"},
  {"bob", "Hey Alice! Thanks for setting this up."},
  {"charlie", "This is pretty cool. How does it work?"},
  {"alice", "It uses Phoenix LiveView for real-time updates!"},
  {"diana", "Nice! I love how fast it is."},
  {"eve", "Just joined. What did I miss?"},
  {"bob", "Not much, we're just testing the chat."},
  {"charlie", "The real-time updates are instant!"},
  {"alice", "Exactly! No page refreshes needed."},
  {"diana", "This would be great for team communication."},
  {"eve", "Agreed! Much better than email."},
  {"bob", "Can we add emoji support?"},
  {"charlie", "And maybe file uploads?"},
  {"alice", "Those are on the roadmap!"},
  {"diana", "Looking forward to it."},
  {"eve", "Keep up the good work!"},
  {"bob", "Thanks for building this, Alice!"},
  {"alice", "Happy to help. Enjoy chatting!"}
]

Enum.each(messages, fn {username, content} ->
  user = Enum.find(created_users, fn u -> u.name == username end)
  {:ok, message} = Chat.create_message(user, %{content: content})
  IO.puts("  #{username}: #{String.slice(content, 0, 40)}...")
  Process.sleep(100)
end)

IO.puts("\nSeeding complete!")
IO.puts("  #{length(created_users)} users created")
IO.puts("  #{length(messages)} messages created")
