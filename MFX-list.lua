-- @description FX list for Reaper left docker (MFX-list)
-- @author M Fabian, inlcudes code by Edgemeal
-- @version 0.0.1
-- @changelog
--   Nothing yet, or rather... everything
-- @link
--   Forum Thread https://forum.cockos.com/showthread.php?t=210987
-- @screenshot 
-- @donation something.good.for.humankind 
-- @about
--   # Native ReaScript reimplementation of Doppelganger's FXlist
--   # Needs the js_ReaScriptAPI (tested with reaper_js_ReaScriptAPI64.dll) by 
--   #         Julian Sander, https://forum.cockos.com/showthread.php?t=212174

-- TODO! Fix the scrolling, only ShiftCtrl+Mousewheel, View: Adjust selected track heights (MIDI CC relative/mousewheel), 972 works as it shoudl!
-- TODO! Find left docker to attach to

local string, table, math, os, utf8 = string, table, math, os, utf8
local load, xpcall, pairs, ipairs = load, xpcall, pairs, ipairs, select
local rpr, gfx = reaper, gfx
-----------------------------------------  Just for debugging
local DO_DEBUG = true
local function Msg(str)
   if DO_DEBUG then rpr.ShowConsoleMsg(tostring(str).."\n") end
end
-------------------------------------------
-- Globals, variables with underscore are global
-- All capitals are constants, do not assign to these in the code
-- Non-constants are used to communicate between different parts of the code
local MFXlist = 
{ 
  VERSION = "0.0.1",
  SCRIPT_NAME = "MFX-list v0.0.1",
  
  MB_LEFT = 1,
  MB_RIGHT = 2,
  
  MOD_CTRL = 4, 
  MOD_SHIFT = 8,
  MOD_ALT = 16, 
  MOD_WIN = 32, 
  MOD_KEYS = 4+8+16+32, 
  
  mouse_y = nil, -- is set to mouse_y when mouse inside MFXlist, else nil
  track_hovered = nil, -- is set to the track (ptr) currently under mouse cursor, nil if mouse outside of client are
  fx_hovered = nil, -- is set to the index (1-based!) of FX under the mouse cursor, nil if mouse is outside of current track FX 
  
  MENU_STR = "Find left dock|Show first track|Show last track|Quit",
  MENU_FINDLEFTDOCK = 1,
  MENU_SHOWFIRSTTCP = 2,
  MENU_SHOWLASTTCP = 3,
  MENU_QUIT = 4,

  COLOR_BLACK   = {012/255, 012/255, 012/255},
  COLOR_VST     = {},
  COLOR_JSFX    = {},
  COLOR_HIGHLIGHT = {},
  COLOR_EMPTYSLOT = {40/255, 40/255, 40/255},
  COLOR_FAINT = {60/255, 60/255, 60/255},
  COLOR_FXHOVERED = {1, 1, 0}, 
  
  FX_DISABLEDA = 0.3, -- fade of name for disabled FX
  FX_OFFLINEDA = 0.1, -- even fainter for offlined FX
  
  FXCHAIN_HIDE = 0, -- flags for TrackFX_Show(track, fxindx, flags)
  FXCHAIN_SHOW = 1,
  FXFLOAT_HIDE = 2,
  FXFLOAT_SHOW = 3,
  
  TRACK_FXENABLED = 4, -- flags for GetTrackState(track)
  TRACK_MUTED = 8,
  
  FONT_NAME1 = "Arial",
  FONT_NAME2 = "Courier New",
  FONT_SIZE1 = 14,
  FONT_SIZE2 = 16,
  FONT_FXNAME = 1,
  FONT_FXBOLD = 2,
  FONT_HEADER = 16,
  FONT_BOLDFLAG = 0x42000000,   -- bold
  FONT_ITFLAG = 0x49000000,     -- italics
  FONT_OUTFLAG = 0x4F000000,    -- outline
  FONT_BLURFLAG = 0x52000000,   -- blurred
  FONT_SHARPFLAG = 0x53000000,  -- sharpen
  FONT_UNDERFLAG = 0x55000000,  -- underline
  FONT_INVFLAG = 0x56000000,    -- invert  
  
  SLOT_HEIGHT = 13, -- pixels high
  
  MATCH_UPTOCOLON = "(.-:)",
  
  WIN_X = 1000,
  WIN_Y = 200,
  WIN_W = 200,
  WIN_H = 200,
  LEFT_ARRANGEDOCKER = 512+1, -- 512 = left of arrange view, +1 == docked (not universally true)
  
  -- CLASS_TRACKLISTWIN = "REAPERTrackListWindow", -- this is the arrange view where the media items live
  CLASS_TCPDISPLAY = "REAPERTCPDisplay", -- this is the TCP where the track panes live
  
  TCP_HWND = nil, -- filled in when script initializes (so strictly speaking not constant, but yeah...)
  TCP_top = nil, -- Set on every defer before calling any other function
  TCP_bot = nil, -- Set on every defer before calling any other function
  
  CMD_SCROLLVERT = 989, -- View: Scroll vertically (MIDI CC relative/mousewheel)
  
  BLITBUF_HEAD = 16, -- off-screen draw buffer for the header
  BLITBUF_HEADW = 300,
  BLITBUF_HEADH = 300,
  
  footer_text = "MFX-list",
}

