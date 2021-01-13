-- @description FX list for Reaper left docker (MFX-list)
-- @author M Fabian, inlcudes code by Edgemeal
-- @SCRIPT_version 0.0.1
-- @changelog
--   Nothing yet, or rather... everything
-- @link
--   Forum Thread https://forum.cockos.com/showthread.php?t=210987
-- @screenshot 
-- @donation something.good.for.humankind 
-- @about
--   # Native ReaScript reimplementation of Doppelganger's FXlist (only the FX part, not the send stuff etc)
--   # Needs the js_ReaScriptAPI (tested with reaper_js_ReaScriptAPI64.dll) by 
--   #         Julian Sander, https://forum.cockos.com/showthread.php?t=212174
--   # Developed using ZeroBrane Studio as IDE, https://studio.zerobrane.com/

-- Done! BIG THING! Have to give focus back to arrange view, otherwise spacebar does not play! WTF? 
--       There is some type of focus-steling going on. Click an FX, while its window is open, spacebar works as play
--       But click again (on MFXlist) to close the floating window. Now spacebar does NOT play! WTF sorcery is this?
--       Discussion on this here https://forum.cockos.com/showthread.php?t=161000, TL;DR: "SWS/BR: Focus arrange on mouse release"
--       But there is also SWS/BR: Focus tracks, maybe that one is more suitable?
--     * This is now done, except for the mouse wheel issue (see below)
-- Done! Fix the scrolling, Mousewheel scroll over MFXlist sends message to TCP, but the arrange view is scrolled! 
-- TODO! Ctrl+Mousewheel in track area does not work the same way as Ctrl+Mousewheel over TCP
-- TODO! Clicking in track area outside of any FX opens FX Chain window. Clicking again, should close it. How to? 
--       This is a problem for empty FX chains
-- TODO! Open Add FX dialog instead of FX Chain window on left click on empty slot. Have no idea how to do that, though.
--       Also, only clicking on empty slot (right below last FX) should open Add FX, no?
-- TODO! Find left docker to attach to automatically? Manual positiono works and is saved, but...
-- Done! Allow drag of FX within and between track(s) rpr.TrackFX_CopyToTrack(src_track, src_fx, dest_track, dest_fx, bool is_move)
--       Note that this requires change to the handling of the left MB, as it is now, down is interpreted as click
-- Done! Track with FX chain disabled, looks no different from each FX disabled by itself (same as dopplist), but maybe should? How?
-- TODO! Dragging, clicking, or just holding left MB down on header or footer should scroll, down for header, up for footer
-- Done! Partially visible FX name inside track rectangle is not cropped correctly. floor was changed to ceil, but not good enough
-- Done! Undo, definitely for Alt+leftclick, but also for drag-drop
--       This turned out to be window focus issue, see GitHub Issue #5 (now closed)
-- Done! Measure time between mouse wheel to give focus to TCP when no mouse wheel for a certain time
--    *  This is now done, but it seems that in general it would be good to give to focus after some inactivity

-- POSS? Double-click... to do what? Nah, too much hassle, have to keep track of time in-between LMB up and down...

local string, table, math, os, utf8 = string, table, math, os, utf8
local load, xpcall, pairs, ipairs = load, xpcall, pairs, ipairs, select
local rpr, gfx = reaper, gfx
-----------------------------------------  Just for debugging
local DO_DEBUG = true
local function Msg(str)
   if DO_DEBUG then rpr.ShowConsoleMsg(tostring(str).."\n") end
