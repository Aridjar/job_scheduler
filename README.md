# JobScheduler<!-- omit in toc -->

This learning project has for purpose to distribute task into worker separated by category or put them in queue if all worker are busy. It also load balance the queues, and save the task in Mnesia.

It is done to have distinctive logic between the request/response elements (such as requesting a web page), and the request which doesn't need a response (such as sending e-mail).

> Note: As Elixir run everything by allocating the same CPU availability to each process, this tool is not necessary, as it can be in languages such as Ruby (which needs Sidekiq (or other)).

## Before continuing

This project was done in March 2020 as part of a private project. It was extracted and put in this Phoenix app and on Github to give you access to it.

Only minor changes (some documentation, the README), which I feel were needed to understand how the JobScheduler works, where added on the initial commit.

## Current problem

As the Application launch at the same time Mnesia and the WorkerBalancer (which depends of Mnesia), it might happens that, when launching the server, Mnesia is called last and the WorkerBalancer don't get the data it needs and shut down the system.

But the logic behind all of that (which is, for now, what interest us the most) is still relevant.

## Summary

- [Before continuing](#before-continuing)
- [Current problem](#current-problem)
- [Summary](#summary)
- [How does it works?](#how-does-it-works)
  - [Component definition](#component-definition)
    - [General](#general)
    - [Category](#category)
    - [Mnesia](#mnesia)
  - [Application workflow](#application-workflow)
  - [WorkerBalancer](#workerbalancer)
- [Technical decision](#technical-decision)
  - [Phoenix](#phoenix)
  - [Mnesia](#mnesia-1)
  - [Categorised FIFO](#categorised-fifo)
  - [Limited amount of worker](#limited-amount-of-worker)
  - [Load balancing](#load-balancing)
- [Install](#install)
- [Testing it](#testing-it)
- [TODO](#todo)
- [Note for later](#note-for-later)

## How does it works?

### Component definition

#### General

1. **Application**: Main supervisor, common to most Elixir project.
2. **Dispatch**: Entry point of the JobScheduler, it's a simple module which redirect the task to the correct worker.
3. **Waiter**: Simple Genserver made to be called with after a certain time. Once the time is over, it calls the `Dispatcher`.
4. **WorkerBalancer**: Genserver which reevaluate the need of worker for each category and send message to allocate them.

#### Category

1. **CategorySupervisor**: Generate associated `FifoAgent`, `WorkerAgent` and `WorkerSupervisor`.
2. **FifoAgent**: Agent storing an erlang [:queue](https://erlang.org/doc/man/queue.html), acting as a fifo storage.
3. **WorkerAgent**: Agent storing a map of worker PIDs and interacting directly with them and the `WorkerSupervisor` of the same category.
4. **WorkerSupervisor**: Starts and terminates workers.
5. **Worker**: Genserver handling the logic. It is by default iddle and waiting for new task if the `FifoAgent` doesn't have anything available.

#### Mnesia

1. **Table**: Behaviour module to define the base functions for a new struct file to work.
2. **Server**: Generser connected to [:mnesia](https://erlang.org/doc/man/mnesia.html), handling all calls.
3. **Table.ServiceWorker**: Module with a structure representing generic task and associated action a `Worker` will have to execute.

### Application workflow

1. Start the application and assocaited processes, including
   1. Mnesia server
   2. Waiter
   3. Every CategorySupervisor (1 per category)
      1. Starts category's `FifoAgent`
         - The `FifoAgent` calls Mnesia to get and store all existing unfinished task of its category
      2. Starts category's `WorkerAgent`
      3. Starts category's `WorkerSupervisor`
   4. WorkerBalancer
      - At the end of the `WorkerBalancer` initialization, the first worker count per category is calculate.
      - It sends the result to the `WorkerAgent`
      - It calls `WorkerSupervisor` spawn the worker, and save the PIDs
      - Workers at spawn take an element from the `FifoAgent` if there are any, otherwise they are set to `:free` 
2. Call `Dispatcher.dispatch()`
   - If there is a timer, send a message to `Waiter`, which will recal the `Dispatcher.dispatch()` function at the end of the timer
3. The `Dispatcher` checks in which category a task should be executed and send the task to the associated `WorkerAgent`
4. The `WorkerAgent` checks if there is any worker is `:free`
   - If there is no worker `:free`, it sends the task to the FifoAgent
5. If/when the worker is/become `:free`, the worker takes the task and execute it, changing its state to `:busy`
   - If there is no task, the worker call the WorkerAgent to change its status to `:free`

### WorkerBalancer

The `WorkerBalancer` doesn't only calculate the workers at the end of the initialization, but also every N seconds after it. The calcul is the following one

1. It takes the number of tasks in the category and multiply it by number associted to a priority.
2. It take the number of available worker and multiply it by the previous result.
3. It divides the previous result by the total number of weighted tasks

There is also a notion of minimum worker available at all time which isn't used yet.

> Note: the dispatcher isn't yet perfected, and may not work for the moment

## Technical decision

Some decision were taken for this project which may be discussed. I don't know if they represent the best way of doing things, but they are still made with some ideas in mind.

### Phoenix

The phoenix server is here to, later, be able to have a web interface to verify if everything works great in a more visual way.

It doesn't add anything for now but the `/dashboard` which itself is still something.

### Mnesia

DB directly integrated into Erlang, it is set up to persist the data on disc should the server be down and the cache erased.

I was curious about it and wanted to learn to use it.

### Categorised FIFO

**Fist In First Out** separated in category. Each category as its own fifo queue which allows it to get the latest jobs associated to its purpose.

There is no define way to pick the category. It can be named after the jobs it as to execute (heavy calculation, email sending...) or based on the priority.

### Limited amount of worker

Though Elixir processes are concurrent (and thread parallel) and the calcul power evenly shared, having too many processes could still impact the performance of the main application. 

By limiting the amount of workers, and keeping the heavy tasks in the workers (combined with memoization), you assure a more stable state of you server, at the cost of, sometimes, some seconds before executing a task.

### Load balancing

It was decided to include a load balancer on the level of the WorkerSupervisor to adapt to the current charges of each category depending of the importance level

Though it is not a necesity, it is still a nice thing to have in some pike condition (such as sending an email to all your users).

## Install

```elixir
mix deps.get
```

## Testing it

As most of the elements are GenServers, and as I didn't find anything at the time to test them, there is no test available.

I recently found a ressource about [testing the genserver with erlang trace](https://www.thegreatcodeadventure.com/testing-genservers-with-erlang-trace/), but it wasn't published at the time of creating the project (March vs August).

```elixir
iex -S mix

# Once you're in the shell of the console
JobScheduler.Tester.generate_jobs(1000)
```

## TODO

- [ ] Stabilise the launch at the start of the application
- [ ] Validate the dispatcher
- [ ] Automate the test through a temporary staging env, and apply chaos engineernig ([check this video?](https://www.youtube.com/watch?v=ALL7n7FaOf4))
- [ ] Handle the LATER elements
- [ ] Add a web interface to generate and visualize worker dispatch and usage
- [ ] Add time consuming code to improve the tests

## Note for later

1. In the `app/worker/config/dev` switch the timer (uncomment one and comment the other)
2. Add or remove workers depending of your need (see the [Not yet](#not_yet) session)
3. Call `Process.send(:worker_queue_worker_balancer, :work, [])`
