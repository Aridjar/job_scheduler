defmodule JobScheduler.Queue.Categories.FifoAgent do
  use Agent
  # tested and validated

  # Warning: risk of bottleneck is important if there is more than 99 999 elements in a queue as some function become O(n) instead of O(1)
  # LATER: generate other agents in case of a high number of elements
  # More about queue here : http://erlang.org/doc/man/queue.html
  def start_link(params) do
    values = :queue.from_list(params[:values])
    Agent.start_link(fn -> values end, name: params[:name])
  end

  def get_length(id), do: Agent.get(id, &:queue.len(&1))
  # get_tail and get_head should remove the element when we get it. update return just :ok
  def get_tail(id), do: Agent.get_and_update(id, &:queue.out_r(&1))
  def get_head(id), do: Agent.get_and_update(id, &:queue.out(&1))
  def add_head(id, val), do: Agent.update(id, &:queue.in_r(val, &1))
  def add_tail(id, val), do: Agent.update(id, &:queue.in(val, &1))
end
