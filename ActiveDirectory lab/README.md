# Active Directory LAB environment
Move entire script folder to the intended server and run the Build-ADForest.ps1 and Build-ADContent.ps1 as needed.


##Functions.ps1
A collection of functions.
### Get-RandomNames
Might need to add a few urls to Trusted Sites. If needed it will prompt for it.
Function gets a list of 99 random names, and and outputs
DisplayName, sam, Givennamn, Surname, OU
### Apply-ACL
Function creates ACE and applies them to OUs.

## Build-ADContent.ps1
Update the configuration variables as needed. 

## Build-ADForest.ps1
Installs AD-Domain-Services on a given server.