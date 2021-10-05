defmodule JobScheduler.Lib.Atom do
  @moduledoc """
  A complementary lib for Elixir `atom` type.
  """

  @doc """
    Change a list of string to a callback string.

  ## Examples

    iex> JobScheduler.Lib.Atom.stringify_callback_info([module: "Module", name: 'function', arity: 2])
    Module.function/2

  """

  def stringify_callback_info(callback_data) do
    "#{callback_data[:module]}.#{callback_data[:name]}/#{callback_data[:arity]}"
  end

  @doc """
    Merge two atoms into one

  ## Examples

    iex> JobScheduler.Lib.Atom.merge_two_atoms(:foo, :bar)
    :foo_bar

    iex> JobScheduler.Lib.Atom.merge_two_atoms(:foo, :bar, "-"")
    :foo-bar

  """

  def merge_two_atoms(atom1, atom2, separator \\ "_") do
    string2 = atom2 |> to_string
    string1 = atom1 |> to_string

    "#{string1}#{separator}#{string2}"
    |> String.to_existing_atom()
  end

  @doc """
    Replace a part of an atom based on a regex rule.

  ## Examples

    iex> JobScheduler.Lib.Atom.replace(:foo, ~r/foo/, "bar")
    :bar

  """

  def replace(atom, regex, replace) do
    atom
    |> to_string
    |> String.replace(regex, replace)
    |> String.to_existing_atom()
  end
end
