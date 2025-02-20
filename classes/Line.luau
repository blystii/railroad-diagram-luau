local generator = require("./../generator")

local Line = { class = "line", n1 = 0, n2 = 0, direction = 0, length = 0 }
Line.__index = Line
function Line.new(n1: {}, n2: {}, direction: string?, length: number?)
    direction = direction or "s"
    length = length or 1
	local meta = setmetatable({ class = "line", n1 = n1, n2 = n2, direction = direction, length = length }, Line)
    generator.insert("line", { n1 = n1, n2 = n2, direction = direction, length = length }, meta)
	return meta
end

function Line:remove()
    generator.remove(self)
end

return Line
