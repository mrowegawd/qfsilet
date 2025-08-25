local nbsp = "\xe2\x80\x82" -- Non-breaking space unicode character "\u{2002}"

local function last_index_of(haystack, needle)
	local i = haystack:match(".*" .. needle .. "()")
	if i == nil then
		return nil
	else
		return i - 1
	end
end

local function strip_before_last_occurence_of(str, sep)
	local idx = last_index_of(str, sep) or 0
	return str:sub(idx + 1), idx
end

local function strip_ansi_coloring(str)
	if not str then
		return str
	end
	-- Remove escape sequences of the following formats:
	-- 1. ^[[34m
	-- 2. ^[[0;34m
	-- 3. ^[[m
	return str:gsub("%[[%d;]-m", "")
end

local function strip_string(selected)
	local pth = strip_ansi_coloring(selected)
	if pth == nil then
		return
	end
	return strip_before_last_occurence_of(pth, nbsp)
end

-- function M.strip_ansi_coloring(str)
--   if not str then
--     return str
--   end
--   -- remove escape sequences of the following formats:
--   -- 1. ^[[34m
--   -- 2. ^[[0;34m
--   -- 3. ^[[m
--   return str:gsub("%[[%d;]-m", "")
-- end

local function ansi_escseq_len(str)
	local stripped = strip_ansi_coloring(str)
	return #str - #stripped
end

local function replace_refs(s)
	local out, _ = string.gsub(s, "%[%[[^%|%]]+%|([^%]]+)%]%]", "%1")
	out, _ = out:gsub("%[%[([^%]]+)%]%]", "%1")
	out, _ = out:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
	return out
end

return {
	strip_string = strip_string,
	ansi_escseq_len = ansi_escseq_len,
	replace_refs = replace_refs,
}
