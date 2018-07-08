﻿# This file is part of OleViewDotNet.
# Copyright (C) James Forshaw 2018
#
# OleViewDotNet is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# OleViewDotNet is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with OleViewDotNet.  If not, see <http://www.gnu.org/licenses/>.

[OleViewDotNet.COMUtilities]::SetupCachedSymbols()

function New-CallbackProgress {
    Param(
        [parameter(Mandatory)]
        [string]$Activity,
        [switch]$NoProgress
    )

    if ($NoProgress) {
        $callback = {}
    } else {
        $callback = { Write-Progress -Activity $args[0] -Status "Processing $($args[1])" -PercentComplete $args[2] }
    }

    [OleViewDotNet.PowerShell.CallbackProgress]::new($Activity, [Action[string, string, int]]$callback)
}

<#
.SYNOPSIS
Get a COM database from the registry or a file.
.DESCRIPTION
This cmdlet loads a COM registration information database from the current registry or a file and returns an object which can be inspected or passed to other methods.
.PARAMETER LoadMode
Specify what to load from the registry.
.PARAMETER User
Specify a user to load when loading user-specific COM registration information.
.PARAMETER Path
Specify a path to load a saved COM database.
.PARAMETER NoProgress
Don't show progress for load.
.INPUTS
None
.OUTPUTS
OleViewDotNet.COMRegistry
.EXAMPLE
Get-ComDatabase
Load a default, merged COM database.
.EXAMPLE
Get-ComDatabase -LoadMode UserOnly
Load a user-only database for the current user.
.EXAMPLE
Get-ComDatabase -User S-1-5-X-Y-Z
Load a merged COM database including user-only information from the user SID.
#>
function Get-ComDatabase {
    [CmdletBinding(DefaultParameterSetName = "FromRegistry")]
    Param(
        [Parameter(ParameterSetName = "FromRegistry")]
        [OleViewDotNet.COMRegistryMode]$LoadMode = "Merged",
        [Parameter(ParameterSetName = "FromRegistry")]
        [NtApiDotNet.Sid]$User,
        [Parameter(Mandatory, ParameterSetName = "FromFile", Position = 0)]
        [string]$Path,
        [switch]$NoProgress
    )
    $callback = New-CallbackProgress -Activity "Loading COM Registry" -NoProgress:$NoProgress

    switch($PSCmdlet.ParameterSetName) {
        "FromRegistry" {
            [OleViewDotNet.COMRegistry]::Load($LoadMode, $User, $callback)
        }
        "FromFile" {
            $Path = Resolve-Path $Path
            [OleViewDotNet.COMRegistry]::Load($Path, $callback)
        }
    }
}

<#
.SYNOPSIS
Save a COM database to a file.
.DESCRIPTION
This cmdlet saves a COM registration database to a file.
.PARAMETER Path
The path to save the database to.
.PARAMETER Database
The database to save.
.PARAMETER NoProgress
Don't show progress for save.
.INPUTS
None
.OUTPUTS
None
.EXAMPLE
Set-ComRegistry -Database $db -Path output.db
Save a database to the file output.db
#>
function Set-ComDatabase {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [OleViewDotNet.COMRegistry]$Database,
        [Parameter(Mandatory, Position = 1)]
        [string]$Path,
        [switch]$NoProgress
    )
    $callback = New-CallbackProgress -Activity "Saving COM Registry" -NoProgress:$NoProgress
    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $Database.Save($Path, $callback)
}

<#
.SYNOPSIS
Compares two COM databases and returns the difference.
.DESCRIPTION
The cmdlet compares two COM database, generates the difference and returns a new database with only the differences.
.PARAMETER Left
The database to the left of the comparison.
.PARAMETER Right
The database to the right of the comparison.
.PARAMETER DiffMode
Specify which database information to preserve in the diff, choice between left (default) or right.
.PARAMETER NoProgress
Don't show progress for compare.
.INPUTS
None
.OUTPUTS
OleViewDotNet.COMRegistry
.EXAMPLE
Compare-ComRegistry -Left $db1 -Right $db2
Compare two databases, returning the differences in the left database.
.EXAMPLE
Compare-ComRegistry -Left $db1 -Right $db2 -DiffMode RightOnly
Compare two databases, returning the differences in the right database.
#>
function Compare-ComDatabase {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [OleViewDotNet.COMRegistry]$Left,
        [Parameter(Mandatory, Position = 1)]
        [OleViewDotNet.COMRegistry]$Right,
        [OleViewDotNet.COMRegistryDiffMode]$DiffMode = "LeftOnly",
        [switch]$NoProgresss
    )
    $callback = New-CallbackProgress -Activity "Comparing COM Registries" -NoProgress:$NoProgress
    [OleViewDotNet.COMRegistry]::Diff($Left, $Right, $DiffMode, $callback)
}

