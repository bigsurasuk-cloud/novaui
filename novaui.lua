--[[
	NovaUI v1.0.0  |  Roblox Luau UI Library
	--------------------------------------------------------------------
	วิธีใช้: วางไฟล์นี้เป็น ModuleScript (เช่น ReplicatedStorage > NovaUI)
	แล้ว require จาก LocalScript  (ดูตัวอย่างใน NovaUI_Example.lua)

	ฟีเจอร์
	  - Window: ลากได้ / ย่อ / ปรับขนาด / ปุ่มลัดเปิด-ปิด / ปุ่มลอยสำหรับมือถือ
	  - Tab + Section
	  - Label, Paragraph, Divider, Button, Toggle, Slider, ProgressBar,
	    Dropdown (เลือกเดียว/หลายตัว/ค้นหาได้), Input, Keybind, ColorPicker
	  - Notification และ Dialog (popup ยืนยัน)
	  - Theme: Dark / Light / Ocean / Purple / Rose / Midnight + ธีมกำหนดเอง + SetAccent
	  - Flags + Config: Export/Import เป็น JSON (เอาไปเก็บเองได้ เช่นส่งไป DataStore ผ่าน Remote)

	API หลัก
	  Library:CreateWindow(cfg)         Library:Notify(cfg)
	  Library:SetTheme(name|table)      Library:AddTheme(name, table)
	  Library:SetAccent(Color3)         Library:GetFlag(flag) / SetFlag(flag, v)
	  Library:SaveConfig()  -> JSON     Library:LoadConfig(json|table)
	  Library:GetConfig()   -> table    Library:ResetConfig()
	  Library:Destroy()

	  Window:CreateTab(cfg)  Window:SelectTab()  Window:CreateDialog(cfg)
	  Window:Show/Hide/Toggle/Minimize/Restore/SetTitle/SetSubtitle/SetSize/
	         SetToggleKey/Notify/Destroy

	  Tab / Section:
	    CreateSection, CreateLabel, CreateParagraph, CreateDivider, CreateButton,
	    CreateToggle, CreateSlider, CreateProgressBar, CreateDropdown,
	    CreateInput, CreateKeybind, CreateColorPicker

	  ทุก Element มี: Set / Get / Reset / SetTitle / SetVisible / Destroy / SetCallback
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local TOPBAR_H = 42
local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local FONT_REG = Enum.Font.Gotham

----------------------------------------------------------------------
-- Library table + Themes
----------------------------------------------------------------------
local Library = {
	Version = "1.0.0",
	Flags = {},
	Elements = {},
	Windows = {},
	Themes = {},
	Parent = nil, -- ถ้าไม่ตั้ง จะใช้ PlayerGui
}

local function Extend(base, overrides)
	local t = table.clone(base)
	for k, v in pairs(overrides) do
		t[k] = v
	end
	return t
end

Library.Themes.Dark = {
	Background = Color3.fromRGB(22, 22, 27),
	Element = Color3.fromRGB(34, 34, 42),
	ElementHover = Color3.fromRGB(44, 44, 54),
	Stroke = Color3.fromRGB(58, 58, 70),
	Text = Color3.fromRGB(240, 240, 245),
	SubText = Color3.fromRGB(150, 150, 165),
	Accent = Color3.fromRGB(94, 129, 255),
	Success = Color3.fromRGB(80, 200, 120),
	Warning = Color3.fromRGB(245, 180, 60),
	Error = Color3.fromRGB(240, 85, 85),
	Knob = Color3.fromRGB(255, 255, 255),
}
Library.Themes.Light = Extend(Library.Themes.Dark, {
	Background = Color3.fromRGB(246, 246, 249),
	Element = Color3.fromRGB(232, 232, 238),
	ElementHover = Color3.fromRGB(221, 221, 230),
	Stroke = Color3.fromRGB(200, 200, 212),
	Text = Color3.fromRGB(28, 28, 36),
	SubText = Color3.fromRGB(105, 105, 122),
	Accent = Color3.fromRGB(70, 110, 240),
})
Library.Themes.Ocean = Extend(Library.Themes.Dark, {
	Background = Color3.fromRGB(13, 23, 33),
	Element = Color3.fromRGB(21, 37, 53),
	ElementHover = Color3.fromRGB(29, 49, 69),
	Stroke = Color3.fromRGB(41, 69, 95),
	Accent = Color3.fromRGB(0, 170, 220),
})
Library.Themes.Purple = Extend(Library.Themes.Dark, {
	Background = Color3.fromRGB(23, 17, 33),
	Element = Color3.fromRGB(37, 27, 53),
	ElementHover = Color3.fromRGB(49, 37, 70),
	Stroke = Color3.fromRGB(73, 55, 99),
	Accent = Color3.fromRGB(150, 100, 255),
})
Library.Themes.Rose = Extend(Library.Themes.Dark, {
	Background = Color3.fromRGB(29, 19, 23),
	Element = Color3.fromRGB(45, 29, 35),
	ElementHover = Color3.fromRGB(58, 38, 46),
	Stroke = Color3.fromRGB(84, 54, 64),
	Accent = Color3.fromRGB(245, 90, 130),
})
Library.Themes.Midnight = Extend(Library.Themes.Dark, {
	Background = Color3.fromRGB(9, 9, 11),
	Element = Color3.fromRGB(20, 20, 24),
	ElementHover = Color3.fromRGB(30, 30, 36),
	Stroke = Color3.fromRGB(44, 44, 52),
	Accent = Color3.fromRGB(120, 140, 255),
})

Library.Theme = Library.Themes.Dark
Library.ThemeName = "Dark"

----------------------------------------------------------------------
-- Class tables
----------------------------------------------------------------------
local Window = {}
Window.__index = Window

local Container = {}
Container.__index = Container

local Tab = setmetatable({}, { __index = Container })
Tab.__index = Tab

local Section = setmetatable({}, { __index = Container })
Section.__index = Section

local Element = {}
Element.__index = Element

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function Tween(inst, props, time, style, dir)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

-- ระบบธีม: เก็บว่า Instance ไหน property ไหน ใช้สีคีย์ไหน เพื่อเปลี่ยนธีมสดได้
local Themed = setmetatable({}, { __mode = "k" })

local function SetThemed(inst, prop, key, time)
	local map = Themed[inst]
	if not map then
		map = {}
		Themed[inst] = map
	end
	map[prop] = key
	local value = Library.Theme[key]
	if time and time > 0 then
		Tween(inst, { [prop] = value }, time)
	else
		inst[prop] = value
	end
end

local function Apply(inst, map)
	for prop, key in pairs(map) do
		SetThemed(inst, prop, key)
	end
end

local function RefreshTheme()
	for inst, map in pairs(Themed) do
		for prop, key in pairs(map) do
			local value = Library.Theme[key]
			if value ~= nil then
				pcall(function()
					inst[prop] = value
				end)
			end
		end
	end
end

local function New(class, props, children)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function Corner(parent, radius)
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

local function Stroke(parent, key, thickness)
	local s = New("UIStroke", {
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	Apply(s, { Color = key or "Stroke" })
	return s
end

local function Pad(parent, l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t or l),
		PaddingRight = UDim.new(0, r or l),
		PaddingBottom = UDim.new(0, b or t or l),
		Parent = parent,
	})
end

local function List(parent, padding)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

-- colorKey = false -> ไม่ผูกกับธีม (ตั้งสีเองได้)
local function Label(parent, props, colorKey)
	local l = New("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	if colorKey ~= false then
		Apply(l, { TextColor3 = colorKey or "Text" })
	end
	l.Parent = parent
	return l
end

local function Hit(parent, height)
	return New("TextButton", {
		Name = "Hit",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = height and UDim2.new(1, 0, 0, height) or UDim2.fromScale(1, 1),
		Parent = parent,
	})
end

local function SafeCall(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[NovaUI] Callback error: " .. tostring(err))
	end
end

local function NextOrder(container)
	container._order = (container._order or 0) + 1
	return container._order
end

local function IsPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function GetParent()
	return Library.Parent or LocalPlayer:WaitForChild("PlayerGui")
end

-- ลากหน้าต่าง/ปุ่ม
local function MakeDraggable(window, handle, target)
	local state = { Moved = false }
	local dragging, dragStart, startPos = false, nil, nil

	handle.InputBegan:Connect(function(input)
		if IsPointer(input) then
			dragging = true
			state.Moved = false
			dragStart = input.Position
			startPos = target.Position
		end
	end)
	window:_connect(UserInputService.InputChanged, function(input)
		if dragging and IsMove(input) then
			local delta = input.Position - dragStart
			if delta.Magnitude > 4 then
				state.Moved = true
			end
			target.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
	window:_connect(UserInputService.InputEnded, function(input)
		if IsPointer(input) then
			dragging = false
		end
	end)
	return state
end

-- ลากค่า (slider, color picker) onUpdate(Vector3 position)
local function BindDrag(window, gui, scroller, onUpdate)
	local dragging = false
	gui.InputBegan:Connect(function(input)
		if IsPointer(input) then
			dragging = true
			if scroller then
				scroller.ScrollingEnabled = false
			end
			onUpdate(input.Position)
		end
	end)
	window:_connect(UserInputService.InputChanged, function(input)
		if dragging and IsMove(input) then
			onUpdate(input.Position)
		end
	end)
	window:_connect(UserInputService.InputEnded, function(input)
		if dragging and IsPointer(input) then
			dragging = false
			if scroller then
				scroller.ScrollingEnabled = true
			end
		end
	end)
end

----------------------------------------------------------------------
-- Config serialize
----------------------------------------------------------------------
local function Serialize(v)
	local t = typeof(v)
	if v == nil then
		return { __t = "Nil" }
	elseif t == "Color3" then
		return { __t = "Color3", hex = v:ToHex() }
	elseif t == "EnumItem" then
		return { __t = "Enum", enum = tostring(v.EnumType), name = v.Name }
	elseif t == "table" then
		local out = {}
		for i, x in ipairs(v) do
			out[i] = Serialize(x)
		end
		return out
	end
	return v
end

local function Deserialize(v)
	if type(v) == "table" then
		if v.__t == "Nil" then
			return nil
		elseif v.__t == "Color3" then
			return Color3.fromHex(v.hex)
		elseif v.__t == "Enum" then
			local ok, item = pcall(function()
				return Enum[v.enum][v.name]
			end)
			return ok and item or nil
		end
		local out = {}
		for i, x in ipairs(v) do
			out[i] = Deserialize(x)
		end
		return out
	end
	return v
end

----------------------------------------------------------------------
-- Library-level API
----------------------------------------------------------------------
function Library:SetTheme(theme)
	if type(theme) == "string" then
		local t = self.Themes[theme]
		if not t then
			warn("[NovaUI] ไม่พบธีมชื่อ: " .. theme)
			return false
		end
		self.Theme = t
		self.ThemeName = theme
	elseif type(theme) == "table" then
		self.Theme = Extend(self.Theme, theme)
		self.ThemeName = "Custom"
	else
		return false
	end
	RefreshTheme()
	return true
end

function Library:AddTheme(name, theme)
	self.Themes[name] = Extend(self.Themes.Dark, theme)
end

function Library:GetThemeNames()
	local names = {}
	for name in pairs(self.Themes) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Library:SetAccent(color)
	self.Theme = Extend(self.Theme, { Accent = color })
	RefreshTheme()
end

function Library:GetFlag(flag)
	return self.Flags[flag]
end

function Library:SetFlag(flag, value, silent)
	local el = self.Elements[flag]
	if el and el.Set then
		el:Set(value, silent)
		return true
	end
	return false
end

function Library:GetConfig()
	local data = {}
	for flag, el in pairs(self.Elements) do
		if el.Get then
			data[flag] = Serialize(el:Get())
		end
	end
	return data
end

function Library:SaveConfig()
	return HttpService:JSONEncode(self:GetConfig())
end

function Library:LoadConfig(data)
	if type(data) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(data)
		end)
		if not ok then
			warn("[NovaUI] Config JSON ไม่ถูกต้อง")
			return 0
		end
		data = decoded
	end
	if type(data) ~= "table" then
		return 0
	end
	local count = 0
	for flag, raw in pairs(data) do
		local el = self.Elements[flag]
		if el and el.Set then
			local ok, err = pcall(function()
				el:Set(Deserialize(raw))
			end)
			if ok then
				count = count + 1
			else
				warn("[NovaUI] โหลด config ไม่สำเร็จที่ " .. tostring(flag) .. ": " .. tostring(err))
			end
		end
	end
	return count
end

function Library:ResetConfig()
	for _, el in pairs(self.Elements) do
		el:Reset()
	end
end

----------------------------------------------------------------------
-- Notification
----------------------------------------------------------------------
local notifGui, notifHolder
local notifCounter = 0

local function EnsureNotifGui()
	if notifGui and notifGui.Parent then
		return
	end
	notifGui = New("ScreenGui", {
		Name = "NovaUI_Notifications",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000,
	})
	notifGui.Parent = GetParent()
	notifHolder = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 300, 1, -32),
		Parent = notifGui,
	})
	New("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = notifHolder,
	})
