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