function Where-HasComServer {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [OleViewDotNet.COMCLSIDEntry]$ClassEntry,
        [string]$ServerName,
        [OleViewDotNet.COMServerType]$ServerType
    )

    PROCESS {
        $write_to_output = $false
        if ($ServerType -eq "UnknownServer") {
            foreach($server in $ClassEntry.Servers.Values) {
                if ($server.Server -match $ServerName) {
                    $write_to_output = $true
                    break
                }
            }
        } else {
            $write_to_output = $ClassEntry.Servers.ContainsKey($ServerType) -and $ClassEntry.Servers[$ServerType].Server -match $ServerName
        }

        if ($write_to_output) {
            Write-Output $ClassEntry
        }
    }
}

<#
.SYNOPSIS
Get COM classes from a database.
.DESCRIPTION
This cmdlet gets COM classes from the database based on a set of criteria. The default is to return all registered classes.
.PARAMETER Database
The database to use.
.PARAMETER Clsid
Specify a CLSID to lookup.
.PARAMETER Name
Specify a name to match against the class name.
.PARAMETER ServerName
Specify a server name to match against.
.PARAMETER ServerType
Specify a type of server to match against. If specified as UnknownServer will search all servers.
.INPUTS
None
.OUTPUTS
OleViewDotNet.COMCLSIDEntry
.EXAMPLE
Get-ComClass -Database $db
Get all COM classes from a database.
.EXAMPLE
Get-ComClass -Database $db -Clsid "ffe1df5f-9f06-46d3-af27-f1fc10d63892"
Get a COM class with a specified CLSID.
.EXAMPLE
Get-ComClass -Database $db -Name "TestClass"
Get COM classes which contain TestClass in their name.
.EXAMPLE
Get-ComClass -Database $db -ServerName "obj.ocx"
Get COM classes which are implemented in a server containing the string "obj.ocx"
.EXAMPLE
Get-ComClass -Database $db -ServerType InProcServer32
Get COM classes which are registered with an in-process server.
.EXAMPLE
Get-ComClass -Database $db -Iid "00000001-0000-0000-C000-000000000046"
Get COM class registered as an interface proxy.
.EXAMPLE
Get-ComClass -Database $db -ProgId htafile
Get COM class from a Prog ID.
#>
function Get-ComClass {
    [CmdletBinding(DefaultParameterSetName = "All")]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [OleViewDotNet.COMRegistry]$Database,
        [Parameter(Mandatory, ParameterSetName = "FromClsid")]
        [Guid]$Clsid,
        [Parameter(Mandatory, ParameterSetName = "FromName")]
        [string]$Name,
        [Parameter(ParameterSetName = "FromServer")]
        [string]$ServerName = "",
        [Parameter(ParameterSetName = "FromServer")]
        [OleViewDotNet.COMServerType]$ServerType = "UnknownServer",
        [Parameter(Mandatory, ParameterSetName = "FromIid")]
        [Guid]$Iid,
        [Parameter(Mandatory, ParameterSetName = "FromProgId")]
        [string]$ProgId
    )
    switch($PSCmdlet.ParameterSetName) {
        "All" {
            Write-Output $Database.Clsids.Values
        }
        "FromClsid" {
            Write-Output $Database.Clsids[$Clsid]
        }
        "FromName" {
            Get-ComClass $Database | ? Name -Match $Name | Write-Output
        }
        "FromServer" {
            Get-ComClass $Database | Where-HasComServer -ServerName $ServerName -ServerType $ServerType | Write-Output
        }
        "FromIid" {
            Write-Output $Database.MapIidToInterface($Iid).ProxyClassEntry
        }
        "FromProgId" {
            Write-Output $Database.MapProgIdToClsid($ProgId)
        }
    }
}

