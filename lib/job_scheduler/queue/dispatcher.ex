defmodule JobScheduler.Queue.Dispatcher do
  @moduledoc """
  The dispatcher is just a module handling where the work_task goes. No Genserver, or anything. It also handle saving.

  This is the module you use to add a job. To do so, call
  JobScheduler.Queue.Dispatch.perform_job(queue, callback, arguments, to_execute_in)
  """
  require Logger

  alias JobScheduler.Mnesia.Tables.ServiceWorker
  alias JobScheduler.Queue.Categories.{WorkerAgent, FifoAgent}

  @spec perform_job(atom, function, list, integer | :now) :: {:ok, String.t()} | {:error, String.t()}
  def perform_job(queue, callback, arguments, to_execute_in \\ :now) do
    with :ok <- JobScheduler.Lib.Function.compare_arity_with_arguments(callback, arguments),
         :ok <- validate_queue_existance(queue),
         {:ok, waiting_timestamp} <- validate_to_execute_in(to_execute_in) do
      perform_valid(queue, callback, arguments, waiting_timestamp)
    else
      {:error, message} = error ->
        Logger.error(message)
        error
    end
  end

  def dispatch(%{} = work_task) do
    stated_work_task = work_task |> Map.put(:state, :queued)
    ServiceWorker.insert(stated_work_task)

    dispatch_logique(stated_work_task)
  end

  def dispatch(id) do
    stated_work_task = %{id: id, state: :queued}
    |> ServiceWorker.get_and_update()
    |> ServiceWorker.tuple_to_map()

    dispatch_logique(stated_work_task)
  end

  defp dispatch_logique(%{callback: callback} = work_task) do
    agent_worker = :worker_agent |> JobScheduler.Lib.Atom.merge_two_atoms(callback)

    with nil <- WorkerAgent.get_first_free_worker(agent_worker) do
      :fifo_agent
      |> JobScheduler.Lib.Atom.merge_two_atoms(callback)
      |> FifoAgent.add_tail(work_task)
    else
      {worker_pid, _} -> Genserver.cast(worker_pid, work_task)
      _ -> Logger.error("Dispatch_logique failed for unexpected reason")
    end
  end

  ##################
  ### Validation ###
  ##################

  defp validate_queue_existance(queue) do
    if Application.fetch_env!(:job_scheduler, :atom_list) |> Keyword.keys() |> Enum.member?(queue) do
      :ok
    else
      {:error, "The queue #{queue} you requested doesn't exist."}
    end
  end

  defp validate_to_execute_in(to_execute_in) do
    actual_time = DateTime.utc_now() |> DateTime.to_unix()
    maximum_wait = Application.fetch_env!(:job_scheduler, :maximum_wait_time_for_worker)

    cond do
      to_execute_in == :now -> {:ok, 0}
      to_execute_in < 0 -> {:error, "You cannot pass a negative number."}
      to_execute_in < maximum_wait -> {:ok, to_execute_in}
      to_execute_in - actual_time < maximum_wait -> {:ok, to_execute_in - actual_time}
      to_execute_in |> is_integer() -> {:error, "A task cannot be executed after more than #{maximum_wait} seconds."}
      true -> {:error, "You cannot pass anything else than a integer or :now atom as the fourth argument."}
    end
  end

  defp perform_valid(queue, callback, arguments, 0),
    do: dispatch(%{queue: queue, callback: callback, arguments: arguments, to_execute_in: 0})

  defp perform_valid(queue, callback, arguments, waiting_timestamp) do
    work_task = %{
      state: :pending,
      queue: queue,
      callback: callback,
      arguments: arguments,
      to_execute_in: waiting_timestamp
    }

    {:ok, id} = ServiceWorker.insert(work_task)
    Process.send_after(:worker_queue_waiter, {:waiter, id}, waiting_timestamp)
  end
end