end
-------------------------------------------
-- Variables with underscore are global
-- All caps denotes constants, do not assign to these in the code!
-- Non-constants are used to communicate between different parts of the code
local MFXlist = 
{ 
  -- user settable stuff
  COLOR_EMPTYSLOT = {40/255, 40/255, 40/255},
  COLOR_FXHOVERED = {1, 1, 0}, 
  --[[ not used for now
  COLOR_BLACK   = {012/255, 012/255, 012/255},
  COLOR_VST     = {},
  COLOR_JSFX    = {},
  COLOR_HIGHLIGHT = {},
  COLOR_FAINT = {60/255, 60/255, 60/255},
  --]]
  FX_DISABLEDA = 0.3, -- fade of name for disabled FX
  FX_OFFLINEDA = 0.1, -- even fainter for offlined FX
  
  -- Delay for return of focus during mouse wheel
  FOCUS_DELAY = 10, 
  
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
  
  -- Script specific constants, from here below change only if you really know what you are doing
  SCRIPT_VERSION = "v0.0.1",
  SCRIPT_NAME = "MFX-list",
  SCRIPT_AUTHORS = {"M Fabian"},
  SCRIPT_YEAR = "2020-2021",
  
  -- Mouse button and modifier key constants
  MB_LEFT = 1,
  MB_RIGHT = 2,
  
  MOD_CTRL = 4, 
  MOD_SHIFT = 8,
  MOD_ALT = 16, 
  MOD_WIN = 32, 
  MOD_KEYS = 4+8+16+32, 
  
  -- determinse how far nmouse can be moved between down and up to still be considered a left click
  -- this then also decides how much the mosue has to move with left MB down to be considered as dragging
  CLICK_RESOX = 10, -- it makes sense to horizontally accept more movement than vertically
  CLICK_RESOY = 3, 
  
  -- Right click menu 
  MENU_STR = "Linear find last|Show first track|Show last track|Info|Quit",
  MENU_FINDLEFTDOCK = 100, -- big number means "not used"
  MENU_LINEARFINDLAST = 1,
  MENU_SHOWFIRSTTCP = 2,
  MENU_SHOWLASTTCP = 3,
  MENU_SHOWINFO = 4,
  MENU_QUIT = 5,
  
  -- Flag constants for TrackFX_Show(track, index, showFlag)
  FXCHAIN_HIDE = 0, 
  FXCHAIN_SHOW = 1,
  FXFLOAT_HIDE = 2,
  FXFLOAT_SHOW = 3,
  
  -- flag constants for GetTrackState(track) return
  TRACK_FXENABLED = 4, 
  TRACK_MUTED = 8, -- seemed liek a good idea, but don't know how to really use it
  
  -- Height for FX slots, FX names are drawn sentered (and clipped) inside this high rectangles
  SLOT_HEIGHT = 13, -- pixels high
  
  -- For matching and shrinking FX names
  MATCH_UPTOCOLON = "(.-:)",
  
  -- Nondocked window size, and docker address (overridden from EXTSTATE if such exists)
  WIN_X = 1000,
  WIN_Y = 200,
  WIN_W = 200,
  WIN_H = 200,
  LEFT_ARRANGEDOCKER = 512+1, -- 512 = left of arrange view, +1 == docked (not universally true)
  
  -- Window class names to look for, I have no idea how or if this works on Mac/Linux
  -- CLASS_TRACKLISTWIN = "REAPERTrackListWindow", -- this is the arrange view where the media items live
  CLASS_TCPDISPLAY = "REAPERTCPDisplay", -- this is the TCP where the track panes live
  
  TCP_HWND = nil, -- filled in when script initializes (so strictly speaking not constant, but yeah...)
  TCP_top = nil, -- Set on every defer before calling any other function
  TCP_bot = nil, -- Set on every defer before calling any other function
  
  MFX_HWND = nil, -- this is our own window, need this to make mousewheel work
  
  ACT_SCROLLVERT = 989, -- View: Scroll vertically (MIDI CC relative/mousewheel)
  ACT_ZOOMVERT = 991, -- View: Zoom vertically (MIDI CC relative/mousewheel)
  ACT_SCROLLVIEWDOWN = 40139, -- View: Scroll view down
  ACT_SCROLLVIEWUP = 40138, -- View: Scroll view up
  
  CMD_FOCUSARRANGE = 0, -- SWS/BR: Focus arrange (_BR_FOCUS_ARRANGE_WND)
  CMD_FOCUSTRACKS = 0,  -- SWS/BR: Focus tracks (_BR_FOCUS_TRACKS)
  CMD_SCROLLTCPDOWN = 0,-- Xenakios/SWS: Scroll track view down (page)
  CMD_SCROLLTCPUP = 0,  -- Xenakios/SWS: Scroll track view up (page)
  
  -- off-screen draw buffer for the header (coudl not get thsi to work, see drawHeader() below)
  BLITBUF_HEAD = 16, 
  BLITBUF_HEADW = 300,
  BLITBUF_HEADH = 300,
  
  -- Globally accessible variables used to communicate between different parts of the code
  mouse_y = nil, -- is set to mouse_y when mouse inside MFXlist, else nil
  track_hovered = nil, -- is set to the track (ptr) currently under mouse cursor, nil if mouse outside of client are
  fx_hovered = nil, -- is set to the index (1-based!) of FX under the mouse cursor, nil if mouse is outside of current track FX 
  
  mbl_downx = nil, -- stores left mouse button down coords, used for left MB drag actions
  mbl_downy = nil,
  down_object = nil, -- {track, fx} stores left mouse button down object if any
  drag_object = nil, -- {track, fx} that is dragged, given by track_hovered, fx_hovered
  drag_endx = nil,
  drag_endy = nil,
  
  openwin_list = nil, -- list of currently open windows to help the external win-close focus issue
  
  footer_text = "MFX-list", -- changes after initializing, shows name of currently hovered track
  header_text = "MFX-list", -- this doesn't really change after initialzing, but could if useful
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
-------------------------- Windows specific stuff here --------------------------------------------------------------
-------------------------------------------------------- Stolen from https://forum.cockos.com/showthread.php?t=230919
-- Requires js_ReaScriptAPI extension, 
-- https://forum.cockos.com/showthread.php?t=212174
local function getClientBounds(hwnd)
  
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
local function getTCPProperties()
-- get first reaper child window with classname "REAPERTCPDisplay".
  local tcp_hwnd = FindChildByClass(rpr.GetMainHwnd(), MFXlist.CLASS_TCPDISPLAY, 1) 
  if tcp_hwnd then
    local x,y,w,h = getClientBounds(tcp_hwnd)
    --msg(w) -- show width
    return tcp_hwnd, x, y, w, h
  end
  return nil, -1, -1, -1, -1
end
------------------------------------------------------------------------------------
-- This works, except for when no modifier key is used, then it scrolls the arrange!
local function sendTCPWheelMessage(mbkeys, wheel, screenx, screeny)
  
  local retval = rpr.JS_WindowMessage_Send(MFXlist.TCP_HWND, 
      "WM_MOUSEWHEEL", 
      mbkeys, -- wParam, mouse buttons and modifier keys
      wheel, -- wParamHighWWord, wheel distance
      screenx, screeny) -- lParam, lParamHighWord, need to fake it is over TCP?  
  
  return retval

end -- sendTCPWheelMessage
--------------------------------------------------------------------
-- None of these seem to work, disregard
local function sendTCPScrollMessage(mbkeys, wheel, screenx, screeny)
  
  -- From swell-types.h: 
  local SB_LINEUP, SB_LINEDOWN = 0, 1
  local updown = wheel < 0 and SB_LINEDOWN or SB_LINEUP
  local retval = rpr.JS_WindowMessage_Send(MFXlist.TCP_HWND, "WM_VSCROLL", updown, 0, 0, 0)
  
  -- Could not get this to work
  -- From here https://forum.cockos.com/showpost.php?p=2146483&postcount=564
  -- local LVM_SCROLL = "0x1014"
  -- rpr.JS_WindowMessage_Send(MFXlist.TCP_HWND, LVM_SCROLL, 0, 0, wheel, 0)
  
end
---------------------------------------------- SWS specifc stuff go here
local function initSWSCommands()
  
  MFXlist.CMD_FOCUSARRANGE = rpr.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
  MFXlist.CMD_FOCUSTRACKS = rpr.NamedCommandLookup("_BR_FOCUS_TRACKS")
  MFXlist.CMD_SCROLLTCPDOWN = rpr.NamedCommandLookup("_XENAKIOS_TVPAGEDOWN") -- scrolls TCP, but too much
  MFXlist.CMD_SCROLLTCPUP = rpr.NamedCommandLookup("_XENAKIOS_TVPAGEUP")
  
end 
-------------------------------------------------
-- These scroll whole pages, I don't want that
local function scrollTCPUp()
  
  rpr.Main_OnCommand(MFXlist.CMD_SCROLLTCPUP, 0)
  
end -- scrollTCPUp
-------------------------------
local function scrollTCPDown()
  
  rpr.Main_OnCommand(MFXlist.CMD_SCROLLTCPDOWN, 0)
  
end -- scrollTCPDown
-----------------------------------------------
-- Set the focus to TCP so keystrokes go there
-- Called after (almost) every mouse click
local function focusTCP()

  -- rpr.Main_OnCommand(MFXlist.CMD_FOCUSTRACKS, 0) -- SWS
  rpr.JS_Window_SetFocus(MFXlist.TCP_HWND)
  -- rpr.SetCursorContext(0) -- native

end -- focusTCP
local function focusMFX()
  
  rpr.JS_Window_SetFocus(MFXlist.MFX_HWND)
  
end -- focusMFX
----------------------------------------------------------
-- Simple linked list implementation for the openwin_list
local linkedList = 
{
  head = nil,
  length = 0,
  
  new = function()
          local self = {}
          setmetatable(self, {__index = linkedList})
          return self
        end, -- new
        
  insert = function(self, element) 
              self.head = {next = self.head, elem = element}
              self.length = self.length + 1
              return 
            end, -- insert
            
  print = function(self)
            if not self.head then
              print("<empty list>")
              return
            end
            local ptr = self.head
            while ptr do
              print(ptr.elem)
              ptr = ptr.next
            end
          end, -- print
          
  find = function(self, element)
          local ptr = self.head
          while ptr do
            if ptr.elem == element then 
              return ptr -- found it
            end
            ptr = ptr.next
          end
          return ptr -- nil     
        end, -- find
        
  -- Have to first find, then remove
  remove = function(self, ptr)
            if not ptr then return false end
            
            if ptr == self.head then
              self.head = self.head.next
              self.length = self.length - 1
              return true
            end
            local pptr = self.head
            while pptr do
              if pptr.next == ptr then 
                pptr.next = ptr.next -- adjust links
                self.length = self.length - 1
                return true
              end
              pptr = pptr.next
            end
            return false -- not found    
          end, -- remove (ptr)
}
----------------------------------------------------------------
-- This doesn't work, I find no way to make sense of the docker
local function findLeftDock()
  
  local mhwnd = rpr.GetMainHwnd()
  local _, mleft, mtop, mright, mbottom = rpr.JS_Window_GetClientRect(mhwnd)
  Msg("MainHwnd, left: "..mleft..", top: "..mtop..", right: "..mright..", bottom: "..mbottom)
  
  local adr = getTitleMatchWindows("REAPER_dock", true) -- this does get all 16 dockers
  local count = #adr
  local docknumber = 0 -- the order of how the dockers are returned does not make sense to me
  for i = 1, count do
    local hwnd = rpr.JS_Window_HandleFromAddress(adr[i]) 
    --local classname = rpr.JS_Window_GetClassName(hwnd)
    --Msg("i: "..i..", adr: "..adr[i]..", class: "..classname)
    --if classname == "REAPER_dock" then
      local _, left, top, right, bottom = rpr.JS_Window_GetRect(hwnd) 
      Msg("REAPER_dock #"..docknumber..", left: "..left..", top: "..top..", right: "..right..", bottom: "..bottom)
      if left == mleft then -- this should be the left docker?
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

  return nil, 0 -- we should never really get here
  
end -- getLastTCPTrackBinary
--------------------------------------------------------------------
-- Since the TCP has a limited number of visible tracks, a linear search
-- starting from the first visible track may be faster than a binary
-- That was the idea, but measuring there seems to be no significant improvement
-- Instead binary search is slightly better with many visible tracks 
local function getLastTCPTrackLinear(tcpheight, firsttrack)
  assert(tcpheight and firsttrack, "getLastTrackLinear: invalid parameter - tcpheight or firsttrack")

  -- Same as in binary search, first take care of some obvious easy cases
  local numtracks = rpr.CountTracks(CURR_PROJ)
  if numtracks == 0 then return nil, 0 end
  
  -- is the last track visible?, If so we are done
  local track = rpr.GetTrack(CURR_PROJ, numtracks-1)
  local posy, _ = getTrackPosAndHeight(track)
  if posy < tcpheight then return track, numtracks end
  
  -- else, look from the first towards the last linearily
  for i = firsttrack, numtracks do -- firsttrack is 1-based
    local track = rpr.GetTrack(CURR_PROJ, i-1)
    local posy, height = getTrackPosAndHeight(track)
    if posy + height > tcpheight then return track, i end
  end

  assert(nil, "getLastTCPTrackLinear: should not really get here!")
  
end -- getLastTCPTrackLinear
--------------------------------------------
-- Tracks can be invisible for two reasons:
-- 1. outside the TCP bounding box
-- 2. have visibility property turned off
local function collectVisibleTracks()
  
  local _, _, _, h = getClientBounds(MFXlist.TCP_HWND)
  
  local _, findex = getFirstTCPTrackBinary()
  local _, lindex = getLastTCPTrackBinary(h)
  
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
  gfx.drawstr(MFXlist.header_text, 5, gfx.w, MFXlist.TCP_top)
  gfx.a = MFXlist.FX_DISABLEDA
  gfx.line(0, MFXlist.TCP_top, gfx.w, MFXlist.TCP_top)
  --]]
  --[[ -- Cannot get this to work correctly, don't know why, giving up for now
       -- It does not blit over the top part of the track draw
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
----------------------------------
local function drawDropIndicator()
  
  if gfx.mouse_cap & MFXlist.MOD_CTRL == MFXlist.MOD_CTRL then
    gfx.set(0, 0, 1) -- blue indicates copy
  else
    gfx.set(0, 1, 0) -- green indicates move
  end
  gfx.line(10, gfx.y, gfx.w-10, gfx.y)
  
end -- drawDropIndicator
-----------------------
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
    local chainon = trinfo.enabled -- track FX chain enabled
    -- if the mouse is currently inside this track rect
    if MFXlist.mouse_y and posy <= MFXlist.mouse_y-drawy and MFXlist.mouse_y-drawy <= posy + height then
      
      MFXlist.footer_text = trinfo.name
      insidetrack = true -- send message to FX part of code, see below
      MFXlist.track_hovered = trinfo.track
      
    end
    -- Draw bounding box for track FX
    gfx.a = MFXlist.FX_OFFLINEDA -- bounding box is always drawn faint
    gfx.rect(0, drawy + posy, gfx.w, height, (chainon and 0 or 1)) -- abled chain is not filled with faint color
    -- Calc the number of FX slots to draw, and draw them
    local fxlist = trinfo.fx
    local numfxs = math.ceil(height / MFXlist.SLOT_HEIGHT) -- max num FX to show 
    local count = math.min(#fxlist, numfxs)
    local cropy = drawy+posy+height-1 -- crop FX name slot to this
    gfx.x, gfx.y = 0, drawy + posy  -- drawing FX names start at this position
    for i = 1, count do
      local fx = fxlist[i]
      gfx.a = (fx.enabled and not fx.offlined and chainon) and 1 or MFXlist.FX_DISABLEDA -- disabled FX are shown faint
      -- if mouse hovers over this FX, draw it in different color
      if insidetrack and gfx.y <= MFXlist.mouse_y and MFXlist.mouse_y < gfx.y + MFXlist.SLOT_HEIGHT then
        
        gfx.set(MFXlist.COLOR_FXHOVERED[1], MFXlist.COLOR_FXHOVERED[2], MFXlist.COLOR_FXHOVERED[3], gfx.a)
        gfx.setfont(MFXlist.FONT_FXBOLD)
        MFXlist.fx_hovered = i -- store fx index (1-based!) for mouse click
        
      else
        
        gfx.setfont(MFXlist.FONT_FXNAME)
        gfx.set(1, 1, 1, gfx.a)
        
      end
      gfx.x = 0
      local corner = math.min(gfx.y + MFXlist.SLOT_HEIGHT, cropy) -- make sure to crop within the bounding track rect
      gfx.drawstr(fx.fxname, 1, gfx.w, corner) 
      if fx.offlined then -- strikeout offlined FX
        
        local w, h = gfx.measurestr(fx.name)
        local y = gfx.y + MFXlist.SLOT_HEIGHT/2
        gfx.line((gfx.w-w)/2, y, (gfx.w+w)/2, y, gfx.a)
        
      end
      -- if dragging and are on top of this FX, show drop indicator above it
      if insidetrack and MFXlist.drag_object and MFXlist.fx_hovered == i then
        
        drawDropIndicator()
        
      end
      gfx.y = gfx.y + MFXlist.SLOT_HEIGHT
      
    end
    -- if dragging and not hovering any FX, draw drop indicator at end of FX chain
    if insidetrack and MFXlist.drag_object and not MFXlist.fx_hovered then
      
      drawDropIndicator()
      
    end
  end
  
  drawHeader()
  drawFooter()

end -- handleTracks
-----------------------------------------
-- Shows it in Reaper's console (for now)
-- Not using Msg here, since we want this
-- to show even if DO_DEBUG is false
local function showInfo(mx, my)
  
  rpr.ShowConsoleMsg(MFXlist.SCRIPT_NAME.." "..MFXlist.SCRIPT_VERSION..'\n')
  local authors = table.concat(MFXlist.SCRIPT_AUTHORS, ", ")
  rpr.ShowConsoleMsg(authors..", "..MFXlist.SCRIPT_YEAR..'\n')
  
end -- showInfo
---------------------------------------
local function handleMenu(mcap, mx, my)

  local menustr = MFXlist.MENU_STR
  if DO_DEBUG and mcap & MFXlist.MOD_KEYS == MFXlist.MOD_CTRL then -- Ctrl only
    menustr = menustr.." | (Setup 10)"
  end
  
  MENU_SETUP10 = MFXlist.MENU_QUIT + 1 -- Only for debug!
  
  gfx.x, gfx.y = mx, my
  local ret = gfx.showmenu(menustr)
  if ret == MFXlist.MENU_QUIT then
    return ret
  elseif ret == MFXlist.MENU_SHOWINFO then
    showInfo(mx, my)
  elseif ret == MENU_SETUP10 then
    setupForTesting(10)
  elseif ret == MFXlist.MENU_SHOWFIRSTTCP then
    local startt = rpr.time_precise()
    local track, idx = getFirstTCPTrackBinary()
    local endt = rpr.time_precise()
    Msg("First visible track: "..idx.." ("..endt-startt..")")
  elseif ret == MFXlist.MENU_SHOWLASTTCP then
    local _, _, _, h = getClientBounds(MFXlist.TCP_HWND)
    local startt = rpr.time_precise()
    local track, idx = getLastTCPTrackBinary(h)
    local endt = rpr.time_precise()
    Msg("Last visible track (bin): "..idx.." ("..endt-startt..")")
  elseif ret == MFXlist.MENU_LINEARFINDLAST then
    local ftrack, fidx = getFirstTCPTrackBinary()
    local _, _, _, h = getClientBounds(MFXlist.TCP_HWND)
    local startt = rpr.time_precise()
    local ltrack, lidx = getLastTCPTrackLinear(h, fidx)
    local endt = rpr.time_precise()
    Msg("Last visible track (lin): "..lidx.." ("..endt-startt..")")
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
-- These variables are global but locally to handleWheel
local count_down = 0 
local prev_wheel = 0

local function handleWheel(mcap, mx, my)
  
  local wheel = gfx.mouse_wheel
  gfx.mouse_wheel = 0
  
  if wheel == 0 and prev_wheel == 0 then 
    
    if count_down == 0 then return end
    
    count_down = count_down - 1 
    if count_down == 0 then
      focusTCP() -- do this after count down
    end
    return 
    
  end -- no wheeling, nothing more to do

  count_down = MFXlist.FOCUS_DELAY
  
  -- So here wheel ~= 0, if this is the first time we need to grab focus and wait one scan cycle to get mod keys
  if prev_wheel == 0 then -- remeber current wheel so we can act on it on the next scan
    
    prev_wheel = wheel -- remember wheel value
    focusMFX() -- set focus so we get the mod keys
    return
    
  end
  
  -- Here prev_wheel ~= 0 and focus is on MFX
  
  if mcap == 0 then -- no mod key
    
    if prev_wheel < 0 then
      rpr.Main_OnCommand(MFXlist.ACT_SCROLLVIEWDOWN, 0)
    else
      rpr.Main_OnCommand(MFXlist.ACT_SCROLLVIEWUP, 0)
    end
    
  -- elseif mcap & MFXlist.MOD_KEYS == MFXlist.MOD_CTRL then
    -- Ctrl+Wheel over TCP locks the zoom to the track that is (or comes) under the cursor, pushing the
    -- other tracks up/down. When sending wheel message with Ctrl mod key, this does not happen, instead
    -- something unclear-what-exactly happens; but we leave it for now...
    -- Could it be View: Zoom in/out vertically (40111, resp 40112) is what happens? No, not exactly that 
    -- either, as those also lock to the track that is (or comes) under the cursor. Maybe must do that?
  else
    -- It does not seem to matter which type of coordinates that are sent
    -- local screenx, screeny = gfx.clienttoscreen(mx, my)
    -- local tcpx, tcpy = rpr.JS_Window_ScreenToClient(MFXlist.TCP_HWND, screenx, screeny)
    sendTCPWheelMessage(mcap, prev_wheel, mx, my) 
    --Msg("sendTCPWheelMessage("..mcap..", "..prev_wheel..", "..mx..", "..my)
    
  end 
  
  prev_wheel = 0
  
end -- handleMousewheel
------------------------------
local function handleLeftMBclick(mcap, mx, my)
  
  local track = MFXlist.track_hovered
  local index = MFXlist.fx_hovered
  local modkeys = mcap & MFXlist.MOD_KEYS
  
  if not track then -- we clicked oustide track area, header or footer
    
    Msg("TODO! Left click over header or footer. What to do?")
    focusTCP()
    return
    
  elseif not MFXlist.fx_hovered then -- so we hover over track but not any fx
    
    -- Left click inside track rect but not on FX, empty slot
    if modkeys == 0 then
      
      -- No modifier key, toggle FX Chain window (would want to open Add FX dialog, but how?)
      local count = rpr.TrackFX_GetCount(track) 
      if count == 0 then -- this case needs specal treatment
        
        Msg("TODO! Empty slot clicked on track with zero FX")
        focusTCP()
        
      else -- if FX Chain is not empty, toggling works if some fx is selected
        
        local openclose = rpr.TrackFX_GetOpen(track, count-1) and 0 or 1 
        Msg("Left click over track empty slot, selected: "..(count-1)..", openclose: "..openclose)
        rpr.TrackFX_Show(track, count-1, openclose) 
        
        if openclose == 0 then -- we just closed and need to focus
          focusTCP()
        end
        
      end
      return
      
    elseif modkeys & MFXlist.MOD_KEYS == (MFXlist.MOD_SHIFT | MFXlist.MOD_CTRL | MFXlist.MOD_ALT) then
      -- Shift+Ctrl+Alt
      Msg("TODO! Left click over track empty slot with Shift+Ctrl+Alt key!")
      focusTCP()
      return
    elseif modkeys & MFXlist.MOD_KEYS == (MFXlist.MOD_SHIFT | MFXlist.MOD_ALT) then
      -- Shift+Alt
      Msg("TODO! Left click over track empty slot with Shift+Alt key!")
      focusTCP()
      return
    elseif modkeys & MFXlist.MOD_KEYS == (MFXlist.MOD_SHIFT | MFXlist.MOD_CTRL) then
      -- Shift+Ctrl
      Msg("TODO! Left click over track empty slot with Shift+Ctrl key!")
      focusTCP()
      return
    elseif modkeys & MFXlist.MOD_KEYS == (MFXlist.MOD_CTRL | MFXlist.MOD_ALT) then
      -- Ctrl+Alt
      Msg("TODO! Left click over track empty slot with Ctrl+Alt key!")
      focusTCP()
      return
    elseif modkeys & MFXlist.MOD_KEYS == MFXlist.MOD_SHIFT then 
      -- Shift key
      Msg("TODO! Left click over track empty slot with Shift key!")
      focusTCP()
      return
    elseif modkeys & MFXlist.MOD_KEYS == MFXlist.MOD_CTRL then
      -- Ctrl key
      Msg("TODO! Left click over track empty slot with Ctrl key!")
      focusTCP()
      return
    elseif modkeys & MFXlist.MOD_KEYS == MFXlist.MOD_ALT then
      -- Alt key
      Msg("TODO! Left click over track empty slot with Alt key!")
      focusTCP()
      return
    else
      assert(nil, "handleLeftMB (1): should not get here!")
    end
    
  end
  
  if modkeys == 0 then 
    -- simple click on FX, show/hide floating window for FX
    
    local showhide = rpr.TrackFX_GetOpen(track, index-1) and 2 or 3 -- 2 for hide floating win, 3 for show floating win
    rpr.TrackFX_Show(track, index-1, showhide)
    -- Set focus to TCP, but only on hide since on open the just opened window should have focus
    if showhide == 2 then
      focusTCP()
    end
    return
    
  elseif modkeys & (MFXlist.MOD_SHIFT | MFXlist.MOD_CTRL | MFXlist.MOD_ALT) == (MFXlist.MOD_SHIFT | MFXlist.MOD_CTRL | MFXlist.MOD_ALT) then
    -- Shift+Alt
    Msg("TODO! Left click over track FX with Shift+Ctrl+Alt key!")
    -- Set focus to TCP so key strokes go there
    focusTCP()
    return
    
  elseif modkeys & (MFXlist.MOD_SHIFT | MFXlist.MOD_ALT) == (MFXlist.MOD_SHIFT | MFXlist.MOD_ALT) then
    -- Shift+Alt
    Msg("TODO! Left click over FX with Shift+Alt key!")
    -- Set focus to TCP so key strokes go there
    focusTCP()
    return
    
  elseif modkeys & (MFXlist.MOD_SHIFT | MFXlist.MOD_CTRL) == (MFXlist.MOD_SHIFT | MFXlist.MOD_CTRL) then
    -- Shift+Ctrl
    Msg("TODO! Left click over FX with Shift+Ctrl key!")
    -- Set focus to TCP so key strokes go there
    focusTCP()
    return
    
  elseif modkeys & (MFXlist.MOD_CTRL | MFXlist.MOD_ALT) == (MFXlist.MOD_CTRL | MFXlist.MOD_ALT) then
    -- Ctr+Alt+Left click on FX, toggle offline/online
    
    local isoffline = rpr.TrackFX_GetOffline(track, index-1)
    rpr.TrackFX_SetOffline(track, index-1, not isoffline)
    -- Set focus to TCP so key strokes go there
    fcousTCP()
    return
    
  elseif modkeys & MFXlist.MOD_SHIFT == MFXlist.MOD_SHIFT then 
    -- Shift+Left click on FX, toggle enable/disable
    
    local endisabled = not rpr.TrackFX_GetEnabled(track, index-1)
    rpr.TrackFX_SetEnabled(track, index-1, endisabled)
    -- Set focus to TCP so key strokes go there
    focusTCP()
    return
    
  elseif modkeys & MFXlist.MOD_CTRL == MFXlist.MOD_CTRL then -- show/hide chain
    -- Ctrl+Left click on FX, toggle track FX Chain window with FX selected
    
    local openclose = rpr.TrackFX_GetOpen(track, index-1) and 0 or 1 -- 0 for hide FX chain win, 1 for show FX chain win
    rpr.TrackFX_Show(track, index-1, openclose)
    -- Set focus to the TCP, but only on close, as after open the just opened win should have focus
    if openclose == 0 then 
      focusTCP()
    end
    return
    
  elseif modkeys & MFXlist.MOD_ALT == MFXlist.MOD_ALT then -- delete
    -- Alt+Left click on FX, delete FX
    
    rpr.TrackFX_Delete(track, index-1)
    -- Set focus to TCP so key strokes go there
    focusTCP()
    return
    
  else
    assert(nil, "handleLeftMB (2): should not get here!")
  end
  
end -- handleLeftMB
--------------------------------------------------------------------
local function withinResolution(mx, my)
  
return MFXlist.mbl_downx - MFXlist.CLICK_RESOX <= mx and  
      mx <= MFXlist.mbl_downx + MFXlist.CLICK_RESOX and 
      MFXlist.mbl_downy - MFXlist.CLICK_RESOY <= my and 
      my <= MFXlist.mbl_downy + MFXlist.CLICK_RESOY
      
end -- insideResolution
------
local mblprev, mbrprev -- global but local, used only in handleMouse

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
  
  -- local wheel = gfx.mouse_wheel
  -- if wheel ~= 0 then 
  --   handleWheel(wheel, mx, my)
  --  return true 
  -- end

  local mcap = gfx.mouse_cap
  local mbldown = mcap & MFXlist.MB_LEFT
  local mbrdown = mcap & MFXlist.MB_RIGHT
  
  handleWheel(mcap, mx, my)
  
  --[[
  -- left mouse button down flank? (should really wait for up-flank to cater for drag, but not now)
  if mbldown == MFXlist.MB_LEFT and mblprev ~= MFXlist.MB_LEFT then
    mblprev = MFXlist.MB_LEFT
    handleLeftMB(mcap, mx, my)
  elseif mbldown ~= MFXlist.MB_LEFT and mblprev == MFXlist.MB_LEFT then
    mblprev = 0
  end
  --]]
  
  -- left mouse button up-flank, allows to drag 
  if mbldown ~= MFXlist.MB_LEFT and mblprev == MFXlist.MB_LEFT then
    
    mblprev = 0
    -- Is up-flank within the resoultion, then it is a click
    -- Note that if dragging is started, and then the drop is done within the resolution
    -- of mbl_down (drag start), then this is interpreted as a click. fxlist does the same
    if withinResolution(mx, my) then
        
        handleLeftMBclick(mcap, mx, my)
        MFXlist.mbl_downx, MFXlist.mbl_downy = nil, nil
        MFXlist.drag_object = nil
        
    else -- this is drag end, aka drop
      
      -- If the drop is done outside of MFXlist, then strack and ttrack == nil
      -- This also fixes dropping on header or footer, it seems
      local strack = MFXlist.drag_object and MFXlist.drag_object[1] or nil  -- source track
      local ttrack = MFXlist.track_hovered  -- target track
      if strack and ttrack then
        local sfxid = MFXlist.drag_object[2]  -- source fx id
        local tfxid = MFXlist.fx_hovered      -- target fxid, can be nil
        
        if DO_DEBUG then
          -- Msg("Drag end... ".."ystart "..MFXlist.mbl_downy..".  yend: "..my)
          local _, sname = rpr.GetTrackName(strack)
          local _, sfxname = rpr.TrackFX_GetFXName(strack, sfxid-1, "")
          local _, tname = rpr.GetTrackName(ttrack)
          local tfxname = "No target FX"
          if tfxid then _, tfxname = rpr.TrackFX_GetFXName(ttrack, tfxid-1, "") end
          Msg("Drop: "..sname..", "..sfxname.." to "..tname..", "..tfxname)
        end -- DO_DEBUG
        
        -- Handle the drop
        if not tfxid then
          tfxid = rpr.TrackFX_GetCount(ttrack) + 1
        end
        -- If any combination of Ctrl is held down when dropping, then it is a copy
        local tomove = not (gfx.mouse_cap & MFXlist.MOD_CTRL == MFXlist.MOD_CTRL)
        
        rpr.TrackFX_CopyToTrack(strack, sfxid-1, ttrack, tfxid-1, tomove)
        
      end
      
      -- Reset drag info
      MFXlist.mbl_downx, MFXlist.mbl_downy = nil, nil
      MFXlist.drag_object = nil
      focusTCP()
      
    end
  -- left mouse button down-flank, may be click or drag start
  elseif mbldown == MFXlist.MB_LEFT and mblprev ~= MFXlist.MB_LEFT then
    
    mblprev = MFXlist.MB_LEFT 
    MFXlist.mbl_downx, MFXlist.mbl_downy = mx, my
    MFXlist.down_object = {MFXlist.track_hovered, MFXlist.fx_hovered}
    
    --[[
    -- If down on hovered element then possible drag start, store start pos, and hovered element
    if MFXlist.fx_hovered then
      
      MFXlist.drag_object = {MFXlist.track_hovered, MFXlist.fx_hovered}
      
      if DO_DEBUG then
        local track = MFXlist.drag_object[1]
        local fxid = MFXlist.drag_object[2]
        local _, tname = rpr.GetTrackName(track)
        local _, fxname = rpr.TrackFX_GetFXName(track, fxid-1, "")
        Msg("Possible drag start: "..tname..", "..fxname)
      end -- DO_DEBUG
      
    end
    --]]
  elseif mbldown == MFXlist.MB_LEFT and mblprev == MFXlist.MB_LEFT then
    -- is down now was down previously, are we dragging?
    -- If down on hovered element then possible drag start, store start pos, and hovered element
    if not withinResolution(mx, my) then
      if not MFXlist.drag_object and MFXlist.fx_hovered then
        
        MFXlist.drag_object = {MFXlist.track_hovered, MFXlist.fx_hovered}
        
        if DO_DEBUG then
          local track = MFXlist.drag_object[1]
          local fxid = MFXlist.drag_object[2]
          local _, tname = rpr.GetTrackName(track)
          local _, fxname = rpr.TrackFX_GetFXName(track, fxid-1, "")
          Msg("Possible drag start: "..tname..", "..fxname)
        end -- DO_DEBUG
        
      end
    end
    
  elseif mbldown ~= MFXlist.MB_LEFT and mblprev ~= MFXlist.MB_LEFT then
    
    -- is up now, was up previosly, just idling
    
  end
  
  -- right mouse button down flank?
  if mbrdown == MFXlist.MB_RIGHT and mbrprev ~= MFXlist.MB_RIGHT then
    
    mbrprev = MFXlist.MB_RIGHT
    local ret = handleMenu(mcap, mx, my) -- onRightClick()
    -- Msg("Showmenu returned: "..ret)
    if ret == MFXlist.MENU_QUIT then
      Msg("Quitting...")
      gfx.quit()
      return false -- tell the defer loop to quit
    end
  -- right mous button up flank?
  elseif mbrdown ~= MFXlist.MB_RIGHT and mbrprev == MFXlist.MB_RIGHT then
    
    mbrprev = 0
    
  end
  
  return true
  
end -- handleMouse
-----------------------------
-- Write EXSTATE info
local function exitScript()
  
  local dockstate, wx, wy, ww, wh = gfx.dock(-1, wx, wy, ww, wh)  
  local dockstr = string.format("%d", dockstate)
  rpr.SetExtState(MFXlist.SCRIPT_NAME, "dock", dockstr, true)
  
  local coordstr = string.format("%d,%d,%d,%d", wx, wy, ww, wh)
  rpr.SetExtState(MFXlist.SCRIPT_NAME, "coords", coordstr, true)
  
  rpr.SetExtState(MFXlist.SCRIPT_NAME, "version", MFXlist.SCRIPT_VERSION, true)
  
  Msg("Bye, bye")
  
end -- exitScript
------------------------------------------------------------
-- Read EXSTATE info and set up in previous docker (if any)
local function openWindow()
  
  -- Dock state - not valid for Reaper v4 or earlier
  local dockstate = MFXlist.LEFT_ARRANGEDOCKER
  if rpr.HasExtState(MFXlist.SCRIPT_NAME, "dock") then 
      local extstate = rpr.GetExtState(MFXlist.SCRIPT_NAME, "dock")
      dockstate = tonumber(extstate)
  end
  local docker = dockstate
  
  -- If we are docked, these coords don't really matter, but still...
  if rpr.HasExtState(MFXlist.SCRIPT_NAME, "coords") then
      local coordstr = rpr.GetExtState(MFXlist.SCRIPT_NAME, "coords")
      local x, y, w, h = coordstr:match("(%d+),(%d+),(%d+),(%d+)")
      MFXlist.WIN_X, MFXlist.WIN_Y, MFXlist.WIN_W, MFXlist.WIN_H = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
  end
  
  gfx.clear = MFXlist.COLOR_EMPTYSLOT[1] * 255 + MFXlist.COLOR_EMPTYSLOT[2] * 255 * 256 + MFXlist.COLOR_EMPTYSLOT[3] * 255 * 65536
  gfx.init(MFXlist.SCRIPT_NAME, MFXlist.WIN_W, MFXlist.WIN_H, docker, MFXlist.WIN_X, MFXlist.WIN_Y)
  
end -- openWindow
------------------------------------------------ 
local function initializeScript()
  
  local hwnd, x, y, w, h = getTCPProperties() -- TCP screen coordinates
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
  
  -- findLeftDock() -- doesnt work (yet)
  
  initSWSCommands()
  
  rpr.atexit(exitScript)
  openWindow()
  
  MFXlist.MFX_HWND = rpr.JS_Window_GetFocus() -- I'm assuming we have the focus now
  -- MFXlist.MFX_HWND = rpr.JS_Window_Find(MFXlist.SCRIPT_NAME, true) -- should also work but have not tried it
  --local foregraound = rpr.JS_Window_GetForeground() -- and that we are at the foreground
  --assert(foregraound == MFXlist.MFX_HWND, "Something is amiss, either I'm not focused or I'm not foreground")

  
  MFXlist.header_text = MFXlist.SCRIPT_NAME.." "..MFXlist.SCRIPT_VERSION
  
  gfx.setfont(MFXlist.FONT_FXNAME, MFXlist.FONT_NAME1, MFXlist.FONT_SIZE1)
  gfx.setfont(MFXlist.FONT_FXBOLD, MFXlist.FONT_NAME1, MFXlist.FONT_SIZE1, MFXlist.FONT_BOLDFLAG)
  gfx.setfont(MFXlist.FONT_HEADER, MFXlist.FONT_NAME2, MFXlist.FONT_SIZE2)
  
  -- Set up the header buffer for blitting -- cannot seem to get the blit of the header to work 
  gfx.dest = MFXlist.BLITBUF_HEAD
  -- according to https://forum.cockos.com/showthread.php?t=204629, this piece is missing
  gfx.setimgdim(MFXlist.BLITBUF_HEAD , -1 , -1);
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
  
  local x, y, w, h = getClientBounds(MFXlist.TCP_HWND) -- screen coords of the TCP 
  _, MFXlist.TCP_top = gfx.screentoclient(x, y) -- top y coord to draw FX at, above this only header stuff
  MFXlist.TCP_bot = MFXlist.TCP_top + h -- bottom y coord to draw FX at, below this only footer stuff
  
  rpr.PreventUIRefresh(1)

  handleTracks()
  local continue = handleMouse() 
  
  rpr.PreventUIRefresh(-1)
  -- rpr.TrackList_AdjustWindows(true)
  -- rpr.UpdateArrange()
  
  -- Check if we are to quit or not
  if gfx.getchar() < 0 or not continue then 
    gfx.quit()
    return
  end

  -- set focus to TCP. Seems to work, but...
  -- Cannot have it here, it messes up other windows focus, such as Action window!
  -- focusTCP()
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