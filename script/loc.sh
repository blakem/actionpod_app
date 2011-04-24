wc -l Gemfile lib/event_queuer.rb lib/pool_* lib/tasks/* app/controllers/* app/helpers/* app/models/* app/views/*/* 2>&1 | grep total
wc -l `find spec` 2>&1 /dev/null | grep total