end

-- cfg: { Title, Content, Duration (วินาที / false = ไม่หายเอง), Type = "Info"|"Success"|"Warning"|"Error", OnClose }
function Library:Notify(cfg)
	if type(cfg) == "string" then
		cfg = { Content = cfg }
	end
	cfg = cfg or {}
	EnsureNotifGui()
	notifCounter = notifCounter + 1

	local colorKey = ({ Info = "Accent", Success = "Success", Warning = "Warning", Error = "Error" })[cfg.Type or "Info"]
		or "Accent"
	local duration = cfg.Duration
	if duration == nil then
		duration = 4
	end

	local wrap = New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = notifCounter,
		Parent = notifHolder,
	})
	local card = New("Frame", {
		Position = UDim2.new(1, 330, 0, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Active = true,
		Parent = wrap,
	})
	Apply(card, { BackgroundColor3 = "Element" })
	Corner(card, 8)
	Stroke(card)
	Pad(card, 12, 10, 12, 10)
	List(card, 4)

	if cfg.Title then
		Label(card, {
			Text = tostring(cfg.Title),
			Font = FONT_BOLD,
			TextSize = 14,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 1,
		}, colorKey)
	end
	if cfg.Content then
		Label(card, {
			Text = tostring(cfg.Content),
			Font = FONT_REG,
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
		}, "SubText")
	end

	local fill
	if duration and duration > 0 then
		local track = New("Frame", { Size = UDim2.new(1, 0, 0, 3), LayoutOrder = 3, Parent = card })
		Apply(track, { BackgroundColor3 = "Stroke" })
		Corner(track, 2)
		fill = New("Frame", { Size = UDim2.fromScale(1, 1), Parent = track })
		Apply(fill, { BackgroundColor3 = colorKey })
		Corner(fill, 2)
	end

	local closed = false
	local handle = {}
	function handle:Close()
		if closed then
			return
		end
		closed = true
		local tw = Tween(card, { Position = UDim2.new(1, 330, 0, 0) }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			wrap:Destroy()
		end)
		SafeCall(cfg.OnClose)
	end

	card.InputBegan:Connect(function(input)
		if IsPointer(input) then
			handle:Close()
		end
	end)

	Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	if fill then
		Tween(fill, { Size = UDim2.new(0, 0, 1, 0) }, duration, Enum.EasingStyle.Linear)
		task.delay(duration, function()
			handle:Close()
		end)
	end
	return handle
end

function Library:Destroy()
	for _, win in ipairs(table.clone(self.Windows)) do
		win:Destroy()
	end
	if notifGui then
		notifGui:Destroy()
		notifGui = nil
	end
end
Library.Unload = Library.Destroy

----------------------------------------------------------------------
-- Element base
----------------------------------------------------------------------
function Element:SetVisible(v)
	self.Instance.Visible = v
end

function Element:SetTitle(t)
	if self._title then
		self._title.Text = tostring(t)
	end
end

function Element:SetCallback(fn)
	self._cfg.Callback = fn
end

function Element:Reset()
	if self.Set then
		self:Set(self._default)
	end
end

function Element:Destroy()
	if self.Flag then
		Library.Elements[self.Flag] = nil
		Library.Flags[self.Flag] = nil
	end
	self.Instance:Destroy()
end

local function NewElement(container, kind, frame, title, cfg, default)
	local el = setmetatable({
		Type = kind,
		Instance = frame,
		Window = container.Window,
		Flag = cfg.Flag,
		_title = title,
		_cfg = cfg,
		_default = default,
	}, Element)
	if cfg.Flag then
		Library.Elements[cfg.Flag] = el
		Library.Flags[cfg.Flag] = default
	end
	-- CallDefault = true -> เรียก Callback ด้วยค่าเริ่มต้นหลังสร้างเสร็จ
	if cfg.CallDefault and default ~= nil then
		task.defer(function()
			SafeCall(cfg.Callback, default)
		end)
	end
	return el
end

local function Commit(el, value, silent)
	if el.Flag then
		Library.Flags[el.Flag] = value
	end
	if not silent then
		SafeCall(el._cfg.Callback, value)
	end
end

-- สร้างกรอบ element มาตรฐาน (ชื่อ + คำอธิบายถ้ามี)
local function ElementFrame(container, cfg, opts)
	opts = opts or {}
	local hasDesc = type(cfg.Description) == "string" and cfg.Description ~= ""
	local rowH = hasDesc and 52 or 36
	local frame = New("Frame", {
		Name = tostring(cfg.Name or "Element"),
		Size = UDim2.new(1, 0, 0, rowH + (opts.Extra or 0)),
		ClipsDescendants = opts.Clip or false,
		LayoutOrder = NextOrder(container),
		Parent = container.Holder,
	})
	Apply(frame, { BackgroundColor3 = "Element" })
	Corner(frame, 6)

	local reserve = opts.Reserve or 0
	local title = Label(frame, {
		Text = tostring(cfg.Name or "Element"),
		Position = UDim2.fromOffset(12, hasDesc and 7 or 0),
		Size = UDim2.new(1, -(24 + reserve), 0, hasDesc and 18 or 36),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	if hasDesc then
		Label(frame, {
			Text = cfg.Description,
			Position = UDim2.fromOffset(12, 26),
			Size = UDim2.new(1, -(24 + reserve), 0, 16),
			Font = FONT_REG,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, "SubText")
	end
	return frame, title, rowH
end

local function HoverFx(frame, hit)
	local hovering = false
	hit.MouseEnter:Connect(function()
		hovering = true
		SetThemed(frame, "BackgroundColor3", "ElementHover", 0.12)
	end)
	hit.MouseLeave:Connect(function()
		hovering = false
		SetThemed(frame, "BackgroundColor3", "Element", 0.12)
	end)
	return function()
		return hovering
	end
end

----------------------------------------------------------------------
-- Container: Section / Label / Paragraph / Divider
----------------------------------------------------------------------
function Container:CreateSection(name)
	local frame = New("Frame", {
		Name = "Section_" .. tostring(name),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = NextOrder(self),
		Parent = self.Holder,
	})
	List(frame, 6)
	local header = Label(frame, {
		Text = tostring(name or "Section"):upper(),
		Font = FONT_BOLD,
		TextSize = 12,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 0,
	}, "Accent")

	local section = setmetatable({
		Window = self.Window,
		Page = self.Page,
		Holder = frame,
		Name = name,
		Instance = frame,
		_order = 0,
		_header = header,
	}, Section)
	return section
end

function Section:SetTitle(t)
	self._header.Text = tostring(t):upper()
end

function Section:SetVisible(v)
	self.Instance.Visible = v
end

function Container:CreateLabel(cfg)
	if type(cfg) ~= "table" then
		cfg = { Text = tostring(cfg) }
	end
	local frame = New("Frame", {
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = NextOrder(self),
		Parent = self.Holder,
	})
	Apply(frame, { BackgroundColor3 = "Element" })
	Corner(frame, 6)
	Pad(frame, 12, 9, 12, 9)
	local lbl = Label(frame, {
		Text = tostring(cfg.Text or ""),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, cfg.Color and false or "Text")
	if cfg.Color then
		lbl.TextColor3 = cfg.Color
	end

	local el = NewElement(self, "Label", frame, lbl, {}, nil)
	function el:SetText(t)
		lbl.Text = tostring(t)
	end
	function el:Get()
		return lbl.Text
	end
	return el
end

function Container:CreateParagraph(cfg)
	cfg = cfg or {}
	local frame = New("Frame", {
		Name = "Paragraph",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = NextOrder(self),
		Parent = self.Holder,
	})
	Apply(frame, { BackgroundColor3 = "Element" })
	Corner(frame, 6)
	Pad(frame, 12, 10, 12, 10)
	List(frame, 4)
	local titleLbl = Label(frame, {
		Text = tostring(cfg.Title or ""),
		Font = FONT_BOLD,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 1,
	})
	local contentLbl = Label(frame, {
		Text = tostring(cfg.Content or ""),
		Font = FONT_REG,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
	}, "SubText")

	local el = NewElement(self, "Paragraph", frame, titleLbl, {}, nil)
	function el:Set(title, content)
		if title ~= nil then
			titleLbl.Text = tostring(title)
		end
		if content ~= nil then
			contentLbl.Text = tostring(content)
		end
	end
	return el
end

function Container:CreateDivider()
	local holder = New("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundTransparency = 1,
		LayoutOrder = NextOrder(self),
		Parent = self.Holder,
	})
	local line = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = holder,
	})
	Apply(line, { BackgroundColor3 = "Stroke" })
	return NewElement(self, "Divider", holder, nil, {}, nil)
end

----------------------------------------------------------------------
-- Button
-- cfg: { Name, Description, Callback }
----------------------------------------------------------------------
function Container:CreateButton(cfg)
	if type(cfg) ~= "table" then
		cfg = { Name = tostring(cfg) }
	end
	local frame, title, rowH = ElementFrame(self, cfg, { Reserve = 30 })
	Label(frame, {
		Text = "›",
		Font = FONT_BOLD,
		TextSize = 22,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, rowH / 2),
		Size = UDim2.fromOffset(16, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, "SubText")
	local hit = Hit(frame)
	local isHovering = HoverFx(frame, hit)
	local el = NewElement(self, "Button", frame, title, cfg, nil)

	hit.MouseButton1Click:Connect(function()
		SetThemed(frame, "BackgroundColor3", "Accent", 0.06)
		task.delay(0.1, function()
			if frame.Parent then
				SetThemed(frame, "BackgroundColor3", isHovering() and "ElementHover" or "Element", 0.2)
			end
		end)
		SafeCall(cfg.Callback)
	end)

	function el:Fire()
		SafeCall(cfg.Callback)
	end
	function el:SetText(t)
		title.Text = tostring(t)
	end
	return el
end

----------------------------------------------------------------------
-- Toggle
-- cfg: { Name, Description, Default, Flag, Callback, CallDefault }
----------------------------------------------------------------------
function Container:CreateToggle(cfg)
	cfg = cfg or {}
	local state = cfg.Default == true
	local frame, title, rowH = ElementFrame(self, cfg, { Reserve = 52 })

	local track = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, rowH / 2),
		Size = UDim2.fromOffset(38, 20),
		Parent = frame,
	})
	Corner(track, 10)
	Apply(track, { BackgroundColor3 = state and "Accent" or "Stroke" })
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = state and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Parent = track,
	})
	Corner(knob, 7)
	Apply(knob, { BackgroundColor3 = "Knob" })

	local hit = Hit(frame)
	HoverFx(frame, hit)
	local el = NewElement(self, "Toggle", frame, title, cfg, state)

	local function render()
		SetThemed(track, "BackgroundColor3", state and "Accent" or "Stroke", 0.15)
		Tween(knob, { Position = state and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.15)
	end

	function el:Set(value, silent)
		value = value == true
		if value == state then
			return
		end
		state = value
		render()
		Commit(self, state, silent)
	end
	function el:Get()
		return state
	end
	function el:Toggle()
		self:Set(not state)
	end

	hit.MouseButton1Click:Connect(function()
		el:Set(not state)
	end)
	return el
end

----------------------------------------------------------------------
-- Slider
-- cfg: { Name, Min, Max, Default, Increment, Suffix, Flag, Callback }
----------------------------------------------------------------------
function Container:CreateSlider(cfg)
	cfg = cfg or {}
	local min = cfg.Min or 0
	local max = cfg.Max or 100
	local inc = cfg.Increment or 1
	local suffix = cfg.Suffix or ""

	local decimals = 0
	do
		local s = string.format("%.10g", inc)
		local dot = s:find("%.")
		if dot then
			decimals = #s - dot
		end
	end

	local function snap(v)
		v = min + math.floor((v - min) / inc + 0.5) * inc
		v = math.clamp(v, min, max)
		local p = 10 ^ decimals
		return math.floor(v * p + 0.5) / p
	end
	local function toAlpha(v)
		if max == min then
			return 0
		end
		return (v - min) / (max - min)
	end

	local value = snap(cfg.Default or min)
	local frame, title, rowH = ElementFrame(self, cfg, { Reserve = 90, Extra = 20 })

	local valueLabel = Label(frame, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0, 80, 0, rowH),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 13,
	}, "SubText")

	local bar = New("Frame", {
		Position = UDim2.new(0, 12, 0, rowH + 2),
		Size = UDim2.new(1, -24, 0, 6),
		Parent = frame,
	})
	Apply(bar, { BackgroundColor3 = "Stroke" })
	Corner(bar, 3)
	local fill = New("Frame", { Size = UDim2.fromScale(toAlpha(value), 1), Parent = bar })
	Apply(fill, { BackgroundColor3 = "Accent" })
	Corner(fill, 3)
	local knob = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(12, 12),
		Parent = fill,
	})
	Apply(knob, { BackgroundColor3 = "Knob" })
	Corner(knob, 6)

	local hit = New("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.new(0, 0, 0, rowH - 4),
		Size = UDim2.new(1, 0, 0, 26),
		Parent = frame,
	})

	local el = NewElement(self, "Slider", frame, title, cfg, value)

	local function render(instant)
		local a = toAlpha(value)
		if instant then
			fill.Size = UDim2.fromScale(a, 1)
		else
			Tween(fill, { Size = UDim2.fromScale(a, 1) }, 0.06)
		end
		valueLabel.Text = string.format("%." .. decimals .. "f", value) .. suffix
	end
	render(true)

	function el:Set(v, silent)
		v = snap(tonumber(v) or value)
		if v == value then
			return
		end
		value = v
		render()
		Commit(self, value, silent)
	end
	function el:Get()
		return value
	end
	function el:SetRange(newMin, newMax)
		min, max = newMin, newMax
		value = snap(value)
		render(true)
	end

	BindDrag(self.Window, hit, self.Page, function(pos)
		local a = math.clamp((pos.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		el:Set(min + (max - min) * a)
	end)
	return el
end

----------------------------------------------------------------------
-- ProgressBar (แสดงผลอย่างเดียว ไม่ใช่ input)
-- cfg: { Name, Min, Max, Default, Suffix, Flag }
----------------------------------------------------------------------
function Container:CreateProgressBar(cfg)
	cfg = cfg or {}
	local min, max = cfg.Min or 0, cfg.Max or 100
	local value = math.clamp(cfg.Default or min, min, max)
	local frame, title, rowH = ElementFrame(self, cfg, { Reserve = 80, Extra = 16 })

	local valueLabel = Label(frame, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0, 70, 0, rowH),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 13,
	}, "SubText")
	local bar = New("Frame", {
		Position = UDim2.new(0, 12, 0, rowH),
		Size = UDim2.new(1, -24, 0, 6),
		Parent = frame,
	})
	Apply(bar, { BackgroundColor3 = "Stroke" })
	Corner(bar, 3)
	local fill = New("Frame", { Size = UDim2.fromScale(0, 1), Parent = bar })
	Apply(fill, { BackgroundColor3 = "Accent" })
	Corner(fill, 3)

	local el = NewElement(self, "ProgressBar", frame, title, cfg, value)
	local function render(instant)
		local a = (max == min) and 0 or (value - min) / (max - min)
		if instant then
			fill.Size = UDim2.fromScale(a, 1)
		else
			Tween(fill, { Size = UDim2.fromScale(a, 1) }, 0.2)
		end
		if cfg.Suffix then
			valueLabel.Text = tostring(math.floor(value * 100 + 0.5) / 100) .. cfg.Suffix
		else
			valueLabel.Text = tostring(math.floor(a * 100 + 0.5)) .. "%"
		end
	end
	render(true)

	function el:Set(v, silent)
		value = math.clamp(tonumber(v) or value, min, max)
		render()
		if self.Flag then
			Library.Flags[self.Flag] = value
		end
		if not silent then
			SafeCall(cfg.Callback, value)
		end
	end
	function el:Get()
		return value
	end
	return el
