defmodule JobScheduler.Queue.Categories.WorkerAgent do
  use Agent

  alias JobScheduler.Queue.Categories.WorkerSupervisor

  @moduledoc """
  State list:
  - free
  - busy
  - to terminate
  """

  def start_link(params) do
    Agent.start_link(fn -> %{} end, name: params[:name])
  end

  # def visualize(id), do: Agent.get(id, & &1)

  def add_workers(id, worker_pids) do
    formated_workers = format_worker(worker_pids)
    Agent.update(id, &Map.merge(&1, formated_workers))
  end

  def remove_worker(id, worker_pid) do
    Agent.update(id, &Map.pop(&1, worker_pid))
  end

  def get_worker(id, worker_pid), do: Agent.get(id, & &1[worker_pid])
  def get_status(id, worker_pid), do: Agent.get(id, & &1[worker_pid][:status])
  def get_worker_task(id, worker_pid), do: Agent.get(id, & &1[worker_pid][:worker_task])

  def get_first_free_worker(id),
    do: Agent.get(id, fn w -> Enum.find(w, fn {_, worker} -> worker[:status] == :free end) end)

  def update_status(id, worker_pid, status), do: Agent.update(id, &%{&1[worker_pid] | status: status})

  def update_worker_task(id, worker_pid, worker_task),
    do: Agent.update(id, &%{&1[worker_pid] | worker_task: worker_task})

  ###############################
  ### impact WorkerSupervisor ###
  ###############################

  def allocate(id, worker_task_to_allocate, category) do
    # LATER: create a merge_two_atoms_r to have a nice pipeline
    category_string = category |> Atom.to_string()
    worker_supervisor = JobScheduler.Lib.Atom.merge_two_atoms(:worker_supervisor, category_string)

    # LATER: replace by functions with guards
    case worker_task_to_allocate - Agent.get(id, &Enum.count(&1)) do
      x when x > 0 -> WorkerSupervisor.start_workers(worker_supervisor, x)
      x when x < 0 -> set_to_terminate(id, x, worker_supervisor)
      _ -> :ok
    end
  end

  # LATER: Can do better than that
  defp set_to_terminate(_, 0, _), do: :ok

  defp set_to_terminate(id, count, worker_supervisor) do
    new_count = count - 1

    with %{pid: worker_id, status: :free} <- Agent.get(id, &Enum.at(&1, new_count)) do
      terminate_worker(id, worker_id, worker_supervisor)
    else
      %{pid: worker_id, status: :busy} -> update_status(id, worker_id, :to_terminate)
      _ -> :ok
    end

    set_to_terminate(id, new_count, worker_supervisor)
  end

  def terminate_worker(id, worker_id, worker_supervisor) do
    remove_worker(id, worker_id)
    WorkerSupervisor.terminate_worker(worker_supervisor, worker_id)
  end

  defp format_worker(pids) do
    pids
    |> Enum.map(&{&1, %{pid: &1, status: :free}})
    |> Map.new()
  end
end