local CURR_PROJ = 0
------------------------------------------------ These are for testing and debuggin
local function addTracksForTesting(num)
  
  local tracknames =
  {
    "First track",
    "Track two",
    "Wow!",
    "Another one",
    "Great stuff!",
    "Quant suff.",
    "Mantergeistmann",
    "",
  }
  
  if num == nil then num = #tracknames end
  
  local count = #tracknames
  if num < count then count = num end
  
  for i = 1, count do
      rpr.InsertTrackAtIndex(i-1, true)
      local track = rpr.GetTrack(CURR_PROJ, i-1)
      rpr.GetSetMediaTrackInfo_String(track, 'P_NAME', tracknames[i], true)
  end
  
  local remains = num - count
  for i = 1, remains do
    rpr.InsertTrackAtIndex(count+i-1, true)
  end
  
end -- addTracksForTesting
-----------------------------------
local function setupForTesting(num)
  
  local NEW_PROJTEMPLATE = "P:/Reaper6/ProjectTemplates/FabianNewDefault.RPP"
  
  rpr.PreventUIRefresh(1)
  
  rpr.Main_OnCommand(40859, 0, 0) -- New project tab
  rpr.Main_openProject("template:noprompt:"..NEW_PROJTEMPLATE)
  
  addTracksForTesting(num)
  
  --gfx.dock(MFXlist.LEFT_ARRANGEDOCKER, 0, 0, 0, 0)
  
  rpr.PreventUIRefresh(-1)
  rpr.TrackList_AdjustWindows(true)
  rpr.UpdateArrange()
  
end -- setUpFortesting
------------------------------------------ Stolen from https://stackoverflow.com/questions/41942289/display-contents-of-tables-in-lua
-- Recursive print of a table, returns a string
local function tprint (tbl, indent)
  if not indent then indent = 0 end
  local toprint = string.rep(" ", indent) .. "{\r\n"
  indent = indent + 2 
  for k, v in pairs(tbl) do
    toprint = toprint .. string.rep(" ", indent)
    if (type(k) == "number") then
      toprint = toprint .. "[" .. k .. "] = "
    elseif (type(k) == "string") then
      toprint = toprint  .. k ..  "= "   
    end
    if (type(v) == "number") then
      toprint = toprint .. v .. ",\r\n"
    elseif (type(v) == "string") then
      toprint = toprint .. "\"" .. v .. "\",\r\n"
    elseif (type(v) == "table") then
      toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
    else
      toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
    end
  end
  toprint = toprint .. string.rep(" ", indent-2) .. "}"
  return toprint
end
-------------------------------------------------------- Stolen from https://forum.cockos.com/showthread.php?t=230919
-- Requires js_ReaScriptAPI extension, 
-- https://forum.cockos.com/showthread.php?t=212174
local function GetClientBounds(hwnd)
  
  local ret, left, top, right, bottom = rpr.JS_Window_GetClientRect(hwnd)
  return left, top, right-left, bottom-top
  
end --GetClientBounds
-----------------------------------------
local function getAllChildWindows(hwnd)
  
  local arr = rpr.new_array({}, 255)
  rpr.JS_Window_ArrayAllChild(hwnd, arr)
  return arr.table() 

end -- getAllChildWIndows
------------------------------------------
local function getTitleMatchWindows(title, exact)
  
  local reaperarray = rpr.new_array({}, 255)
  rpr.JS_Window_ArrayFind(title, exact, reaperarray)
  return reaperarray.table()
  
end -- getTitleMatchWindows
-----------------------------------------------------------------
-- Find the occurrance-th instance of a window named by classname 
local function FindChildByClass(hwnd, classname, occurrence) 

  local adr = getAllChildWindows(hwnd)
  local count = #adr
  for j = 1, count do
    local hwnd = rpr.JS_Window_HandleFromAddress(adr[j]) 
    if rpr.JS_Window_GetClassName(hwnd) == classname then
      occurrence = occurrence - 1
      if occurrence == 0 then
        return hwnd
      end
    end
  end
  
end --FindChildByClass
---------------------------------------------------------
-- Returns the HWND and the screen coordinates of the TCP
local function getTCPProperties(classname)
-- get first reaper child window with classname "REAPERTCPDisplay".
  local tcp_hwnd = FindChildByClass(rpr.GetMainHwnd(), classname, 1) 
  if tcp_hwnd then
    local x,y,w,h = GetClientBounds(tcp_hwnd)
    --msg(w) -- show width
    return tcp_hwnd, x, y, w, h
  end
  return nil, -1, -1, -1, -1