end

----------------------------------------------------------------------
-- Dropdown
-- cfg: { Name, Options = {...}, Default, Multi, Searchable, MaxVisible,
--        CloseOnSelect, Flag, Callback }
----------------------------------------------------------------------
function Container:CreateDropdown(cfg)
	cfg = cfg or {}
	local multi = cfg.Multi == true
	local options = table.clone(cfg.Options or {})
	local searchable = cfg.Searchable == true
	local maxVisible = cfg.MaxVisible or 5

	local frame, title, rowH = ElementFrame(self, cfg, { Reserve = 170, Clip = true })

	local valueLabel = Label(frame, {
		Text = "None",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -30, 0, 0),
		Size = UDim2.new(0, 140, 0, rowH),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 13,
	}, "SubText")
	local arrowHolder = New("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(16, rowH),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	local arrow = Label(arrowHolder, {
		Text = "▼",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Center,
	}, "SubText")
	local header = Hit(frame, rowH)
	HoverFx(frame, header)

	local listTop = rowH + 4
	local searchBox
	if searchable then
		local sf = New("Frame", {
			Position = UDim2.fromOffset(8, rowH + 4),
			Size = UDim2.new(1, -16, 0, 24),
			Parent = frame,
		})
		Apply(sf, { BackgroundColor3 = "Background" })
		Corner(sf, 5)
		searchBox = New("TextBox", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 1, 0),
			Font = FONT_REG,
			TextSize = 13,
			PlaceholderText = "Search...",
			Text = "",
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = sf,
		})
		Apply(searchBox, { TextColor3 = "Text", PlaceholderColor3 = "SubText" })
		listTop = rowH + 4 + 28
	end

	local scroll = New("ScrollingFrame", {
		Position = UDim2.fromOffset(8, listTop),
		Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = frame,
	})
	Apply(scroll, { ScrollBarImageColor3 = "Stroke" })
	List(scroll, 2)

	local open = false
	local selected = multi and {} or nil
	local buttons = {}
	local visibleCount = 0
	local el

	local function setFrom(v)
		if multi then
			selected = {}
			if type(v) == "string" then
				v = { v }
			end
			if type(v) == "table" then
				for _, o in ipairs(v) do
					if table.find(options, o) then
						selected[o] = true
					end
				end
			end
		else
			if v ~= nil and table.find(options, v) then
				selected = v
			else
				selected = nil
			end
		end
	end

	local function getValue()
		if multi then
			local arr = {}
			for _, o in ipairs(options) do
				if selected[o] then
					table.insert(arr, o)
				end
			end
			return arr
		end
		return selected
	end

	local function isSelected(o)
		if multi then
			return selected[o] == true
		end
		return selected == o
	end

	local function updateVisual()
		for o, b in pairs(buttons) do
			local sel = isSelected(o)
			SetThemed(b, "TextColor3", sel and "Accent" or "Text", 0.12)
			Tween(b, { BackgroundTransparency = sel and 0.82 or 1 }, 0.12)
		end
		local v = getValue()
		if multi then
			if #v == 0 then
				valueLabel.Text = "None"
			elseif #v <= 2 then
				local names = {}
				for i, o in ipairs(v) do
					names[i] = tostring(o)
				end
				valueLabel.Text = table.concat(names, ", ")
			else
				valueLabel.Text = #v .. " selected"
			end
		else
			valueLabel.Text = v ~= nil and tostring(v) or "None"
		end
	end

	local function resize()
		local count = math.min(visibleCount, maxVisible)
		local listH = count > 0 and (count * 30 - 2) or 0
		scroll.Size = UDim2.new(1, -16, 0, listH)
		local target = open and (listTop + listH + 8) or rowH
		Tween(frame, { Size = UDim2.new(1, 0, 0, target) }, 0.18)
	end

	local function applyFilter()
		local q = searchBox and searchBox.Text:lower() or ""
		visibleCount = 0
		for _, o in ipairs(options) do
			local b = buttons[o]
			if b then
				local show = q == "" or tostring(o):lower():find(q, 1, true) ~= nil
				b.Visible = show
				if show then
					visibleCount = visibleCount + 1
				end
			end
		end
		resize()
	end

	local function setOpen(state)
		open = state
		Tween(arrow, { Rotation = open and 180 or 0 }, 0.18)
		if not open and searchBox then
			searchBox.Text = ""
		end
		resize()
	end

	local function choose(o)
		if multi then
			selected[o] = (not selected[o]) or nil
		else
			selected = o
		end
		updateVisual()
		Commit(el, getValue())
		if not multi and cfg.CloseOnSelect ~= false then
			setOpen(false)
		end
	end

	local function build()
		for _, b in pairs(buttons) do
			b:Destroy()
		end
		table.clear(buttons)
		for i, o in ipairs(options) do
			local b = New("TextButton", {
				Name = tostring(o),
				Size = UDim2.new(1, -6, 0, 28),
				BackgroundTransparency = 1,
				Text = tostring(o),
				Font = FONT,
				TextSize = 13,
				AutoButtonColor = false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				LayoutOrder = i,
				Parent = scroll,
			})
			Corner(b, 5)
			Pad(b, 8, 0, 8, 0)
			Apply(b, { BackgroundColor3 = "Accent", TextColor3 = "Text" })
			b.MouseEnter:Connect(function()
				if not isSelected(o) then
					Tween(b, { BackgroundTransparency = 0.9 }, 0.1)
				end
			end)
			b.MouseLeave:Connect(function()
				if not isSelected(o) then
					Tween(b, { BackgroundTransparency = 1 }, 0.1)
				end
			end)
			b.MouseButton1Click:Connect(function()
				choose(o)
			end)
			buttons[o] = b
		end
	end

	setFrom(cfg.Default)
	build()
	el = NewElement(self, "Dropdown", frame, title, cfg, getValue())
	updateVisual()
	applyFilter()

	if searchBox then
		searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)
	end
	header.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	function el:Set(v, silent)
		setFrom(v)
		updateVisual()
		Commit(self, getValue(), silent)
	end
	function el:Get()
		return getValue()
	end
	function el:Refresh(newOptions, keepSelection)
		local prev = getValue()
		options = table.clone(newOptions or {})
		setFrom(keepSelection and prev or nil)
		build()
		updateVisual()
		applyFilter()
		Commit(self, getValue(), true)
	end
	function el:Open()
		setOpen(true)
	end
	function el:Close()
		setOpen(false)
	end
	return el
