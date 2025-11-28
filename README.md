# MethWheelchair 1.11

Disables movement keybinds after standing still for at least one frame after Mephistroth finishes casting Shackles of the Legion.<br>
After the debuff is gone or after 6.5 secs of cast event re-enables keybinds.<br>
Hitting movement keybinds during that time will cancel spell casts.<br>
Additionally removes movement keybinds while under effect of Enveloped Flames used by Lingering Magi as well as display full-screen effect while affected by Astral Insight spell used by Lingering Astrologists.<br>
During Chess fight displays dark yellow full-screen effect during King's Fury cast that changes to light pink once player breaks line of sight with King, provided that both SuperWoW and UnitXP are correctly installed. In case of lack of UnitXP, effect will remain dark yellow. *(Additional full-screen effects option in settings)*<br>

Whenever you change your keybinds make sure to relog afterwards, before using/testing the addon.<br>

Click minimap button or type ``/mw`` to open configuration panel.<br>


## Commands

Use ``/mw`` to toggle UI.<br>
Use ``/mw restore`` to forcefully restore your keybinds.<br>
Use ``/mw unbind`` or ``/mw test`` to test keybind removal.<br>
Use ``/mw keybinds`` to display list of saved keybinds.<br>
Use ``/mw logininfo`` to toggle display of saved keybinds on login.<br>
Use ``/mw fse`` to toggle displaying full-screen effect.<br>
Use ``/mw afse`` to toggle displaying additional full-screen effects like King's Fury or Astral Insight warnings.<br>
Use ``/mw lmb`` to toggle blocking left mouse button (prevents moving on pressing left and right mouse buttons simultaneously). *More info in Known issues section.*<br>
Use ``/mw mmb`` to toggle mutual blocking of both mouse buttons (prevents moving on pressing left and right mouse buttons simultaneously). *More info in Known issues section.*<br>
Use ``/mw autorun`` to toggle unbinding auto run while on Meth platform.<br>
Use ``/mw jump`` to toggle unbinding jump while on Meth platform.<br>
Use ``/mw eu`` to toggle unbinding keybinds before shackle cast finishes depending on configured value.<br>
Use ``/mw eu <number_value>`` to set early unbind value (replace ``<number_value>`` with number between 0.0 and 3.0).<br>


## Known issues

- Requires player to manually stop moving before Shackles of the Legion cast finishes.

- Opening Key Bindings setting in game menu and pressing "Okay" button while some keybinds are removed by the addon will remove them permanently and will require manual restoration. This includes auto-unbinding auto-run and jump keybinds while on meth platform.

- Holding Strafe Left and Strafe Right keys at same time causes player to stop moving because velocity in both direction adds up to 0, but when keybinds are restored and player presses one of strafe keybinds and releases it, the player character will start running in opposite direction until opposite direction keybind is pressed and released. *In short: Sometimes after Shackles, you have to quickly tap left and right movement keys or your character will move funny.*

- Protection against moving by holding Left and Right Mouse Buttons simultaneously disables Left Mouse Button functionality in game world meaning that you can't target enemies by clicking on their models or rotate camera by holding Left Mouse Button, you can still target enemies by clicking their nameplates or cast your spells by clicking them. Right Mouse Button still works during that time and should be used for these actions (targeting by clicking models, rotating camera). Full Left Mouse Button functionality is restored at the same time as all movement keybinds are restored - when shackles ends or after 6.5 secs. <br>*This works only with SuperWoW installed.* <br>As a side effect, movement action MOVEANDSTEER (by default bound to holding down Mouse Wheel) is permanently disabled after first movement block. It is not restored when shackle ends. To restore its functionality relog or use command ``/mw reload``.

- During Shackle there is only one mouse button pressed at a time allowed. This will fail if both mouse buttons trigger MouseDown event during same frame. This shouldn't be an issue for SuperWoW users, due to solution in section above, but will result in Shackle Shatter in the case of non-SuperWoW user.

- Another way to Shatter Shackle:<br>
    **1.** Press Right Mouse Button<br>
    **2.** Press Left Mouse Button<br>
    **3.** Press S - Stop moving<br>
    **4.** Get Shackle debuff - trigger unbind<br>
    **5.** Release both mouse buttons<br>
    **6.** Start walking backwards<br>
    **7.** Release S<br>
    **8.** Continue walking backwards<br>

    *Replace S with A or D to spin instead of walking backwards (not shattering shackle)*<br>