end
--------------------------------------------------------
local function findLeftDock()
  
  local mhwnd = rpr.GetMainHwnd()
  local _, mleft, mtop, mright, mbottom = rpr.JS_Window_GetClientRect(mhwnd)
  Msg("MainHwnd, left: "..mleft..", top: "..mtop..", right: "..mright..", bottom: "..mbottom)
  
  local adr = getTitleMatchWindows("REAPER_dock", true)
  local count = #adr
  local docknumber = 0 -- guessing that the dockers come in order
  for i = 1, count do
    local hwnd = rpr.JS_Window_HandleFromAddress(adr[i]) 
    --local classname = rpr.JS_Window_GetClassName(hwnd)
    --Msg("i: "..i..", adr: "..adr[i]..", class: "..classname)
    --if classname == "REAPER_dock" then
      local _, left, top, right, bottom = rpr.JS_Window_GetRect(hwnd) 
      Msg("REAPER_dock #"..docknumber..", left: "..left..", top: "..top..", right: "..right..", bottom: "..bottom)
      if left == mleft then -- this should be the left docker
        -- then what? how to get its number? do they come in order?
        --MFXlist.LEFT_ARRANGEDOCKER = 2^docknumber + 1
      end
      docknumber = docknumber + 1
    --end
  end
  
end -- findLeftDock
--------------------------------------------------------
local function collectFX(track)
  assert(track, "collectFX: invalid parameter - track")
  
  local fxtab = {}
  
  local numfx = rpr.TrackFX_GetCount(track)
  for i = 1, numfx do
    local _, fxname = rpr.TrackFX_GetFXName(track, i-1, "")
    local fxtype = fxname:match(MFXlist.MATCH_UPTOCOLON) or "VID:"  -- Video processor FX don't have prefixes
    fxname = fxname:gsub(MFXlist.MATCH_UPTOCOLON.."%s", "") -- up to colon and then space, replace by nothing
    fxname = fxname:gsub("%([^()]*%)","")
    local enabled =  rpr.TrackFX_GetEnabled(track, i-1)
    local offlined = rpr.TrackFX_GetOffline(track, i-1)
    table.insert(fxtab, {fxname = fxname, fxtype = fxtype, enabled = enabled, offlined = offlined}) -- confusing <key, value> pairs here, but it works
  end
  return fxtab
end
------------------------------------------
local function getTrackPosAndHeight(track)
  assert(track, "getTrackPosAndHeight: invalid parameter - track")
  
  local height = rpr.GetMediaTrackInfo_Value(track, "I_WNDH") -- current TCP window height in pixels including envelopes
  local posy = rpr.GetMediaTrackInfo_Value(track, "I_TCPY") -- current TCP window Y-position in pixels relative to top of arrange view
  return posy, height
  
end -- getTrackPosAndHeight()
---------------------------------------------------------------------------
local function getTrackInfo(track)
  assert(track, "getTrackInfo: invalid parameter - track")
  
  local _, name = rpr.GetTrackName(track)
  local visible = rpr.IsTrackVisible(track, false) -- false for TCP (true for MCP)
  local enabled = rpr.GetMediaTrackInfo_Value(track, "I_FXEN") ~= 0 -- fx enabled, 0=bypassed, !0=fx active
  local posy, height = getTrackPosAndHeight(track)
  local fx = collectFX(track)
  
  return {track = track, name = name, visible = visible, enabled = enabled, height = height, posy = posy, fx = fx}
end
------------------------------
local function collectTracks()
  local tracks = {}
  
  if rpr.GetMasterTrackVisibility() & 0x1 == 1 then -- Master track visible in TCP
    local master = rpr.GetMasterTrack(CURR_PROJ)
    local info = getTrackInfo(master)
    table.insert(tracks, info)
  end

  local numtracks = rpr.CountTracks(CURR_PROJ) -- excludes the master track, taken care of above
  for i = 1, numtracks do
    local track = rpr.GetTrack(CURR_PROJ, i-1)
    local info = getTrackInfo(track)
    table.insert(tracks, info)
  end
  
  return tracks
end
--------------------------------------------------------
local function showTracks(tracks) -- In console output

  for i = 1, #tracks do
    local trinfo = tracks[i]
    -- local fxtable = collectFX(trinfo.track)
    Msg("Track: "..trinfo.name..", "..(trinfo.visible and "is vis" or "not vis")..", "..(trinfo.enabled and "fx enab" or "fx disab")..", "..trinfo.height..", "..trinfo.posy)
    local fxtable = trinfo.fx
    for j = 1, #fxtable do
      local fx = fxtable[j]
      Msg(fx.fxtype.." "..fx.fxname..", "..(fx.enabled and "is enabled" or "not enabled"))
    end
  end
