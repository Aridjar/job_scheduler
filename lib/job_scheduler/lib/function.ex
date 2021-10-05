defmodule JobScheduler.Lib.Function do
  @moduledoc """
  Complementary lib for Elxir functions
  """

  @doc """


  ## Examples

    iex> JobScheduler.Lib.Function.compare_arity_with_arguments(&JobScheduler.Lib.Function.compare_arity_with_arguments/2, ["arg1", "arg2"])
    :ok

    iex> JobScheduler.Lib.Function.compare_arity_with_arguments(&JobScheduler.Lib.Function.compare_arity_with_arguments/2, ["arg1"])
    {:error, "The number of argument doesn't equal the arity of the callback JobScheduler.Lib.Function.compare_arity_with_arguments/2."}

  """

  def compare_arity_with_arguments(callback, arguments) do
    callback_data = :erlang.fun_info(callback)

    if callback_data[:arity] == arguments |> Enum.count() do
      :ok
    else
      callback_info = JobScheduler.Lib.Atom.stringify_callback_info(callback_data)
      {:error, "The number of argument doesn't equal the arity of the callback #{callback_info}."}
    end
  end
end
