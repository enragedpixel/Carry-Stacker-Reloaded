# Carry-Stacker-Reloaded
Payday 2 BLT Mod

[![Download](img/downloadButton.png)](https://github.com/enragedpixel/Carry-Stacker-Reloaded/releases/latest/download/CarryStackerReloaded.zip)

Have you ever thought  
*Man... I could get a hold of some more paintings on myself... But I can only carry one.*

**Well, wait no longer!**  
I hereby bring you a fully functional and customizable **Carry Stacker *(Reloaded)*** in a standalone version! 

***What can you do with it?***  
Well.. You can... Carry multiple bags at once...

***Is it restricted to anything?***  
**Yes!** *Let me fetch you the information from within the mod.*  

![Instructions](img/modDescription.png)

***I want to go full nuts with this. Can I carry an infinite amount of bags somehow?***  
**Yes.**  
Just set the weight of the desired type to **0** and you're good to go :)

***Does this work in Multiplayer?***  
**Yes**, *in a restricted way.*  
If the **host** has the mod, he can use it fine.  
Vanilla clients won't be affected.  
Clients that have the mod can then use it.  
If a **client** has the mod, and the host **does NOT** have it, the client won't be able to use it.  

***When I'm hosting a game, do clients get notified that I am using the mod?***  
**Yes**, they do get notified about that.  
It's the same implementation as in *Keepers* or *Moveable Intimidated Cops*, for example.  
Thanks to TdlQ for the awesome code :)

[![Download](img/downloadButton.png)](https://github.com/enragedpixel/Carry-Stacker-Reloaded/releases/latest/download/CarryStackerReloaded.zip)

# Changelog
Click [here](https://htmlpreview.github.io/?https://github.com/enragedpixel/Carry-Stacker-Reloaded/blob/master/.github/Changelog.html) to see the changelog.

# Compatibility Issues
**The Fixes**: For Carry Stacker Reloaded to work, the fix `remove_bag_from_back_playerman` has been disabled. This fix is, as per the mod's description: `If someone throws a bag then remove it from his back and from hud`

# Acknowledgements
Special thanks to @HugoZink for creating the awesome [template](https://github.com/HugoZink/PD2AutoUpdateExample) used to for auto-updates.

# Development
Source code is `CarryStackerReloaded` directory. It needs to be here for autoupdates to work! :)

`install.py` is a python3 util script that will copy the mod's source into `PAYDAY2/mods` directory. Note it will overwrite the mod if its already there. To use it, do not forget to change the `MODS_DIR` variable

To create a new release:
1. Update mod's version in [mod.txt](https://github.com/enragedpixel/Carry-Stacker-Reloaded/blob/master/CarryStackerReloaded/mod.txt)
2. Update the [Changelog](https://github.com/enragedpixel/Carry-Stacker-Reloaded/blob/master/.github/Changelog.html)
3. Go to [actions](https://github.com/enragedpixel/Carry-Stacker-Reloaded/actions/workflows/release.yml) and run the workflow to create a release. Do not forget to set the version tag accordingly :)