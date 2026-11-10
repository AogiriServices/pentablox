--[[
	Pentablox - Spec Menu
	======================
	A Roblox executor script that builds a menu using the Vantura UI library
	(https://github.com/Femfus/menu-lib) and lets you shift the player's HEAD
	and BODY parts live using CFrame offsets.

	Toggle the menu with the DELETE key.

	Why CFrame changes need a loop:
	  Roblox re-applies character physics/animation every frame, so a one-time
	  head.CFrame = ... gets overwritten within a frame. To keep the offset
	  ("desync") alive we re-apply it on RenderStepped.

	Debug visualization:
	  The "Show Desync" button renders a red wireframe SelectionBox + a live
	  BillboardGui readout on each affected part, so you can actually SEE where
	  the fake offset is pointing (from your own camera, where you normally
	  can't see your own head/torso moving).
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ---------------------------------------------------------------------------
-- Load the Vantura menu library (from GitHub, with a local fallback)
-- ---------------------------------------------------------------------------

local Vantura
local ok, err = pcall(function()
	Vantura = loadstring(game:HttpGet(
		"https://raw.githubusercontent.com/Femfus/menu-lib/main/library.lua?t=" .. os.time()))()
end)
if not ok or not Vantura then
	warn("[Pentablox] Failed to load Vantura lib:", tostring(err))
	return
end

-- ---------------------------------------------------------------------------
-- CFrame spec offsets
-- ---------------------------------------------------------------------------

local MAX_STUDS = 6

local OFFSETS = {
	HeadX  = 0, HeadY  = 0, HeadZ  = 0,
	BodyX  = 0, BodyY  = 0, BodyZ  = 0,
}

-- Which parts carry which offsets, and how to find them per rig.
local PARTS = {
	{ name = "Head",   find = function(c) return c:FindFirstChild("Head")   end, offset = "Head"  },
	{ name = "Body",   find = function(c)
		if c:FindFirstChild("UpperTorso") then return c:FindFirstChild("UpperTorso") end
		if c:FindFirstChild("Torso")        then return c:FindFirstChild("Torso")        end
		return nil end, offset = "Body" },
}

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

-- Applies every stored offset as a CFrame relative to the part's parent,
-- which keeps the parts attached for both R6 and R15. Called every frame.
local function applySpecs()
	local char = getCharacter()
	if not char then return end

	for _, spec in ipairs(PARTS) do
		local part = spec:find(char)
		if part and part.Parent then
			local off = OFFSETS[spec.offset .. "X"]
				* Vector3.new(1, 0, 0)
			+ OFFSETS[spec.offset .. "Y"]
				* Vector3.new(0, 1, 0)
			+ OFFSETS[spec.offset .. "Z"]
				* Vector3.new(0, 0, 1)
			part.CFrame = part.Parent.CFrame * CFrame.new(off)
		end
	end
end

-- Continuous loop so the offset survives physics/animation each frame.
RunService.RenderStepped:Connect(applySpecs)

-- ---------------------------------------------------------------------------
-- Debug visualization: show where the fake desync is
-- ---------------------------------------------------------------------------

local debugEnabled = false
local debugObjects = {}

local function makeReadout(name, offsetKey)
	local bg = Instance.new("BillboardGui")
	bg.Name = name .. "_Readout"
	bg.AlwaysOnTop = true
	bg.Size = UDim2.new(0, 180, 0, 48)
	bg.StudsOffset = Vector3.new(0, 2.5, 0)
	bg.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(220, 38, 38)
	stroke.Thickness = 1
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -8, 0, 20)
	title.Position = UDim2.new(0, 6, 0, 3)
	title.BackgroundTransparency = 1
	title.Text = name
	title.TextColor3 = Color3.fromRGB(255, 90, 90)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.new(1, -8, 0, 24)
	value.Position = UDim2.new(0, 6, 0, 24)
	value.BackgroundTransparency = 1
	value.TextColor3 = Color3.fromRGB(220, 220, 220)
	value.Font = Enum.Font.GothamMono
	value.TextSize = 11
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Parent = frame

	bg.Parent = part -- set below once we have the part
	return bg, value, frame
end

local function enableDebug()
	debugEnabled = true
	local char = getCharacter()

	for _, spec in ipairs(PARTS) do
		local part = spec:find(char)
		if not part then continue end

		-- Wireframe showing the part's actual bounds (the desync position).
		local box = Instance.new("SelectionBox")
		box.Name = spec.name .. "_Box"
		box.Color3 = Color3.fromRGB(220, 38, 38)
		box.LineThickness = 0.03
		box.Adornee = part
		box.Visible = true
		box.Parent = part

		-- Live readout of the current offset + world position.
		local bg, value, frame = makeReadout(spec.name, spec.offset)
		bg.Adornee = part
		table.insert(debugObjects, box)
		table.insert(debugObjects, { bg = bg, value = value, name = spec.name })
	end
end

local function disableDebug()
	debugEnabled = false
	for _, obj in ipairs(debugObjects) do
		if obj.Parent then
			obj:Destroy()
		end
	end
	debugObjects = {}
end

-- ---------------------------------------------------------------------------
-- Custom slider widget (the Vantura lib ships without sliders)
-- ---------------------------------------------------------------------------

local UserInput = game:GetService("UserInputService")

local function buildSlider(tab, name, value, callback)
	value = value or 0

	local el = Instance.new("Frame")
	el.Size = UDim2.new(1, -6, 0, 40)
	el.BackgroundColor3 = Color3.fromRGB(24, 24, 26)
	el.BackgroundTransparency = 0.15
	el.BorderSizePixel = 0
	el.Parent = tab.Page

	local elCorner = Instance.new("UICorner")
	elCorner.CornerRadius = UDim.new(0, 3)
	elCorner.Parent = el

	local elStroke = Instance.new("UIStroke")
	elStroke.Color = Color3.fromRGB(36, 36, 40)
	elStroke.Thickness = 1
	elStroke.Parent = el

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0.4, 0, 1, 0)
	titleLabel.Position = UDim2.new(0, 12, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = name
	titleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	titleLabel.Font = Enum.Font.GothamMedium
	titleLabel.TextSize = 12
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = el

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.3, 0, 0.5, 0)
	valueLabel.Position = UDim2.new(1, -132, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = string.format("%+.2f", value)
	valueLabel.TextColor3 = Color3.fromRGB(220, 38, 38)
	valueLabel.Font = Enum.Font.GothamMedium
	valueLabel.TextSize = 11
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.Parent = el

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0.5, -10, 0, 6)
	bar.Position = UDim2.new(0.4, 12, 0, 24)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	bar.BorderSizePixel = 0
	bar.Parent = el

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0.5, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local knob = Instance.new("TextButton")
	knob.Text = ""
	knob.Size = UDim2.fromOffset(14, 14)
	knob.Position = UDim2.new(0.5, -7, 0.5, -7)
	knob.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
	knob.BorderSizePixel = 0
	knob.Parent = bar

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0, 2)
	knobCorner.Parent = knob

	local dragging = false
	local value2 = 0

	local function apply(v)
		value2 = math.clamp(v, -1, 1)
		valueLabel.Text = string.format("%+.2f", value2)
		if value2 >= 0 then
			fill.Position = UDim2.new(0.5, 0, 0, 0)
			fill.Size = UDim2.new(0.5 * value2, 0, 1, 0)
		else
			fill.Position = UDim2.new(0.5 + value2 * 0.5, 0, 0, 0)
			fill.Size = UDim2.new(-value2 * 0.5, 0, 1, 0)
		end
		knob.Position = UDim2.new(0.5 + value2 * 0.5, -7, 0.5, -7)
		callback(name, value2 * MAX_STUDS)
	end

	apply(0)

	knob.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	knob.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	bar.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			apply((inp.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
			dragging = true
		end
	end)

	UserInput.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			apply((inp.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X)
		end
	end)

	return {
		Set = function(v) apply(v / MAX_STUDS) end,
		Get = function() return value2 * MAX_STUDS end,
	}
end

-- ---------------------------------------------------------------------------
-- Build the menu
-- ---------------------------------------------------------------------------

local GUI = Vantura:Create({
	Name = "Pentablox",
	Size = UDim2.fromOffset(660, 480),
})

local specsTab = GUI:Tab({
	Name = "Specs",
	Icon = "https://raw.githubusercontent.com/Femfus/menu-lib/main/icons/aimbot.png",
})

buildSlider(specsTab, "Head X", OFFSETS.HeadX, function(k, v) OFFSETS[k] = v end)
buildSlider(specsTab, "Head Y", OFFSETS.HeadY, function(k, v) OFFSETS[k] = v end)
buildSlider(specsTab, "Head Z", OFFSETS.HeadZ, function(k, v) OFFSETS[k] = v end)
buildSlider(specsTab, "Body X", OFFSETS.BodyX, function(k, v) OFFSETS[k] = v end)
buildSlider(specsTab, "Body Y", OFFSETS.BodyY, function(k, v) OFFSETS[k] = v end)
buildSlider(specsTab, "Body Z", OFFSETS.BodyZ, function(k, v) OFFSETS[k] = v end)

specsTab:Button({
	Name = "Show / Hide Desync",
	Description = "Wireframe + live position readout on each part.",
	Callback = function()
		if debugEnabled then
			disableDebug()
		else
			enableDebug()
		end
	end,
})

specsTab:Button({
	Name = "Reset Spec Offsets",
	Description = "Moves every part back to its default CFrame.",
	Callback = function()
		for k in pairs(OFFSETS) do OFFSETS[k] = 0 end
		GUI:Notification({
			Name = "Specs Reset",
			Description = "All offsets returned to zero.",
			Duration = 3,
		})
	end,
})

GUI:Notification({
	Name = "Pentablox Ready",
	Description = "Press DELETE to toggle this menu.",
	Duration = 5,
})

-- ---------------------------------------------------------------------------
-- DELETE key toggle
-- ---------------------------------------------------------------------------

local DELETE_KEY = Enum.KeyCode["Delete"] or Enum.KeyCode.Delete

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == DELETE_KEY then
		GUI.ScreenGui.Enabled = not GUI.ScreenGui.Enabled
	end
end)

print("[Pentablox] Spec menu initialized. Toggle with DELETE.")
