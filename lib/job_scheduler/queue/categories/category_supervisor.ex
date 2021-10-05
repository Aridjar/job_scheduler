defmodule JobScheduler.Queue.Categories.CategorySupervisor do
  # Automatically defines child_spec/1
  use Supervisor

  def start_link(category_name: category_name, name: name) do
    Supervisor.start_link(__MODULE__, [category_name: category_name], name: name)
  end

  @impl true
  def init(category_name: category_name) do
    generate_children(category_name)
    |> Supervisor.init(strategy: :one_for_one)
  end

  def extract_category_name(id, origin), do: id |> Atom.to_string() |> String.replace_prefix(origin, "")

  defp generate_children(category_name) do
    [
      generate_worker_supervisor(category_name),
      generate_fifo_agent(category_name),
      generate_worker_agent(category_name)
    ]
  end

  defp generate_worker_supervisor(category_name) do
    supervisor_name = JobScheduler.Lib.Atom.merge_two_atoms(:worker_supervisor, category_name)

    %{
      id: {JobScheduler.Queue.Categories.WorkerSupervisor, supervisor_name},
      start: {
        JobScheduler.Queue.Categories.WorkerSupervisor,
        :start_link,
        [[name: supervisor_name, category_name: category_name]]
      }
    }
  end

  defp generate_fifo_agent(category_name) do
    fifo_name = JobScheduler.Lib.Atom.merge_two_atoms(:fifo_agent, category_name)

    {:ok, values} =
      category_name
      |> String.to_existing_atom()
      |> JobScheduler.Mnesia.Tables.ServiceWorker.select_by_category()

    %{
      id: {JobScheduler.Queue.Categories.FifoAgent, fifo_name},
      start: {
        JobScheduler.Queue.Categories.FifoAgent,
        :start_link,
        [[name: fifo_name, values: values]]
      }
    }
  end

  defp generate_worker_agent(category_name) do
    availability_name = JobScheduler.Lib.Atom.merge_two_atoms(:worker_agent, category_name)
    values = []

    %{
      id: {JobScheduler.Queue.Categories.WorkerAgent, availability_name},
      start: {
        JobScheduler.Queue.Categories.WorkerAgent,
        :start_link,
        [[name: availability_name, values: values]]
      }
    }
  end
end