end
--------------------------------------------------------
-- Find the index of the first track visible in the TCP
-- A track can be invisible from the TCP for two reasons:
-- 1. It has its TCP visbility property set to false, and then its height seems to be 0 (this is used)
-- 2. It is outside of the TCP view rectangle, posy either negative or larger than TCP height
local function getFirstTCPTrackLinear()
-- This version does a linear search from index 0 looking for the first track for which posy+height > 0
-- Note that the returned track index is 1-based, just as track numbering, so MASTER is index 0
  
  if rpr.GetMasterTrackVisibility() & 0x1 == 1 then -- Master track visible in TCP
    local master = rpr.GetMasterTrack(CURR_PROJ)
    local posy, height = getTrackPosAndHeight(master)
    if height + posy > 0 then return master, 0 end
  end

  local numtracks = rpr.CountTracks(CURR_PROJ) -- excludes the master track, taken care of above
  if numtracks == 0 then return nil, -1 end
    
  for i = 1, numtracks do
    local track = rpr.GetTrack(CURR_PROJ, i-1)
    local posy, height = getTrackPosAndHeight(track)
    if height + posy > 0 then return track, i end -- rules out invisible track (height == 0) at the top (posy = 0)
  end
  assert(nil, "getFirstTrackLinear: Should never get here!")
  
end -- getFirstTCPTrackLinear
---------------------------------------
local function getFirstTCPTrackBinary()
  
  local fixForMasterTCPgap = false
  
  if rpr.GetMasterTrackVisibility() & 0x1 == 1 then -- Master track visible in TCP
    local master = rpr.GetMasterTrack(CURR_PROJ)
    local posy, height = getTrackPosAndHeight(master)
    if height + posy > 0 then return master, 0 end
    if height + posy == 0 then fixForMasterTCPgap = true end
  end
  
  local numtracks = rpr.CountTracks(CURR_PROJ)
  if numtracks == 0 then return nil, -1 end
  
  -- When the MASTER posy + height == 0, then the 0th track is at posy == 5
  -- And this is then the first visible track. Special case
  if fixForMasterTCPgap then 
    local track = rpr.GetTrack(CURR_PROJ, 0)
    return track, 1
  end
    
  local left, right = 0, numtracks - 1
  while left <= right do
    local index = math.floor((left + right) / 2)
    local track = rpr.GetTrack(CURR_PROJ, index)
    local posy, height = getTrackPosAndHeight(track)
    if posy < 0 then
      if posy + height > 0 then return track, index + 1 end -- Rules out invisible tracks, height == 0, at the top
      left = index + 1
    elseif posy > 0 then
      right = index - 1
    else -- posy == 0, then this is the one
      return track, index + 1
    end      
  end
  assert(nil, "getFirstTCPTrackBinary: Should never get here!")
  
end -- getFirstTCPTrackBinary
---------------------------------------------------------------------------
-- Does a binary search, halving and halving until it finds the right track
-- If no tracks, or only the Master track is visible, this returns nil, 0
-- But in that case getFirstTCPTrack has already returned either the master or -1
local function getLastTCPTrackBinary(tcpheight)
  assert(tcpheight, "getLastTCPTrack: invalid parameter - tcpheight")
  
  local numtracks = rpr.CountTracks(CURR_PROJ)
  if numtracks == 0 then return nil, 0 end
  
  -- is the last track visible?, If so we are done
  local track = rpr.GetTrack(CURR_PROJ, numtracks-1)
  local posy, _ = getTrackPosAndHeight(track)
  if posy < tcpheight then return track, numtracks end
  
  -- else, do a binary search
  -- A linear search from the first visible track could be faster...
  local left, right = 0, numtracks - 1
  while left <= right do
    local index = math.floor((left + right) / 2)
    local track = rpr.GetTrack(CURR_PROJ, index)
    local posy, height = getTrackPosAndHeight(track)
    if posy < tcpheight then
      if posy + height >= tcpheight then return track, index + 1 end
      left = index + 1
    elseif posy > tcpheight then
      right = index - 1
    else -- posy == tcpheight, the previous track is the last visible
      local track = rpr.GetTrack(CURR_PROJ, index - 1)
      return track, index
    end
  end

  return nil, 0
  
end -- getLastTCPTrackBinary
--------------------------------------------
-- Tracks can be invisible for two reasons:
-- 1. outside the TCP bounding box
-- 2. have visibility property turned off
local function collectVisibleTracks()
  
  local _, _, _, h = GetClientBounds(MFXlist.TCP_HWND)
  
  local _, findex = getFirstTCPTrackBinary()
  local _, lindex = getLastTCPTrackBinary(h)
  --Msg("First/last visible track: "..findex..", "..lindex)
  
  local vistracks = {}
  if findex < 0 then return vistracks end -- No visible tracks
  if findex == 0 then -- master track is visible
    local master = rpr.GetMasterTrack(CURR_PROJ)
    local minfo = getTrackInfo(master)
    table.insert(vistracks, minfo)
    findex = 1
  end
    
  for i = findex, lindex do
    local track = rpr.GetTrack(CURR_PROJ, i-1)
    local trinfo = getTrackInfo(track)
    if trinfo.visible then table.insert(vistracks, trinfo) end
  end
  
  --Msg(tprint(vistracks))
  return vistracks
  
