defmodule EventStoreWeb.Router do
  use EventStoreWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", EventStoreWeb do
    pipe_through :api
  end
end
