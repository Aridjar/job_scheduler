defmodule JobScheduler.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      JobSchedulerWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: JobScheduler.PubSub},
      # Start the Endpoint (http/https)
      JobSchedulerWeb.Endpoint,
      # Start a worker by calling: JobScheduler.Worker.start_link(arg)
      # {JobScheduler.Worker, arg}

      {JobScheduler.Mnesia.Server, []},
      {JobScheduler.Queue.Waiter, []},
      {JobScheduler.Queue.WorkerBalancer, []}
    ] ++ generate_category_supervisors()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JobScheduler.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JobSchedulerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp generate_category_supervisors() do
    Application.fetch_env!(:job_scheduler, :queues)
    |> Enum.flat_map(&generate_category_supervisor/1)
  end

  def generate_category_supervisor({key, _}) do
    category_name = Atom.to_string(key)
    supervisor_name = String.to_existing_atom("category_supervisor_#{category_name}")

    [
      %{
        id: {JobScheduler.Queue.Categories.CategorySupervisor, supervisor_name},
        start: {
          JobScheduler.Queue.Categories.CategorySupervisor,
          :start_link,
          [[category_name: category_name, name: supervisor_name]]
        }
      }
    ]
  end
end
