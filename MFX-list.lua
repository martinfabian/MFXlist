-- @description FX list for Reaper left docker (MFX-list)
-- @author M Fabian, inlcude code by Edgemeal
-- @version 0.0.1
-- @changelog
--   Nothing yet, or rather... everything
-- @link
--   Forum Thread https://forum.cockos.com/showthread.php?t=210987
-- @screenshot 
-- @donation something.good.for.humankind 
-- @about
--   # Native ReaScript reimplementation of Doppelganger's FXlist

local string, table, math, os, utf8 = string, table, math, os, utf8
local load, xpcall, pairs, ipairs = load, xpcall, pairs, ipairs, select
local rpr, gfx = reaper, gfx
-----------------------------------------  Just for debugging
local DO_DEBUG = true
local function Msg(str)
   if DO_DEBUG then rpr.ShowConsoleMsg(tostring(str).."\n") end
end
-------------------------------------------
local MFXlist = 
{
  SCRIPT_NAME = "MFX-list for Reaper",
  VERSION = "0.0.1",
  
  MB_LEFT = 1,
  MB_RIGHT = 2,
  
  MOD_CTRL = 4, 
  MOD_SHIFT = 8,
  MOD_ALT = 16, 
  MOD_WIN = 32, 
  MOD_KEYS = 4+8+16+32, 
  
  MENU_STR = "Show tracks|Show first track|Show last track|Quit",
  MENU_SHOWTRACKS = 1,
  MENU_SHOWFIRSTTCP = 2,
  MENU_SHOWLASTTCP = 3,
  MENU_QUIT = 4,

  COLOR_BLACK   = {012, 012, 012},
  COLOR_VST     = {},
  COLOR_JSFX    = {},
  COLOR_HIGHLIGHT = {},
  COLOR_EMPTYSLOT = {40, 40, 40},
  
  FONT_NAME1 = "Arial",
  FONT_NAME2 = "Courier New",
  FONT_SIZE = 14,
  
  SLOT_HEIGHT = 12, -- pixels high
  
  MATCH_UPTOCOLON = "(.-:)",
  
  WIN_X = 1000,
  WIN_Y = 200,
  WIN_W = 200,
  WIN_H = 200,
  LEFT_ARRANGEDOCKER = 512+1, -- 512 = left of arrange view, +1 == docked
  
  TCP_HWND = nil, -- filled in when script initializes (so strictly speaking not constant, but yeah...)
  TOP_LINEY = nil, -- Also filled in when initializing (meaningful to have it stored?)
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
end
------------------------------------------------------
local function FindChildByClass(hwnd, classname, occurance) 
  local arr = rpr.new_array({}, 255)
  rpr.JS_Window_ArrayAllChild(hwnd, arr)
  local adr = arr.table() 
  local control_occurance = 0
  local count = #adr
  for j = 1, count do
    local hwnd = rpr.JS_Window_HandleFromAddress(adr[j]) 
    if rpr.JS_Window_GetClassName(hwnd) == classname then
      control_occurance = control_occurance + 1
      if occurance == control_occurance then
        return hwnd
      end
    end
  end
end
---------------------------------------------------------
-- Returns the HWND and the screen coordinates of the TCP
local function getTCPProperties()
-- get first reaper child window with classname "REAPERTCPDisplay".
  local tcp_hwnd = FindChildByClass(rpr.GetMainHwnd(), 'REAPERTCPDisplay', 1)
  if tcp_hwnd then
    local x,y,w,h = GetClientBounds(tcp_hwnd)
    --msg(w) -- show width
    return tcp_hwnd, x, y, w, h
  end
  return nil, -1, -1, -1, -1
end
--------------------------------------------------------
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
    table.insert(fxtab, {fxname = fxname, fxtype = fxtype, enabled = enabled}) -- confusing <key, value> pairs here, but it works
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
-- A track can be invisible from teh TCP for two reasons:
-- 1. It has its TCP visbility property set to false (and then its height seems to eb 0)
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
  
  if rpr.GetMasterTrackVisibility() & 0x1 == 1 then -- Master track visible in TCP
    local master = rpr.GetMasterTrack(CURR_PROJ)
    local posy, height = getTrackPosAndHeight(master)
    if height + posy > 0 then return master, 0 end
  end
  
  local numtracks = rpr.CountTracks(CURR_PROJ)
  if numtracks == 0 then return nil, -1 end
  
  local left, right = 0, numtracks - 1
  while left <= right do
    local index = math.floor((left + right) / 2)
    local track = rpr.GetTrack(CURR_PROJ, index)
    local posy, height = getTrackPosAndHeight(track)
    if posy < 0 then
      if posy + height > 0 then return track, index + 1 end
      left = index + 1
    elseif posy > 0 then
      right = index - 1
    else -- posy == 0, then this is the one
      return track, index + 1
    end      
  end
  assert(nil, "getFirstTCPTrackBinary: Should never get here!")
  
end -- getFirstTCÅTracksBinary
---------------------------------------------------------------------------
-- Does a binary search, halving and halving until it finds the rigth track
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
  
end -- getLastTCPTrackLinear
--------------------------------------------
-- Tracks can be invisible for two reasons:
-- 1. outside the TCP bounding box
-- 2. have visibility property turned off
local function collectVisibleTracks()
  
  local _, _, _, h = GetClientBounds(MFXlist.TCP_HWND)
  
  local _, findex = getFirstTCPTrackBinary()
  local _, lindex = getLastTCPTrackBinary(h)
  Msg("First/last visible track: "..findex..", "..lindex)
  
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
------------------------------
local function drawTracks()
  
  gfx.r, gfx.g, gfx.b = 0, 0, 0
  gfx.setfont(2, MFXlist.FONT_NAME1, MFXlist.FONT_SIZE)
  
  local x, y, _, h = GetClientBounds(MFXlist.TCP_HWND)
  local _, drawy = gfx.screentoclient(x, y)
    
  local vistracks = collectVisibleTracks()
  local numtracks = #vistracks
  for i = 1, numtracks do 
    local trinfo = vistracks[i]
    local posy = trinfo.posy
    local height = trinfo.height
    gfx.rect(0, drawy + posy, gfx.w, height, 0)
    --drawy = drawy + height
    local fxlist = trinfo.fx
    gfx.x, gfx.y = 0, drawy + posy    
    for i = 1, #fxlist do
      gfx.x = 0
      --gfx.drawstr(trinfo.name, 1, gfx.w, gfx.y + MFXlist.FONT_SIZE) -- https://forum.cockos.com/showthread.php?t=226916
      gfx.drawstr(fxlist[i].fxname, 1, gfx.w, gfx.y + MFXlist.FONT_SIZE)
      gfx.y = gfx.y + MFXlist.FONT_SIZE
      --Msg(trinfo.name..": "..fxlist[i].fxname)
    end
  end
  
  gfx.r, gfx.g, gfx.b = 1, 1, 1
  gfx.line(0, drawy + h, gfx.w, drawy + h)
  
end -- drawTracks
------------------------------------------------
local function openWindow()
  gfx.clear = MFXlist.COLOR_EMPTYSLOT[1] + MFXlist.COLOR_EMPTYSLOT[2] * 256 + MFXlist.COLOR_EMPTYSLOT[3] * 65536
  gfx.init(MFXlist.SCRIPT_NAME, MFXlist.WIN_W, MFXlist.WIN_H, MFXlist.LEFT_ARRANGEDOCKER, MFXlist.WIN_X, MFXlist.WIN_Y)
end
---------------------------------------
local function handleMenu(m_cap, mx, my)

  local menustr = MFXlist.MENU_STR
  if DO_DEBUG and m_cap & MFXlist.MOD_KEYS == MFXlist.MOD_CTRL then -- Ctrl only?
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
  elseif ret == MFXlist.MENU_SHOWTRACKS then
    local tracks = collectTracks()
    showTracks(tracks)
  end
  return ret
end -- handleMenu

-----------------------------
local function exitScript()
  Msg("Bye, bye")
end -- exitScrip
------------------------------------------------ 
local function initializeScript()
  
  rpr.atexit(exitScript)
  openWindow()
  local hwnd, x, y, w, h = getTCPProperties() -- screen coordinates
  assert(hwnd, "Could not get TCP HWND, cannot do much now")
  
  MFXlist.TCP_HWND = hwnd
  local cx, cy = gfx.screentoclient(x, y)
  gfx.line(0, cy, gfx.w, cy)
  gfx.line(0, cy + h, gfx.w, cy + h)
  Msg("Dock: "..gfx.dock(-1)..", gfx.w: "..gfx.w..", gfx.h: "..gfx.h)
  Msg("TCP x: "..x..", y: "..y..", w: "..w..", h:"..h)
  
  drawTracks()
  
end -- initializeScript
------------------------------------------------ Here is the main loop
local function mfxlistMain()
  
  -- mouse handling etc
  local m_cap = gfx.mouse_cap
  local mbr_down = m_cap & MFXlist.MB_RIGHT
  if mbr_down == MFXlist.MB_RIGHT and mbr_prev ~= MFXlist.MB_RIGHT then
    mx, my = gfx.mouse_x, gfx.mouse_y
    mbr_prev = MFXlist.MB_RIGHT
    local ret = handleMenu(m_cap, mx, my) 
    -- Msg("Showmenu returned: "..ret)
    if ret == MFXlist.MENU_QUIT then
      Msg("Quitting...")
      gfx.quit()
      return
    end
  elseif mbr_down ~= MFXlist.MB_RIGHT and mbr_prev == MFXlist.MB_RIGHT then
    mbr_prev = 0
  end
  
  --drawTracks()
  
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
--Msg("Num tracks: "..rpr.CountTracks(CURR_PROJ))

-- setupForTesting(10)
initializeScript()

-- local tracks = collectTracks()
-- Msg(tprint(tracks))
-- showTracks(tracks)

-- local track, index = getFirstTCPTrackLinear()
-- Msg("First visible track: "..index)

mfxlistMain()

--[[ Stuff on dockers and HWNDs
https://forum.cockos.com/showthread.php?p=1507649#post1507649
https://forum.cockos.com/showthread.php?t=230919
https://forum.cockos.com/showthread.php?t=229668
https://forum.cockos.com/showthread.php?t=212174
https://forum.cockos.com/showthread.php?t=222314
https://forum.cockos.com/showthread.php?t=207081
https://forum.cockos.com/showthread.php?p=2203603
--]]