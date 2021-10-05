defmodule JobScheduler.Queue.Categories.WorkerSupervisor do
  # tested and validate
  # Automatically defines child_spec/1
  use DynamicSupervisor
  alias JobScheduler.Queue.Categories.{WorkerAgent, CategorySupervisor}

  def start_link(name: name, category_name: category_name) do
    DynamicSupervisor.start_link(__MODULE__, %{category_name: category_name}, name: name)
  end

  @impl true
  def init(%{category_name: name}) do
    worker_agent = :worker_agent |> JobScheduler.Lib.Atom.merge_two_atoms(name)
    fifo_agent = :fifo_agent |> JobScheduler.Lib.Atom.merge_two_atoms(name)
    args = [supervisor: self(), worker_agent: worker_agent, fifo_agent: fifo_agent]

    DynamicSupervisor.init(strategy: :one_for_one, extra_arguments: [args])
  end

  def start_workers(id, number) when number > 0 do
    worker_pids =
      1..number
      |> Enum.map(fn _ -> start_worker(id) end)

    category = CategorySupervisor.extract_category_name(id, "worker_supervisor_")

    JobScheduler.Lib.Atom.merge_two_atoms(:worker_agent, category)
    |> WorkerAgent.add_workers(worker_pids)

    {:ok, worker_pids}
  end

  def terminate_worker(id, worker_pid), do: DynamicSupervisor.terminate_child(id, worker_pid)

  defp start_worker(id) do
    spec = {JobScheduler.Queue.Categories.Worker, []}
    {:ok, worker_pid} = DynamicSupervisor.start_child(id, spec)

    worker_pid
  end
end
