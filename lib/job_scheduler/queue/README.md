# Mnesia worker <!-- omit in toc -->

This readme should guide you on how to improve the worker services and how to test it.

## Summary

- [Summary](#summary)
- [test dispatcher](#test-dispatcher)
- [Test worker_balancer](#test-worker_balancer)
- [TODO](#todo)

## test dispatcher

1. 

## Test worker_balancer

1. In the `app/worker/config/dev` switch the timer (uncomment one and comment the other)
2. Add or remove workers depending of your need (see the [Not yet](#not_yet) session)
3. Call `Process.send(:worker_queue_worker_balancer, :work, [])`

- vocabulary : WorkTask

## TODO
