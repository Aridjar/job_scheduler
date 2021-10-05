defmodule JobScheduler.Mnesia.Tables.ServiceWorker do
  @behaviour JobScheduler.Mnesia.Table
  require Logger

  @moduledoc """
  The default model, used to handle task related to a worker

  payload details
  %{
    id: integer, based on the total created + 1
    state: an atom from the list [:pending, :in_progress, :resolved] # To expend
    queue: an atom. See app/worker/config/atom_list.exs to have the full list
    callback: a function. Called with data[:callback].(data[:arguments])
    arguments: a list of argument. Can be empty or nil
    to_execute_in: timestamp
    created_at: date
    updated_at: date
  }
  """

  #  JobScheduler.Mnesia.Tables.ServiceWorker.insert(%{
  #   state: :new, queue: :low, callback: &JobScheduler.Queue.Categories.Worker.test_callback/2, arguments: [:hello, "world"], to_execute_in: 0})

  # LATER: add number of tries, add last time tried, log errors by tries
  # LATER: Redo the file
  defstruct(
    id: nil,
    state: nil,
    queue: nil,
    callback: nil,
    arguments: nil,
    to_execute_in: nil,
    created_at: nil,
    updated_at: nil
  )

  @impl JobScheduler.Mnesia.Table
  def start_mnesia() do
    attributes = generate_attributes()

    with {:atomic, :ok} <- :mnesia.create_table(ServiceWorker, attributes: attributes, disc_copies: [node()]) do
      :mnesia.add_table_index(ServiceWorker, :state)
      :mnesia.add_table_index(ServiceWorker, :queue)
    else
      {:aborted, {:already_exists, _}} -> nil
      {:aborted, message} -> Logger.error(message)
    end

    :ok
  end

  @impl JobScheduler.Mnesia.Table
  def insert(data), do: GenServer.call(:worker_mnesia_server, {:insert, ServiceWorker, data})

  @impl JobScheduler.Mnesia.Table
  def update(data), do: GenServer.call(:worker_mnesia_server, {:update, ServiceWorker, data})

  @impl JobScheduler.Mnesia.Table
  def update_or_create(data), do: GenServer.call(:worker_mnesia_server, {:update_or_create, ServiceWorker, data})

  def get_and_update(data) do
    [{_, id} | _] = updated_data = elem_to_position(data)
    GenServer.call(:worker_mnesia_server, {:get_and_update, ServiceWorker, {id, updated_data}})
  end

  @impl JobScheduler.Mnesia.Table
  def read(id) when is_integer(id), do: GenServer.call(:worker_mnesia_server, {:read, ServiceWorker, id})

  @impl JobScheduler.Mnesia.Table
  def delete(id) when is_integer(id), do: GenServer.call(:worker_mnesia_server, {:delete, ServiceWorker, id})

  @impl JobScheduler.Mnesia.Table
  def update_and_read(id, data),
    do: GenServer.call(:worker_mnesia_server, {:update_and_read, ServiceWorker, %{id: id, data: data}})

  def select(), do: GenServer.call(:worker_mnesia_server, {:select})
  def count(), do: GenServer.call(:worker_mnesia_server, {:count})

  # LATER: make it better
  # Query: select all values from Mnesia where the third element is equal to `category`
  # See: http://erlang.org/doc/apps/erts/match_spec.html

  # Used at the ServiceWorker restart to get the unfinished jobs
  def select_by_category(category) do
    query = [
      {{ServiceWorker, :"$1", :"$2", :"$3", :"$4", :"$5", :"$6", :"$7", :"$8"}, [{:==, :"$3", category}], [:"$$"]}
    ]

    GenServer.call(:worker_mnesia_server, {:select, ServiceWorker, query})
  end

  defp generate_attributes() do
    [
      :id,
      :state,
      :queue,
      :callback,
      :arguments,
      :to_execute_in,
      :created_at,
      :updated_at
    ]
  end

  @impl JobScheduler.Mnesia.Table
  def formate_data(data) do
    {
      ServiceWorker,
      data[:id],
      data[:state],
      data[:queue],
      data[:callback],
      data[:arguments],
      data[:to_execute_in],
      data_created_at(data),
      new_date()
    }
  end

  def tuple_to_map({:ok, data}) do
    generate_attributes()
    |> Enum.zip(data)
    |> Enum.into(%{})
  end

  def elem_to_position(changes) do
    position = %{
      id: 1,
      state: 2,
      queue: 3,
      callback: 4,
      arguments: 5,
      to_execute_in: 6,
      updated_at: 8
    }

    Enum.map(changes, fn {index, value} -> {position[index], value} end)
  end

  defp data_created_at(%{created_at: nil}), do: new_date()
  defp data_created_at(%{created_at: time}), do: time
  defp data_created_at(_), do: new_date()

  defp new_date(), do: DateTime.now("Etc/UTC") |> elem(1)

  @doc """
  A method to test the service worker.
  """

  def generate_test(0), do: :ok

  def generate_test(occurence) do
    %{
      state: :new,
      queue: :high,
      callback: nil,
      arguments: nil,
      to_execute_in: nil
    }
    |> insert()

    generate_test(occurence - 1)
  end
end
