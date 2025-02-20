local generator = require("./../generator")
local Line = require("./Line")

local NonTerminal = { class = "nonterminal", text = 0, min_size = 0 }
NonTerminal.__index = NonTerminal
function NonTerminal.new(text: string, min_size: { x: number?, y: number? }?)
	min_size = min_size or generator.properties.min_size
    local meta = setmetatable({ class = "nonterminal", text = text, min_size = min_size }, NonTerminal)
	generator.insert("nonterminal", { text = text, min_size = min_size }, meta)
	return meta
end

function NonTerminal:remove()
	generator.remove(self)
end

function NonTerminal:lock()
	generator.lockNode(self)
end

function NonTerminal:connect(...)
	return Line.new(self, ...)
end

return NonTerminal
