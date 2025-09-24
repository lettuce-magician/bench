# bench
Simple, platform-agnostic and atomic benchmarker library for luau.

# Installation
```bash
pesde add letiul/bench
```

# Examples
### Simple benchmarking
```luau
local bench = require("@pkg/bench")

local results = bench.mark(function(begin, finish)
    -- begins automatically with profile "default"

    begin("task.wait") -- starts tracking time with profile "task.wait"

    task.wait(1)

    finish() -- stops tracking and registers the time taken to the profile

    -- return a string to give a name to the benchmark, otherwise it will give a default name.
    return "my benchmark"
end)

-- print the results
bench.out(results)
```

### Iterating benchmark
```luau
local bench = require("@pkg/bench")

local t = {}

-- runs the benchmark 10 times, computes averages, total, worst and best time from the iterations.
local results = bench.iter(10, function(n, begin, finish)
    begin("table.insert")

    table.insert(t, n)

    finish()

    begin("t[#t+1]")

    t[#t+1] = n

    finish()

    return "table comparison"
end)

bench.out(results)
```

### Comparing benchmarks
```luau
local bench = require("@pkg/bench")

local res1 = bench.iter(1000, function(n, begin, finish)
    begin("create")
    local t = table.create(1)
    finish()

    begin("insert")
    table.insert(t, n)
    finish()

    return "table.insert"
end)

local res2 = bench.iter(1000, function(n, begin, finish)
    begin("create")
    local t = {}
    finish()

    begin("insert")
    t[#t+1] = n
    finish()

    return "empty table"
end)

bench.out(bench.compare(res1,res2))
```