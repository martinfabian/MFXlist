# MFXlist
This is a script for the Reaper DAW (digital audio workstation), that adds an FX strip to the left of the TCP for quick and easy access. MFXlist packages existing functionality into a better (in my opinion) user interface compared to the existing native implementation; the used screen estate is simply smaller. 

![](MFXlist.gif)

MFXlist consists of roughly 1400 lines of Lua code, and was developed on Windows, and Reaper v6.19/x64. It uses the js_ReaScriptAPI extension (https://forum.cockos.com/showthread.php?t=212174), which is available also for Linux and Mac, so the script should work also on those systems, but I have not tried it on Linux. 

## Installation

MFXlist is available from the ReaTeam's repo in ReaPack, so the easiest thing is to install it from there. Also js_ReaScriptAPI is easiest installed through ReaPack. Download from https://reapack.com/ the ReaPack suitable for your system, put the file in Reaper's UserPlugins folder. Start Reaper, pull down the Extensions menu, and open ReaPack. There you can search for js_ReaScriptAPI, right-click it and install. You will have to restart Reaper. Then you can install MFXlist in the same way.

Once that is set up, open Reaper's action list, click New action..., then Load ReaScript..., you get a file dialog where you can select Fabian_MFXlist.lua. After loading it, if you do not see it in the action list, type "MFX" in the filter bar and it should come up. You start it by double-clicking it, just as any script.

## First time

The first time MFXlist starts up it docks itself into whatever docker Reaper regards as number 513 on your system. For some reason this differs from system to system, so you will probably have to drag it to the docker at the left of the arrange view, to the left of the TCP. MFXlist will remember its last docking position, so this should only be necessary the first time.

SWS has a handy action "SWS/S&M: Set global startup action" that allows you to set a startup action by entering the command ID into the dialog box that appears when you run the SWS action. You get the command ID of MFXlist by right-clicking on the MFXlist action and choosing "Copy selected action command ID". I use that SWS action to run MFXlist on Reaper startup.

## User interface

MFXlist relies on mouse and modifier keys (Shift, Ctrl, Alt). Clicking on an FX toggles open/close its floating window. Shift+click on an FX toggles bypass. Ctrl+click on an FX toggles open/close the FX chain for the track that FX is on. Alt+click on an FX removes it from the FX chain.

Clicking in the track area below any FX toggles open/close the Add FX to track dialog. Ctrl+click toggles open/close the FX chain dialog for that track. 

Drag-drop of an FX without Ctrl held down, moves the FX between tracks or within a track. Drag-drop of an FX with Ctrl held down, copies the FX. Move and copy are indicated by different colors of the drop indicator.

MFXlist handles scroll wheel messages, with and without modifier keys, though not (yet) exactly in the same way as scroll wheeling on the TCP.

## Customization

The easiest way to customize MFXlist is to use X-Rayms' preset script (https://gist.github.com/X-Raym/f7f6328b82fe37e5ecbb3b81aff0b744#file-preset-lua). A preset script with the variables that seem useful to customize is available from here https://raw.githubusercontent.com/martinfabian/MFXlist/main/MFXpreset.lua Right-click and Save as.. "MFXpreset.lua" (or whatever) in the same folder as you have the MFXlist script (if you installed through ReaPack this will be Scripts\ReaTeam Scripts\FX). The good thing with presets is that these do not get overwritten by updates of the main script.

Two customizations that are worth mentioning here are:
* You can replace the standard FX browser with any FX browser you want. I have tested Quick Adder (https://forum.cockos.com/showthread.php?t=232928) and Fast FX Finder (https://forum.cockos.com/showthread.php?t=229807), and the preset file mentioned above shows how this is done. You get from Reaper the command ID of the FX browser you want to use and put it as a string in place of the "nil", where it says "-- Alternative FX browser, put command ID here" in the preset File.
* You can also add special FX that you want to have accessible on MFXlist's right-click menu. By default, ReaEQ, ReaComp, ReaFIR and ReaDelay are on the right-click menu, but these can be changed by replacing these names in the preset file.

Now, since MFXlist is an ordinary Reaper Lua script, you have access to the source code and can customize it to your heart's content if you do not want to use a preset script. Just like any programmer I am fully convinced that my code is self-documenting, but I have anyway included comments that might be useful for customization; just look at the code, the easiest customizable stuff is at the top.

## Enhancements

Ideas are welcome. One thing that I am looking at is to have the possibility of shortcuts in the header. A list of action command IDs could be given, and these commands can the be available in the header to invoke by a click.

## Known issues

There is a known issue with focus stealing in certain cases. This means that sometimes MFXlist steals the keyboard input so that key strokes do not go to Reaper, so keyboard shortcuts do not work. Clicking somewhere in the arrange view or on the TCP fixes this. I know what the problem is, I am just not sure how to fix it without affecting other focus related things that currently do work.

MFXlist does not work on Reaper v5 or earlier.

## Unknown issues

Please report to me. Posting in the MFXlist thread on the Reaper forum (https://forum.cockos.com/showthread.php?p=2395407) will work.