end -- collectVisibleTracks
-----------------------------
local function drawHeader()
  
  --[ [
  -- Draw over everything above the FX list drawing area
  gfx.set(MFXlist.COLOR_EMPTYSLOT[1], MFXlist.COLOR_EMPTYSLOT[2], MFXlist.COLOR_EMPTYSLOT[3])
  gfx.rect(0, 0, gfx.w, MFXlist.TCP_top)
  --gfx.set(MFXlist.COLOR_FAINT[1], MFXlist.COLOR_FAINT[1], MFXlist.COLOR_FAINT[1])
  gfx.set(1, 1, 1, 0.7)
  gfx.x, gfx.y = 0, 0
  gfx.setfont(MFXlist.FONT_HEADER)
  gfx.drawstr(MFXlist.SCRIPT_NAME, 5, gfx.w, MFXlist.TCP_top)
  --]]
  --[[ -- Cannot get this to work correctly, don't know why, giving up for now
  -- Blit the bufhead
  gfx.dest = -1
  local headw, headh = gfx.getimgdim(MFXlist.BLITBUF_HEAD)
  local headx, heady = (headw - gfx.w) / 2, (headh - MFXlist.TCP_top) / 2
  gfx.blit(MFXlist.BLITBUF_HEAD, 1, 0, headx, heady, gfx.w, MFXlist.TCP_top, 0, 0, gfx.w, MFXlist.TCP_top)
  --]]
  
end -- drawHeader
------------------------------
local function drawFooter()
  
  -- Draw bottom line of FX list area (should not draw FX below this, it will be erased)
  gfx.line(0, MFXlist.TCP_bot, gfx.w, MFXlist.TCP_bot)  
  gfx.set(MFXlist.COLOR_EMPTYSLOT[1], MFXlist.COLOR_EMPTYSLOT[2], MFXlist.COLOR_EMPTYSLOT[3])
  gfx.rect(0, MFXlist.TCP_bot + 1, gfx.w, gfx.h - MFXlist.TCP_bot - 1)
  
  local text = MFXlist.footer_text
  if text and text ~= "" then 
    --Msg("text: "..text)
    gfx.set(1, 1, 1, 0.7)
    gfx.setfont(MFXlist.FONT_FXNAME, MFXlist.FONT_NAME1, MFXlist.FONT_SIZE1)
    gfx.x, gfx.y = 0, MFXlist.TCP_bot   
    gfx.drawstr(text, 5, gfx.w, gfx.h) -- Note, the last two parameters are the right/bottom COORDS of the box to draw within, not width/height
  end

