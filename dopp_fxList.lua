-- dopp_fxList
-- Author: dopp (7 May 2018)
-- GNU General Public License v3.0
local theming = { --[[ USER AREA: change RGB colors            R:   G:   B: 
--([ panels background                              --]] bp = {61,  64,  68}, 
--[[ effects section bg & IL meter bg               --]] bf = {38,  40,  42}, 
--[[ track separator line                           --]] bt = {17,  17,  17}, 
--[[ fx instruments background                      --]] vi = {0,   183, 204}, 
--[[ fx jesusonic background                        --]] js = {127, 130, 132}, 
--[[ fx online background                           --]] fo = {175, 181, 188}, 
--[[ fx online background hovered                   --]] fl = {255, 255, 255}, 
--[[ fx bypassed background                         --]] fb = {25,  27,  27}, 
--[[ fx byp & off & unavailable & empty bg hovered  --]] fh = {28,  30,  30}, 
--[[ round marker for sel fx with mid mouse         --]] fm = {102, 0,   0}, 
--[[ round marker for sel fx with shift+mid mouse   --]] fs = {76,  0,   153}, 
--[[ send & receive & hw out background             --]] rb = {25,  27,  27}, 
--[[ send marker & sel track with mid mouse         --]] rs = {91,  89,  145}, 
--[[ receive marker & sel track with mid mouse      --]] rr = {40,  130, 38}, 
--[[ hw out marker                                  --]] rh = {127, 130, 132}, 
--[[ text (IL threshold 1)                          --]] i1 = {0,   178,  165}, 
--[[ text (IL threshold 2)                          --]] i2 = {153, 25,  0}, 
--[[ text (IL threshold 3)                          --]] i3 = {25,  153, 0}, 
--[[ text (TPmax, LRA)                              --]] i4 = {112, 117, 122}, 
--[[ text (fx online)                               --]] f1 = {0,   0,   0}, 
--[[ text (fx bybass)                               --]] f2 = {178, 102, 51}, 
--[[ text (fx offline)                              --]] f3 = {102, 102, 102}, 
--[[ text (fx unavailable)                          --]] f4 = {127, 25,  0}, 
--[[ text (fx online and opened)                    --]] f5 = {255, 255, 255}, 
--[[ text (sends/recv/hwout)                        --]] r1 = {175, 181, 188}, 
--[[ text (sends hovered by mouse)                  --]] r2 = {229, 229, 229}, 
--[[ text (sel sends with shift+mid mouse)          --]] r3 = {178, 114, 0}, 
--[[ text (sel sends with shift+mid mouse, hovered) --]] r4 = {229, 165, 0} 
}  

local CUR_PROJ = 0

local info = debug.getinfo(1,'S') 
local spath = info.source:match[[^@?(.*[\/])[^\/]-$]] 
local conf, st, t, fxcn, fxsh, cbuf, grt = {}, {}, {}, {}, {}, {}, {}
local cmn, ratk, ratd, sdsh, bufr, buto, dpm = {}, {}, {}, {}, {}, {}, {}
local rat = {rx=0, sym=0, syms=0, syl=0, sys=0, syc=0, sya=0, sycs=0, syr=0}
local yalu, yalb, wsr, ratew, afxchk, cur = 67, 13, 100, 0, false

local __, __, secid, cmdid, __, __, __ = reaper.get_action_context();

reaper.SetToggleCommandState(secid, cmdid, 1); 
reaper.RefreshToolbar2(secid, cmdid)

for k,v in pairs(theming) do t[k] = {v[1]/255, v[2]/255, v[3]/255} end

local c = {"weed", "sun", "blood", "alien_shit", "sky",
          themevi = {t.vi[1], t.vi[2], t.vi[3]}, themejs = {t.js[1], t.js[2], t.js[3]}, sky = {0, 0.72, 0.8}, weed = {0.16, 0.51, 0.15}, sun = {0.7, 0.7, 0.15}, 
          orange = {0.6, 0.31, 0.1}, blood = {0.6, 0.16, 0.16}, alien_shit = {0.36, 0.35, 0.57}, everyday = {0.50, 0.51, 0.52}, mostboring = {0.69, 0.71, 0.74} 
        } 
        
local function ReadConfig()
    local def = {wndx = 0, wndy = 0, wndw = 100, wndh = 600, dock = 1, mth = -14, uth = -8, fsz = 14, fsz2 = 20, s2x = 1, grw = 0,
        dpMeter = "", tplr = "", cmnt = "", tnc = "", hlght = "", mshtw = "", rtng = "", rcv = "", sd = "", hw = "", ctrls = "", c = "themevi", cj = "themejs"} 
  
    for key in pairs(def) do 
        local esstr = reaper.GetExtState("dopp_fxList", key)
        if esstr == "" or esstr == nil then conf[key] = def[key] else conf[key] = tonumber(esstr) or esstr end
    end  
end 

local function SaveConfig()
    conf.dock, conf.wndx, conf.wndy, conf.wndw, conf.wndh = gfx.dock(-1, 0,0,0,0)
    for key in pairs(conf) do 
      reaper.SetExtState("dopp_fxList", key, tostring(conf[key]), true) 
    end
end 

local function Kill() 
  reaper.SetToggleCommandState(secid, cmdid, 0); 
  reaper.RefreshToolbar2(secid, cmdid); 
  SaveConfig(); 
  gfx.quit(); 
end

local function OMnu(om) 
  if conf[om] == "" then 
    conf[om] = "!" 
  else 
    conf[om] = "" 
  end 
end

local function IsMouseInside(x,y,w,h) 
  return (x <= gfx.mouse_x and gfx.mouse_x < (x + w) and y <= gfx.mouse_y and gfx.mouse_y < (y + h)) 
end

local function Rats(key, coo) 
    ratd[key] = true; 
    rat.rx = gfx.mouse_x; 
    rat[coo] = gfx.mouse_y; 
    if rat[coo] >= yalu then 
      st.srcT, st.srcY, st.nn, st.sty = reaper.DP_TL(rat[coo], conf.s2x) 
    else 
      st.srcT, st.srcY, st.sty = nil, nil, nil; 
    end
end

local function DpMeter()
    dpm.mtr, dpm.name, dpm.chk = reaper.GetMasterTrack(0), "dpMeter4", nil
    if conf.dpMeter ~= "!" then return end
    local cnt, offchk = 0, nil;
    local mfxc = reaper.TrackFX_GetCount(dpm.mtr)
    dpm.idx = reaper.TrackFX_AddByName(dpm.mtr, dpm.name, true, 1)
    if not dpm.idx or dpm.idx < 0 then return else dpm.idxx = 0x1000000 + dpm.idx end 
    if reaper.TrackFX_GetOffline(dpm.mtr, dpm.idxx) then reaper.TrackFX_SetOffline(dpm.mtr, dpm.idxx, false); offchk = true end
    local dpmloc = {Type = 2, WriteAutomationData = 4, OUTEBUIL = 22, OUTEBUTPMax = 27, OUTEBULRA = 28, Reset = 29}
    local npr = reaper.TrackFX_GetNumParams(dpm.mtr, dpm.idxx); 
    for k,v in pairs (dpmloc) do 
        for pr = 0, npr-1 do
            local rv, pbuf = reaper.TrackFX_GetParamName(dpm.mtr, dpm.idxx, pr, "")
            if rv and pbuf then pbuf = pbuf:gsub("[:%s]+","") if pbuf then if k == pbuf then dpm[k] = pr; cnt = cnt + 1 break end end end
        end
    end 
    if cnt == 6 then 
        reaper.TrackFX_SetParam(dpm.mtr, dpm.idxx, dpm.Type, 1)
        reaper.TrackFX_SetParam(dpm.mtr, dpm.idxx, dpm.WriteAutomationData, 1); dpm.chk = true
    elseif cnt ~= 6 and mfxc ~= reaper.TrackFX_GetCount(dpm.mtr) then reaper.TrackFX_Delete(dpm.mtr, dpm.idxx) end
    if offchk then reaper.TrackFX_SetOffline(dpm.mtr, dpm.idxx, true) end 
end

local function ShowTooltip(tr, k)
    if gfx.mouse_y <= yalu then return end
    if ratd.left or ratd.ctrl then cmn.time = nil; cmn.chk = nil; cmn.data = nil return end
    local rat_scrx, rat_scry = gfx.clienttoscreen(gfx.mouse_x, gfx.mouse_y)
    local __, tnm = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    local tn = reaper.CSurf_TrackToID(tr, false); if tn == 0 then tnm = "master" end 
    if conf.cmnt ~= "!" or gfx.mouse_cap ~= 6 then cmn.time = nil; cmn.chk = nil; 
        if conf.grw == 2 then 
            local wet, __, __ = reaper.TrackFX_GetParam(tr, k-1, reaper.TrackFX_GetNumParams(tr, k-1)-1);
            local wet_str = (wet >= 0.0) and tostring(math.floor((wet*100.0)+0.5).."%: ") or ""
            cmn.data = string.format("%s: %s%s:%s", k, wet_str, math.floor(tn), tnm)
        else cmn.data = string.format("%s: %s:%s", k, math.floor(tn), tnm) end
    end
    if conf.cmnt == "!" and gfx.mouse_cap == 6 and cmn.chk ~= true then
        if not cmn.time then cmn.time = reaper.time_precise() + 0.05 end
        if cmn.time and cmn.time < reaper.time_precise() then 
            cmn.time, cmn.chk = nil, true
            local tmpc = {}
            local rv, chunk = reaper.GetTrackStateChunk(tr, "", false)
            if not rv then return end
            for block in chunk:gmatch("\nFXID.-\n<COMMENT.->") do
                block = ((block:reverse()):match("^>.-DIXF")):reverse()
                local guirdo = block:match("FXID (.-)\n") 
                local data = reaper.DP_Dec(block:match("<COMMENT \n(.-)\n>"),"")   
                tmpc[#tmpc+1] = {guirdo = guirdo, data = data}
            end
            local nch = reaper.GetMediaTrackInfo_Value(tr, "I_NCHAN")
            cmn.data = string.format("Track %s: %s [%s]\n-------------------\n", math.floor(tn), tnm, math.floor(nch))
            local fxcount = reaper.TrackFX_GetCount(tr); local pdcsum = 0
            for i=0, fxcount-1 do
                local data = ""
                local rv1, pdc = reaper.TrackFX_GetNamedConfigParm(tr, i, "pdc")
                local rv2, inp, oup = reaper.TrackFX_GetIOSize(tr, i)
                if not rv1 then pdc = "" else pdcsum = pdcsum + pdc end
                if not rv2 then inp, oup = "", "" else if oup == -1 then oup = inp end end
                local wet, __, __ = reaper.TrackFX_GetParam(tr, i, reaper.TrackFX_GetNumParams(tr, i)-1);
                for l=1, #tmpc do if tmpc[l].guirdo == reaper.TrackFX_GetFXGUID(tr, i) then data = tmpc[l].data or "" break end end
                local __, fname = reaper.TrackFX_GetFXName(tr, i, "")
                if fname then if fname:match(": (.*)") then fname = fname:match(": (.*)"):gsub("%(.-%)$","") end else fname = "fx" end
                cmn.data = string.format("%s%s: %s: %s [%s|%s] %s%%: %s\n", cmn.data, i+1, fname, pdc, inp, oup, math.floor((wet*100.0)+0.5), data)
            end
            cmn.data = cmn.data .. "-------------------\n" .. tostring(math.floor(pdcsum)) .. " spls"
        end
    end
    if ratew%((gfx.mouse_cap == 6) and 61 or 3) == 0 then reaper.TrackCtl_SetToolTip(cmn.data, rat_scrx+20, rat_scry+14, false) end
end

local function Cont(srctrack, msy, mly, sty, fxf, fxs)
    local fschk = 0; 
    local srcB, dstB = reaper.DP_Horz(srctrack, msy, mly, sty, (conf.tnc == "!") and 1 or 0, 14 * conf.s2x)    
    for k = srcB, dstB do
        if ({reaper.TrackFX_GetFXName(srctrack, k-1, "")})[1] then
            local fguid = reaper.TrackFX_GetFXGUID(srctrack, k-1); 
            local fexschk = false
            for j=1, #fxs do 
              if fxs[j].fxguid == fguid then 
                table.remove(fxs, j); 
                fexschk = true; 
                fschk = fschk + 1; 
                break 
              end 
            end
            if fexschk == false then
                for l=#fxf, 1, -1 do 
                  if fxf[l].fxguid == fguid then 
                    table.remove(fxf, l) 
                  end 
                end
                fxs[#fxs+1] = {track = srctrack, fxguid = fguid}; 
                fschk = fschk + 1
            end   
        end
    end
    if fschk == 0 then if ratd.mid then fxcn = {} else fxsh = {} end end
end

local function Duplicate(msy, mly, mop)
    cur = nil; 
    reaper.DP_AfxV(reaper.GetMasterTrack(0), -1); 
    if msy < yalu or mly < yalu then return end; reaper.DP_FocusMwnd();
    if reaper.GetMediaTrackInfo_Value(reaper.CSurf_TrackFromID(0, false), "I_WNDH") < 1 and reaper.CountTracks(0) < 1 then return end
    local srcT, srcF, sty = st.srcT, st.srcY, st.sty;
    local dstT, dstF, dstFC, __ = reaper.DP_TL(mly, conf.s2x)
    if srcF then if srcF < 1 then srcF = nil end end; if dstF < 1 then dstF = nil end
    if not dstT or not srcT or not sty then return end
    local check_chain = true
    local srcFchk, srcFname = reaper.TrackFX_GetFXName(srcT, srcF-1, "")
    local dstFchk, dstFname = reaper.TrackFX_GetFXName(dstT, dstF-1, "")
    if ratd.left or ratd.ctrl or mop == 1 then
        if dstT == srcT and dstF == srcF and dstF and ((srcFchk == false and dstFchk == false) or (srcFchk and dstFchk and mop == 1)) then 
            check_chain = false; afxchk = true; reaper.DP_AfxV(dstT, dstF); return
        end
    elseif ratd.alt or mop == 3 then
        if dstT == srcT and dstF == srcF and srcFchk and dstFchk then
            check_chain = false; reaper.TrackFX_Delete(srcT, srcF-1) return
        end
    end
    if dstT == srcT and dstF == srcF and mop ~= 4 and mop ~= 5 and mop ~= 6 then
        check_chain = false
        if (ratd.ctrl and srcFchk) or mop == 10 then
            if reaper.TrackFX_GetChainVisible(srcT) == -1 or (srcF-1) ~= reaper.TrackFX_GetChainVisible(srcT) then
                reaper.TrackFX_Show(srcT, srcF-1, 1) else reaper.TrackFX_Show(srcT, srcF-1, 0) end
        elseif ratd.left and srcFchk then
            if not reaper.TrackFX_GetOpen(srcT, srcF-1) then 
                reaper.TrackFX_Show(srcT, srcF-1, 3) 
                if conf.mshtw == "!" then reaper.DP_FShift(srcT, srcF-1, wsr+15) end
            else reaper.TrackFX_Show(srcT, srcF-1, 2) end
            if srcFname:match("^JS: Volume Trim$") then reaper.TrackFX_SetParam(srcT, srcF-1, 3, 1) end
        end
    end
    local fchk = false
    if #fxcn >= 1 and srcFchk then
        for l=1, #fxcn do if fxcn[l].fxguid == reaper.TrackFX_GetFXGUID(srcT, srcF-1) then fchk = true end end 
    end
    if dstT == srcT and dstF == srcF and (mop == 4 or mop == 5) then
        check_chain = false; if srcFchk then cbuf = {} else return end
        if fchk then cbuf = fxcn else cbuf[#cbuf+1] = {track = srcT, fxguid = reaper.TrackFX_GetFXGUID(srcT, srcF-1)} end
        if mop == 5 then cbuf.chk = true else cbuf.chk = false end 
    end
    if srcF and dstF and (ratd.mid or ratd.mid_shift) then
        check_chain = false; if fxcn[1] then if fxcn[1].track ~= srcT then fxcn = {} end end
        if ratd.mid_shift then Cont(srcT, msy, mly, sty, fxcn, fxsh) end
        if ratd.mid then Cont(srcT, msy, mly, sty, fxsh, fxcn) end 
    end
    if check_chain and cbuf[1] ~= nil and mop == 6 then
        reaper.DP_Vclr(3)
        for i=1, #cbuf do reaper.DP_Vadd(3, cbuf[i].track, cbuf[i].fxguid) end
        local ratdcbool = (ratd.alt and 1 or 0) | (ratd.ctrl and 2 or 0) | (ratd.left and 32 or 0) | 256
        reaper.DP_Cm(srcT, dstT, srcF or 0, dstF or 0, dstFC, ratdcbool, cbuf.chk or false, dstFchk or false)
    end
    if check_chain and srcFchk and dstF then
        reaper.DP_Vclr(1)
        for i=1, #fxcn do reaper.DP_Vadd(1, fxcn[i].track, fxcn[i].fxguid) end
        local ratdcbool = (ratd.alt and 1 or 0) | (ratd.ctrl and 2 or 0) | (ratd.left and 32 or 0)
        reaper.DP_Cm(srcT, dstT, srcF or 0, dstF or 0, dstFC, ratdcbool, fchk or false, dstFchk or false)
        fxcn = {}
    end
end

local function Bypoff(msy, mly, mop, locate)
    cur = nil; 
    if msy < yalu or mly < yalu then return end; 
    
    reaper.DP_FocusMwnd();
    if reaper.GetMediaTrackInfo_Value(reaper.CSurf_TrackFromID(0, false), "I_WNDH") < 1 and reaper.CountTracks(0) < 1 then return end
    
    local srcT, srcF = st.srcT, st.srcY;
    local dstT, dstF, dstFC, __ = reaper.DP_TL(mly, conf.s2x)  
    if srcF then if srcF < 1 then srcF = nil end end; if dstF < 1 then dstF = nil end
    if not srcT or not dstT then return end
    if srcT == dstT and mop == 9 then reaper.DP_tTByp(srcT) end
    local srcFchk, srcFname = reaper.TrackFX_GetFXName(srcT, srcF-1, "")
    local dstFchk, dstFname = reaper.TrackFX_GetFXName(dstT, dstF-1, "")
    if locate then
        local cbyp = (reaper.GetMediaTrackInfo_Value(srcT, "I_FXEN") == 0.0) and "!" or ""
        if srcFchk and dstFchk and dstT == srcT and dstF == srcF then return false, cbyp
        elseif srcFchk == false and dstFchk == false and dstT == srcT and dstF == srcF then return true, cbyp end
    end 
    if srcT == dstT and srcF == dstF and mop == 2 then reaper.DP_AfxV(reaper.GetMasterTrack(0), -1); reaper.DP_FMenuFav(srcT, srcF, spath.."dopp_fxList.favourites") end
    if not srcFchk then return end
    local rf_fxguid = reaper.TrackFX_GetFXGUID(srcT, srcF-1); if not rf_fxguid then return end
    local fchk, schk = false, false
    if #fxcn >= 1 and srcFchk then for l=1, #fxcn do if fxcn[l].fxguid == rf_fxguid then fchk = true end end end
    if #fxsh >= 1 and srcFchk then for l=1, #fxsh do if fxsh[l].fxguid == rf_fxguid then schk = true end end end
    if srcT == dstT and srcF == dstF and (ratd.shift or mop == 7) then
        if fchk then
            for l=1, #fxcn do for j=0, dstFC-1 do if fxcn[l].fxguid == reaper.TrackFX_GetFXGUID(srcT, j) then reaper.DP_tFByp(srcT,j) end end end
        elseif schk then 
            for l=1, #fxsh do
                local trcount = reaper.TrackFX_GetCount(fxsh[l].track)
                for j=0, trcount-1 do if fxsh[l].fxguid == reaper.TrackFX_GetFXGUID(fxsh[l].track, j) then reaper.DP_tFByp(fxsh[l].track, j) end end
            end
        elseif fchk == false and schk == false then reaper.DP_tFByp(srcT, srcF-1) end
    elseif srcT == dstT and srcF == dstF and (ratd.ctrl_shift or mop == 8) then
        if fchk == false then reaper.DP_tFOff(srcT, srcF-1)
        elseif fchk then 
            for l=1, #fxcn do for j=0, dstFC-1 do if fxcn[l].fxguid == reaper.TrackFX_GetFXGUID(srcT, j) then reaper.DP_tFOff(srcT, j) end end end
        end 
    end
end

local function ContT(bu, srcB, dstB)
    local ex = {}
    for j=srcB, dstB do 
        for k=#bu, 1, -1 do 
          local tr = reaper.CSurf_TrackFromID(j, false)
          if bu[k] == tr and reaper.GetMediaTrackInfo_Value(tr, "I_WNDH") > 0 then 
             table.remove(bu,k); ex[#ex+1] = j; 
             break 
          end 
        end 
    end
    for j=srcB, dstB do 
        local exchk = true; for k=1, #ex do if ex[k] == j then exchk = false; break end end
        if exchk then 
            local tr = reaper.CSurf_TrackFromID(j,false)
            if reaper.GetMediaTrackInfo_Value(tr, "I_WNDH") > 0 then bu[#bu+1] = tr end 
        end
    end
    local sortT = {}; for j=1, #bu do sortT[#sortT+1] = reaper.CSurf_TrackToID(bu[j], false) end; table.sort(sortT); 
    bu = {}; for j=1, #sortT do bu[#bu+1] = reaper.CSurf_TrackFromID(sortT[j], false) end return bu
end

local function ContS(srcT, ti, msy, mly, sty)
    local sdchk = 0; 
    local srcH, dstH = reaper.DP_Horz(srcT, msy, mly, sty, (conf.tnc == "!") and 1 or 0, 14 * conf.s2x); 
    if #sdsh < 1 then
        for k=srcH, dstH do
            local rc, cat, ri = reaper.DP_RCR(srcT, k, st.rtng)
            if cat > -2 and ri > -1 then
                local rnum = 0; for l=-1, 1 do rnum = rnum + reaper.GetTrackNumSends(srcT, l) end
                sdsh[#sdsh+1] = {rnum = rnum, i = ti, track = srcT, name = reaper.DP_RName(srcT,cat,ri,""), cat = cat, ri = ri}
                sdchk = sdchk + 1
            end   
        end
    elseif #sdsh > 0 then 
        local ex = {}
        for k=srcH, dstH do
            local rc, cat, ri = reaper.DP_RCR(srcT, k, st.rtng)
            if cat > -2 and ri > -1 then
                for j=#sdsh, 1, -1 do
                    if sdsh[j].track == srcT and sdsh[j].name == reaper.DP_RName(srcT,cat,ri,"") and sdsh[j].cat == cat and sdsh[j].ri == ri then
                        table.remove(sdsh,j); sdchk = sdchk + 1; ex[#ex+1] = k break
                    end
                end
            end
        end
        for k=srcH, dstH do
            local exchk = true; for j=1, #ex do if ex[j] == k then exchk = false break end end
            if exchk then 
                local rc, cat, ri = reaper.DP_RCR(srcT, k, st.rtng)
                if cat > -2 and ri > -1 then
                    local rnum = 0; for l=-1, 1 do rnum = rnum + reaper.GetTrackNumSends(srcT, l) end
                    sdsh[#sdsh+1] = {rnum = rnum, i = ti, track = srcT, name = reaper.DP_RName(srcT,cat,ri,""), cat = cat, ri = ri}
                    sdchk = sdchk + 1
                else sdsh = {} return end
            end
        end
    end
    if sdchk == 0 then sdsh = {} end
end

local function SwitchER(route, case, srcT, srcC, srcS)
    local rtab, cnt, rline, rpmsline = {}, {}, "", ""
    if case == 1 then 
        for j=1, 2 do
            cnt[j] = 0
            local rdata = reaper.GetExtState("dopp_fxList_sends", route[j])
            for rline in rdata:gmatch(":>.-:<") do 
                rpmsline = string.format("%s%s|", rpmsline, rline:match(":>|(.-)|"))
                rtab[#rtab+1] = rline
                cnt[j] = cnt[j] + 1
            end
        end
        local rmen = gfx.showmenu(rpmsline)
        if not rmen or rmen < 1 then return end
        table.remove(rtab, rmen); 
        if rmen <= cnt[1] then reaper.SetExtState("dopp_fxList_sends", route[1], table.concat(rtab, "", 1, cnt[1]-1), true)
        elseif rmen > cnt[1] then reaper.SetExtState("dopp_fxList_sends", route[2], table.concat(rtab, "", cnt[1]+1, cnt[1]+cnt[2]-1), true) end
    else
        local rdata = reaper.GetExtState( "dopp_fxList_sends", route[srcC+2])
        local defparms = {"Tom", "Jerry", "B_MUTE", "B_PHASE", "B_MONO", "D_VOL", "D_PANLAW", "D_PAN", "I_SENDMODE", "I_AUTOMODE", "I_SRCCHAN", "I_DSTCHAN", "I_MIDIFLAGS"}        
        if case == 2 then            
            for rline in rdata:gmatch(":>(.-):<") do 
                local rpms = {}; for ridx in rline:gmatch("|(.-)|") do rpms[#rpms+1] = ridx end
                rtab[#rtab+1] = rpms; rpmsline = rpmsline .. rtab[#rtab][1] .. "|"
            end
            local rmen = gfx.showmenu(rpmsline)
            if not rmen or rmen < 1 then return end
            local rtabNew = rtab[rmen]
            if #rtabNew == #defparms then
                if bufr[1] then
                    for j=1, #bufr do
                        local srcS = reaper.GetTrackNumSends(srcT, srcC)
                        if bufr[j]~= srcT then reaper.CreateTrackSend(bufr[j], srcT) end
                        reaper.DP_RMode(srcT, srcC, srcS, tonumber(rtabNew[2]) or -1.0)
                        for i = 3, #rtabNew do reaper.SetTrackSendInfo_Value(srcT, srcC, srcS, defparms[i], tonumber(rtabNew[i])) end
                    end
                elseif buto[1] then
                    for j=1, #buto do
                        local srcS = reaper.GetTrackNumSends(srcT, srcC)
                        if buto[j] ~= srcT then 
                            reaper.CreateTrackSend(srcT, buto[j])
                            reaper.DP_RMode(srcT, srcC, srcS, tonumber(rtabNew[2]) or -1.0)
                            for i = 3, #rtabNew do reaper.SetTrackSendInfo_Value(srcT, srcC, srcS, defparms[i], tonumber(rtabNew[i])) end
                        end
                    end
                else
                    reaper.DP_RMode(srcT, srcC, srcS, tonumber(rtabNew[2]) or -1.0)
                    for i = 3, #rtabNew do reaper.SetTrackSendInfo_Value(srcT, srcC, srcS, defparms[i], tonumber(rtabNew[i])) end
                end
            end
        elseif case == 3 then 
            local csv_rv, sendname = reaper.GetUserInputs("Preset for "..route[srcC+2], 1, "Enter name:,extrawidth=200", "")
            sendname = sendname:gsub("[<|>]", "")
            if not csv_rv or not sendname or sendname == "" then return end
            sendname = "|".. route[srcC+2] ..": ".. sendname .."|" 
            local parms = {[1] = sendname, [2] = "|"..tostring(reaper.DP_RMode(srcT, srcC, srcS, -2.0)).."|"}
            for prm=3, #defparms do parms[#parms+1] = "|"..tostring(reaper.GetTrackSendInfo_Value(srcT, srcC, srcS, defparms[prm])).."|" end
            reaper.SetExtState("dopp_fxList_sends", route[srcC+2], rdata..":>"..table.concat(parms)..":<", true);
        end
    end
end

local function MasPar(bu, srcT)
    for i=1, #bu do 
      if bu[i] == srcT then 
        for j=1, #bu do 
          reaper.DP_tTPar(bu[j]) 
        end 
        return 
      end 
    end
    reaper.DP_tTPar(srcT)
end

local function Routing(msy, mly, mop, route, locate)
    cur = nil; if msy < yalu or mly < yalu or ratd.cha then return end reaper.DP_FocusMwnd(); 
    if reaper.GetMediaTrackInfo_Value(reaper.CSurf_TrackFromID(0, false), "I_WNDH") < 1 and reaper.CountTracks(0) < 1 then return end
    local srcT, srcR, sty = st.srcT, st.srcY, st.sty; 
    local dstT, dstR, __, __ = reaper.DP_TL(mly, conf.s2x)  
    if srcR then if srcR < 1 then srcR = nil end end; if dstR < 1 then dstR = nil end
    if not dstT or not srcT or not sty then return end
    local srcB = reaper.CSurf_TrackToID(srcT, false); local dstB = reaper.CSurf_TrackToID(dstT, false);
    local __, srccat, srcri = reaper.DP_RCR(srcT, srcR or 0, st.rtng)
    local __, dstcat, dstri = reaper.DP_RCR(dstT, dstR or 0, st.rtng)
    local srcC = (srccat > -2) and srccat or nil; local srcS = (srcri > -1) and srcri or nil;
    local dstC = (dstcat > -2) and dstcat or nil; local dstS = (dstri > -1) and dstri or nil;
    if locate then
        local mastr = false; if srcB == 0 then mastr = true end
        if srcS and dstS and dstT == srcT and dstR == srcR then return false, mastr
        elseif not srcS and not dstS and dstT == srcT and dstR == srcR then return true, mastr
        else return nil, mastr end
    end
    if ratd.mid then
        if srcB > dstB then dstB = dstB+srcB; srcB = dstB-srcB; dstB = dstB-srcB end
        if not bufr[1] and not buto[1] then 
            for j=srcB, dstB do 
                local tr = reaper.CSurf_TrackFromID(j,false) 
                if reaper.GetMediaTrackInfo_Value(tr, "I_WNDH") > 0 then bufr[#bufr+1] = tr end 
            end
        elseif bufr[1] and not buto[1] then bufr = ContT(bufr, srcB, dstB)
        elseif buto[1] and not bufr[1] then buto = ContT(buto, srcB, dstB) end return
    end
    if srcR and dstR and ratd.mid_shift then ContS(srcT, srcB, msy, mly, sty) end
    if dstT ~= srcT and dstR and srcR and ratd.left then reaper.CreateTrackSend(srcT, dstT) end
    if dstT == srcT and dstR == srcR then 
        if mop == 1 then
            if not bufr[1] and not buto[1] then bufr = {srcT} elseif bufr[1] and not buto[1] then bufr = {}
            elseif not bufr[1] and buto[1] then for k=1, #buto do if buto[k] ~= srcT then reaper.CreateTrackSend(srcT, buto[k]) end end end
        elseif mop == 2 then
            if not buto[1] and not bufr[1] then buto = {srcT} elseif buto[1] and not bufr[1] then buto = {}
            elseif not buto[1] and bufr[1] then for k=1, #bufr do if bufr[k] ~= srcT then reaper.CreateTrackSend(bufr[k], srcT) end end end
        elseif mop == 3 then if bufr[1] then SwitchER(route, 2, srcT, -1) elseif buto[1] then SwitchER(route, 2, srcT, 0) end
        elseif mop == 5 then SwitchER(route, 1)
        elseif mop == 9 then if not buto[1] then MasPar(bufr, srcT) elseif not bufr[1] then MasPar(buto, srcT) end
        elseif mop == 10 then
            local chk;
            for j = -1, 1 do
                for k = 0, reaper.GetTrackNumSends(srcT, j)-1 do 
                    if reaper.GetTrackSendInfo_Value(srcT, j, k, "B_MUTE") == 0 then chk = true; break end end
                if chk then break end
            end
            for j = -1, 1 do 
                for k = 0, reaper.GetTrackNumSends(srcT, j)-1 do
                    if chk then reaper.SetTrackSendInfo_Value(srcT, j, k, "B_MUTE", 1)
                    else reaper.SetTrackSendInfo_Value(srcT, j, k, "B_MUTE", 0) end 
                end
            end          
        elseif ratd.ctrl or ratd.left or mop == 11 then 
            if not srcC or not srcS or conf.ctrls ~= "!" or not st.ctrls or mop == 11 then 
                reaper.Main_OnCommandEx(40297, 0, 0); reaper.SetTrackSelected(reaper.CSurf_TrackFromID(0, false), false)
                reaper.SetMediaTrackInfo_Value(srcT, "I_SELECTED", 1)
                reaper.Main_OnCommandEx(40293, 0, 0)
            elseif srcC > -2 and srcS > -1 and conf.ctrls == "!" and st.ctrls then reaper.DP_tOpenControls(srcT, srcC, srcS) end -- needs "Fira Mono Medium" font
        end 
        if not srcS then return end 
        if mop == 3 and srcC < 1 and #bufr == 0 and #buto == 0 then SwitchER(route, 2, srcT, srcC, srcS)
        elseif mop == 4 and srcC < 1 then SwitchER(route, 3, srcT, srcC, srcS)
        elseif ratd.alt or mop == 6 then reaper.RemoveTrackSend(srcT, srcC, srcS)
        elseif ratd.shift or mop == 7 then
            local scntchk = false
            for j=1, #sdsh do 
                if sdsh[j].track == srcT and sdsh[j].cat == srcC and sdsh[j].ri == srcS then scntchk = true break end 
            end
            if sdsh[1] and scntchk then
                local ex = {}
                for j=1, #sdsh do if sdsh[j].cat == 0 then 
                    local track, ri = reaper.DP_RDest(sdsh[j].track, 0, sdsh[j].ri, true)
                    for k=1, #sdsh do if sdsh[k].cat == -1 then 
                            if sdsh[k].track == track and sdsh[k].ri == ri then ex[#ex+1] = k; break end 
                    end end 
                end end
                for j=1, #sdsh do 
                    local exchk = true; for k=1, #ex do if ex[k] == j then exchk = false break end end
                    if exchk then reaper.DP_tRMute(sdsh[j].track, sdsh[j].cat, sdsh[j].ri) end
                end
            else reaper.DP_tRMute(srcT, srcC, srcS) end
        elseif mop == 8 and (srcC == -1 or srcC == 0) then
            local tr, __ = reaper.DP_RDest(srcT, srcC, srcS, false) 
            if tr then reaper.DP_TGoto(tr); reaper.SetOnlyTrackSelected(tr) end
            reaper.TrackList_AdjustWindows(false); reaper.UpdateArrange()
        end
    end
end

local function ValWet()
    if rat.wet.val then
        if ratd.dbl then 
          ratd.dbl = nil; 
          reaper.TrackFX_SetParam(rat.wet.tr, rat.wet.f, rat.wet.p, 1.0); 
          return; 
        end 
        local incr = (ratd.ctrl) and 0.001 or 0.01
        local iter = (gfx.mouse_y - rat.wet.prev)*incr 
        rat.wet.val = math.min(math.max(rat.wet.val - iter, 0.0), 1.0)
        local wettip = string.format("%s: %s: %s%%", rat.wet.f+1, rat.wet.fname, math.floor((rat.wet.val*100.0)+0.5)) or "" 
        reaper.TrackCtl_SetToolTip(wettip, rat.wet.sx, rat.wet.sy, false) 
        if rat.wet.prev ~= gfx.mouse_y then 
            reaper.TrackFX_SetParam(rat.wet.tr, rat.wet.f, rat.wet.p, rat.wet.val)
            rat.wet.prev = gfx.mouse_y
        end
    end
end

local function ValR()
    if rat.cha.val then
        local rc, cat, ri = reaper.DP_RCR(rat.cha.tr, rat.cha.k, st.rtng)
        if ratd.dbl then ratd.dbl = nil; 
            reaper.SetTrackSendInfo_Value(rat.cha.tr, cat, ri, "D_PAN", 0)
            reaper.SetTrackSendInfo_Value(rat.cha.tr, cat, ri, "D_VOL", 1); return; end   
        local incr = (ratd.ctrl or ratd.shift) and 0.01 or 0.2
        local iter = (gfx.mouse_y - rat.cha.prev)*incr 
        if ratd.shift then rat.cha.val = math.min(math.max((rat.cha.val - iter), -1), 1)
        else local vdb = 20*(math.log(rat.cha.val, 10)); rat.cha.val = math.min(math.max((10^((vdb - iter)/20)), 6.3095734448019e-008), 4) end
        if rat.cha.prev ~= gfx.mouse_y then 
            reaper.SetTrackSendInfo_Value(rat.cha.tr, cat, ri, ratd.shift and "D_PAN" or "D_VOL", rat.cha.val)
            rat.cha.prev = gfx.mouse_y
        end
    end
end

local function I(trac, try, trh, w_al, rtng) 
    local s2x = 14*conf.s2x; 
    local tryh = trh + try; 
    local w_al_r = w_al + rtng
    local qu = (conf.tnc == "") and tryh or tryh + s2x; 
    local w_alwet = 4 + (4*conf.s2x);
    local ratx, raty = gfx.mouse_x, gfx.mouse_y
    local tr_byp = reaper.GetMediaTrackInfo_Value(trac, "I_FXEN")
    local fxc = reaper.TrackFX_GetCount(trac)-1;
    local rc = 0; 
    if conf.rtng == "!" then 
      rc, __, __ = reaper.DP_RCR(trac, -1, st.rtng) 
    end
    if tryh >= yalu and raty > try and raty < tryh and ratx < w_al_r and ratx > 0 then
        local quant = (conf.tnc == "") and math.floor(trh/s2x) or math.ceil(trh/s2x)
        local frc = (ratx < w_al and ratx > 0) and fxc+2 or 1
        for cell=frc, quant do
            local yf_e = (cell-1)*s2x + try 
            if raty > yf_e and raty < (yf_e + s2x) and reaper.DP_TipZ(ratx, raty) then
                local s2xl = s2x; if conf.tnc == "!" then if cell >= quant then s2xl = trh%s2x end end; gfx.set(t.fh[1], t.fh[2], t.fh[3], 1.0); 
                if conf.rtng == "!" and ratx < w_al_r and ratx > w_al then gfx.rect(w_al, yf_e+1, rtng-1, s2xl-1, 1)
                elseif ratx < w_al and ratx > 0 then gfx.rect(1, yf_e+1, w_al-2, s2xl-1, 1); ShowTooltip(trac, cell) end break
            end
        end
    end
    for k=0, fxc do
        local yf = (k*s2x) + try; local yf2x = yf + s2x
        local s2xl = (yf2x <= tryh) and s2x or trh%s2x 
        if yf2x < qu then
            local color = {t.fo[1], t.fo[2], t.fo[3]}
            local __, af = reaper.TrackFX_GetFXName(trac, k, ""); if not af then af = "fx" end
            if af:match("JS:") then color = c[conf.cj] elseif af:match("VST3?i:") or af:match("AUi:") then color = c[conf.c] end
            if af:match(": (.*)") then af = af:match(": (.*)"):gsub("%(.-%)$","") end
            local fstate = reaper.DP_FBroken(trac,k)
            local af_w, af_h = gfx.measurestr(af)
            gfx.x, gfx.y = 0, yf
            if raty > yf and raty <= yf2x and ratx < w_al and ratx > 0 and reaper.DP_TipZ(ratx, raty) then
                if fstate == 2 and tr_byp == 1 then
                    gfx.set(color[1], color[2], color[3], 1); gfx.rect(1,yf+1,w_al-2,s2xl-1,1); 
                    gfx.set(t.fl[1], t.fl[2], t.fl[3], 0.4); gfx.rect(1,yf+1,w_al-2,s2xl-1,1); 
                    if conf.hlght == "!" then if reaper.TrackFX_GetFloatingWindow(trac, k) then gfx.set(t.f5[1], t.f5[2], t.f5[3], 1.0) else gfx.set(t.f1[1], t.f1[2], t.f1[3], 1.0) end
                    else gfx.set(t.f1[1], t.f1[2], t.f1[3], 1.0) end
                elseif fstate == 1 or (fstate == 2 and tr_byp == 0) then
                    gfx.set(t.fh[1], t.fh[2], t.fh[3], 1.0); gfx.rect(1,yf+1,w_al-2,s2xl,1); gfx.set(t.f2[1], t.f2[2], t.f2[3])
                elseif fstate == 0 then
                    gfx.set(t.fh[1], t.fh[2], t.fh[3], 1.0); gfx.rect(1,yf+1,w_al-2,s2xl,1); gfx.set(t.f3[1], t.f3[2], t.f3[3])
                elseif fstate == 3 then
                    gfx.set(t.fh[1], t.fh[2], t.fh[3], 1.0); gfx.rect(1,yf+1,w_al-2,s2xl,1); gfx.set(t.f4[1], t.f4[2], t.f4[3]) end 
                ShowTooltip(trac, k+1)
            else
                if fstate == 2 and tr_byp == 1 then
                    gfx.set(color[1], color[2], color[3], 1.0); gfx.rect(1,yf+1,w_al-2,s2xl-1,1); 
                    if conf.hlght == "!" then if reaper.TrackFX_GetFloatingWindow(trac, k) then gfx.set(t.f5[1], t.f5[2], t.f5[3], 1.0) else gfx.set(t.f1[1], t.f1[2], t.f1[3], 1.0) end
                    else gfx.set(t.f1[1], t.f1[2], t.f1[3], 1.0) end                    
                    if conf.grw == 2 and s2xl >= s2x/1.4 then 
                      gfx.arc(w_alwet,yfwet,4.0*conf.s2x,-2.32,wet,1); 
                      gfx.arc(w_alwet,yfwet,3.4*conf.s2x,-2.32,wet,1) 
                    end -- math.pi*135/180=270grad = 2.3562~
                elseif fstate == 1 or (fstate == 2 and tr_byp == 0) then
                    gfx.set(t.fb[1], t.fb[2], t.fb[3], 1.0); gfx.rect(1,yf+1,w_al-2,s2xl,1); gfx.set(t.f2[1], t.f2[2], t.f2[3], 1.0)
                elseif fstate == 0 then gfx.set(t.f3[1], t.f3[2], t.f3[3], 1.0)
                elseif fstate == 3 then gfx.set(t.f4[1], t.f4[2], t.f4[3], 1.0) end
            end
            if s2xl > s2x/2 then 
                if conf.grw == 2 then 
                    if fstate == 2 and tr_byp == 1 and s2xl >= s2x/1.4 then 
                        local yfwet = yf + (math.floor(7*conf.s2x))*s2xl/s2x
                        local wet, __, __ = reaper.TrackFX_GetParam(trac, k, reaper.TrackFX_GetNumParams(trac, k)-1); wet = (wet-0.5)*4.64;
                        gfx.arc(w_alwet,yfwet,4.0*conf.s2x,-2.32,wet,1); gfx.arc(w_alwet,yfwet,3.4*conf.s2x,-2.32,wet,1) 
                    end
                    gfx.x = 7 + (conf.s2x*8); if (af_w+6 + gfx.x) <= w_al then gfx.drawstr(af,5,w_al,yf+s2xl) else gfx.drawstr(af,4,w_al,yf+s2xl) end
                else if (af_w+6) <= w_al then gfx.drawstr(af,5,w_al,yf+s2xl) else gfx.x = 3*(math.floor(conf.s2x)); gfx.drawstr(af,4,w_al,yf+s2xl) end end
                if conf.grw == 1 then
                    local grv, gr = reaper.TrackFX_GetNamedConfigParm(trac, k, "GainReduction_dB")
                    local tk = tostring(trac)..tostring(k+1); if ratew%25 == 0 then grt[tk] = nil end
                    if grv then gr = string.format("%.1f", gr); local kt = tostring(k+1)..tostring(trac)
                        if gr ~= "0.0" then if grt[kt] == nil or tonumber(grt[kt]) > tonumber(gr) then grt[kt] = gr end
                            if ratew%25 == 0 then if grt[kt] ~= "0.0" then grt[tk] = grt[kt] end grt[kt] = nil end end end
                    if fstate == 2 and grt[tk] and grv then gfx.x = 4; gfx.drawstr(grt[tk], 4, w_al/2, yf + s2xl) end
                end
            end
            if conf.grw < 2 then if af:match("^Volume Trim$") then if reaper.TrackFX_GetParam(trac, k, 2) >= 0 then gfx.set(0.4, 0.0, 0.0, 1.0); gfx.rect(6, yf+3, 4*conf.s2x, math.floor(9*conf.s2x), 1) end end end
            local w_al2 = w_al - (10*conf.s2x); local yf2 = yf + (math.floor(7*conf.s2x))*s2xl/s2x; local rad2 = (math.floor(3*conf.s2x))*s2xl/s2x
            if #fxcn > 0 then for j=1, #fxcn do if fxcn[j].track == trac and fxcn[j].fxguid == reaper.TrackFX_GetFXGUID(trac, k) then gfx.set(t.fm[1], t.fm[2], t.fm[3], 1.0); gfx.circle(w_al2, yf2, rad2, 1, 0); break end end end
            if #fxsh > 0 then for j=1, #fxsh do if fxsh[j].track == trac and fxsh[j].fxguid == reaper.TrackFX_GetFXGUID(trac, k) then gfx.set(t.fs[1], t.fs[2], t.fs[3], 1.0); gfx.circle(w_al2, yf2, rad2, 1, 0); break end end end
        end
    end
    for k=1, rc do
        local __, cat, ri = reaper.DP_RCR(trac, k, st.rtng)
        local yf = (k-1)*s2x + try; local yf2x = yf + s2x;
        local s2xl = (yf2x <= tryh) and s2x or trh%s2x; local sdshchk = nil; 
        if #sdsh > 0 and yf2x < qu then
            for j=1, #sdsh do
                if sdsh[j].track == trac and sdsh[j].i ~= reaper.CSurf_TrackToID(trac, false) then sdsh = {} break end
                if sdsh[j].track == trac and sdsh[j].name == reaper.DP_RName(trac, cat, ri, "") and sdsh[j].cat == cat and sdsh[j].ri == ri then
                    local rnum = 0; for l=-1, 1 do rnum = rnum + reaper.GetTrackNumSends(trac, l) end
                    if sdsh[j].rnum ~= rnum then sdsh = {} break end; sdshchk = true break 
                end 
            end 
        end
        if yf2x < qu then
            local dvol = reaper.GetTrackSendInfo_Value(trac, cat, ri, ratd.shift and rat.cha and "D_PAN" or "D_VOL")
            if not ratd.shift or not rat.cha then
                if reaper.DP_RMode(trac, cat, ri, -2.0) == 1 then dvol = math.min(math.floor(dvol*128),127)
                else dvol = 20*math.log(dvol, 10); dvol = (dvol < -144) and "-inf" or string.format("%.1f", dvol) end    
            else if dvol == 0 then dvol = "C " else dvol = string.format("%.0f"..(dvol > 0 and "R" or "L"), dvol*100) end end
            local dvol_w, dvol_h = gfx.measurestr(tostring(dvol))         
            gfx.x, gfx.y = w_al+8, yf
            gfx.set(t.rb[1], t.rb[2], t.rb[3], 1.0); gfx.rect(w_al,yf+1,rtng-1,s2xl,1);
            if cat < 0 then gfx.set(t.rr[1],t.rr[2],t.rr[3],1.0) elseif cat > 0 then gfx.set(t.rh[1],t.rh[2],t.rh[3],1.0) 
            else gfx.set(t.rs[1],t.rs[2],t.rs[3],1.0) end; gfx.rect(w_al+2,yf+3,4,s2xl-5,1);
            if raty > yf and raty < yf2x and ratx < w_al_r and ratx > w_al and reaper.DP_TipZ(ratx, raty) then 
                if sdshchk then gfx.set(t.r4[1], t.r4[2], t.r4[3], 1) else gfx.set(t.r2[1], t.r2[2], t.r2[3], 1) end; 
                if ratew%3 == 0 then if gfx.mouse_y > yalu then 
                    local scat = {"recv<-", "send->", "HW out->"}
                    local rat_scrx, rat_scry = gfx.clienttoscreen(gfx.mouse_x, gfx.mouse_y) 
                    reaper.TrackCtl_SetToolTip(string.format("%s%s", scat[cat+2], reaper.DP_RName(trac, cat, ri, "") or ""), rat_scrx+20, rat_scry+14, false) 
                end end
            else if sdshchk then gfx.set(t.r3[1], t.r3[2], t.r3[3], 1.0) else gfx.set(t.r1[1], t.r1[2], t.r1[3], 1.0) end end
            if s2xl > s2x/2 and gfx.w > math.floor(conf.s2x)*100 then
                gfx.drawstr(tostring(reaper.DP_RName(trac, cat, ri, "")), 4, w_al_r-dvol_w-8, yf+s2xl) 
                gfx.x, gfx.y = w_al_r-dvol_w-8, yf
                local smode = reaper.GetTrackSendInfo_Value(trac, cat, ri, "I_AUTOMODE")
                if smode > 0 then if smode < 6 then gfx.set(c[ c[smode] ][1], c[ c[smode] ][2], c[ c[smode] ][3], 1.0) end end
                gfx.drawstr(dvol, 6, w_al_r-3, yf + s2xl) end
            if reaper.GetTrackSendInfo_Value(trac,cat,ri,"B_MUTE") == 1 then gfx.set(0.10,0.11,0.11,0.75); gfx.rect(w_al,yf+1,rtng-2,s2xl,1); end
        end
    end
end

local function Spaghetti() 
    local cap = gfx.mouse_cap; 
    ratk.left = cap == 1; -- left mouse button
    ratk.right = cap == 2; -- right mosue button
    ratk.ctrl = cap == 5 or cap == 33; -- Ctrl + left button or Win + left button
    ratk.shift = cap == 9; -- Shift + left button
    ratk.ctrl_shift = cap == 13 or cap == 41; -- Ctrl + Shift + left button or Win + Shift + left button
    ratk.alt = cap == 17; -- Alt + left button
    ratk.mid = cap == 64; -- Middle mouse button
    ratk.mid_shift = cap == 72; -- Shift + Middle button
    
    local gc = gfx.getchar(); 
    if gc ~= 27 and gc ~= -1 and not st.sclose then 
      reaper.defer(Spaghetti) 
    else 
      return 
    end
    
    if dpm.mtr ~= reaper.GetMasterTrack(0) then sdsh, buto, bufr = {}, {}, {}; DpMeter() end
    if afxchk then afxchk = reaper.DP_Afx((conf.mshtw == "!") and 1 or 0, wsr) end
    if rat.wet then 
      ValWet() 
    elseif rat.cha then 
      ValR() 
    end
    if ratew > 63 then 
      ratew = 0; 
      if cap ~= 6 then -- 6 == Ctrl + right button
        reaper.TrackCtl_SetToolTip("", gfx.mouse_x, gfx.mouse_y, false) 
      end 
    end; 
    ratew = ratew + 1
    if gfx.mouse_wheel ~= 0 then 
      if gfx.mouse_wheel < 0 then 
        reaper.Main_OnCommandEx(40139, 0, CUR_PROJ) -- View: Scroll view down
      else 
        reaper.Main_OnCommandEx(40138, 0, CUR_PROJ) -- View: Scroll view up
      end; 
      gfx.mouse_wheel = 0; 
    end
    if conf.rtng == "!" then 
      st.rtng = ((conf.rcv=="!") and 1 or 0) + ((conf.sd=="!") and 2 or 0) + ((conf.hw=="!") and 4 or 0) 
    end
    st.sclose, yalu, yalb, wsr = reaper.DP_Yal(false)
    local s2x = math.floor(conf.s2x); 
    local rtng, w_al = 0, 100*s2x; 
    gfx.setfont(1); 
    if gfx.w > 100*s2x then 
      if conf.rtng == "!" then 
        rtng = 80*s2x 
      end; 
      w_al = gfx.w - rtng 
    end; 
    local w_al_r = w_al + rtng;
    if ratew & 1 == 1 then if reaper.DP_Og(ratew) then
        gfx.x, gfx.y = 0, 0
        local __, idx, try, ha = reaper.DP_TV()
        local trc = reaper.CountTracks(0)
        for i=idx, trc do
            local tr = reaper.CSurf_TrackFromID(i, false)
            local trh = reaper.GetMediaTrackInfo_Value(tr, "I_WNDH") -- current (TCP window) track(?) height in pixels including envelopes (read-only)
            if trh > 0 then
                if i == 0 then trh = trh + 5 end
                gfx.set(t.bt[1], t.bt[2], t.bt[3], 1.0); 
                gfx.rect(0, try, w_al, trh, 0); 
                gfx.rect(w_al-1, try, rtng+1, trh, 0)
                
                I(tr, try, trh, w_al, rtng)
                
                if conf.rtng == "!" then              
                    local rtab = {}; 
                    if buto[1] then 
                      rtab = buto 
                    elseif bufr[1] then 
                      rtab = bufr 
                    end
                    for j=1, #rtab do 
                        if rtab[j] == tr then
                            local sclr = (buto[1] ~= nil) and "rr" or "rs"; 
                            local sca = 1; 
                            gfx.set(t[sclr][1], t[sclr][2], t[sclr][3], sca);
                            for k=0, 2 do 
                              gfx.rect(w_al-1+k,try+k,rtng+1-(k*2),trh-(k*2), 0); 
                              sca = 0.5*sca; gfx.a = sca; 
                            end 
                            break
                        end
                    end
                end               
                try = try + trh
            end
            if try > ha then break end
        end
        gfx.set(t.bp[1], t.bp[2], t.bp[3], 1.0); 
        gfx.rect(0, 0, w_al_r, yalu, 1); 
        gfx.rect(0, gfx.h-yalb, w_al_r, yalb, 1)
        
        gfx.set(t.bf[1], t.bf[2], t.bf[3], 1.0); 
        gfx.rect(10, yalu-(59*s2x), w_al_r-20, 50*s2x, 1)
        
        dpm.idx = reaper.TrackFX_AddByName(dpm.mtr, dpm.name, true, 0); 
        if conf.dpMeter == "!" and dpm.idx and dpm.idx >= 0 and dpm.chk then 
            dpm.idxx = 0x1000000 + dpm.idx
            if not reaper.TrackFX_GetOffline(dpm.mtr, dpm.idxx) then
                local __, iloud = reaper.TrackFX_GetFormattedParamValue(dpm.mtr, dpm.idxx, dpm.OUTEBUIL, "")
                local __, tpmax = reaper.TrackFX_GetFormattedParamValue(dpm.mtr, dpm.idxx, dpm.OUTEBUTPMax, "")
                local __, lra = reaper.TrackFX_GetFormattedParamValue(dpm.mtr, dpm.idxx, dpm.OUTEBULRA, "")
                gfx.set(t.i4[1], t.i4[2], t.i4[3], 1.0); gfx.x, gfx.y = w_al_r/2, yalu-(31*s2x)
                gfx.drawstr(tostring(lra), 5, w_al_r-10, yalu-(9*s2x)) 
                tpmax = tonumber(tpmax); if tpmax then
                    if tpmax >= 0 then gfx.set(0.6, 0.1, 0, 1) end; gfx.x = 10;
                    gfx.drawstr((tpmax <= -140) and "---" or tostring(tpmax), 5, w_al_r/2-10, yalu-(9*s2x)) end
                iloud = tonumber(iloud); if iloud then
                    if conf.tplr == "!" then if iloud <= -70 and tpmax <= -70 then iloud = -70 else iloud = iloud - tpmax end end
                    if iloud < conf.mth then gfx.set(t.i1[1], t.i1[2], t.i1[3], 1.0) elseif iloud > conf.uth then gfx.set(t.i2[1], t.i2[2], t.i2[3], 1) else gfx.set(t.i3[1], t.i3[2], t.i3[3], 1.0) end                                
                    if conf.tplr == "!" then iloud = -iloud end; gfx.x, gfx.y = 10, yalu-(59*s2x); gfx.setfont(2)
                    gfx.drawstr((iloud <= -70 or iloud >= 70) and "---" or tostring(iloud), 5, w_al_r-10, yalu-(29*s2x)) end
            end
        end 
        gfx.update();
        end
    end
    
    if IsMouseInside(10, yalu-(59*s2x), w_al_r-10, 50*s2x) then
        if ratk.left and not ratd.left then ratd.left = true end 
        if not ratk.left and ratd.left then
            if dpm.mtr and dpm.idxx and dpm.chk then 
                reaper.TrackFX_SetParam(dpm.mtr, dpm.idxx, dpm.Reset, 1) 
                dpm.res = reaper.time_precise() + 0.001
            end    
        end
        if dpm.res then 
            if dpm.res < reaper.time_precise() then 
                reaper.TrackFX_SetParam(dpm.mtr, dpm.idxx, dpm.Reset, 0); dpm.res = nil  
            end 
        end
    end
    
    if IsMouseInside(0, 0, w_al_r, yalu) then
        if ratk.right and not ratd.right then ratd.right = true end 
        if not ratk.right and ratd.right then 
            gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
            local omenc = "|theme||blue|green|yellow|orange|red|purple|grey|<light"
            local omencdef = {"sky","weed","sun","orange","blood","alien_shit","everyday","mostboring"}
            local omens2x = (math.ceil(conf.s2x) == 2) and "!" or ""
            local omengrw = "GR/Wet: Hidden|"; if conf.grw == 1 then omengrw = "!Show: Gain Reduction|" elseif conf.grw == 2 then omengrw = "!Show: Wet|" end
            local omencm = omens2x.."Scale Mode: "..conf.s2x.."x|"..omengrw..conf.dpMeter.."Loudness meter|"..conf.tplr.."TPLR|"..conf.cmnt.."FX comments|"..conf.tnc.."Truncated cells|"..conf.hlght.."Highlight float|"..conf.mshtw.."Shift float FX|Close all FX"
            local omensd = "||"..conf.rtng.."Show routing|"..conf.rcv.."Receives|"..conf.sd.."Sends|"..conf.hw.."HW outputs|"..conf.ctrls.."Controls (test only)"
            local omen = gfx.showmenu(omencm..omensd.."||>Color: instruments"..omenc.."|>Color: JS"..omenc.."|Color: thresholds..|Font size..||About||Dock|Close")
            if omen == 1 then if conf.s2x == 1 then conf.s2x = 1.5 elseif conf.s2x == 1.5 then conf.s2x = 2 else conf.s2x = 1 end  
            elseif omen == 2 then conf.grw = (conf.grw+1)%3 elseif omen == 3 then OMnu("dpMeter"); reaper.SetExtState("dopp_fxList", "dpMeter", conf.dpMeter, true); DpMeter()           
            elseif omen == 4 then OMnu("tplr") elseif omen == 5 then OMnu("cmnt") elseif omen == 6 then OMnu("tnc") elseif omen == 7 then OMnu("hlght") elseif omen == 8 then OMnu("mshtw")
            elseif omen == 9 then reaper.DP_FClose() elseif omen == 10 then OMnu("rtng") elseif omen == 11 then OMnu("rcv") elseif omen == 12 then OMnu("sd") elseif omen == 13 then OMnu("hw") elseif omen == 14 then OMnu("ctrls") 
            elseif omen == 15 then conf.c = "themevi" elseif omen > 15 and omen < 24 then conf.c = omencdef[omen-15] elseif omen == 24 then conf.cj = "themejs" elseif omen > 24 and omen < 32 then conf.cj = omencdef[omen-24]  
            elseif omen == 33 then
                local rv, cth = reaper.GetUserInputs("color thresholds", 2, "input number values:", tostring(conf.mth)..","..tostring(conf.uth))
                if rv then conf.mth, conf.uth = cth:match("(%-?%d-%.?[%d?]-),(%-?[%d]+%.?%d?%d?)")
                    if not tonumber(conf.mth) or not tonumber(conf.uth) then conf.mth = -14; conf.uth = -8
                    else conf.mth = tonumber(conf.mth); conf.uth = tonumber(conf.uth) end end
            elseif omen == 34 then
                local rv, fszs = reaper.GetUserInputs("Set font size", 2, "  FX font 14:(8..40),  IL font 20:(8..60)", tostring(conf.fsz)..","..tostring(conf.fsz2))
                if rv then local fnt1, fnt2 = fszs:match("(%d%d?),(%d%d?)"); fnt1 = tonumber(fnt1) or 14; fnt2 = tonumber(fnt2) or 20 
                    conf.fsz = math.max(math.min(fnt1, 40), 8); conf.fsz2 = math.max(math.min(fnt2, 60), 8) 
                    gfx.setfont(1, st.font, conf.fsz); gfx.setfont(2, st.font, conf.fsz2) end  
            elseif omen == 35 then reaper.MB("Script: fxList for TCP\n\nVersion: 0.7 alpha\n\nAuthor: dopp (Oleksiy)\n7 May 2018","About",0)
            elseif omen == 36 then 
                local dock = gfx.dock(-1); if dock%2 == 1 then gfx.dock(dock-1) else gfx.dock(dock+1) end 
                conf.dock, conf.wndx, conf.wndy, conf.wndw, conf.wndh = gfx.dock(-1, 0,0,0,0)
            elseif omen == 37 then st.sclose = true end; reaper.DP_FocusMwnd()
            if omen > 0 and omen ~= 3 and omen ~= 9 and omen ~= 35 and omen ~= 37 then SaveConfig() end
        end   
    end
    
    if IsMouseInside(0, 0, w_al, gfx.h - yalb) and not rat.wet and not rat.cha then
        if ratk.right and ratd.right == false then Rats("right","syr"); end 
        if not ratk.right and ratd.right then 
            gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
            local rat_ly, mpaste, mop = gfx.mouse_y, "#Paste"
            if cbuf[1] then if reaper.TrackFX_GetCount(cbuf[1].track) > 0 then mpaste = "Paste" else cbuf = {} end end
            local empc, cbyp = Bypoff(rat.syr, rat_ly, 0, true)
            if empc == false then mop = gfx.showmenu("Add|Favourites..|Delete||Copy|Cut|"..mpaste.."||Bypass|Offline||"..(cbyp and cbyp or "").."Bypass FX Chain|Show FX Chain")
            elseif empc then mop = gfx.showmenu("Add|Favourites..|#Delete||#Copy|#Cut|"..mpaste.."||#Bypass|#Offline||"..(cbyp and cbyp or "").."Bypass FX Chain|Show FX Chain") end
            if mop == 1 or mop == 3 or mop == 4 or mop == 5 or mop == 6 or mop == 10 then Duplicate(rat.syr, rat_ly, mop)
            elseif mop == 2 or mop == 7 or mop == 8 or mop == 9 then Bypoff(rat.syr, rat_ly, mop, false) end
        end 
        if conf.grw == 2 and gfx.mouse_x < (7 + (8*conf.s2x)) and gfx.mouse_x > 0 then 
            if ratk.left and not ratd.left then
                if rat.dbl then if reaper.time_precise() - rat.dbl < 0.3 then ratd.dbl = true rat.dbl = nil; else ratd.dbl = nil; rat.dbl = nil end end 
                if not rat.dbl then rat.dbl = reaper.time_precise() end
            end
            if (ratk.left and not ratd.left) or (ratk.ctrl and not ratd.ctrl) then 
                local tr, k, __, __ = reaper.DP_TL(gfx.mouse_y, conf.s2x) 
                if tr and k > 0 then 
                    local wet_idx = reaper.TrackFX_GetNumParams(tr, k-1)-1
                    local wet, __, __ = reaper.TrackFX_GetParam(tr, k-1, wet_idx)
                    local __, af = reaper.TrackFX_GetFXName(tr, k-1, ""); if not af then af = "fx" end
                    if af:match(": (.*)") then af = af:match(": (.*)"):gsub("%(.-%)$","") end
                    local sx, sy = gfx.clienttoscreen(gfx.mouse_x+20, gfx.mouse_y-20)
                    cur = nil; rat.wet = (not rat.wet) and {prev = gfx.mouse_y, sx = sx, sy = sy, tr = tr, f = k-1, p = wet_idx, val = wet, fname = af} or nil; 
                end
            end
        end
        if cur then if gfx.mouse_y > (cur+7) or gfx.mouse_y < (cur-7) then reaper.DP_Curdd() end end
        if ratk.left and not ratd.left then Rats("left","syl"); cur = rat.syl; 
        elseif ratk.ctrl and not ratd.ctrl then Rats("ctrl","syc"); cur = rat.syc elseif ratk.alt and not ratd.alt then Rats("alt","sya"); cur = rat.sya
        elseif ratk.shift and not ratd.shift then Rats("shift","sys") elseif ratk.ctrl_shift and not ratd.ctrl_shift then Rats("ctrl_shift","sycs")
        elseif ratk.mid and not ratd.mid then Rats("mid","sym") elseif ratk.mid_shift and not ratd.mid_shift then Rats("mid_shift","syms") end 
        if rat.rx < w_al then 
            if not ratk.left and ratd.left then Duplicate(rat.syl, gfx.mouse_y)
            elseif not ratk.ctrl and ratd.ctrl then Duplicate(rat.syc, gfx.mouse_y) elseif not ratk.alt and ratd.alt then Duplicate(rat.sya, gfx.mouse_y)
            elseif not ratk.shift and ratd.shift then Bypoff(rat.sys, gfx.mouse_y) elseif not ratk.ctrl_shift and ratd.ctrl_shift then Bypoff(rat.sycs, gfx.mouse_y) 
            elseif not ratk.mid and ratd.mid then Duplicate(rat.sym, gfx.mouse_y) elseif not ratk.mid_shift and ratd.mid_shift then Duplicate(rat.syms, gfx.mouse_y) end  
        end
        
    end
    if IsMouseInside(w_al, 0, rtng, gfx.h - yalb) and not rat.wet and not rat.cha then
        if ratk.right and ratd.right == false then Rats("right","syr"); end 
        if not ratk.right and ratd.right then 
            gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
            local rat_ly, rprst, mop = gfx.mouse_y, "#"
            local crto = (buto[1]~=nil) and "!" or ""
            local crfr = (bufr[1]~=nil) and "!" or ""
            local route = {"recv", "send"}
            local empc, mtchk = Routing(rat.syr, rat_ly, 0, route, true)
            local appl = (empc and bufr[1]== nil and buto[1] == nil) and "#" or ""
            for k,v in pairs(route) do if reaper.GetExtState("dopp_fxList_sends", v):match(":>.-:<") then rprst = "" break end end
            if mtchk then if empc == false then mop = gfx.showmenu("Remove|Mute"); mop = mop + 5 end
            else if empc == false then mop = gfx.showmenu(crfr.."Create send from|"..crto.."Create send to|Apply preset..|>Save/remove presets|Save preset|<"..rprst.."Remove preset||Remove|Mute|Go to source/destination||Mute master/parent send|Mute routing|Show routing")
                elseif empc then mop = gfx.showmenu(crfr.."Create send from|"..crto.."Create send to|"..appl.."Apply preset..|>Save/remove presets|#Save preset|<"..rprst.."Remove preset||#Remove|#Mute|#Go to source/destination||Mute master/parent send|Mute routing|Show routing") end end
            Routing(rat.syr, rat_ly, mop, route, false)
        end 
        if conf.rtng == "!" and gfx.mouse_x > gfx.w - (20*math.floor(conf.s2x)) and gfx.mouse_x < gfx.w then 
            if ratk.left and not ratd.left then
                if rat.dbl then if reaper.time_precise() - rat.dbl < 0.3 then ratd.dbl = true rat.dbl = nil; else ratd.dbl = nil; rat.dbl = nil end end 
                if not rat.dbl then rat.dbl = reaper.time_precise() end
            end
            if (ratk.left and not ratd.left) or (ratk.ctrl and not ratd.ctrl) or (ratk.shift and not ratd.shift) then 
                local tr, k, __, __ = reaper.DP_TL(gfx.mouse_y, conf.s2x) 
                if tr and k > 0 then   
                    local rc, cat, ri = reaper.DP_RCR(tr, k or -1, st.rtng)
                    if cat > -2 and ri > -1 then cur = nil; 
                        rat.cha = (not rat.cha) and {prev = gfx.mouse_y, tr = tr, k = k, 
                        val = reaper.GetTrackSendInfo_Value(tr, cat, ri, ratk.shift and "D_PAN" or "D_VOL")} or nil
                    end
                end
            end
        end
        if cur then if gfx.mouse_y > (cur+7) or gfx.mouse_y < (cur-7) then reaper.DP_Curdd() end end    
        if ratk.left and not ratd.left then Rats("left","syl"); cur = rat.syl elseif ratk.ctrl and not ratd.ctrl then Rats("ctrl","syc")
        elseif ratk.alt and not ratd.alt then Rats("alt","sya") elseif ratk.shift and not ratd.shift then Rats("shift","sys")
        elseif ratk.mid and not ratd.mid then Rats("mid","sym") elseif ratk.mid_shift and not ratd.mid_shift then Rats("mid_shift","syms") end
        if rat.rx >= w_al then
            if not ratk.left and ratd.left then Routing(rat.syl, gfx.mouse_y) elseif not ratk.ctrl and ratd.ctrl then Routing(rat.syc, gfx.mouse_y)  
            elseif not ratk.alt and ratd.alt then Routing(rat.sya, gfx.mouse_y) elseif not ratk.shift and ratd.shift then Routing(rat.sys, gfx.mouse_y) 
            elseif not ratk.mid and ratd.mid then Routing(rat.sym, gfx.mouse_y) elseif not ratk.mid_shift and ratd.mid_shift then Routing(rat.syms, gfx.mouse_y) end 
        end
    end 
    if rat.cha then if cap ~= 1 and cap ~= 5 and cap ~= 33 and cap ~= 9 then rat.cha = nil; reaper.DP_FocusMwnd() end end
    if rat.wet then if cap ~= 1 and cap ~= 5 and cap ~= 33 then rat.wet = nil; reaper.DP_FocusMwnd() end end
    if cur then if cap == 0 then cur = nil end end
    if cap ~= 1 then ratd.left = false end; if cap ~= 2 then ratd.right = false end
    if cap ~= 5 and cap ~= 33 then ratd.ctrl = false end; if cap ~= 9 then ratd.shift = false end
    if cap ~= 13 and cap ~= 41 then ratd.ctrl_shift = false end; if cap ~= 17 then ratd.alt = false end
    if cap ~= 64 then ratd.mid = false end; if cap ~= 72 then ratd.mid_shift = false end
end

ReadConfig(); 
gfx.init("fxlist[dopp]", conf.wndw, conf.wndh, conf.dock, conf.wndx, conf.wndy) 
gfx.mode = 0; 
gfx.clear = theming.bf[1] + (theming.bf[2]*256) + (theming.bf[3]*65536); 
theming = {} 
if reaper.APIExists("DP_tOpenControls") then 
  st.ctrls = true 
end; 
st.rtng = 0 

if not (reaper.GetOS()):match("^Win[36][24]$") then 
  conf.fsz = 11; 
  conf.fsz2 = 16 
end 
if (reaper.GetOS()):match("^OSX[36][24]$") then 
  st.font = "Lucida Grande" 
else 
  st.font = "Calibri" 
end 
gfx.setfont(1, st.font, conf.fsz); 
gfx.setfont(2, st.font, conf.fsz2) 
reaper.UpdateArrange(); 
reaper.TrackList_AdjustWindows(false) 
--st.sclose, yalu, yalb, wsr = reaper.DP_Yal(true);
reaper.atexit(Kill); 
Spaghetti() 
