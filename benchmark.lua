-- benchmark.lua
-- Benchmark script for wrk targeting http://localhost:8080/results?seat_no=X
-- Usage: wrk -t12 -c400 -d30s -s benchmark.lua http://localhost:8080

local thread_id = 0

-- Called once per thread during initialization to set a thread-specific ID
setup = function(thread)
   thread_id = thread_id + 1
   thread:set("id", thread_id)
end

-- Called per thread state initialization
init = function(args)
   -- Seed the random number generator using time and the unique thread ID
   -- to ensure different threads do not generate identical random sequences.
   math.randomseed(os.time() + id)
   
   -- Warm up the PRNG
   for i = 1, 10 do
      math.random()
   end
end

-- Called for each HTTP request
request = function()
   -- Generate a random seat number in the specified range
   local seat_no = math.random(2001970, 2993862)
   local path = "/results?seat_no=" .. seat_no
   return wrk.format("GET", path)
end
