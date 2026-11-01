--- @since 26.9.1
local M = {}

local function extractor_path()
	local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
	return config_home .. "/yazi/plugins/xlsx-text.yazi/extract.py"
end

local function extract_text(job)
	local output, err = Command("python")
		:arg({ extractor_path(), tostring(job.file.url) })
		:output()
	if err then
		return nil, tostring(err)
	end
	if not output.status.success then
		return nil, output.stderr ~= "" and output.stderr or "Excel extraction failed"
	end
	return output.stdout
end

local function visible_lines(text, skip, height)
	local lines = {}
	local first = skip + 1
	local last = skip + height
	local index = 0

	for line in (text .. "\n"):gmatch("(.-)\n") do
		index = index + 1
		if index >= first and index <= last then
			lines[#lines + 1] = line
		end
		if index >= last then
			break
		end
	end

	return table.concat(lines, "\n")
end

function M:peek(job)
	local text, err = extract_text(job)
	if not text then
		require("empty").msg(job, err)
		return
	end

	local visible = visible_lines(text, job.skip, job.area.h)
	if visible == "" and job.skip == 0 then
		visible = "No cell values found in this workbook."
	end

	ya.preview_widget(job, ui.Text(visible):area(job.area):wrap(ui.Wrap.NO))
end

function M:seek(job)
	local hovered = cx.active.current.hovered
	if not hovered or hovered.url ~= job.file.url then
		return
	end

	local step = math.floor(job.units * job.area.h / 10)
	step = step == 0 and ya.clamp(-1, job.units, 1) or step
	ya.emit("peek", {
		math.max(0, cx.active.preview.skip + step),
		only_if = job.file.url,
	})
end

return M
