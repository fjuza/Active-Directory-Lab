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