defmodule ChatterWeb.ChatLiveTest do
  use ChatterWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Chatter.Accounts
  alias ChatterWeb.Presence

  @endpoint ChatterWeb.Endpoint

  setup do
    user1 = Accounts.get_or_create_user("alice") |> elem(1)
    user2 = Accounts.get_or_create_user("bob") |> elem(1)

    on_exit(fn ->
      Presence.untrack(self(), "chat:presence", user1.id)
      Presence.untrack(self(), "chat:presence", user2.id)
    end)

    {:ok, user1: user1, user2: user2}
  end

  defp track_presence(user) do
    Presence.track(self(), "chat:presence", user.id, %{
      name: user.name,
      joined_at: System.system_time(:second)
    })
  end

  describe "presence tracking" do
    test "displays user as online when they join the chat", %{conn: conn, user1: user1} do
      track_presence(user1)
      Process.sleep(50)

      {:ok, view, html} = live(conn, "/chat?user_id=#{user1.id}")

      assert html =~ user1.name
      assert has_element?(view, ".status-indicator")

      online_users = get_online_users_from_view(view)
      assert user1.name in online_users
    end

    test "shows multiple users as online when they are connected", %{
      conn: conn,
      user1: user1,
      user2: user2
    } do
      track_presence(user1)
      track_presence(user2)
      Process.sleep(50)

      {:ok, view1, _html} = live(conn, "/chat?user_id=#{user1.id}")
      {:ok, view2, _html} = live(conn, "/chat?user_id=#{user2.id}")

      online_users_view1 = get_online_users_from_view(view1)
      online_users_view2 = get_online_users_from_view(view2)

      assert user1.name in online_users_view1
      assert user2.name in online_users_view1

      assert user1.name in online_users_view2
      assert user2.name in online_users_view2
    end

    test "updates online user count when a user joins", %{conn: conn, user1: user1, user2: user2} do
      track_presence(user1)
      Process.sleep(50)

      {:ok, view1, html} = live(conn, "/chat?user_id=#{user1.id}")

      assert html =~ "1"

      track_presence(user2)
      Process.sleep(100)

      updated_html = render(view1)
      assert updated_html =~ user2.name

      online_count = get_online_count_from_view(view1)
      assert online_count == 2
    end

    test "removes user from online list when they leave the chat", %{
      conn: conn,
      user1: user1,
      user2: user2
    } do
      {:ok, view1, _html} = live(conn, "/chat?user_id=#{user1.id}")
      {:ok, view2, _html} = live(conn, "/chat?user_id=#{user2.id}")

      Process.sleep(100)

      online_users_before = get_online_users_from_view(view1)
      assert user2.name in online_users_before

      view2 |> element("button", "Leave Chat") |> render_click()

      Process.sleep(100)

      online_users_after = get_online_users_from_view(view1)
      refute user2.name in online_users_after
      assert user1.name in online_users_after
    end

    test "updates online user count when a user leaves", %{
      conn: conn,
      user1: user1,
      user2: user2
    } do
      {:ok, view1, _html} = live(conn, "/chat?user_id=#{user1.id}")
      {:ok, view2, _html} = live(conn, "/chat?user_id=#{user2.id}")

      Process.sleep(100)

      online_count_before = get_online_count_from_view(view1)
      assert online_count_before == 2

      view2 |> element("button", "Leave Chat") |> render_click()

      Process.sleep(100)

      online_count_after = get_online_count_from_view(view1)
      assert online_count_after == 1
    end

    test "shows user as offline when they disconnect", %{conn: conn, user1: user1, user2: user2} do
      {:ok, view1, _html} = live(conn, "/chat?user_id=#{user1.id}")
      {:ok, view2, _html} = live(conn, "/chat?user_id=#{user2.id}")

      Process.sleep(100)

      html_before = render(view1)
      assert html_before =~ user2.name

      GenServer.stop(view2.pid, :normal)

      Process.sleep(100)

      online_users_after = get_online_users_from_view(view1)
      refute user2.name in online_users_after
    end

    test "receives presence_diff broadcast when users join or leave", %{
      conn: conn,
      user1: user1,
      user2: user2
    } do
      track_presence(user1)
      Process.sleep(50)

      {:ok, _view1, _html} = live(conn, "/chat?user_id=#{user1.id}")

      Phoenix.PubSub.subscribe(Chatter.PubSub, "chat:presence")

      track_presence(user2)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "presence_diff",
        topic: "chat:presence"
      }
    end

    test "tracks user with correct metadata", %{user1: user1} do
      track_presence(user1)

      Process.sleep(50)

      presences = Presence.list("chat:presence")
      assert Map.has_key?(presences, user1.id)

      presence_data = presences[user1.id]
      assert [meta] = presence_data.metas
      assert meta.name == user1.name
      assert is_integer(meta.joined_at)
    end

    test "deduplicates same user in online list", %{conn: conn, user1: user1} do
      {:ok, view1, _html} = live(conn, "/chat?user_id=#{user1.id}")

      Process.sleep(100)

      online_users = get_online_users_from_view(view1)
      assert Enum.count(online_users, fn name -> name == user1.name end) == 1

      GenServer.stop(view1.pid, :normal)

      Process.sleep(100)

      presences_after = Presence.list("chat:presence")
      refute Map.has_key?(presences_after, user1.id)
    end
  end

  defp get_online_users_from_view(view) do
    html = render(view)

    Regex.scan(~r/<div class="status-indicator"><\/div>\s*<span[^>]*>([^<]+)</, html)
    |> Enum.map(fn [_, name] -> String.trim(name) end)
    |> Enum.sort()
  end

  defp get_online_count_from_view(view) do
    html = render(view)

    case Regex.run(~r/industrial-accent-green">(\d+)</, html) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end
end
