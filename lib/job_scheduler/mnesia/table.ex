defmodule JobScheduler.Mnesia.Table do
  @moduledoc """
  Behaviour module used to define the functions a worker should include.
  """

  @callback start_mnesia() :: :ok
  @callback insert(map) :: :ok | {:aborted, String.t()}
  @callback update(map) :: :ok | {:aborted, String.t()}
  @callback update_or_create(map) :: :ok | {:aborted, String.t()}
  @callback read(integer) :: {:ok, map} | {:aborted, String.t()}
  @callback delete(integer) :: :ok | {:aborted, String.t()}
  @callback update_and_read(integer, map) :: {:ok, map} | {:aborted, String.t()}
  @callback formate_data(map) :: tuple
end
