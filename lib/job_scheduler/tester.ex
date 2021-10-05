defmodule JobScheduler.Tester do
  @moduledoc """
  This module should only be used in a specific test environment.
  As it is not possible to test behaviour based on genserver in the test files,
  this file is here to automate the test in a specific genserver_test environment.

  It also provides functions to use in iex console, to simplify the generation of job and check their state.
  """

  @doc """

  ## Parameters

  - range|integer: number of job to generate. Should be at least 1

  """
  alias JobScheduler.Queue.Dispatcher

  # JobScheduler.Tester.generate_jobs(1)
  def generate_jobs(), do: :rand.uniform(1000) |> generate_jobs()
  def generate_jobs(_.._ = range), do: range |> Enum.random() |> generate_jobs()
  def generate_jobs(nb_job_to_generate), do: 1..nb_job_to_generate |> Enum.each(&generate_job/1)

  def generate_job(_), do: generate_job()

  def generate_job() do
    {callback, arguments} = generate_callaback_and_args()
    queue = generate_queue()
    to_execute_in = generate_to_execute_in()

    Dispatcher.perform_job(
      queue,
      callback,
      arguments,
      to_execute_in
    )

    :ok
  end

  defp generate_callaback_and_args() do
    position = 0..2 |> Enum.random()

    {
      {&JobScheduler.Tester.no_arity_function/0, []},
      {&JobScheduler.Tester.one_arity_function/1, ["foo"]},
      {&JobScheduler.Tester.two_arities_function/2, ["foo", "bar"]}
    }
    |> elem(position)
  end

  defp generate_queue() do
    position = 0..4 |> Enum.random()
    {:wait_room, :low, :default, :high, :critical} |> elem(position)
  end

  defp generate_to_execute_in(), do: 1..60 |> Enum.random()

  def no_arity_function(), do: IO.inspect("executed")
  def one_arity_function(_), do: IO.inspect("executed")
  def two_arities_function(_, _), do: IO.inspect("executed")
end
