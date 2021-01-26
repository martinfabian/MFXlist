---------------------------------------- TestingFindFirstTrackBinary.lua ------------------------------------
-- I know there is a bug lurking in MFXlist concerning the binary search for the first (partly) visible track
-- This tries to fidn that bug by generating random examples of "track lists" and run the binary search on those
-- This does not run in Reaper, but replaces reaper specific commands by pure lua functions
local math, io = math, io

local setup = {} -- This is the setup

local function generateFailingSetup()
  
  return 
  { -- This is the FailingTrackSetup.txt. This not really failing anymore, except for
    -- if mastertrackvisibility is set to 0. Then there is no track with posy <= 0, 
    -- and so the binary search cannot find anything and the assertion fires. But this
    -- is an impossible case, since Reaper does not allow posy > 0 for all tracks except when
    -- master track is visible. Put another way master track not visible => posy <= 0 for some track
    
    -- But now we have something that fails! If master posy + height < 0 but posy + height + mastergap > 0
    mastertrackvisibility = 1, 
    mastertrack = { name = "MASTER", posy = -164, height = 163 },
    tracks =  {
      { name = "Track 1", posy = 4, height = 163 }, -- posy == 5 can only occur when master track visible
      { name = "Track 2", posy = 151, height = 146 },
      { name = "Track 3", posy = 297, height = 146 },
      { name = "Track 4", posy = 443, height = 146 },
      { name = "Track 5", posy = 589, height = 146 },
      { name = "Track 6", posy = 735, height = 146 }, 
      { name = "Track 7", posy = 881, height = 146 },
      { name = "Track 8", posy = 1027, height = 146 },
      { name = "Track 9", posy = 1173, height = 146 },
      { name = "Track 10", posy = 1319, height = 146 },
      { name = "Track 11", posy = 1465, height = 146 },
      { name = "Track 12", posy = 1611,  height = 146 },
                },
    trackcount = 12,
  }
end -- generateFailing Setup
----------------------------------------------------------------------
-- See math.random here http://lua-users.org/wiki/MathLibraryTutorial
local function initRandomGeneration()
  
  math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )
  
end -- initRandomGeneration
--------------------------------------------------
-- Allow to setup with fixed track height (like 0)
local function generateRandomSetup(fixedheight)
  
  initRandomGeneration()
  
  local setup = {}
  -- Begin by deciding mastertrack visibility
  -- master track not visible => posy <= 0 for some track
  setup.mastertrackvisibility = (math.random() < 0.25 and 1 or 0)
  setup.mastertrack = { name = "MASTER", posy = -146, height = 146 }
  
  local posy = math.random(-1000, 0) -- random int -1000 >= n <= 0
  if setup.mastertrackvisibility == 1 then -- if visible, the master track is the topmost one
    setup.mastertrack.posy = posy
    setup.mastertrack.height = math.random(0, 200)
    posy = posy + setup.mastertrack.height + 5 -- where 5 is the master gap
  end
  
  setup.tracks = {}
  setup.trackcount = math.random(0, 200)
  for i = 1, setup.trackcount do
    local track = {}
    track.name = "Track "..i
    track.posy = posy
    track.height = (fixedheight and fixedheight or math.random(0, 200))
    posy = posy + track.height
    table.insert(setup.tracks, track)
  end
  
  return setup
  
end -- generateRandomSetup
----------------------------
local function printTrack(track)
  
  print("name = "..track.name..", posy = "..track.posy..", height = "..track.height)
  
end -- printTrack
---------------------------
local function printSetup(full)
  
  print("master track visibility: "..setup.mastertrackvisibility)
  if setup.mastertrackvisibility == 1 then printTrack(setup.mastertrack) end
  local tracks = setup.tracks
  for i = 1, setup.trackcount do
    printTrack(tracks[i])
    if not full and tracks[i].posy > 0 then break end
  end
  print("trackcount = "..setup.trackcount)
  
end
--------------------------------------------------
local rpr = {} -- collects the fake rpr functions

function rpr.GetMasterTrack(proj)
  
  return setup.mastertrack
  
end -- GetMasterTrack

function rpr.GetMasterTrackVisibility()

  return setup.mastertrackvisibility

end -- rpr.GetMasterTrackVisibility()

function rpr.CountTracks(proj)
  
  return setup.trackcount
  
end -- CountTracks

function rpr.GetTrack(proj, index)
  assert(0 <= index and index < setup.trackcount, "GetTrack: out of bounds indexing: "..index) 
  
  return setup.tracks[index+1]
  
end -- GetTrack

function rpr.GetMediaTrackInfo_Value(track, info)
  
  if info == "I_WNDH" then return track.height end
  if info == "I_TCPY" then return track.posy end
  
  assert(nil, "GetMediaTRackInfo: unknown info string: "..info)
  
end -- GetMediaTrackInfo_Value

------------------------------------------
local function getTrackPosAndHeight(track)
  assert(track, "getTrackPosAndHeight: invalid parameter - track")
  
  local height = rpr.GetMediaTrackInfo_Value(track, "I_WNDH") -- current TCP window height in pixels including envelopes
  local posy = rpr.GetMediaTrackInfo_Value(track, "I_TCPY") -- current TCP window Y-position in pixels relative to top of arrange view
  return posy, height
  
end -- getTrackPosAndHeight()
---------------------------------------
local function getFirstTCPTrackBinary()
  
  local fixForMasterTCPgap = false
  local mastergap = 5
  
  if rpr.GetMasterTrackVisibility() & 0x1 == 1 then -- Master track visible in TCP
    local master = rpr.GetMasterTrack(CURR_PROJ)
    local posy, height = getTrackPosAndHeight(master)
    if height + posy > 0 then return master, 0 end
    if height + posy + mastergap >= 0 then fixForMasterTCPgap = true end
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
  -- assert(nil, "getFirstTCPTrackBinary: Should never get here!")
  error("getFirstTCPTrackBinary: Should never get here!")
  
end -- getFirstTCPTrackBinary
-----------------------------------------------

local status, track, index

setup = generateFailingSetup()
printSetup()
status, track, index = pcall(getFirstTCPTrackBinary)
if status == false then
  print("Fail!")
  return
else
  print("Succsess")
end
--[ [

local ch1 = "\\"
local ch2 = "/"
local ch = ch1
io.write(ch2)
repeat
  setup = generateRandomSetup(0) -- 0 here means "all tracks hidden, height == 0
  -- printSetup(false)

  status, track, index = pcall(getFirstTCPTrackBinary)
  
  io.write("\b"..ch)
  ch = (ch == ch1 and ch2 or ch1)
  
until status == false 

printSetup(false)

--[[
if setup.trackcount == 0 then 
  print("Zero track count")
else 
  print("*** First visible track: \""..track.name.."\", index: "..index)
end
--]]