#Build AD
$SetupADDSForest = $false
if($SetupADDSForest -eq $true{
	Add-WindowsFeature -Name ad-domain-services -IncludeManagementTools
	$password = ConvertTo-SecureString "P4$$w0rd" -AsPlainText -Force
	Install-ADDSForest -DomainName "lab.sp.local" -ForestMode Win2012r2 -DomainMode Win2012R2 -SafemodePassword $password -Force
}


$objects = Import-Csv -Path ADObjects.csv -Delimiter ';'

$objects | foreach {
	$hashObject = @(
		CanonicalName = $PSItem.CanonicalName
		CN = $PSItem.CN
		Description = $PSItem.Description
		DisplayName = $PSItem.DisplayName
		DistinguishedName = $PSItem.DistinguishedName
		instanceType = $PSItem.instanceType
		Name = $PSItem.Name
		ObjectClass = $PSItem.ObjectClass
		ProtectedFromAccidentalDeletion = $PSItem.ProtectedFromAccidentalDeletion

	)
	$objType = $PSItem.ObjectClass
	switch($objType){
		case 'organizationalUnit'{
			$OUPath="dc=lab,dc=sp,dc=local"
			New-ADOrganizationalUnit -Name $hashObject.Name -Path $OUPath
		}
		case 'user'{
			New-ADUser -Name $hashObject.Name -samaccountname ($hashObject.DisplayName).replace(" ", ".") -Path $ -Force
		}
		case 'group'{

		}
	}
}