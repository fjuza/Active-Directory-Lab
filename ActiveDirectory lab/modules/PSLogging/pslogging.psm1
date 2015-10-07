#severity
Set-Variable -Name MSGTYPE_INFO -Value 0 -Option ReadOnly
Set-Variable -Name MSGTYPE_WARN -Value 1 -Option ReadOnly
Set-Variable -Name MSGTYPE_ERR -Value 2 -Option ReadOnly
#Severity Description
Set-Variable -Name SEVERITY_DESC -Value 'PS-Info', 'PS-Warn', 'PS-Error' -Option Constant


#Initialize configurable settings for logging
#These values will be used as default unless overwritten by calling
[int]$logLevel = $MSGTYPE_INFO

#Default, use module name and location to store logs.
$SCRIPT:LogFileName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path.ToString())
$SCRIPT:ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path.ToString())
$SCRIPT:LogFileName += '.log'
[int]$SCRIPT:NumOfArchives = 10

function Write-Log {
<#
.SYNPOSIS
    Write a message to the log file.
.DESCRIPTION
    Logs a message to the logfile if the severity is higher than or equal to $logLevel
    Default severity level is information
.PARAMETER scriptName
    Name of the script/program to be used with logged messages.
    Use the $MSGTYPE_XXXX constants.
.PARAMETER logName
    Full Name of the file where messages will be written
.PARAMETER severity
    The severity of the message. Can be Information, Warning or Error
    Use the $MSGTYPE_XXXX constants.
.PARAMETER message
    A string to be printed to the log.

.EXAMPLE
    Write-Log $MSGTYPE_ERROR "You done fucked up now!"
#>

    param(
        [string]$scriptName = $SCRIPT:ScriptName,
        [string]$logName = $SCRIPT:LogFileName,
        [Parameter(Mandatory=$true)]
        [int][ValidateScript({$MSGTYPE_INFO,$MSGTYPE_WARN, $MSGTYPE_ERR -contains $_})]$severity,
        [Parameter(Mandatory=$true)]
        [string]$message
    )
    try {
        if($severity -ge $logLevel){
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $callerName = (Get-PSCallStack)[2].InvocationInfo.MyCommand.Name
            $output = "$timestamp`t`[$($SEVERITY_DESC[$severity])`]: ($callerName)`t$message"

            Write-Output $output >> $logName

            switch($severity){
                $MSGTYPE_INFO {Write-Host $output -ForegroundColor Magenta; break}
                $MSGTYPE_WARN {Write-Host $output -ForegroundColor Yellow; break}
                $MSGTYPE_ERR {Write-Host $output -ForegroundColor Red; break}
            }
        }
    } catch {
        $ex = $_.Exception
        $excMsg = $ex.Message.ToString()
        Write-Host "[Write-Log]: "$excMsg -ForegroundColor Red

        while($ex.InnerException){
            $ex = $ex.InnerException
            $excMsg = $ex.InnerException.Message.ToString()
            Write-Host "`t"$ex.InnerException.Message -ForegroundColor Red
        }
    }
}

function Add-BackSlashToPath($path){
<#
.SYNOPSIS
    Add a backslash to any given path if it is missing.
.DESCRIPTION
    Powershell usually returns path without a backslash.
    This fixes that.
.EXAMPLE
    Add-BackSlashToPath -Path "C:\Test-PS-1"
    C:\Test-PS-1\
.EXAMPLE
    Add-BackSlashToPath -Path C:\Windows\System32\
    C:\Windows\System32\
.EXAMPLE
    Add-BackslashToPath -Path \\server1\C$\Windows\System32
    \\server1\C$\Windows\System32\
#>
    if(Test-Path -path $path -IsValid) {
        if($path -match "\\$"){
            $strPath = $path
        } else {
            $strPath = $path + "\"
        }
    } else {
        $strPath = ".\"
    }
    $strPath
}

function Get-ScriptInfo{
<#
    .SYNOPSIS
       Get script information and return script base name and path
    .DESCRIPTION
       Get a script name and returns script base name and path.
       The function does not take any parameters.
    .EXAMPLE
       $scriptInfo = Get-ScriptInfo; $ScriptInfo.Name; $ScriptInfo.Path

       Parent
       c:\powershell\utils
#> 
    try{
        $scriptPath = $MyInvocation.ScriptName.ToString()
        Write-Debug "script path: $scriptPath"
        $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
        $scriptDir = [System.IO.Path]::GetDirectoryName($scriptPath)
        if($scriptDir -eq ""){
            $currPath = Resolve-Path "."
            $scriptDir = $currPath.Path.ToString()
        }
        return (@{Name = $scriptName; Path = $scriptDir})
    } catch {
        $ex = $_.Exception
        $excMsg = $ex.Message.ToString()
        Write-Host "[Get-ScriptInfo]: $($excMsg)" -ForegroundColor Red
        while($ex.InnerException){
            $ex = $ex.InnerException
            $excMsg = $ex.InnerException.Message.ToString()
            Write-Host "[Get-ScriptInfo]: $($excMsg)" -ForegroundColor Red
        }
    } finally {
        $SCRIPT:ScriptName = $scriptName
        $SCRIPT:LogFileName = $scriptDir + '\' + $scriptName + '.log'
    }
}

