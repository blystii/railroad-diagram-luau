local generator = require("./../generator")
local Line = require("./Line")

local Terminal = { class = "terminal", text = 0, min_size = 0 }
Terminal.__index = Terminal
function Terminal.new(text: string, min_size: { x: number?, y: number? }?)
    min_size = min_size or generator.properties.min_size
    local meta = setmetatable({ class = "terminal", text = text, min_size = min_size }, Terminal)
    generator.insert("terminal", { text = text, min_size = min_size }, meta)
    return meta
end

function Terminal:remove()
	generator.remove(self)
end

function Terminal:lock()
    generator.lockNode(self)
end

function Terminal:connect(...)
    return Line.new(self, ...)
end

return Terminal
