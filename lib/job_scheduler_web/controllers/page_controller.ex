defmodule JobSchedulerWeb.PageController do
  use JobSchedulerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
