--[[
 * ReaScript Name: MFXlist - Preset example
 * About: Edit the User Config Areas to make it work.
 * Author: X-Raym, M Fabian
 * Author URI: https://www.extremraym.com
 * Licence: GPL v3
 * REAPER: 5.0
 * Version: 1.0
--]]

-- USER CONFIG AREA 1/2 ------------------------------------------------------

-- This preset works with MFXlist v0.9.5 and newer
script = "Fabian_MFXlist.lua" -- 1. The target script path relative to this file. If no folder, then it means preset file is right to the target script.

-------------------------------------------------- END OF USER CONFIG AREA 1/2

-- PARENT SCRIPT CALL --------------------------------------------------------

-- Get Script Path
script_folder = debug.getinfo(1).source:match("@?(.*[\\|/])")
script_path = script_folder .. script -- This can be erased if you prefer enter absolute path value above.

-- Prevent Init() Execution
preset_file_init = true

-- Run the Script
if reaper.file_exists( script_path ) then
  dofile( script_path )
else
  reaper.MB("Missing parent script.\n" .. script_path, "Error", 0)
  return
end

---------------------------------------------------- END OF PARENT SCRIPT CALL

-- USER CONFIG AREA 2/2 ------------------------------------------------------

-- 2. Put your variables there, so that it overrides the default ones. 
-- You can usually copy the User Config Area variable of the target script. Examples below.

-- MFXlist customizable settings, commented out ones are default values
MFXlist.COLOR_EMPTYSLOT = {60/255, 0, 60/255}
-- MFXlist.COLOR_FXHOVERED = {1, 1, 0}
-- MFXlist.COLOR_DROPMOVE = {0, 0, 1},
-- MFXlist.COLOR_DROPCOPY = {0, 1, 0},
MFXlist.COLOR_SELECTEDTRACK = {1, 1, 0}
-- MFXlist.SHOW_FXTYPE = false, -- Show FX type prefix, JS:, VST:, VSTi:, VID:
-- MFXlist.MENU_QUICKFX = {"ReaEQ", "ReaComp", "ReaFIR", "ReaDelay"}
-- MFXlist.FX_DISABLEDA = 0.3, -- fade of name for disabled FX
-- MFXlist.FX_OFFLINEDA = 0.1, -- even fainter for offlined FX
-- MFXlist.FONT_NAME1 = "Arial",
-- MFXlist.FONT_NAME2 = "Courier New",
-- MFXlist.FONT_SIZE1 = 14,
-- MFXlist.FONT_SIZE2 = 16,
-- MFXlist.SLOT_HEIGHT = 13, -- pixels high
-- MFXlist.ALT_FXBROWSER = nil, -- Alternative FX browswer, put command ID here
	-- These are the command IDs on my machine
    -- "_RS490460a16d7e7bb0285ccb1891b67f8f59593a61", -- Quick Adder
    -- "_RS36fe8a223d7ec08e45d4e8569c9bc15b9e417dfa", -- Fast FX finder
-------------------------------------------------- END OF USER CONFIG AREA 2/2

-- RUN -------------------------------------------------------------------

Init() -- run the init function of the target script.