end

----------------------------------------------------------------------
-- Input (TextBox)
-- cfg: { Name, Default, Placeholder, Numeric, Min, Max, MaxLength,
--        ClearOnFocus, EnterOnly, Live, Flag, Callback }
----------------------------------------------------------------------
function Container:CreateInput(cfg)
	cfg = cfg or {}
	local numeric = cfg.Numeric == true
	local frame, title, rowH = ElementFrame(self, cfg, { Reserve = 160 })

	local boxFrame = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0, rowH / 2),
		Size = UDim2.fromOffset(140, 24),
		Parent = frame,
	})
	Apply(boxFrame, { BackgroundColor3 = "Background" })
	Corner(boxFrame, 5)
	local stroke = Stroke(boxFrame)

	local box = New("TextBox", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -12, 1, 0),
		Font = FONT_REG,
		TextSize = 13,
		ClearTextOnFocus = cfg.ClearOnFocus == true,
		PlaceholderText = cfg.Placeholder or "Type here...",
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = boxFrame,
	})
	Apply(box, { TextColor3 = "Text", PlaceholderColor3 = "SubText" })

	local function clampNum(n)
		if cfg.Min then
			n = math.max(n, cfg.Min)
		end
		if cfg.Max then
			n = math.min(n, cfg.Max)
		end
		return n
	end

	local value = cfg.Default
	if value == nil then
		value = numeric and 0 or ""
	end
	if numeric then
		value = clampNum(tonumber(value) or 0)
	end
	box.Text = tostring(value)

	local el = NewElement(self, "Input", frame, title, cfg, value)
	local setting = false

	local function parse(text)
		if numeric then
			return clampNum(tonumber(text) or value)
		end
		return text
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if setting then
			return
		end
		local t = box.Text
		if numeric then
			t = t:gsub("[^%d%.%-]", "")
		end
		if cfg.MaxLength and #t > cfg.MaxLength then
			t = t:sub(1, cfg.MaxLength)
		end
		if t ~= box.Text then
			box.Text = t
			return
		end
		if cfg.Live then
			value = parse(t)
			Commit(el, value)
		end
	end)

	box.Focused:Connect(function()
		SetThemed(stroke, "Color", "Accent", 0.12)
	end)
	box.FocusLost:Connect(function(enter)
		SetThemed(stroke, "Color", "Stroke", 0.12)
		if cfg.EnterOnly and not enter then
			box.Text = tostring(value)
			return
		end
		value = parse(box.Text)
		setting = true
		box.Text = tostring(value)
		setting = false
		Commit(el, value)
	end)

	function el:Set(v, silent)
		if numeric then
			value = clampNum(tonumber(v) or value)
		else
			value = tostring(v == nil and "" or v)
		end
		setting = true
		box.Text = tostring(value)
		setting = false
		Commit(self, value, silent)
	end
	function el:Get()
		return value
	end
	function el:Focus()
		box:CaptureFocus()
	end
	return el
