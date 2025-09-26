--!strict
type begin = (profile: string) -> ()
type finish = () -> ()
type outOptions = {
	noPrint: boolean?,
	removeName: boolean?,
}

export type markResult = {
	profiles: { [string]: number },
	total: number,
	type: "mark",
	name: string,
}

export type iterEntry = {
	iterations: { number },
	best: number,
	worst: number,
	total: number,
	average: number,
}

export type iterResult = {
	profiles: { [string]: iterEntry },
	total: number,
	name: string,
	type: "iter",
	iterations: number,
}

export type compareResult = {
	benches: { benchResult },
	best: string,
	worst: string,
	diffs: { [string]: { [string]: number } },
	total: number,
	type: "compare",
}

export type benchResult = markResult | iterResult

local measure = os.clock
local benchCount = 0

local function getDefaultBenchName()
	return "bench" .. (if benchCount == 0 then "" else 0)
end

local function stringIf<T>(cond: T, str: string)
	if cond then
		return str
	end

	return ""
end

-- benchmarks a function, providing two functions to assign profiles and calculate intervals between functions.
local function mark(fn: (begin: begin, finish: finish) -> string?)
	local result = {
		profiles = {},
		total = 0,
		name = getDefaultBenchName(),
		type = "mark",
	}

	local is_default = true
	local profile = "default"
	local t = measure()

	local function begin(str: string)
		assert(t == 0 or is_default, "attempt to begin a profile when one is already running")
		profile = str
		is_default = false
		t = measure()
	end

	local function finish()
		assert(t ~= 0, "attempt to finish a profile when no active profile is running")
		local interval = measure() - t
		result.profiles[profile] = interval
		result.total += interval
		t = 0
	end

	local name = fn(begin, finish)

	if t ~= 0 then
		finish()
	end

	if typeof(name) == "string" then
		result.name = name
	end

	benchCount += 1

	return result
end

-- benchmarks a function `n` times, then returns data about the iterations between the profiles, incluinding intervals for each iteration,
-- average time and best and worst times for each profile.
local function iter(n: number, fn: (i: number, begin: begin, finish: finish) -> string?)
	local result = {
		profiles = {} :: { [string]: iterEntry },
		total = 0,
		name = getDefaultBenchName(),
		iterations = n,
		type = "iter",
	}

	local is_default = true
	local profile = "default"
	local t = measure()

	local function begin(str: string)
		assert(t == 0 or is_default, "attempt to begin a profile when one is already running")
		profile = str
		is_default = false
		t = measure()
	end

	local function finish()
		assert(t ~= 0, "attempt to finish a profile when no active profile is running")
		local interval = measure() - t
		local entry = result.profiles[profile]

		if entry ~= nil then
			local index = #entry.iterations + 1
			local best_iter = entry.iterations[entry.best]
			local worst_iter = entry.iterations[entry.worst]

			if interval < best_iter then
				entry.best = index
			elseif interval > worst_iter then
				entry.worst = index
			end

			entry.total += interval
			entry.iterations[index] = interval
		else
			result.profiles[profile] = {
				iterations = { interval },
				best = 1,
				worst = 1,
				total = interval,
				average = 0,
			}
		end

		result.total += interval
		t = 0
	end

	local name
	for i = 1, n do
		local retName = fn(i, begin, finish)

		if t ~= 0 then
			finish()
		end

		if name == nil then
			name = retName
		end
	end

	if name then
		result.name = name
	end

	for str, data in result.profiles do
		data.average = data.total / #data.iterations
	end

	return result
end

-- compares the provided benchmarks, returning a table with the comparison data.
local function compare(...: benchResult)
	local benches = { ... }
	local result = {
		benches = benches,
		best = "",
		worst = "",
		diffs = {},
		total = 0,
		type = "compare",
	}

	for _, bench in ipairs(benches) do
		local diffs = {}

		result.total += bench.total

		for _, other in ipairs(benches) do
			if other == bench then
				continue
			end

			diffs[other.name] = bench.total - other.total
		end

		result.diffs[bench.name] = diffs
	end

	local minValue, maxValue = math.huge, -math.huge

	for _, data in benches do
		if data.total > maxValue then
			maxValue = data.total
			result.worst = data.name
		end

		if data.total < minValue then
			minValue = data.total
			result.best = data.name
		end
	end

	return result
end

-- provides a simple pretty printer for all kinds of benchmark results.
local function out(result: benchResult | compareResult, options: outOptions?): string
	local opt = options or {
		noPrint = false,
		removeName = false,
	}

	local output
	if result.type == "mark" then
		local profilesStr = ""

		for str, value: number in result.profiles do
			profilesStr ..= `* {str}: {value}\n`
		end

		local name = stringIf(not opt.removeName, `--== {result.name} ==--\n`)
		output = `{name}Total: {result.total}\n{profilesStr}`
	elseif result.type == "iter" then
		local profilesStr = ""

		for str, entry in result.profiles do
			profilesStr ..= `-- {str} --\nAvg: {entry.average}\nBest Iteration: {entry.iterations[entry.best]}\nWorst Iteration: {entry.iterations[entry.worst]}\n`
		end

		local name = stringIf(not opt.removeName, `--== {result.name} ==--\n`)
		output = `{name}Avg: {result.total}\nIterations: {result.iterations}\n{profilesStr}`
	elseif result.type == "compare" then
		local benchesStr = ""

		for _, data in result.benches do
			local diffStr = ""
			local diff = result.diffs[data.name]

			for key, value in diff do
				diffStr ..= `-> {data.name} - {key}: {value}\n`
			end

			benchesStr ..= `--// {data.name} \\\\--\n{out(data, { noPrint = true, removeName = true })}\nDiffs:\n{diffStr}\n`
		end

		output = `Total: {result.total}\nBest: {result.best}\nWorst: {result.worst}\n\n[BENCHMARKS]\n{benchesStr}`
	end

	if not opt.noPrint then
		print(output)
	end

	return output :: string
end

return {
	mark = mark,
	iter = iter,
	compare = compare,
	out = out,
}
