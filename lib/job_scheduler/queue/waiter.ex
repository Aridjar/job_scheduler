defmodule JobScheduler.Queue.Waiter do
  @moduledoc """
  The delayed job Genserver as for purpose to save a job which has to be executed after at least a certain amount of time
  """

  use GenServer

  alias JobScheduler.Queue.Dispatcher

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: :worker_queue_waiter)
  end

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end

  @impl true
  def handle_info({:waiter, work_task_id}, state) do
    Dispatcher.dispatch(work_task_id)
    {:noreply, state}
  end
end
