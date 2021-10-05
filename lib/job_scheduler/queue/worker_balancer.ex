defmodule JobScheduler.Queue.WorkerBalancer do
  @moduledoc """
  The timer module has for purpose to call every N secondes the caller supervisor and pass it a social_media list.
  N depends of the number of elements stored in the social_media_storage and other parameters such as:
    - :max_agent, which is one element to calcul the time between each call
    - :base_timer, which is a configuration base value,
      and is the time between the first and the second call of the same social_media agent, in milliseconds
    - :timer, which is the result of a division between the number of agents and the number of base_timer
  Outside of the base, it also use two `handle_cast/2` to update the `:timer`
  The first `handle_cast/2` handle the case where there is a new agent. It takes as parameter `:update_max_agent`.
  The second `handle_cast/2` handle the case where there is a new base_timer set. It takes as parameter a tuple with
    athe atom `:update_base_timer` and the new base timer.
  """

  # :sys.get_state(:worker_queue_worker_balancer)

  use GenServer

  alias JobScheduler.Queue.Categories.{FifoAgent, WorkerAgent}

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: :worker_queue_worker_balancer)
  end

  @impl true
  def init(_) do
    base_timer = Application.fetch_env!(:job_scheduler, :timer)
    max_thread = Application.fetch_env!(:job_scheduler, :max_thread)
    queues = Application.fetch_env!(:job_scheduler, :queues)

    new_state = %{
      max_thread: max_thread,
      timer: base_timer,
      queues: queues,
      init_completed: false
    }

    {:ok, new_state}
  end

  ##################
  ### Timer loop ###
  ##################

  defp schedule_work(%{timer: timer}), do: Process.send_after(self(), :work, timer)

  @impl true
  def handle_info(:work, state) do
    balance_workers(state)
    schedule_work(state)
    {:noreply, state}
  end

  ###############################
  ### Other private functions ###
  ###############################

  ######################
  ### Initialization ###
  ######################

  @impl true
  def handle_cast(:complete_init, %{init_completed: true} = state), do: {:noreply, state}

  @impl true
  def handle_cast(:complete_init, state) do
    balance_workers(state)

    new_state = %{state | init_completed: true}
    schedule_work(new_state)

    {:noreply, new_state}
  end

  ######################
  ### Cast functions ###
  ######################

  @impl true
  def handle_cast({:update_queues, new_queues}, %{queues: queues} = state) do
    updated_queues = queues ++ new_queues

    {:noreply, %{state | queues: updated_queues}}
  end

  ####################
  ### Queue action ###
  ####################

  defp balance_workers(%{queues: queues} = state) do
    # Determine how many threads can be dynamically allocated
    available_threads = get_available_threads(state)

    {category_work_task_count, total_work_task_count} =
      queues
      |> Enum.map(&get_work_task_quantity(&1))
      |> Enum.map_reduce(0, fn {_, v} = t, acc -> {t, v + acc} end)

    category_work_task_count
    |> Enum.each(&calcul_category_worker(&1, state, total_work_task_count, available_threads))

    :ok
  end

  defp get_available_threads(%{queues: queues, max_thread: max_thread}) do
    minimum_thread_allocated =
      queues
      |> Enum.map(&elem(&1, 1)[:min_worker])
      |> Enum.reduce(&(&1 + &2))

    max_thread - minimum_thread_allocated
  end

  defp get_work_task_quantity({key, %{priority_level: priority_level}}) do
    length =
      :fifo_agent
      |> JobScheduler.Lib.Atom.merge_two_atoms(key)
      |> FifoAgent.get_length()

    {key, length * get_modifier(priority_level)}
  end

  defp calcul_category_worker({category, category_work_task_count}, state, total_work_task_count, available_threads) do
    work_tasks_to_allocate =
      count_work_tasks_to_allocate(category, category_work_task_count, state, total_work_task_count, available_threads)

    :worker_agent
    |> JobScheduler.Lib.Atom.merge_two_atoms(category)
    # LATER: This doesn't work yet
    |> WorkerAgent.allocate(work_tasks_to_allocate, category)
  end

  # LATER: get the number of used worker per category in comparison of the minimum worker per category
  # if there is less used worker, up the number of worker in this category to the minimum,
  # and update available_threads accordingly
  defp count_work_tasks_to_allocate(
         category,
         category_work_task_count,
         %{queues: queues},
         total_work_task_count,
         available_threads
       ) do
    (category_work_task_count * available_threads / total_work_task_count)
    |> round()
    |> :erlang.+(queues[category][:min_worker])
  end

  # LATER: find an algo to reduce this
  defp get_modifier(priority_level) do
    case priority_level do
      0 -> 1
      1 -> 3
      2 -> 4
      3 -> 5
      4 -> 6
      5 -> 8
      6 -> 10
      7 -> 12
      8 -> 16
      9 -> 20
      10 -> 24
      _ -> 0
    end
  end
end
