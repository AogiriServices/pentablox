--[[
	Pentablox - Spec Menu
	======================
	A Roblox executor script that builds a menu using the Vantura UI library
	(https://github.com/Femfus/menu-lib) and lets you shift the player's HEAD
	and BODY parts live using CFrame offsets.

	Toggle the menu with the DELETE key.
	Every slider value is applied as a CFrame translation on the affected part.

	Load it inside an executor with:
	  local spec = loadstring(game:HttpGet("https://raw.githubusercontent.com/AogiriServices/pentablox/main/specMenu.lua"))()
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

-- Names of the parts we can move. On R6 it's "Torso"; on R15 it's "UpperTorso".
local OFFSETS = {
	HeadX  = 0, HeadY  = 0, HeadZ  = 0,
	BodyX  = 0, BodyY  = 0, BodyZ  = 0,
}

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

-- R15 -> UpperTorso, R6 -> Torso.
local function getBodyPart()
	local char = getCharacter()
	if char:FindFirstChild("UpperTorso") then return char:FindFirstChild("UpperTorso") end
	if char:FindFirstChild("Torso") then return char:FindFirstChild("Torso") end
	return nil
end

-- Applies every stored offset as a CFrame relative to the part's parent,
-- which keeps the parts attached for both R6 and R15.
local function applySpecs()
	local char = getCharacter()
	local head = char:FindFirstChild("Head")
	local body = getBodyPart()

	if head and head.Parent then
		head.CFrame = head.Parent.CFrame * CFrame.new(OFFSETS.HeadX, OFFSETS.HeadY, OFFSETS.HeadZ)
	end

	if body and body.Parent then
		body.CFrame = body.Parent.CFrame * CFrame.new(OFFSETS.BodyX, OFFSETS.BodyY, OFFSETS.BodyZ)
	end
end

-- Re-apply after every respawn so the offsets stick to the new rig.
player.CharacterAdded:Connect(function(char)
	RunService.RenderStepped:Wait() -- let the rig finish assembling
	applySpecs()
end)

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

	-- Slider track
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
	Size = UDim2.fromOffset(640, 440),
})

local specsTab = GUI:Tab({
	Name = "Specs",
	Icon = "https://raw.githubusercontent.com/Femfus/menu-lib/main/icons/aimbot.png",
})

-- Head sliders
buildSlider(specsTab, "Head X", OFFSETS.HeadX, function(k, v) OFFSETS[k] = v; applySpecs() end)
buildSlider(specsTab, "Head Y", OFFSETS.HeadY, function(k, v) OFFSETS[k] = v; applySpecs() end)
buildSlider(specsTab, "Head Z", OFFSETS.HeadZ, function(k, v) OFFSETS[k] = v; applySpecs() end)

-- Body sliders
buildSlider(specsTab, "Body X", OFFSETS.BodyX, function(k, v) OFFSETS[k] = v; applySpecs() end)
buildSlider(specsTab, "Body Y", OFFSETS.BodyY, function(k, v) OFFSETS[k] = v; applySpecs() end)
buildSlider(specsTab, "Body Z", OFFSETS.BodyZ, function(k, v) OFFSETS[k] = v; applySpecs() end)

-- Reset button
specsTab:Button({
	Name = "Reset Spec Offsets",
	Description = "Moves every part back to its default CFrame.",
	Callback = function()
		for k in pairs(OFFSETS) do OFFSETS[k] = 0 end
		applySpecs()
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

-- Bracket lookup so it resolves on older Roblox clients too.
local DELETE_KEY = Enum.KeyCode["Delete"] or Enum.KeyCode.Delete

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == DELETE_KEY then
		local enabled = not GUI.ScreenGui.Enabled
		GUI.ScreenGui.Enabled = enabled
		if enabled then
			applySpecs()
		end
	end
end)

-- Apply once the character exists.
local char = getCharacter()
if char then
	RunService.RenderStepped:Wait()
	applySpecs()
end

print("[Pentablox] Spec menu initialized. Toggle with DELETE.")