end

----------------------------------------------------------------------
-- Keybind
-- cfg: { Name, Default (Enum.KeyCode), Flag,
--        Callback  = ถูกเรียกตอนกดปุ่มนั้น,
--        OnChanged = ถูกเรียกตอนเปลี่ยนปุ่ม }
-- กดปุ่ม Backspace/Delete ตอนตั้งค่า = ล้างปุ่ม, Escape = ยกเลิก
----------------------------------------------------------------------
function Container:CreateKeybind(cfg)
	cfg = cfg or {}
	local key = cfg.Default
	local listening = false
	local frame, title, rowH = ElementFrame(self, cfg, { Reserve = 100 })

	local btn = New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0, rowH / 2),
		Size = UDim2.fromOffset(84, 24),
		Font = FONT_REG,
		TextSize = 12,
		AutoButtonColor = false,
		Text = "",
		Parent = frame,
	})
	Corner(btn, 5)
	Apply(btn, { BackgroundColor3 = "Background", TextColor3 = "Text" })
	local stroke = Stroke(btn)

	local function show()
		btn.Text = listening and "..." or (key and key.Name or "None")
		SetThemed(stroke, "Color", listening and "Accent" or "Stroke", 0.12)
	end
	show()

	local el = NewElement(self, "Keybind", frame, title, cfg, key)

	function el:Set(k, silent)
		if type(k) == "string" then
			local ok, kc = pcall(function()
				return Enum.KeyCode[k]
			end)
			k = ok and kc or nil
		end
		key = k
		listening = false
		show()
		if self.Flag then
			Library.Flags[self.Flag] = key
		end
		if not silent then
			SafeCall(cfg.OnChanged, key)
		end
	end
	function el:Get()
		return key
	end
	function el:GetName()
		return key and key.Name or "None"
	end

	btn.MouseButton1Click:Connect(function()
		listening = true
		show()
	end)

	self.Window:_connect(UserInputService.InputBegan, function(input, gpe)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local code = input.KeyCode
				if code == Enum.KeyCode.Escape then
					listening = false
					show()
				elseif code == Enum.KeyCode.Backspace or code == Enum.KeyCode.Delete then
					el:Set(nil)
				else
					el:Set(code)
				end
			end
			return
		end
		if gpe or not key then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == key then
			SafeCall(cfg.Callback, key)
		end
	end)
	return el
