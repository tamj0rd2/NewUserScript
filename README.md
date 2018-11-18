# NewUserScript
A PowerShell script to create new AD users

## Functionality
* Create an AD user
* Create and attach a mailbox
* Maps a home drive for the user

## config.json
* ADDomain - The name of the domain (e.g CONTOSO)
* EmailDomain - The email domain (e.g contoso.com)
* HomePathBase - The base folder where user home folders will be stored
* HomeDriveLetter - The drive letter that will represent the user's home folder
* LoginScript - The name of the login script to give each user
* ExchangeSetup - Can either be "365", "hybrid" or "onsite"
* ADConnectServer - The server name where AD connect is installed. Used for "hybrid" exchange setups
* Locations - Allows users at different locations to be stored in different AD Organisational Units
* UserSettings - Booleans
** ChangePasswordAtNextLogon - If true, the user will need to change their password the first time they log in0
** PasswordNeverExpired - If true, the user's password will be set to never expired
** UserIsEnabled - If true, the user will be enabled by default

## Troubleshooting
* Remember to escape backslashes in paths
