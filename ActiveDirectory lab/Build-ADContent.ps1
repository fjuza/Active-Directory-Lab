#Requires -Modules PowershellAccessControl, ActiveDirectory, GroupPolicy
#Requires -Version 4
$VerbosePreference = "Continue"
# Load modules now.
Import-Module PowershellAccessControl
Import-Module ActiveDirectory
Import-Module GroupPolicy


###############################################################################
##								  CONFIGURATION								 ##
###############################################################################
$ou = Import-Csv "$PSScriptRoot\OrganizationalUnit.csv" -Delimiter ';'
$groups = Import-Csv "$PSScriptRoot\groups.csv" -Delimiter ';'
$aclList = Import-Csv "$PSScriptRoot\acl.csv" -Delimiter ';'

### SET to $False if script is running on a existing domain to create random SamAccountNames for Groups. Note: ACL-creation probably won't work in this version.
$isCleanDeploy = $True
$password = ConvertTo-SecureString "123QWEqwe" -AsPlainText -Force

#Import-Module $PSScriptRoot\modules\PSLogging\pslogging.psm1
. "$PSScriptRoot\functions.ps1"

#Basic settings
#To work DOMAIN_DN needs to be correct.
New-Variable -Name DOMAIN_DN -Value "DC=eval,DC=lab,DC=local" -Visibility Public -Option Constant
New-Variable -Name BASE_NAME -Value "lab" -Visibility Public -Option Constant
New-Variable -Name BASE_OU -Value "OU=lab" -Visibility Public -Option Constant

$user_ou = "OU=Internal,OU=Standard Users,OU=Users,$BASE_OU,$DOMAIN_DN"
$base_dn = "$BASE_OU,$DOMAIN_DN"
###############################################################################
##								  BUILD TREE								 ##
###############################################################################
#Build OUs
#Create the base OU.
New-ADOrganizationalUnit -Name $BASE_NAME -path $DOMAIN_DN -ProtectedFromAccidentalDeletion:$False


Write-Verbose -Message "Starting to create organizational units in tree."
$ou | foreach {
    $name = $PSItem.Name
    $ouPath = $PSItem.Path
    if($ouPath -like ""){
	    $path = $base_dn
    } else {
        $path = "$ouPath,$base_dn" 
    }
	New-ADOrganizationalUnit -Name $name -Path $path -ProtectedFromAccidentalDeletion:$False
}
Write-Verbose -Message "All organizational units created."
###############################################################################
##								  CREATE GROUPS								 ##
###############################################################################
Write-Verbose -Message "Creating groups."
$sam = Get-Random -Minimum 10000 -Maximum 99999
#Create Groups
$groups | foreach {
	$Name = $PSItem.Name
	$Path = "{0},{1}" -f $PSItem.Path, $base_dn
	$GroupCategory = $PSItem.GroupCategory
	$GroupScope = $PSItem.GroupScope
	if($isCleanDeploy -eq $False){
		New-ADGroup -SamAccountName $sam -Name $Name -GroupScope $GroupScope -GroupCategory $GroupCategory -Path $Path
	} else {
		New-ADGroup -Name $Name -GroupScope $GroupScope -GroupCategory $GroupCategory -Path $Path
	}
   $sam++
}
Write-Verbose -Message "All groups created."
###############################################################################
##								  POPULATE AD								 ##
###############################################################################
Write-Verbose -Message "Populating AD with users."
#Create users
$users = Get-RandomNames -OU $user_ou
$users | foreach {
	New-ADUser $PSItem.DisplayName -GivenName $PSItem.GivenName -Surname $PSItem.Surname -SamAccountName $PSItem.SamAccountName -Path $PSItem.OU -AccountPassword $password -Enabled:$true
}

#this creates one admin per tier.
#TODO: This needs to be a function rather than a all these lines of code. 
New-ADUser testes_t1 -samaccountname testes_t1 -Path "OU=Tier 1 Admins,OU=Users,$base_dn" -AccountPassword $password -Enabled:$True
New-ADUser testes_t2 -samaccountname testes_t2 -Path "OU=Tier 2 Admins,OU=Users,$base_dn" -AccountPassword $password -Enabled:$True
New-ADUser testes_t3 -samaccountname testes_t3 -Path "OU=Tier 3 Admins,OU=Users,$base_dn" -AccountPassword $password -Enabled:$True
New-ADUser testes_t4 -samaccountname testes_t4 -Path "OU=Tier 4 Admins,OU=Users,$base_dn" -AccountPassword $password -Enabled:$True
Add-ADGroupMember "Tier 1 Admins" -Member testes_t1
Add-ADGroupMember "Computer Group Management" -Member "Tier 1 Admins"
Add-ADGroupMember "Low-Impact Server Management" -Member "Tier 1 Admins"
Add-ADGroupMember "Standard Users Management" -Member "Tier 1 Admins"
Add-ADGroupMember "Distribution Group Management" -Member "Tier 1 Admins"

Add-ADGroupMember "Tier 2 Admins" -Member testes_t2
Add-ADGroupMember "Medium-Impact Server Management" -Member "Tier 2 Admins"
Add-ADGroupMember "Restricted Users Management" -Member "Tier 2 Admins"
Add-ADGroupMember "Fileshare Management" -Member "Tier 2 Admins"

Add-ADGroupMember "Tier 3 Admins" -Member testes_t3
Add-ADGroupMember "Exchange Administrator" -Member "Tier 3 Admins"
Add-ADGroupMember "High-Impact Server Management" -Member "Tier 3 Admins"
Add-ADGroupMember "GPO Management" -Member "Tier 3 Admins"
Add-ADGroupMember "Role Group Management" -Member "Tier 3 Admins"

Add-ADGroupMember "Tier 4 Admins" -Member testes_t4
Add-ADGroupMember "Mission-Critical Server Management" -Member "Tier 4 Admins"
Add-ADGroupMember "Tier Admin Users Management" -Member "Tier 4 Admins"
Add-ADGroupMember "RBAC Management" -Member "Tier 4 Admins"
Add-ADGroupMember "Users Management" -Member "Tier 4 Admins"
Add-ADGroupMember "Exchange Administrator" -Member "Tier 4 Admins"

Write-Verbose -Message "AD is populated."
###############################################################################
##								  WRITE ACL									 ##
###############################################################################
Write-Verbose -Message "Creating ACE and applying ACLs."
$aclList | foreach {
    $OU = "{0},{1}" -f $PSItem.OU, $base_dn
    Apply-ACL -Principal $PSItem.principal -adObject $OU
}
Write-Host "Done."