end

----------------------------------------------------------------------
-- ColorPicker
-- cfg: { Name, Default (Color3), Flag, Callback }
----------------------------------------------------------------------
function Container:CreateColorPicker(cfg)
	cfg = cfg or {}
	local color = cfg.Default or Color3.fromRGB(255, 255, 255)
	local h, s, v = color:ToHSV()
	local PANEL_H = 156

	local frame, title, rowH = ElementFrame(self, cfg, { Reserve = 60, Clip = true })
	local swatch = New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, rowH / 2),
		Size = UDim2.fromOffset(34, 18),
		BackgroundColor3 = color,
		Parent = frame,
	})
	Corner(swatch, 4)
	Stroke(swatch)

	local header = Hit(frame, rowH)
	HoverFx(frame, header)

	local panel = New("Frame", {
		Position = UDim2.fromOffset(12, rowH + 4),
		Size = UDim2.new(1, -24, 0, PANEL_H),
		BackgroundTransparency = 1,
		Parent = frame,
	})

	-- กล่อง Saturation / Value
	local sv = New("Frame", {
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		Active = true,
		Parent = panel,
	})
	Corner(sv, 4)
	local white = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = sv,
	})
	Corner(white, 4)
	New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local black = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Parent = sv,
	})
	Corner(black, 4)
	New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
	local svCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Parent = sv,
	})
	Corner(svCursor, 5)
	New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = svCursor })

	-- แถบ Hue
	local hue = New("Frame", {
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Active = true,
		Parent = panel,
	})
	Corner(hue, 6)
	local keypoints = {}
	for i = 0, 6 do
		table.insert(keypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i % 6) / 6, 1, 1)))
	end
	New("UIGradient", { Color = ColorSequence.new(keypoints), Parent = hue })
	local hueCursor = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(6, 16),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = hue,
	})
	Corner(hueCursor, 3)
	New("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.5, Parent = hueCursor })

	-- Hex
	local hexFrame = New("Frame", {
		Position = UDim2.fromOffset(0, 128),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = panel,
	})
	Apply(hexFrame, { BackgroundColor3 = "Background" })
	Corner(hexFrame, 5)
	local hex = New("TextBox", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		Font = FONT_REG,
		TextSize = 13,
		Text = "",
		PlaceholderText = "#RRGGBB",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = hexFrame,
	})
	Apply(hex, { TextColor3 = "Text", PlaceholderColor3 = "SubText" })

	local el = NewElement(self, "ColorPicker", frame, title, cfg, color)

	local function refresh(silent)
		color = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = color
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(h, 0.5)
		hex.Text = "#" .. color:ToHex():upper()
		Commit(el, color, silent)
	end
	refresh(true)

	BindDrag(self.Window, sv, self.Page, function(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		refresh()
	end)
	BindDrag(self.Window, hue, self.Page, function(pos)
		h = math.clamp((pos.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 1)
		refresh()
	end)

	hex.FocusLost:Connect(function()
		local text = "#" .. (hex.Text:gsub("#", ""))
		local ok, c = pcall(Color3.fromHex, text)
		if ok and c then
			h, s, v = c:ToHSV()
		end
		refresh()
	end)

	local open = false
	header.MouseButton1Click:Connect(function()
		open = not open
		Tween(frame, { Size = UDim2.new(1, 0, 0, open and (rowH + 4 + PANEL_H + 10) or rowH) }, 0.2)
	end)

	function el:Set(c, silent)
		if typeof(c) ~= "Color3" then
			return
		end
		h, s, v = c:ToHSV()
		refresh(silent)
	end
	function el:Get()
		return color
	end
	return el
end

----------------------------------------------------------------------
-- Tab
----------------------------------------------------------------------
function Tab:_setActive(active)
	self.Active = active
	self.Page.Visible = active
	Tween(self._btn, { BackgroundTransparency = active and 0 or 1 }, 0.15)
	Tween(self._indicator, { BackgroundTransparency = active and 0 or 1 }, 0.15)
	SetThemed(self._text, "TextColor3", active and "Text" or "SubText", 0.15)
	if self._icon then
		local prop = self._icon:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
		SetThemed(self._icon, prop, active and "Accent" or "SubText", 0.15)
	end
end

function Tab:Select()
	self.Window:SelectTab(self)
end

function Tab:SetName(name)
	self.Name = name
	self._text.Text = tostring(name)
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function Window:_connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(self._conns, c)
	return c
end

-- cfg: { Title, Subtitle, Size = UDim2.fromOffset(w,h), MinSize = Vector2, SidebarWidth,
--        ToggleKey = Enum.KeyCode, Theme = "Dark", Resizable = true,
--        MobileButton = nil(auto)/true/false, DisplayOrder, OnClose, Name }
function Library:CreateWindow(cfg)
	cfg = cfg or {}
	if cfg.Theme then
		Library:SetTheme(cfg.Theme)
	end

	local self = setmetatable({}, Window)
	self.Library = Library
	self.Tabs = {}
	self.Title = tostring(cfg.Title or "NovaUI")
	self.ToggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
	self.Visible = true
	self.Minimized = false
	self._conns = {}
	self._destroyed = false

	local sizeCfg = cfg.Size or UDim2.fromOffset(580, 400)
	local w, h = sizeCfg.X.Offset, sizeCfg.Y.Offset
	local cam = workspace.CurrentCamera
	if cam then
		local vp = cam.ViewportSize
		w = math.min(w, vp.X - 24)
		h = math.min(h, vp.Y - 70)
	end
	local minSize = cfg.MinSize or Vector2.new(400, 280)
	minSize = Vector2.new(math.min(minSize.X, w), math.min(minSize.Y, h))
	local sidebarW = cfg.SidebarWidth or (w < 480 and 110 or 150)

	local gui = New("ScreenGui", {
		Name = "NovaUI_" .. tostring(cfg.Name or self.Title),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = cfg.DisplayOrder or 100,
	})
	gui.Parent = GetParent()
	self._gui = gui

	local main = New("Frame", {
		Name = "Main",
		Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2),
		Size = UDim2.fromOffset(w, h),
		ClipsDescendants = true,
		Parent = gui,
	})
	Apply(main, { BackgroundColor3 = "Background" })
	Corner(main, 10)
	Stroke(main)
	self._main = main

	-- Topbar
	local topbar = New("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, TOPBAR_H),
		BackgroundTransparency = 1,
		Parent = main,
	})
	local titleHolder = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -100, 1, 0),
		Parent = topbar,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = titleHolder,
	})
	self._titleLabel = Label(titleHolder, {
		Text = self.Title,
		Font = FONT_BOLD,
		TextSize = 15,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
	})
	self._subtitleLabel = Label(titleHolder, {
		Text = tostring(cfg.Subtitle or ""),
		Font = FONT_REG,
		TextSize = 12,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = cfg.Subtitle ~= nil,
		LayoutOrder = 2,
	}, "SubText")

	local topLine = New("Frame", {
		Position = UDim2.fromOffset(0, TOPBAR_H),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = main,
	})
	Apply(topLine, { BackgroundColor3 = "Stroke" })

	local function TopButton(text, fromRight, callback)
		local b = New("TextButton", {
			Size = UDim2.fromOffset(28, 28),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -fromRight, 0.5, 0),
			BackgroundTransparency = 1,
			Text = text,
			Font = FONT_BOLD,
			TextSize = 18,
			AutoButtonColor = false,
			Parent = topbar,
		})
		Corner(b, 6)
		Apply(b, { TextColor3 = "SubText", BackgroundColor3 = "ElementHover" })
		b.MouseEnter:Connect(function()
			Tween(b, { BackgroundTransparency = 0 }, 0.12)
			SetThemed(b, "TextColor3", "Text", 0.12)
		end)
		b.MouseLeave:Connect(function()
			Tween(b, { BackgroundTransparency = 1 }, 0.12)
			SetThemed(b, "TextColor3", "SubText", 0.12)
		end)
		b.MouseButton1Click:Connect(callback)
		return b
	end
	TopButton("×", 10, function()
		SafeCall(cfg.OnClose)
		self:Destroy()
	end)
	TopButton("–", 42, function()
		if self.Minimized then
			self:Restore()
		else
			self:Minimize()
		end
	end)

	MakeDraggable(self, topbar, main)

	-- Body
	local body = New("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, TOPBAR_H + 1),
		Size = UDim2.new(1, 0, 1, -(TOPBAR_H + 1)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = main,
	})
	self._body = body

	local sidebar = New("ScrollingFrame", {
		Name = "Sidebar",
		Size = UDim2.new(0, sidebarW, 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = body,
	})
	List(sidebar, 4)
	Pad(sidebar, 8)
	self._sidebar = sidebar

	local sideLine = New("Frame", {
		Position = UDim2.fromOffset(sidebarW, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = body,
	})
	Apply(sideLine, { BackgroundColor3 = "Stroke" })

	local content = New("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(sidebarW + 1, 0),
		Size = UDim2.new(1, -(sidebarW + 1), 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = body,
	})
	self._content = content

	-- Resize grip
	if cfg.Resizable ~= false then
		local grip = New("TextButton", {
			Name = "Resize",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -3),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Text = "◢",
			Font = FONT,
			TextSize = 10,
			AutoButtonColor = false,
			ZIndex = 5,
			Parent = main,
		})
		Apply(grip, { TextColor3 = "SubText" })
		self._grip = grip

		local resizing, startPos, startSize = false, nil, nil
		grip.InputBegan:Connect(function(input)
			if IsPointer(input) then
				resizing = true
				startPos = input.Position
				startSize = main.AbsoluteSize
			end
		end)
		self:_connect(UserInputService.InputChanged, function(input)
			if resizing and IsMove(input) then
				local d = input.Position - startPos
				local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
				local nw = math.clamp(startSize.X + d.X, minSize.X, vp.X)
				local nh = math.clamp(startSize.Y + d.Y, minSize.Y, vp.Y)
				main.Size = UDim2.fromOffset(nw, nh)
			end
		end)
		self:_connect(UserInputService.InputEnded, function(input)
			if IsPointer(input) then
				resizing = false
			end
		end)
	end

	-- ปุ่มลัดเปิด/ปิด
	self:_connect(UserInputService.InputBegan, function(input, gpe)
		if gpe or self._destroyed then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end)

	-- ปุ่มลอยสำหรับมือถือ
	if cfg.MobileButton == true or (cfg.MobileButton == nil and UserInputService.TouchEnabled) then
		local mb = New("TextButton", {
			Name = "MobileToggle",
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.new(1, -60, 0, 12),
			Text = "UI",
			Font = FONT_BOLD,
			TextSize = 14,
			AutoButtonColor = false,
			ZIndex = 20,
			Parent = gui,
		})
		Corner(mb, 22)
		Apply(mb, { BackgroundColor3 = "Accent", TextColor3 = "Knob" })
		local st = MakeDraggable(self, mb, mb)
		mb.Activated:Connect(function()
			if not st.Moved then
				self:Toggle()
			end
		end)
	end

	table.insert(Library.Windows, self)
	return self
end

function Window:CreateTab(cfg, icon)
	if type(cfg) ~= "table" then
		cfg = { Name = tostring(cfg), Icon = icon }
	end
	local name = tostring(cfg.Name or "Tab")

	local btn = New("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = #self.Tabs + 1,
		Parent = self._sidebar,
	})
	Apply(btn, { BackgroundColor3 = "Element" })
	Corner(btn, 6)

	local indicator = New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 16),
		BackgroundTransparency = 1,
		Parent = btn,
	})
	Corner(indicator, 2)
	Apply(indicator, { BackgroundColor3 = "Accent" })

	local textX = 12
	local iconObj
	if cfg.Icon and cfg.Icon ~= "" then
		if tostring(cfg.Icon):match("^rbxasset") then
			iconObj = New("ImageLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0.5, -8),
				Size = UDim2.fromOffset(16, 16),
				Image = cfg.Icon,
				Parent = btn,
			})
			Apply(iconObj, { ImageColor3 = "SubText" })
		else
			iconObj = Label(btn, {
				Text = tostring(cfg.Icon),
				Position = UDim2.new(0, 10, 0, 0),
				Size = UDim2.new(0, 20, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 15,
			}, "SubText")
		end
		textX = 36
	end
	local text = Label(btn, {
		Text = name,
		Position = UDim2.new(0, textX, 0, 0),
		Size = UDim2.new(1, -textX - 6, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 13,
	}, "SubText")

	local page = New("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = self._content,
	})
	Apply(page, { ScrollBarImageColor3 = "Stroke" })
	List(page, 6)
	Pad(page, 10)

	local tab = setmetatable({
		Window = self,
		Name = name,
		Page = page,
		Holder = page,
		Active = false,
		_order = 0,
		_btn = btn,
		_indicator = indicator,
		_text = text,
		_icon = iconObj,
	}, Tab)

	btn.MouseEnter:Connect(function()
		if not tab.Active then
			Tween(btn, { BackgroundTransparency = 0.6 }, 0.1)
		end
	end)
	btn.MouseLeave:Connect(function()
		if not tab.Active then
			Tween(btn, { BackgroundTransparency = 1 }, 0.1)
		end
	end)
	btn.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	if type(tab) == "string" then
		for _, t in ipairs(self.Tabs) do
			if t.Name == tab then
				tab = t
				break
			end
		end
	elseif type(tab) == "number" then
		tab = self.Tabs[tab]
	end
	if type(tab) ~= "table" then
		return
	end
	for _, t in ipairs(self.Tabs) do
		t:_setActive(t == tab)
	end
	self.ActiveTab = tab
end

function Window:SetTitle(t)
	self.Title = tostring(t)
	self._titleLabel.Text = self.Title
end

function Window:SetSubtitle(t)
	self._subtitleLabel.Text = tostring(t or "")
	self._subtitleLabel.Visible = t ~= nil and t ~= ""
end

function Window:SetSize(size)
	if typeof(size) == "Vector2" then
		size = UDim2.fromOffset(size.X, size.Y)
	end
	self._main.Size = size
end

function Window:SetToggleKey(key)
	self.ToggleKey = key
end

function Window:SetVisible(v)
	self.Visible = v
	self._main.Visible = v
end
function Window:Show()
	self:SetVisible(true)
end
function Window:Hide()
	self:SetVisible(false)
end
function Window:Toggle()
	self:SetVisible(not self.Visible)
end
function Window:IsVisible()
	return self.Visible
end

function Window:Minimize()
	if self.Minimized or self._destroyed then
		return
	end
	self.Minimized = true
	self._restoreSize = self._main.Size
	if self._grip then
		self._grip.Visible = false
	end
	Tween(self._main, { Size = UDim2.fromOffset(self._main.Size.X.Offset, TOPBAR_H + 1) }, 0.2)
	task.delay(0.2, function()
		if self.Minimized and not self._destroyed then
			self._body.Visible = false
		end
	end)
end

function Window:Restore()
	if not self.Minimized or self._destroyed then
		return
	end
	self.Minimized = false
	self._body.Visible = true
	if self._grip then
		self._grip.Visible = true
	end
	Tween(self._main, { Size = self._restoreSize }, 0.2)
end

function Window:Notify(cfg)
	return Library:Notify(cfg)
end

-- cfg: { Title, Content, Buttons = { {Text, Callback, Primary}, ... } }
function Window:CreateDialog(cfg)
	cfg = cfg or {}
	local overlay = New("Frame", {
		Name = "Dialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Active = true,
		Parent = self._main,
	})
	Corner(overlay, 10)
	Tween(overlay, { BackgroundTransparency = 0.45 }, 0.15)

	local card = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(math.clamp(self._main.AbsoluteSize.X - 40, 200, 340), 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = overlay,
	})
	Apply(card, { BackgroundColor3 = "Element" })
	Corner(card, 8)
	Stroke(card)
	Pad(card, 14)
	List(card, 10)

	Label(card, {
		Text = tostring(cfg.Title or "Dialog"),
		Font = FONT_BOLD,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 1,
	})
	if cfg.Content then
		Label(card, {
			Text = tostring(cfg.Content),
			Font = FONT_REG,
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
		}, "SubText")
	end

	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = card,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = row,
	})

	local dialog = {}
	local closed = false
	function dialog:Close()
		if closed then
			return
		end
		closed = true
		card.Visible = false
		Tween(overlay, { BackgroundTransparency = 1 }, 0.12)
		task.delay(0.13, function()
			overlay:Destroy()
		end)
	end

	local buttons = cfg.Buttons or { { Text = "OK" } }
	for i, b in ipairs(buttons) do
		local primary = b.Primary
		if primary == nil then
			primary = (i == #buttons)
		end
		local btn = New("TextButton", {
			Size = UDim2.fromOffset(0, 32),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = tostring(b.Text or "OK"),
			Font = FONT_BOLD,
			TextSize = 13,
			AutoButtonColor = false,
			LayoutOrder = i,
			Parent = row,
		})
		Corner(btn, 6)
		Pad(btn, 16, 0, 16, 0)
		Apply(btn, {
			BackgroundColor3 = primary and "Accent" or "Stroke",
			TextColor3 = primary and "Knob" or "Text",
		})
		btn.MouseEnter:Connect(function()
			Tween(btn, { BackgroundTransparency = 0.15 }, 0.1)
		end)
		btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundTransparency = 0 }, 0.1)
		end)
		btn.MouseButton1Click:Connect(function()
			dialog:Close()
			SafeCall(b.Callback)
		end)
	end
	return dialog
end

function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, c in ipairs(self._conns) do
		c:Disconnect()
	end
	table.clear(self._conns)

	for flag, el in pairs(Library.Elements) do
		if el.Window == self then
			Library.Elements[flag] = nil
			Library.Flags[flag] = nil
		end
	end

	local idx = table.find(Library.Windows, self)
	if idx then
		table.remove(Library.Windows, idx)
	end
	self._gui:Destroy()
end

return Library