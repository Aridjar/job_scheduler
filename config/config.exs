# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :job_scheduler,
  timer: 365 * 24 * 60 * 60 * 1000,
  # timer: 1 * 60 * 1000,
  maximum_wait_time_for_worker: 365 * 24 * 60 * 60,
  max_thread: 200,
  queues: [
    wait_room: %{name: :wait_room, priority_level: 1, min_worker: 1},
    low: %{name: :low, priority_level: 3, min_worker: 2},
    default: %{name: :default, priority_level: 5, min_worker: 3},
    high: %{name: :high, priority_level: 7, min_worker: 4},
    critical: %{name: :critical, priority_level: 9, min_worker: 10}
  ]

# Configures the endpoint
config :job_scheduler, JobSchedulerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "em59NehLyp/K+OefHkxTCRhA/9M3+ZIc3zZDKGuVmlyaIZB3iookSC8YdEz0cDcf",
  render_errors: [view: JobSchedulerWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: JobScheduler.PubSub,
  live_view: [signing_salt: "vhgqJHk2"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.12.18",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
import_config "atom_list.exs"
