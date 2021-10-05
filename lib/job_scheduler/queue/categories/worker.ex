defmodule JobScheduler.Queue.Categories.Worker do
  @moduledoc """
  The delayed worker_task Genserver as for purpose to save a worker_task which has to be executed after at least a certain amount of time

  List des status:
  - free
  - busy
  - to_terminate

  State:
  - worker_supervisor
  - fifo_agent
  - worker_agent
  """
  use GenServer

  require Logger

  alias JobScheduler.Queue.Categories.{WorkerAgent, FifoAgent}
  alias JobScheduler.Mnesia.Tables.ServiceWorker

  def start_link(custom_args, supervisor_args) do
    args = (supervisor_args ++ custom_args) |> Enum.into(%{})

    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(%{worker_agent: worker_agent} = init_arg) do
    WorkerAgent.add_workers(worker_agent, [self()])
    get_next_worker_task(init_arg)
    {:ok, init_arg}
  end

  @impl true
  def handle_cast(
        %{id: id, callback: callback, arguments: args},
        %{worker_agent: worker_agent, supervisor: supervisor} = state
      ) do
    # LATER: update WorkerAgent with the id
    Logger.info("BEGAN JOB #{id}")
    WorkerAgent.update_status(worker_agent, self(), :busy)
    # LATER: check if the callback endend successfully
    callback |> apply(args)
    ServiceWorker.delete(id)

    with :to_terminate <- WorkerAgent.get_status(worker_agent, self()) do
      WorkerAgent.terminate_worker(worker_agent, self(), supervisor)
    else
      _ -> get_next_worker_task(state)
    end

    {:noreply, state}
  end

  defp get_next_worker_task(%{worker_agent: worker_agent, fifo_agent: fifo_agent}) do
    with {:ok, %{id: _} = data} <- FifoAgent.get_head(fifo_agent) do
      # LATER: update workerAgent with the data id
      Genserver.cast(self(), data)
    else
      _ -> WorkerAgent.update_status(worker_agent, self(), :free)
    end
  end

  def test_callback(arg_01, arg_02 \\ nil) do
    IO.inspect(arg_01)
    IO.inspect(arg_02)
    {:ok, :world}
  end
end
