defmodule JobScheduler.Mnesia.Server do
  # This module should only be called from other JobScheduler module.

  @moduledoc """
  Behaviour module used to define the functions a worker should include.
  """

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{total_created: 0}, name: :worker_mnesia_server)
  end

  @impl true
  def init(stack) do
    start_mnesia()

    # LATER: to handle this call for any table, we will have to add another element ot any handle call wich is the key
    total_created = get_total_created(ServiceWorker) |> elem(1)

    {:ok, %{stack | total_created: total_created}}
  end

  ############################
  ### Database interaction ###
  ############################

  @impl true
  def handle_call({:insert, table, data}, _, %{total_created: total_created} = state) do
    :mnesia.transaction(fn ->
      insert_data(table, data, total_created)
    end)

    {:reply, {:ok, total_created}, state, {:continue, {:update_total_created, total_created + 1, table}}}
  end

  @impl true
  def handle_call({:read, table, id}, _, state) do
    {:atomic, data} =
      :mnesia.transaction(fn ->
        :mnesia.read(table, id, :write)
      end)

    {:reply, {:ok, data}, state}
  end

  @impl true
  def handle_call({:update_or_create, table, %{id: id} = data}, _, %{total_created: total_created} = state) do
    :mnesia.transaction(fn ->
      case :mnesia.read(table, id, :write) do
        [] ->
          insert_data(table, data, total_created)
          {:reply, :ok, state, {:continue, {:update_total_created, total_created + 1, table}}}

        _ ->
          update_data(table, data)
          {:reply, :ok, state}
      end
    end)
  end

  @impl true
  def handle_call({:update, table, %{id: id} = data}, _, state) do
    :mnesia.transaction(fn ->
      case :mnesia.read(table, id, :write) do
        [_] -> update_data(table, data)
        _ -> :ok
      end
    end)

    {:reply, :ok, state}
  end

  @doc """
  Update the object and return the associated data in one mnesia call
  """
  @impl true
  def handle_call({:get_and_update, table, {id, changes}}, _, state) do
    {:atomic, new_object} =
      :mnesia.transaction(fn ->
        object =
          :mnesia.wread({table, id})
          |> List.first()

        ret =
          Enum.reduce(changes, object, fn {index, value}, acc ->
            acc |> Tuple.delete_at(index) |> Tuple.insert_at(index, value)
          end)

        :mnesia.write(object)
        ret
      end)

    {:reply, {:ok, new_object}, state}
  end

  @impl true
  def handle_call({:delete, table, id}, _, state) do
    :mnesia.transaction(fn ->
      :mnesia.delete({table, id})
    end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:select, table, query}, _, state) do
    {:atomic, data} =
      :mnesia.transaction(fn ->
        :mnesia.select(table, query)
      end)

    {:reply, {:ok, data}, state}
  end

  @doc """
  Needed to keep the index up to date to avoid removing a job.
  Shouldn't be called outside the Server module
  """
  @impl true
  def handle_continue({:update_total_created, total_created, table}, state) do
    create_or_update_total_created(table, total_created)

    {:noreply, %{state | total_created: total_created}}
  end

  defp insert_data(table, data, total_created) do
    updated_data = data |> Map.put(:id, total_created)
    module = table_to_module_name(table)

    module.formate_data(updated_data)
    |> :mnesia.write()
  end

  defp update_data(table, data) do
    module = table_to_module_name(table)

    module.formate_data(data)
    |> :mnesia.write()
  end

  #################
  ### Librairie ###
  #################

  # the table name is a module name. A module name is an atom beginning with Elixir such as `Elixir.atom`
  defp table_to_module_name(atom), do: JobScheduler.Lib.Atom.replace(atom, ~r/Elixir./, "Elixir.JobScheduler.Mnesia.Tables.")

  ######################
  ### Initialization ###
  ######################

  defp start_mnesia() do
    :mnesia.create_schema([node()])
    :mnesia.start()

    :mnesia.create_table(GeneralStorage,
      attributes: [:table_name, :attribute_name, :attribute_value],
      disc_copies: [node()]
    )

    :mnesia.wait_for_tables([GeneralStorage], 500)

    start_all_tables()
  end

  # LATER: handle the count recuperation at the start
  defp get_total_created(table) do
    :mnesia.transaction(fn ->
      case :mnesia.read(GeneralStorage, table, :write) do
        [] -> create_or_update_total_created(table)
        [data] -> elem(data, 3)
        # :erts_dirty_process_signal_handler
        _ -> :error
      end
    end)
  end

  defp create_or_update_total_created(table, total_created \\ 0) do
    :mnesia.transaction(fn ->
      :mnesia.write({GeneralStorage, table, :total_created, total_created})
    end)

    total_created
  end

  defp start_all_tables() do
    JobScheduler.Mnesia.Tables.ServiceWorker.start_mnesia()
  end
end
