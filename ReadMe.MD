GlamourUI Is a UI enhancement addon for Ashita v4.  While it's currently in its early stages, I have big plans for it in the future.


Initially, the addon is adding a Party list and a target bar.  The current aesthetic is just the default Ashita UI, but one of the plans is to build a theming engine and a layout engine.  These two components combined will allow the player to customize the look of each element of the UI entirely.  Want the different components of your party list rearranged?  The layout engine will provide an easy means to do so.  Want to make custom textures for everything?  The theming engine will easily accomplish that.


Download and Setup Instructions:

Download the latest release from:  https://github.com/bangplaysgames/glamourui/releases

Extract the contents of the zip file directly into your Ashita folder or Horizon\Game\ folder.


I have added a new Theme Repository for players to create their own themes and share them:  https://github.com/bangplaysgames/glamouruithemes/
Clone the repository, make your new theme in its own folder, then create a pull request.  This will be the best way for user generated themes to be shared with other players.  I'm excited to see what others' designs are.


Currently, I have just a handful of commands:

/glam - The primary command.  This will print a help text to the chatlog.

/glam help - This mimics the /glam command.

/glam config - Opens the GlamourUI Configuration Window

/glam partylist - Toggles the party list on and off.

/glam partylist setscale # - Changes the scale of the party list.  Replace # with the scale multiplier.  (Default 1.  Accepts integers or decimals.)

/glam targetbar - Toggles the target bar on and off.

/glam targetbar setscale # - Changes the scale of the target bar.


Example Screenshots
Party List:

![alt text](https://github.com/bangplaysgames/images/blob/main/GlamourUI/PartyList.png?raw=true)


Target Bar:

![alt text](https://github.com/bangplaysgames/images/blob/main/GlamourUI/target%20bar.png?raw=true)
