defmodule ChatterWeb.PageController do
  use ChatterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
