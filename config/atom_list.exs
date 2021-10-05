use Mix.Config

# The atom list is here to secure the transformation from string to atom, allowing dynamical calls
# Get main atoms : Application.fetch_env!(:job_scheduler, :atom_list) |> Keyword.keys

config :job_scheduler,
  atom_list: [
    wait_room: [
      :category_supervisor_wait_room,
      :worker_supervisor_wait_room,
      :worker_agent_wait_room,
      :fifo_agent_wait_room
    ],
    low: [
      :category_supervisor_low,
      :worker_supervisor_low,
      :worker_agent_low,
      :fifo_agent_low
    ],
    default: [
      :category_supervisor_default,
      :worker_supervisor_default,
      :worker_agent_default,
      :fifo_agent_default
    ],
    high: [
      :category_supervisor_high,
      :worker_supervisor_high,
      :worker_agent_high,
      :fifo_agent_high
    ],
    critical: [
      :category_supervisor_critical,
      :worker_supervisor_critical,
      :worker_agent_critical,
      :fifo_agent_critical
    ]
  ]