end -- drawFooter
------------------------------
local function handleTracks()
  
  -- gfx.set(1, 1, 1)
  gfx.setfont(MFXlist.FONT_FXNAME)--, MFXlist.FONT_NAME1, MFXlist.FONT_SIZE1)
  
  MFXlist.fx_hovered = nil
  MFXlist.track_hovered = nil
  
  local drawy = MFXlist.TCP_top
  
  local vistracks = collectVisibleTracks()
  local numtracks = #vistracks
  for i = 1, numtracks do 
    gfx.set(1, 1, 1, gfx.a)
    local insidetrack = false -- used to send message from track to FX on track
    local trinfo = vistracks[i]
    local posy = trinfo.posy
    local height = trinfo.height
    local enabled = trinfo.enabled
    if MFXlist.mouse_y and posy <= MFXlist.mouse_y-drawy and MFXlist.mouse_y-drawy <= posy + height then
      MFXlist.footer_text = trinfo.name
      insidetrack = true -- send message to FX part of code, see below
      MFXlist.track_hovered = trinfo.track
    end
    -- Draw bounding box for track FX
    gfx.a = MFXlist.FX_OFFLINEDA -- always faint
    gfx.rect(0, drawy + posy, gfx.w, height, 0) -- rect around the slots for this track
    -- Calc the number of FX slots to draw, and draw them
    local fxlist = trinfo.fx
    local numfxs = math.floor(height / MFXlist.SLOT_HEIGHT) -- max num FX to show
    local count = math.min(#fxlist, numfxs)
    gfx.x, gfx.y = 0, drawy + posy  -- drawing FX names start at this position
    for i = 1, count do
      local fx = fxlist[i]
      gfx.a = (fx.enabled and not fx.offlined) and 1 or MFXlist.FX_DISABLEDA -- disabled FX are shown faint
      -- if mouse hovers over this FX, draw it in different color
      if insidetrack and gfx.y <= MFXlist.mouse_y and MFXlist.mouse_y < gfx.y + MFXlist.SLOT_HEIGHT then
        gfx.set(MFXlist.COLOR_FXHOVERED[1], MFXlist.COLOR_FXHOVERED[2], MFXlist.COLOR_FXHOVERED[3], gfx.a)
        gfx.setfont(MFXlist.FONT_FXBOLD)
        MFXlist.fx_hovered = i -- store fx index (1-based!) for mouse click
        -- Msg("fx_hovered assigned")
      else
        gfx.setfont(MFXlist.FONT_FXNAME)
        gfx.set(1, 1, 1, gfx.a)
      end
      gfx.x = 0
      gfx.drawstr(fx.fxname, 1, gfx.w, gfx.y + MFXlist.SLOT_HEIGHT)
      if fx.offlined then
        local w, h = gfx.measurestr(fx.name)
        local y = gfx.y+ MFXlist.SLOT_HEIGHT/2
        gfx.line((gfx.w-w)/2, y, (gfx.w+w)/2, y, gfx.a)
      end
      gfx.y = gfx.y + MFXlist.SLOT_HEIGHT
    end
  end
  
  drawHeader()
  drawFooter()

end -- handleTracks
---------------------------------------
local function handleMenu(mcap, mx, my)

  local menustr = MFXlist.MENU_STR
  if DO_DEBUG and mcap & MFXlist.MOD_KEYS == MFXlist.MOD_CTRL then -- Ctrl only?
    menustr = menustr.." | (Setup 10)"
  end
  
  MENU_SETUP10 = MFXlist.MENU_QUIT + 1 -- Only for debug!
  
  gfx.x, gfx.y = mx, my
  local ret = gfx.showmenu(menustr)
  if ret == MFXlist.MENU_QUIT then
    return ret
  elseif ret == MENU_SETUP10 then
    setupForTesting(10)
  elseif ret == MFXlist.MENU_SHOWFIRSTTCP then
    local startt = rpr.time_precise()
    local track, idx = getFirstTCPTrackBinary()
    local endt = rpr.time_precise()
    Msg("First visible track: "..idx.." ("..endt-startt..")")
  elseif ret == MFXlist.MENU_SHOWLASTTCP then
    local _, _, _, h = GetClientBounds(MFXlist.TCP_HWND)
    local startt = rpr.time_precise()
    local track, idx = getLastTCPTrackBinary(h)
    local endt = rpr.time_precise()
    Msg("Last visible track: "..idx.." ("..endt-startt..")")
  elseif ret == MFXlist.MENU_FINDLEFTDOCK then
    findLeftDock()
  end
  return ret
end -- handleMenu
--------------------------------------------
-- Swap bits 2 and 3 (0-based from the left)
local function swapCtrlShft(bits)	
  
  local mask = MFXlist.MOD_CTRL | MFXlist.MOD_SHIFT -- 0xC -- 1100
  local shftctrl = ((bits & MFXlist.MOD_CTRL) << 1) | ((bits & MFXlist.MOD_SHIFT) >> 1)

  return (bits & ~mask) | shftctrl

end -- swapCtrlShft
---------------------------------------------------------------
-- Mouse wheel over MFXlist, send the TCP a mousewheel message
-- Need to "interpret" modifier keys to windows standard
-- Reaper:  MLB, MRB, CTRL, SHFT, ALT, WIN, MID mouse button
-- Windows: MLB, MRB, SHFT, CTRL,    ,    , MID mouse button
-- bit indx  0    1     2    3    4    5     6
local function handleMousewheel(wheel, mx, my)
  
  -- put mx slightly to the right of our own track draw area
  -- to enter into the TCP area
  mx = gfx.w + 7 -- 7 pixels into the TCP area should be enough
  local screenx, screeny = gfx.clienttoscreen(mx, my) 
  
  -- There is an issue with passing mousewheel without mod keys on to the TCP
  -- The message affects the TCP *and* the arrange view, so we must do something
  if gfx.mouse_cap == 0 then
    -- Msg("CMD_SCROLLVERT, mx: "..mx..", screenx: "..screenx)
    -- rpr.Main_OnCommand(MFXlist.CMD_SCROLLVERT, 0) -- This does not work! Why?
    local mbkeys = 0x18 -- Ctrl + Alt (?)
       local retval = rpr.JS_WindowMessage_Send(MFXlist.TCP_HWND, 
      "WM_MOUSEWHEEL", 
      mbkeys, -- wParam, mouse buttons amd modifier keys
      wheel, -- wParamHighWWord, wheel distance
      screenx, screeny) -- lParam, lParamHighWord, need to fake it is over TCP?    
  else
    local mbkeys = swapCtrlShft(gfx.mouse_cap)
    --Msg("mouse_cap: "..gfx.mouse_cap..", mbkeys: "..mbkeys)
       local retval = rpr.JS_WindowMessage_Send(MFXlist.TCP_HWND, 
      "WM_MOUSEWHEEL", 
      mbkeys, -- wParam, mouse buttons amd modifier keys
      wheel, -- wParamHighWWord, wheel distance
      screenx, screeny) -- lParam, lParamHighWord, need to fake it is over TCP?
  end
  
  gfx.mouse_wheel = 0
  
end -- handleMousewheel
------------------------------
local function handleLeftMB(mcap, mx, my)
  
  local track = MFXlist.track_hovered

  if not MFXlist.track_hovered then -- we clicked over empty area or ouside track area
    
    Msg("TODO! Left click over header or footer. What to do?")    
    return
    
  elseif not MFXlist.fx_hovered then -- so we hover over track but not any fx
    
    
    rpr.TrackFX_Show(track, 0, 1) -- show FX chain but with no FX, how to open Add FX dialog?
    return
    
  end
  
  local index = MFXlist.fx_hovered
  local modkeys = mcap & MFXlist.MOD_KEYS
  -- Msg("modkeys: "..modkeys)
  if modkeys == 0 then -- simple click, show/hide floating window
    
    local showhide = rpr.TrackFX_GetOpen(track, index-1) and 2 or 3
    rpr.TrackFX_Show(track, index-1, showhide)
    
  elseif modkeys & (MFXlist.MOD_CTRL | MFXlist.MOD_ALT) == (MFXlist.MOD_CTRL | MFXlist.MOD_ALT) then
    
    local isoffline = rpr.TrackFX_GetOffline(track, index-1)
    rpr.TrackFX_SetOffline(track, index-1, not isoffline)
    
  elseif modkeys & MFXlist.MOD_SHIFT == MFXlist.MOD_SHIFT then -- set/unset enabled
    
    local endisabled = not rpr.TrackFX_GetEnabled(track, index-1)
    rpr.TrackFX_SetEnabled(track, index-1, endisabled)
    
  elseif modkeys & MFXlist.MOD_CTRL == MFXlist.MOD_CTRL then -- show/hide chain
    
    local openclose = rpr.TrackFX_GetOpen(track, index-1) and 0 or 1
    rpr.TrackFX_Show(track, index-1, openclose)
    
  elseif modkeys & MFXlist.MOD_ALT == MFXlist.MOD_ALT then -- delete
    
    rpr.TrackFX_Delete(track, index-1)
    
  end
  
end -- handleLeftMB
----------------------------
local function handleMouse()
  
  local mx, my = gfx.mouse_x, gfx.mouse_y
  
  -- if we are not inside the client rect, we can just as well return (but not quit)
  if mx < 0 or gfx.w < mx or my < 0 or gfx.h < my then -- outside of client area
    MFXlist.mouse_y = nil
    MFXlist.footer_text = MFXlist.SCRIPT_NAME
    return true 
  end    
  
  -- Are we inside the track draw area?
  if 0 <= mx and mx <= gfx.w and MFXlist.TCP_top <= my and my <= MFXlist.TCP_bot then 
    -- this only works when docked (but then... lots of stuff here only works when docked)
    MFXlist.mouse_y = my
    --MFXlist.fx_hovered = nil -- {0, 0} -- zerozero means not over any FX
  else -- either in header or in footer
    MFXlist.fx_hovered = nil
    MFXlist.mouse_y = nil
    MFXlist.footer_text = MFXlist.SCRIPT_NAME
  end
  
  local wheel = gfx.mouse_wheel
  if wheel ~= 0 then handleMousewheel(wheel, mx, my) end

  local mcap = gfx.mouse_cap
  local mbldown = mcap & MFXlist.MB_LEFT
  local mbrdown = mcap & MFXlist.MB_RIGHT
  
  -- is left mouse button clicked?
  if mbldown == MFXlist.MB_LEFT and mblprev ~= MFXlist.MB_LEFT then
    mblprev = MFXlist.MB_LEFT
    handleLeftMB(mcap, mx, my)
  elseif mbldown ~= MFXlist.MB_LEFT and mblprev == MFXlist.MB_LEFT then
    mblprev = 0
  end
  
  -- is right mouse button clicked?
  if mbrdown == MFXlist.MB_RIGHT and mbrprev ~= MFXlist.MB_RIGHT then
    --local mx, my = gfx.mouse_x, gfx.mouse_y
    mbrprev = MFXlist.MB_RIGHT
    local ret = handleMenu(mcap, mx, my) -- onRightClick()
    -- Msg("Showmenu returned: "..ret)
    if ret == MFXlist.MENU_QUIT then
      Msg("Quitting...")
      gfx.quit()
      return false -- tell the defer loop to quit
    end
  elseif mbrdown ~= MFXlist.MB_RIGHT and mbrprev == MFXlist.MB_RIGHT then
    mbrprev = 0
  end
  
  return true
  
end -- handleMouse
-----------------------------
local function exitScript()
  Msg("Bye, bye")
end -- exitScript
------------------------------------------------
local function openWindow()
  gfx.clear = MFXlist.COLOR_EMPTYSLOT[1] * 255 + MFXlist.COLOR_EMPTYSLOT[2] * 255 * 256 + MFXlist.COLOR_EMPTYSLOT[3] * 255 * 65536
  gfx.init(MFXlist.SCRIPT_NAME, MFXlist.WIN_W, MFXlist.WIN_H, MFXlist.LEFT_ARRANGEDOCKER, MFXlist.WIN_X, MFXlist.WIN_Y)
end -- openWindow
------------------------------------------------ 
local function initializeScript()
  
  -- findLeftDock() -- doesnt work (yet)
  
  rpr.atexit(exitScript)
  openWindow()
  
  gfx.setfont(MFXlist.FONT_FXNAME, MFXlist.FONT_NAME1, MFXlist.FONT_SIZE1)
  gfx.setfont(MFXlist.FONT_FXBOLD, MFXlist.FONT_NAME1, MFXlist.FONT_SIZE1, MFXlist.FONT_BOLDFLAG)
  gfx.setfont(MFXlist.FONT_HEADER, MFXlist.FONT_NAME2, MFXlist.FONT_SIZE2)
  
  local hwnd, x, y, w, h = getTCPProperties(MFXlist.CLASS_TCPDISPLAY) -- screen coordinates
  assert(hwnd, "Could not get TCP HWND, cannot do much now, sorry")
  MFXlist.TCP_HWND = hwnd
  
  local cx, cy = gfx.screentoclient(x, y)
  MFXlist.TCP_top = cy
  MFXlist.TCP_bot = MFXlist.TCP_top + h
    
  gfx.line(0, cy, gfx.w, cy) -- line on level with TCP top (do not draw FX above this)
  gfx.line(0, cy + h, gfx.w, cy + h) -- line on level with TCP bottom (do not draw FX below this)
  Msg("Dock: "..gfx.dock(-1)..", gfx.w: "..gfx.w..", gfx.h: "..gfx.h)
  Msg("TCP area (screen coords): "..x..", "..y..", "..w..", "..h)
  Msg("MFXlist header: 0, 0, "..gfx.w..", "..MFXlist.TCP_top) 
  Msg("MFXlist drawing area: 0, "..MFXlist.TCP_top..", "..gfx.w..", "..MFXlist.TCP_bot - MFXlist.TCP_top)
  Msg("MFXlist footer: 0, "..MFXlist.TCP_bot..", "..gfx.w..", "..gfx.h - MFXlist.TCP_bot)
  
  -- Set up the header buffer for blitting -- cannot seem to get the blit of the header to work 
  gfx.dest = MFXlist.BLITBUF_HEAD
  gfx.setimgdim(MFXlist.BLITBUF_HEAD, MFXlist.BLITBUF_HEADW, MFXlist.BLITBUF_HEADH) -- gfx.w, cy)
  gfx.clear = MFXlist.COLOR_EMPTYSLOT[1] * 255 + MFXlist.COLOR_EMPTYSLOT[2] * 255 * 256 + MFXlist.COLOR_EMPTYSLOT[3] * 255 * 256 * 256 -- will this clear gfx.dest?
  gfx.set(1, 1, 1, 0.7)
  gfx.x, gfx.y = 0, 0
  gfx.setfont(MFXlist.FONT_HEADER, MFXlist.FONT_NAME1, MFXlist.FONT_HEADSIZE, MFXlist.FONT_BOLDFLAG)
  gfx.drawstr(MFXlist.SCRIPT_NAME, 5, MFXlist.BLITBUF_HEADW, MFXlist.BLITBUF_HEADH) 
  
  gfx.dest = -1
  handleTracks()
  
