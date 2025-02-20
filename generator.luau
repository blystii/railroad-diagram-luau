local fs = require("@lune/fs")

local function betterFind(t, f)
	for i, v in t do
		if f(v) then return i end
	end
	return nil
end

local function writeToFile(file, content, no_tab)
	if #content == 0 then return end
	content = if type(content) == "string" then content else table.concat(content, "\n" .. (if no_tab then "" else "\t")) .. "\n"
	fs.writeFile(file, fs.readFile(file) .. (if no_tab then "" else "\t") .. tostring(content) .. "\n")
end

local function restructureTable(t)
    local new_t = {}
    for _, v in t do
        table.insert(new_t, v)
    end
    return new_t
end

local out = ""
local open_file = false

local generator = {}

generator.properties = {
	canvas_size = { x = 1000, y = 1000 },
	min_size = { x = 20, y = 20 },
	arrows = true,
    title = "",
    corner_radius = 5,
    thickness = 1
}

local code = {}

local char_width = 7.7
local function getTextWidth(text, min_width)
	local width = math.ceil((#text * char_width + 4) / 20) * 20
	return if width >= (min_width or 0) then width else min_width
end

local function refreshCode(n)
    code[n.code] = {
		`<rect x="{n.x1}" y="{n.y}" width="{n.width}" height="{n.height}"{if n.class == "terminal" then ` rx="{generator.properties.corner_radius}"` else ""} fill="white" stroke="black"/>`,
		`<text x="{n.mx}" y="{n.my + 5}" text-anchor="middle"{if n.class == "terminal" then "" else ' font-weight="bold"'}>{n.text}</text>`
	}
    if n.class == "ends" then
        local found_code = code[n.code]
        found_code[1] = `<rect x="{n.x1}" y="{n.y}" width="1" height="20" fill="black"/>`
        found_code[2] = if n.text then `<text x="{n.x1 + 3}" y="{n.y + 1.5}" font-weight="bold">{n.text}</text>` else nil
    end
end

local nodes = {}

local lines = {}

local function newNode(class, components, original)
	local text = components.text
	local min_size = components.min_size
	if type(text) ~= "string" then
		error(`invalid text; expected string, got {type(text)} '{text}'`)
	end
	local width = getTextWidth(text, min_size.x)
	local height = min_size.y
	local last_node = nodes[#nodes]
	local x1 = last_node.x2 + 10
	local x2 = x1 + width
	local mx = (x1 + x2) / 2
	local y = last_node.y
	local my = height / 2 + y
	table.insert(code, {
		`<rect x="{x1}" y="{y}" width="{width}" height="{height}"{if class == "terminal" then ` rx="{generator.properties.corner_radius}"` else ""} fill="white" stroke="black"/>`,
		`<text x="{mx}" y="{my + 5}" text-anchor="middle"{if class == "terminal" then "" else ' font-weight="bold"'}>{text}</text>`
	})
	table.insert(nodes, {
		class = class,
		text = text,
		x1 = x1,
		x2 = x2,
		mx = mx,
		y = y,
		my = my,
		width = width,
		height = height,
		code = #code,
		original = original
	})
end

local function addXOffset(n1, n2, unlocked, offset)
	if n2.x1 ~= n1.x2 + offset and unlocked then
		n2.x1 = n1.x2 + offset
		n2.x2 = n2.x1 + n2.width
		n2.mx = (n2.x1 + n2.x2) / 2
		refreshCode(n2)
	end
end
local function addYOffset(n1, n2, unlocked, offset)
	if n2.y ~= n1.y + offset and unlocked then
		n2.y = n1.y + offset
		n2.my = n2.y + n2.height / 2
		refreshCode(n2)
	end
end

local function placeArrow(n, side)
	if not generator.properties.arrows then return end
	local diff_10 = if side == "left" then n.x2 + 10 else n.x1 - 10
	return `<polygon points="{diff_10},{n.my - 5} {if side == "left" then n.x2 else n.x1},{n.my} {diff_10},{n.my + 5}"/>`
end

local function getHalfDistance(n1, n2)
	return (n2.x1 - n1.x2) / 2
end

local ends = {
    _start = {
        node = 0,
        used = false
    },
    _end = {
        node = 0,
        used = false
    }
}
local function insertEnds(title, end_type)
    title = if title and #title > 0 then title else nil
	local original = {}
	function original:connect(n2: {}, direction: string?, length: number?, inverted: boolean?)
		generator.insert("line", { n1 = original, n2 = n2, direction = direction or "s", length = length or 1, inverted = inverted or false }, original)
	end
	table.insert(code, {
		`<rect x="14" y="15" width="1" height="20" fill="black"/>`,
        if title then `<text x="17" y="13.5" font-weight="bold">{title}</text>` else nil
	})
	table.insert(nodes, {
		class = "ends",
        end_type = end_type,
        text = title,
		x1 = 14,
		x2 = 15,
		mx = 14.5,
		y = 15,
		my = 25,
		width = 1,
		height = 20,
		code = #code,
		original = original
	})
    ends[`_{end_type}`].node = #nodes
	return original
end

local function straight(n1, n2, length, inverted, original, unlocked, forward)
	local x_length = 40
	if length ~= 1 then
		x_length *= length
	end
    if not forward then
        x_length = -x_length - n1.width - n2.width
    end
	addXOffset(n1, n2, unlocked, x_length)
	addYOffset(n1, n2, unlocked, 0)
	table.insert(code, {
		`<line x1="{if forward then n1.x2 else n1.x1}" y1="{n1.my}" x2="{if forward then n2.x1 else n2.x2}" y2="{n2.my}" stroke="black"/>`,
		placeArrow(n2, if forward then nil else "left")
	})
	table.insert(lines, {
		code = #code,
		original = original
	})
end

local function up(n1, n2, length, inverted, original, unlocked, forward)
	local y_length = -40
	if length ~= 1 then
		y_length *= length
	end
	if forward then
		addXOffset(n1, n2, unlocked, 40)
	else
		addXOffset(n1, n2, unlocked, -n1.width)
	end
	addYOffset(n1, n2, unlocked, y_length)
	y_length += 10
	local half_distance = getHalfDistance(n1, n2) - 5
	local x2 = n1.x2
	local my = n1.my
	table.insert(code, {
		`<path d="M{x2},{my} l{half_distance},0 q5,0 5,-5 l0,{y_length} q0,-5 5,-5 l{half_distance},0" fill="transparent" stroke="black"/>`,
		placeArrow(n2, if forward then nil else "left")
	})
    if not forward then
        code[#code][1] = `<path d="M{x2},{my} l{-half_distance},0 q5,0 5,-5 l0,{y_length} q0,-5 -5,-5 l{half_distance},0" fill="transparent" stroke="black"/>`
    end
	table.insert(lines, {
		code = #code,
		original = original
	})
end

local function down(n1, n2, length, inverted, original, unlocked, forward)
    local corner = generator.properties.corner_radius
	local y_length = 40
	if length ~= 1 then
		y_length *= length
	end
	if forward then
        addXOffset(n1, n2, unlocked, 40)
    else
		addXOffset(n1, n2, unlocked, -n1.width)
    end
	addYOffset(n1, n2, unlocked, y_length)
	y_length -= 10
	local half_distance = getHalfDistance(n1, n2) - corner
    local x2 = n1.x2
    local my = n1.my
	table.insert(code, {
		`<path d="M{x2},{my} l{half_distance},0 q{corner},0 {corner},{corner} l0,{y_length} q0,{corner} {corner},{corner} l{half_distance},0" fill="transparent" stroke="black"/>`,
		placeArrow(n2, if forward then nil else "left")
	})
    if not forward then
        code[#code][1] = `<path d="M{x2},{my} l{-half_distance},0 q{corner},0 {corner},{corner} l0,{y_length} q0,{corner} -{corner},{corner} l{half_distance},0" fill="transparent" stroke="black"/>`
    end
	table.insert(lines, {
		code = #code,
		original = original
	})
end

local function reversePath(path, axis)
    local reversed = ""
    for instr, arg1, arg2, arg3, arg4 in path:gmatch("(%w)([%d-]*),?([%d-]*)%s?([%d-]*),?([%d-]*)") do
        arg1, arg2, arg3, arg4 = tonumber(arg1), tonumber(arg2), tonumber(arg3), tonumber(arg4)
        if axis == "x" then arg1, arg3 = -arg1, arg3 and -arg3 end
        if axis == "y" then arg2, arg4 = -arg2, arg4 and -arg4 end
        reversed ..= `{instr}{arg1},{arg2}` .. if arg3 then ` {arg3},{arg4} ` else " "
    end
    return reversed:sub(1, -2)
end

local sequenced_directions = {
	s = function(pos, length, forward)
		local x_length = 40
        if not forward then x_length = -x_length end
        x_length = if pos.forward then x_length else -x_length
		if length ~= 1 then x_length *= length end
		return `l{x_length},0`, { x = pos.x + x_length, y = pos.y, forward = if forward then pos.forward else not pos.forward }
	end,
	u = function(pos, length, forward, corner)
        local y_length = -40
        local x_offset = if pos.forward then 40 else -40
		if length ~= 1 then y_length *= length end
        local x_length = 20 - corner
	    local y_offset = y_length + corner * 2
        local ret_code, ret_pos = `l{x_length},0 q{corner},0 {corner},-{corner} l0,{y_offset} q0,-{corner} {corner},-{corner} l{x_length},0`, { x = pos.x + x_offset, y = pos.y + y_length, forward = pos.forward }
        if not forward then ret_code, ret_pos =`l{x_length},0 q{corner},0 {corner},-{corner} l0,{y_offset} q0,-{corner} -{corner},-{corner} l-{x_length},0`, { x = pos.x, y = pos.y + y_length, forward = not pos.forward } end
		if not pos.forward then ret_code = reversePath(ret_code, "x") end
        return ret_code, ret_pos
	end,
	d = function(pos, length, forward, corner)
		local y_length = 40
        local x_offset = if pos.forward then 40 else -40
		if length ~= 1 then y_length *= length end
        local x_length = 20 - corner
        local y_offset = y_length - corner * 2
        local ret_code, ret_pos = `l{x_length},0 q{corner},0 {corner},{corner} l0,{y_offset} q0,{corner} {corner},{corner} l{x_length},0`, { x = pos.x + x_offset, y = pos.y + y_length, forward = pos.forward }
        if not forward then ret_code, ret_pos =`l{x_length},0 q{corner},0 {corner},{corner} l0,{y_offset} q0,{corner} -{corner},{corner} l-{x_length},0`, { x = pos.x, y = pos.y + y_length, forward = not pos.forward } end
		if not pos.forward then ret_code = reversePath(ret_code, "x") end
        return ret_code, ret_pos
	end
}

local function directionSequence(sequence, n1, n2, length, inverted, original, unlocked)
	local n_sequence = {}
	local sequence_len = #sequence
	for i = 1, sequence_len * length do
		table.insert(n_sequence, sequence[(i - 1) % sequence_len + 1])
	end
	local x2 = n1.x2
	local my = n1.my
	local direction_code = ""
	local pos = {
		x = if n_sequence[1].direction == "S" then n1.x1 else x2,
		y = my - n2.height / 2,
        forward = true
	}
	local final_code = `<path d=\"M{pos.x},{my}`
	for _, v in n_sequence do
        local lowered = v.direction:lower()
		direction_code, pos = sequenced_directions[lowered](pos, v.length, v.direction == lowered, generator.properties.corner_radius)
		final_code ..= ` {direction_code}`
	end
    local thickness = generator.properties.thickness
	final_code ..= '" fill="transparent" stroke="black"' .. if thickness ~= 1 then ` stroke-width="{thickness}"/>` else "/>"
    if unlocked then
		n2.x1 = pos.x
    end
    if unlocked and not pos.forward then
        n2.x1 -= n2.width
    end
    if unlocked then
		n2.x2 = n2.x1 + n2.width
		n2.mx = n2.x1 + n2.width / 2
		n2.y = pos.y
		n2.my = n2.y + n2.height / 2
    end
	refreshCode(n2)
	table.insert(code, {
		final_code,
		placeArrow(n2, if pos.forward then "right" else "left")
	})
	table.insert(lines, {
		code = #code,
		original = original,
	})
end

local directions = {
	s = straight,
	u = up,
	d = down
}

local function getDirectionSequence(direction)
	local seq = {}
	local skip_ind = 0
	for i = 1, #direction do
		if i <= skip_ind then continue end
		local char = direction:sub(i, i)
		local plus_1 = i + 1
		if not directions[char:lower()] then error(`unknown direction '{char}'`) end
		local is_number = tonumber(direction:sub(plus_1, plus_1))
		local found_non_digit = (direction:find("[^%d%.]", plus_1) or #direction + 1) - 1
		local length = if is_number then direction:sub(plus_1, found_non_digit) else 1
		if select(2, tostring(length):gsub("%.", "")) > 1 then error(`malformed number '{length}'`) end
		skip_ind = if is_number then found_non_digit else 0
		table.insert(seq, { direction = char, length = tonumber(length) })
	end
	return seq
end

local function newLine(class, components, original)
	local direction = components.direction
	local direction_sequence = getDirectionSequence(direction)
	local length = components.length
	if type(length) ~= "number" or length <= 0 then
		error(`invalid length; length '{length}' cannot be inferior or equal to 0`)
	elseif length <= 0 then
		error(`invalid length; expected number, got {type(length)} '{length}'`)
	end
	local n1 = nodes[betterFind(nodes, function(v)
		return v.original == components.n1
	end)] or error("unknown node 1")
	local n2 = nodes[betterFind(nodes, function(v)
		return v.original == components.n2
	end)] or error("unknown node 2")
    if n1.class == "ends" then
        ends[`_{n1.end_type}`].used = true
    end
    if n2.class == "ends" then
		ends[`_{n2.end_type}`].used = true
    end
    --[[
	if #direction == 1 then
		directions[direction:lower()](n1, n2, length, inverted, original, not n2.locked, direction == direction:lower())
		return
	end
    ]]
	directionSequence(direction_sequence, n1, n2, length, nil, original, not n2.locked)
end

function generator.setup(path, properties: { canvas_size: { x: number?, y: number? }?, min_size: { x: number?, y: number? }?, arrows: boolean?, title: string?, corner_radius: number?, thickness: number? }?)
    if open_file then error("attempt to setup new file while another one is open") end
    local global_props = generator.properties
	global_props.canvas_size = if properties then properties.canvas_size or global_props.canvas_size else global_props.canvas_size
	global_props.min_size = if properties then properties.min_size or global_props.min_size else global_props.min_size
	global_props.arrows = if properties then if properties.arrows ~= nil then properties.arrows else global_props.arrows else global_props.arrows
    global_props.title = if properties then properties.title or global_props.title else global_props.title
    global_props.corner_radius = if properties then properties.corner_radius or global_props.corner_radius else global_props.corner_radius
    global_props.thickness = if properties then properties.thickness or global_props.thickness else global_props.thickness
    out = path
	fs.writeFile(out, "")
	writeToFile(out, `<svg viewBox="0 0 {global_props.canvas_size.x} {global_props.canvas_size.y}" xmlns="http://www.w3.org/2000/svg" font-family="Consolas">\n`, true)
    open_file = true
	return insertEnds(global_props.title, "start"), insertEnds(nil, "end")
end

local classes = {
	["terminal"] = newNode,
	["nonterminal"] = newNode,
	["line"] = newLine
}
function generator.insert(class, components, original)
	classes[class](class, components, original)
end

function generator.remove(thing)
	local target_table = if thing.class == "line" then lines else nodes
	local ind = betterFind(target_table, function(v)
		return v.original == thing
	end)
	code[target_table[ind].code] = {}
	table.remove(target_table, ind)
end

function generator.lockNode(node)
	local found_node = nodes[betterFind(nodes, function(v)
		return v.original == node
	end)]
	node.locked, found_node.locked = true, true
end

function generator.endFile()
    if not open_file then error("attempt to end file never setup") end
    for _, v in ends do
        if not v.used then
            code[v.node] = nil
            nodes[v.node] = nil
        end
    end
    code = restructureTable(code)
	for i = 1, #code do
		writeToFile(out, code[#code - i + 1])
	end
	writeToFile(out, "</svg>", true)
    open_file = false
end

return generator
