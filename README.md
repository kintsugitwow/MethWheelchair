# MethWheelchair

Disables movement keybinds after standing still for at least one frame after Mephistroth finishes casting Shackles of the Legion.<br>
After debuff is gone or after 6.5 seconds of cast event re-enables keybinds.<br>
Hitting movement keybinds during that time will cancel spell casts.


Use ``/run MethWheelchair.Restore()`` macro to forcefully restore your keybinds.<br>
Use ``/run MethWheelchair.Unbind()`` macro to test keybind removal.<br>


## Known issues:

- Holding Strafe Left and Strafe Right keys at same time causes player to stop moving because velocity in both direction adds up to 0, but when keybinds are restored and player presses one of strafe keybinds and releases it, the player character will start running in opposite direction until opposite direction keybind is pressed and released.

- Protection agains moving by holding left and right mouse button disables camera movement on left button, rmb camera rotation still works.

- Requires player to stop moving in the first place.