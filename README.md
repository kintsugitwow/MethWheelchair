# MethWheelchair

Disables movement keybinds after standing still for at least one frame after Shackles of the Legion cast has started. After debuff is gone re-enables keybinds. 


Use ``/run MethWheelchair.Restore()`` macro to forcefully restore your keybinds.


## Known issues:

- Holding Strafe Left and Strafe Right keys at same time causes player to stop moving because velocity in both direction adds up to 0, but when keybinds are restored and player presses one of strafe keybinds and releases it, the player character will start running in opposite direction until opposite direction keybind is pressed and released. 
