# RB2RS-Database-Converter

This Windows PowerShell Script converts the latest radio station database from Radio-Browser.info into a version compatible with RadioSure software.

![](https://zupimages.net/up/22/20/isdj.png)

* Usage (must be configured before use) : ./RB2RS-converter.ps1
* This script should be used with a local MariaDB server & 7zip.
* Recommended PowerShell version : 7 (and above) 

Note : The resulting zip file can be placed on an online server, so my other script RB2RS-database-Updater (VBScript) can be used to download and install it automatically.

--------------------------------------
Additional information : 
* "Table 'radios.stationcheckhistory' doesn't exist" is a Radio-Browser issue which will surely be fixed soon : https://github.com/segler-alex/radiobrowser-api-rust/issues/137 (It has no impact.)