<#
.SYNOPSIS
Get COM process information.
.DESCRIPTION
This cmdlet opens a specified set of processes and extracts the COM information from them. For this to work you need symbol support.
.PARAMETER Database
The database to use to lookup information.
.PARAMETER Process
Specify a list of process objects to parse. You can get these from Get-Process cmdlet.
.PARAMETER DbgHelpPath
Specify location of DBGHELP.DLL file. For remote symbol support use one from Debugging Tools for Windows.
.PARAMETER SymbolPath
Specify the location of symbols for the resolver.
.PARAMETER ParseStubMethods
Specify to parse the method parameter information on a process stub.
.PARAMETER ResolveMethodNames
Specify to try and resolve method names for interfaces.
.PARAMETER ParseRegisteredClasses
Specify to parse classes registered by the process.
.PARAMETER NoProgress
Don't show progress for process parsing.
.INPUTS
None
.OUTPUTS
OleViewDotNet.COMProcessEntry
.EXAMPLE
Get-ComProcess -Database $db
Get all COM processes.
.EXAMPLE
Get-Process notepad | Get-ComProcess -Database $db
Get COM process from a list of processes.
#>
function Get-ComProcess {
    [CmdletBinding(DefaultParameterSetName = "All")]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [OleViewDotNet.COMRegistry]$Database,
        [string]$DbgHelpPath = "dbghelp.dll",
        [string]$SymbolPath = "srv*https://msdl.microsoft.com/download/symbols",
        [switch]$ParseStubMethods,
        [switch]$ResolveMethodNames,
        [switch]$ParseRegisteredClasses,
        [parameter(Mandatory, ValueFromPipeline, ParameterSetName = "FromProcess")]
        [System.Diagnostics.Process[]]$Process,
        [switch]$NoProgress
    )

    BEGIN {
        if ($DbgHelpPath -eq "") {
            $DbgHelpPath = "dbghelp.dll"
        }
        if ($SymbolPath -eq "") {
            $SymbolPath = $env:_NT_SYMBOL_PATH
            if ($SymbolPath -eq "") {
                $SymbolPath = 'srv*https://msdl.microsoft.com/download/symbols'
            }
        }
        $procs = @()
    }

    PROCESS {
        switch($PSCmdlet.ParameterSetName) {
            "All" {
                $procs = Get-Process
            }
            "FromProcess" {
                $procs += $Process
            }
        }
    }

    END {
        $callback = New-CallbackProgress -Activity "Parsing COM Processes" -NoProgress:$NoProgress
        $config = [OleViewDotNet.COMProcessParserConfig]::new($DbgHelpPath, $SymbolPath, `
                    $ParseStubMethods, $ResolveMethodNames, $ParseRegisteredClasses)
        [OleViewDotNet.COMProcessParser]::GetProcesses([System.Diagnostics.Process[]]$procs, $config, $callback, $Database) | Write-Output
    }
}

<#
.SYNOPSIS
Start a log of COM activations in the current process.
.DESCRIPTION
This cmdlet starts a COM activation log for the current process. It will write out all 
COM classes created until Stop-ComActivationLog is called.
.PARAMETER Database
Optional database to lookup names for activated objects.
.PARAMETER Path
Specify a path for the log file.
.PARAMETER Append
If specified then new entries will be appended to the log rather than replacing the log file.
.INPUTS
None
.OUTPUTS
None
.EXAMPLE
Start-ComActivationLog activations.log
Start COM activation log to activations.log.
.EXAMPLE
Start-ComActivationLog activations.log -Database $db
Start COM activation log to activations.log with a database for name lookup.
.EXAMPLE
Start-ComActivationLog activations.log -Append
Start COM activation log to activations.log appending new entries to the end of the file.
#>
function Start-ComActivationLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,
        [switch]$Append,
        [OleViewDotNet.COMRegistry]$Database
    )

    $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    [OleViewDotNet.PowerShell.LoggingActivationFilter]::Instance.Start($Path, $Append, $Database)
}

<#
.SYNOPSIS
Stop the log of COM activations in the current process.
.DESCRIPTION
This cmdlet stops a COM activation log for the current process.
.INPUTS
None
.OUTPUTS
None
.EXAMPLE
Stop-ComActivationLog
Stop COM activation log.
#>
function Stop-ComActivationLog {
    [OleViewDotNet.PowerShell.LoggingActivationFilter]::Instance.Stop()
}

<#
.SYNOPSIS
Get COM AppIDs from a database.
.DESCRIPTION
This cmdlet gets COM AppIDs from the database based on a set of criteria. The default is to return all registered AppIds.
.PARAMETER Database
The database to use.
.PARAMETER AppId
Specify a AppID to lookup.
.PARAMETER Name
Specify a name to match against the AppId name.
.PARAMETER ServiceName
Specify a service name to match against.
.PARAMETER IsService
Specify a returns AppIDs implemented by services.
.INPUTS
None
.OUTPUTS
OleViewDotNet.COMAppIDEntry
.EXAMPLE
Get-ComAppId -Database $db
Get all COM AppIDs from a database.
#>
function Get-ComAppId {
    [CmdletBinding(DefaultParameterSetName = "All")]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [OleViewDotNet.COMRegistry]$Database,
        [Parameter(Mandatory, ParameterSetName = "FromAppId")]
        [Guid]$AppId,
        [Parameter(Mandatory, ParameterSetName = "FromName")]
        [string]$Name,
        [Parameter(ParameterSetName = "FromServiceName")]
        [string]$ServiceName = "",
        [Parameter(ParameterSetName = "FromIsService")]
        [switch]$IsService
    )
    switch($PSCmdlet.ParameterSetName) {
        "All" {
            Write-Output $Database.AppIDs.Values
        }
        "FromAppId" {
            Write-Output $Database.AppIDs[$AppId]
        }
        "FromName" {
            Get-ComAppId $Database | ? Name -Match $Name | Write-Output
        }
        "FromServiceName" {
            Get-ComAppId $Database | ? ServiceName -Match $ServiceName | Write-Output
        }
        "FromIsService" {
            Get-ComAppId $Database | ? IsService | Write-Output
        }
    }
}