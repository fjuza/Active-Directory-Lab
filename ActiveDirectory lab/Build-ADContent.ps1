#Requires -Modules PowershellAccessControl, ActiveDirectory, GroupPolicy
#Requires -Version 4
$VerbosePreference = "Continue"
# Load modules now.
Import-Module PowershellAccessControl
Import-Module ActiveDirectory
Import-Module GroupPolicy

#Import some useful functions
& 

###############################################################################
$ou = Import-Csv -Path "C:\Users\Administrator\Documents\OrganizationalUnit.csv" -Delimiter ';'
$groups = Import-Csv "C:\Users\Administrator\Documents\groups.csv" -Delimiter ';'
$aclList = Import-Csv 'C:\Users\frejuz\Documents\Visual Studio 2015\Projects\ActiveDirectory lab\ActiveDirectory lab\acl.csv' -Delimiter ';'



###############################################################################
##								  BUILD TREE								 ##
###############################################################################
#Build OUs
$isFirst = $True
Write-Verbose -Message "Starting to create organizational units in tree."
$ou | foreach {
    $name = $PSItem.Name
    $ouPath = $PSItem.Path
    if($isFirst -like $True){
	    $path = $PSItem.domain
        $isFirst = $False
    } else {
        $path = "{0},{1}" -f $ouPath,$PSItem.domain
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
	$Path = $PSItem.Path
	$GroupCategory = $PSItem.GroupCategory
	$GroupScope = $PSItem.GroupScope
    $PSitem | ft Name, Path, GroupScope, GroupCategory -AutoSize
    New-ADGroup -SamAccountName $sam -Name $PSItem.Name -GroupScope $PSItem.GroupScope -GroupCategory $PSItem.GroupCategory -Path $PSItem.Path
    $sam++
}
Write-Verbose -Message "All groups created."
###############################################################################
##								  POPULATE AD								 ##
###############################################################################
Write-Verbose -Message "Populating AD with users."
#Create users
$users = Get-RandomNames
$password = ConvertTo-SecureString "p4$$w0rd" -AsPlainText -Force
$users | foreach {
	New-ADUser $PSItem.DisplayName -GivenName $PSItem.GivenName -Surname $PSItem.Surname -SamAccountName $PSItem.SamAccountName -Path $PSItem.OU -AccountPassword $password -Enabled:$true
}
Write-Verbose -Message "AD is populated."
###############################################################################
##								  WRITE ACL									 ##
###############################################################################
Write-Verbose -Message "Creating ACE and applying ACLs."
$aclList | foreach {
	Apply-ACL -Principal $PSItem.principal -adObject $PSItem.OU
}


###############################################################################
##								  FUNCTIONS									 ##
##									START									 ##
###############################################################################

function Get-RandomNames{
	param(
		[string]$OU = "OU=Internal,OU=Standard Users,OU=Users,OU=lab2,dc=lab,dc=sp,dc=local"
	)
	$uri = 'http://random-name-generator.info/random/?n=100&g=1&st=1'
	$html = Invoke-WebRequest -Uri $uri #Commented to decrease traffic during testing.
	$content = ($html.ParsedHtml.body.getElementsByTagName('li'))
	$outerText = $content | Select outerText
	$names = $outerText[8..106]
	$nHash = @()
	Write-Verbose -Message "99 problems, a DisplayName aint one."
	$names.outerText | foreach {
		$arrName = $PSItem.split(' ')
		$GivenName = $arrName[0]
		$Surname = $arrName[1]
		$sam = $arrName[0].substring(0,3).toLower()+$arrName[1].substring(0,3).toLower()
		$pHash = @{
			DisplayName = $PSItem
			GivenName = $GivenName
			Surname = $Surname
			SamAccountName = $sam
			OU = $OU
		}
		$obj = New-Object psobject -Property $pHash
		$nHash += $obj
	}
	return $nHash
}

function Apply-ACL {
	param(
		[string]$Principal,
		[string]$adObject
	)
	$aces = @(
		New-AccessControlEntry -Principal $principal -AceType AccessAllowed -ActiveDirectoryRights CreateChild
		New-AccessControlEntry -Principal $principal -AceType AccessAllowed -ActiveDirectoryRights ListChildren
		New-AccessControlEntry -Principal $principal -AceType AccessAllowed -ActiveDirectoryRights Delete
		New-AccessControlEntry -Principal $principal -AceType AccessAllowed -ActiveDirectoryRights ListContents
		New-AccessControlEntry -Principal $principal -AceType AccessAllowed -ActiveDirectoryRights ReadPermissions
		New-AccessControlEntry -Principal $principal -AceType AccessAllowed -ActiveDirectoryRights ReadProperty
		New-AccessControlEntry -Principal $principal -AceType AccessAllowed -ActiveDirectoryRights DeleteChild
		New-AccessControlEntry -Principal $principal -AceType AccessAllowed -ActiveDirectoryRights ChangePermissions
		New-AccessControlEntry -Principal $principal -AceType AccessAllowed -ActiveDirectoryRights WriteProperty
		New-AccessControlEntry -Principal $principal -AceType AccessAllowed -ActiveDirectoryRights ExtendedRight		
	)
	try{
		$adObject | Add-AccessControlEntry -AceObject $aces -Force
	}
	catch {
		Write-Host $PSItem.Exception.Message -ForegroundColor Red
	}
}

###############################################################################
##								  FUNCTIONS									 ##
##									 END									 ##
###############################################################################