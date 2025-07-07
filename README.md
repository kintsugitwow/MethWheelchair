# MethWheelchair

Disables movement keybinds after standing still for at least one frame after Mephistroth finishes casting Shackles of the Legion.<br>
After debuff is gone or after 6.5 seconds of cast event re-enables keybinds.<br>
Hitting movement keybinds during that time will cancel spell casts.


Use ``/mw restore`` to forcefully restore your keybinds.<br>
Use ``/mw unbind`` or ``/mw test`` to test keybind removal.<br>
Use ``/mw keybinds`` to display list of saved keybinds.<br>
Use ``/mw logininfo`` to toggle display of saved keybinds on login.<br>
Use ``/mw lmb`` to toggle blocking left mouse button (prevents moving on pressing left and right mouse buttons simultaneously). *More info in Known issues section.*<br>


## Known issues:

- Requires player to manually stop moving before Shackles of the Legion cast finishes.

- Holding Strafe Left and Strafe Right keys at same time causes player to stop moving because velocity in both direction adds up to 0, but when keybinds are restored and player presses one of strafe keybinds and releases it, the player character will start running in opposite direction until opposite direction keybind is pressed and released. *In short: Sometimes after Shackles you have to quickly tap left and right movement keys or your character will move funny.*

- Protection agains moving by holding Left and Right Mouse Buttons simultaneously disables Left Mouse Button functinality in game world meaning that you can't target enemies by clicking on their models or rotate camera by holding Left Mouse Button, you can still target enemies by clicking their namepaltes or cast your spells by clicking them. Right Mouse Button still works during that time and should be used for these actions (targeting by clicking models, rotating camera). Full Left Mouse Button functionality is restored the same time as all movment keybinds are restored - when shackles ends.<br>As a side effect, movement action MOVEANDSTEER (by default bound to holding down Mouse Wheel) is permamently disabled after first movement block. It is not restored when shackle ends. To restore its functionality relog or use command ``/mw reload``.