function Switch-LogFile {
<#
.SYNPSIS
    Achive the log files for the script
.DESCRIPTION
    The number of archive files we maintain is determined by the numArch parameter.
    Log file name is ProgramName.log
.EXAMPLE
    Switch-LogFile -Name "C:\Test\First.log" -Arch 10
#>
    Param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][int]$Arch = $SCRIPT:NumOfArchives
    )
    try{
        $pathToFile = [System.IO.Path]::GetDirectoryName($Name)

        if( !(Test-Path -Path "$pathToFile")){
            pathToFile = New-Item -Path "$pathToFile" -type directory
        }
        $pathToFile = Resolve-Path $pathToFile
        $pathToFile = Add-BackSlashToPath $pathToFile.Path.ToString()
        $isValidPath = Test-Path -Path "$pathToFile" -IsValid
        Write-Debug $isValidPath

        if($isValiedPath){
            $gciLogPath = $pathToFile + "*"
            $Name = $Name.Substring($Name.LastIndexOf('\')+1)
            $logName = $Name.Substring(0,$Name.Length - 4)
            Write-Debug $gciLogPath

            $defaultLogExists = Test-Path -Path $gciLogPath -Include $Name

            if($defaultLogExists){
                $dirContent = Get-ChildItem $gciLogPath -Filter "$logName*.log" | Sort-Object -Property Name -Descending | Select-Object Name
                foreach($filename in $dirContent){
                    if($fileName.Name -match "^*`.\d{3}"){
                        $matchVal = $Matches[0]
                        if( ( [int]$matchVal.Substring(1, $matchVal.Length-1) ) -eq ($Arch) ) {
                            Write-Debug "Deleting log file: $($filename.Name)"
                            $fileToDel = $pathToFile + "$($filename.Name)"
                            Remove-Item -LiteralPath $fileToDel
                        } else {
                            $logNum = $matchVal.Substring(1,$matchVal.Length-1)
                            $logNum = "{0:D3}" -f (([int]$logNum) + 1)
                            $newName = "$logName.$logNum.log"
                            $fullPath = $pathToFile + "$($filename.Name)"
                            Rename-Item -Path $fullPath -NewName $newName
                        }
                    }
                }
                $fullPath = $pathToFile + $Name
                Write-Debug $fullPath
                Rename-Item -Path $fullPath -NewName "$logName.001.log"
                $newLogFile = New-Item -Path $fullPath -ItemType File -Force
            } else {
                $fullPath = $pathToFile+$Name
                $newLogFile = New-Item -Path $fullPath -ItemType File -Force
            }
        }
    } catch {
        Write-Error $_
    }
}

function New-LogFile {
<#
.SYNOPSIS
    Instansiate new empty object and adds properties and methods for Log.
.DESCRIPTION
    This function Instanstiate and adds properties and methods to support Logging. This is done to allow calling 
    script to create it's own object with log file name specific to the script.

.PARAMETER scriptName
    Name of the script/program to be used with logged messages.
.PARAMETER logName
    Full Name of hte file where messages will be written.
.EXAMPLE
    $ScriptInfo = Get-ScriptInfo
    $logFileName = $scriptInfo.Path + '\' + $scriptInfo.Name + '.log'
    Switch-LogFile -Name $logFileName
    $hlog = New-LogFile ($scriptInfo.Name, $logFileName)
#>

    param(
        [string]$scriptName = $SCRIPT:ScriptName,
        [string]$logName = $SCRIPT:LogFileName
    )

    New-Object Object |
        Add-Member NoteProperty LogFileName $logName -PassThru |
        Add-Member NoteProperty ScriptBaseName $scriptName -PassThru |
        Add-Member scriptMethod SetLogFileName {
            param([string]$logFileName)
                $this.LogFileName = $logName 
        } -PassThru |
        Add-Member ScriptMethod GetLogFileName {
            param([string]$logFileName)
                $this.LogFileName
        } -PassThru |
        Add-Member ScriptMethod WritePSInfo {
            <#
            .SYNOPSIS
               Write entry to logfile
            #>
            param($message)
                Write-Log $this.ScriptBaseName $this.LogfileName $MSGTYPE_INFO $message
        } -PassThru |
        Add-Member ScriptMethod WritePSWarn {
            <#
            .SYNOPSIS
               Write entry to logfile
            #>
            param($message)
                Write-Log $this.ScriptBaseName $this.LogFileName $MSGTYPE_WARN $message
        } -PassThru |
        Add-Member ScriptMethod WritePSError {
            param($message)
                Write-Log $this.ScriptBaseName $this.LogFileName $MSGTYPE_ERR $message
        } -PassThru

}




































