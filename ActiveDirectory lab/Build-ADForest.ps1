#Installs Windows Features and configures a new ADDS Forest. Only run if you need to.

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
$safeModeAdminPassword = ConvertTo-SecureString "Fiskplask&Korvspad" -AsPlainText -Force
Install-ADDSForest -DomainName 'eval.lab.local' -InstallDNS -DomainMode Win2012R2 -ForestMode Win2012R2 -SafeModeAdministratorPassword $safeModeAdminPassword