end -- initializeScript
------------------------------------------------ Here is the main loop
local function mfxlistMain()
  
  local x, y, w, h = GetClientBounds(MFXlist.TCP_HWND)
  _, MFXlist.TCP_top = gfx.screentoclient(x, y) -- top y coord to draw FX at, above this only header stuff
  MFXlist.TCP_bot = MFXlist.TCP_top + h
  
  handleTracks()
  if not handleMouse() then return end
    
  -- Check if we are to quit or not
  local dstate = gfx.dock(-1)
  if gfx.getchar() < 0 then --or dstate == MFXlist.LEFT_ARRANGEDOCKER then
    Msg("dock state: "..dstate)
    gfx.quit()
    return
  end

  rpr.defer(mfxlistMain)
  
end -- mfxlistMain
------------------------------------------------ It all starts here, really
Msg("MFX-list ******")

--[[
local tracks = collectTracks()
Msg(tprint(tracks))
--]]

initializeScript()
mfxlistMain() -- run main loop

--[[ Stuff on dockers and HWNDs
https://forum.cockos.com/showthread.php?p=1507649#post1507649
https://forum.cockos.com/showthread.php?t=230919
https://forum.cockos.com/showthread.php?t=229668
https://forum.cockos.com/showthread.php?t=212174
https://forum.cockos.com/showthread.php?t=222314
https://forum.cockos.com/showthread.php?t=207081
https://forum.cockos.com/showthread.php?p=2203603
https://forum.cockos.com/showthread.php?t=221174
--]]