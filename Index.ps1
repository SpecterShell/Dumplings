<#
.SYNOPSIS
    Panda Web Monitor Script
.DESCRIPTION
    The intent of the script is to run the scripts of the tasks inside the specified folder,
    including fetching and handling the data from websites,
    comparing current state with last state,
    and writing current state to repository and sending messages if something is changed.
.EXAMPLE
    .\Index.ps1 -Automation
    Start Automation
.EXAMPLE
    .\Index.ps1 -Test
    Run automation on all tasks without writing files or sending messages
.EXAMPLE
    .\Index.ps1 -Test -Name '115.115'
    Run automation on "115.115" task without writing files or sending messages
.EXAMPLE
    .\Index.ps1 -Clean -Name '115.115'
    Delete log files for "115.115" task
.EXAMPLE
    .\Index.ps1 -Clean -IncludeStates
    Delete log files and state files for all tasks
#>
param (
    [Parameter(
        ParameterSetName = 'Automation',
        HelpMessage = 'Run script in Automation mode'
    )]
    [switch]
    $Automation = $false,

    [Parameter(
        ParameterSetName = 'Automation',
        HelpMessage = 'Do not add, commit and push to remote repository'
    )]
    [switch]
    $NoPush = $false,

    [Parameter(
        ParameterSetName = 'Test',
        HelpMessage = 'Run script in Test mode'
    )]
    [switch]
    $Test = $false,

    [Parameter(
        ParameterSetName = 'Clean',
        HelpMessage = 'Run script in Clean mode'
    )]
    [switch]
    $Clean = $false,

    [Parameter(
        ParameterSetName = 'Clean',
        HelpMessage = 'Also clean state files'
    )]
    [switch]
    $IncludeStates = $false,

    [Parameter(
        ParameterSetName = 'Test',
        HelpMessage = 'The name of the task to be tested. Leave blank to test all tasks'
    )]
    [Parameter(
        ParameterSetName = 'Clean',
        HelpMessage = 'The name of the task to be cleaned. Leave blank to clean all tasks'
    )]
    [ArgumentCompleter({ (Get-ChildItem -Path $FakeBoundParameters.Path -Include 'Task.ps1' -Recurse -File).Directory.Name })]
    [string[]]
    $Name = @(),

    [Parameter(
        HelpMessage = 'The path containing tasks'
    )]
    [string]
    $Path = $(Join-Path -Path $PSScriptRoot -ChildPath 'tasks')
)

# Install required modules
@('powershell-yaml', 'PowerHTML') | ForEach-Object -Process {
    if (-not (Get-Module -Name $_ -ListAvailable)) {
        Write-Host -Object "Panda: Installing $_"
        Install-Module -Name $_ -Scope CurrentUser -Force
        if (-not (Get-Module -Name $_ -ListAvailable)) {
            throw "Panda: Unable to install $_"
        }
        Write-Host -Object "Panda: $_ has been installed"
    }
    else {
        Write-Host -Object "Panda: $_ has already been installed"
    }
}

# Import config
Join-Path -Path $PSScriptRoot -ChildPath 'Config.psm1' | Import-Module -Force
# Import helper modules
Join-Path -Path $PSScriptRoot -ChildPath 'modules' | `
    Get-ChildItem -Include '*.psm1' -Recurse -File | `
    Import-Module -Force

# Override Invoke-WebRequest and Invoke-RestMethod with custom parameters
if ($DefaultWebRequestParameters) {
    New-Alias -Name 'Invoke-WebRequest' -Value 'Invoke-CustomWebRequest' -Scope Script
    New-Alias -Name 'Invoke-RestMethod' -Value 'Invoke-CustomRestMethod' -Scope Script
}

# Continue on error
$ErrorActionPreference = 'Continue'
# Hide progress bar for Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

function Read-Yaml {
    param (
        [parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        [System.IO.FileInfo]
        $Path
    )

    process {
        $Object = [PSCustomObject](Get-Content -Path $Path | ConvertFrom-Yaml -Ordered)
        # Change the kind of the DateTime object inside the PSObject to Utc
        $Object.PSObject.Properties | `
            Where-Object -Property 'TypeNameOfValue' -EQ -Value 'System.DateTime' | `
            ForEach-Object -Process { $_.Value = $_.Value.ToUniversalTime() }
        return $Object
    }
}

# Probe tasks, and get their directories
filter Get-Tasks {
    # Avoid conflicts with catch
    $Path = $_

    $Tasks = Get-ChildItem -Path $Path -Include 'Task.ps1' -Recurse -File | Select-Object -ExpandProperty 'DirectoryName'
    if ($Tasks.Count -eq 0) {
        Write-Error -Message "No tasks found in $Path" -CategoryActivity 'Panda'
    }
    return $Tasks
}

# Initialize task
filter Import-Task {
    # Avoid conflicts with catch
    $Path = $_

    # Import task
    try {
        $Session = & (Join-Path -Path $Path -ChildPath 'Task.ps1')
    }
    catch {
        Write-Error -Message "Failed to load task in $Path`: $($_.Exception.Message)" -CategoryActivity 'Panda'
        return
    }
    # Validate task
    if (-not ($Session -and $Session.Config -and $Session.Fetch)) {
        Write-Error -Message "Invalid task in $Path" -CategoryActivity 'Panda'
        return
    }

    # Add Name for Write-Host and Write-Error
    $Name = Split-Path -Path $Path -Leaf
    Add-Member -MemberType NoteProperty -Name 'Name' -Value $Name -InputObject $Session
    # Add Path for reading state files and log files in other functions
    Add-Member -MemberType NoteProperty -Name 'Path' -Value $Path -InputObject $Session
    # Add Status for filtering tasks
    Add-Member -MemberType NoteProperty -Name 'Status' -Value 'None' -InputObject $Session
    # Add Template if not specified, for generating message
    if (-not $Session.Template) {
        Add-Member -MemberType NoteProperty -Name 'Template' -Value $DefaultTemplate -InputObject $Session
    }

    # Skip task on demand
    if ($Session.Config.Skip -eq $true) {
        Write-Host -Object "$($Name): Skipped" -ForegroundColor DarkGray
        return
    }

    return $Session
}

# Run the scriptblock of the task to get current state
filter Invoke-Task {
    # Avoid conflicts with catch
    $Session = $_

    Write-Host -Object "$($Session.Name): Fetch start"
    try {
        $State = Invoke-Command -ScriptBlock $Session.Fetch
    }
    catch {
        Write-Error -Message "Fetch failed: $($_.Exception.Message)" -CategoryActivity $Session.Name
        return
    }
    Write-Host -Object "$($Session.Name): Fetch succeed"
    Add-Member -MemberType NoteProperty -Name 'CurrentState' -Value $State -InputObject $Session
    return $Session
}

# Read the state file to get last state
filter Import-LastState {
    # Avoid conflicts with catch
    $Session = $_

    $Path = Join-Path -Path $Session.Path -ChildPath 'State.yaml'
    # If state file exists, read and load
    if (Test-Path -Path $Path) {
        try {
            $State = Read-Yaml -Path $Path
        }
        catch {
            Write-Error -Message "Failed to load last state: $($_.Exception.Message)" -CategoryActivity $Session.Name
            return
        }
        Write-Host -Object "$($Session.Name): Last State loaded"
        Add-Member -MemberType NoteProperty -Name 'LastState' -Value $State -InputObject $Session
        return $Session
    }
    # If state file doesn't exist, mark the task as "new"
    else {
        Write-Host -Object "$($Session.Name): Last state not found" -ForegroundColor Yellow
        $Session.Status = 'New'
        return $Session
    }
}

# Compare current state with last state
filter Compare-State {
    # Avoid conflicts with catch
    $Session = $_

    # If last state exists, compare states
    if ($Session.LastState) {
        # $Changes = Compare-Object -ReferenceObject $Session.LastState.PSObject.Properties -DifferenceObject $Session.CurrentState.PSObject.Properties
        $Changes = Compare-Object -ReferenceObject $Session.LastState -DifferenceObject $Session.CurrentState -Property @('Version', 'InstallerUrl')
        # If state is changed, mark the task as "Changed"
        if ($Changes.Count -gt 0) {
            Write-Host -Object "$($Session.Name): State changed" -ForegroundColor Green
            $Session.Status = 'Changed'
            return $Session
        }
        # If state is not changed, do nothing
        else {
            Write-Host -Object "$($Session.Name): State not changed"
            return $Session
        }
    }
    return $Session
}

# Write message to output using the template of the task
filter Write-Message {
    # Avoid conflicts with catch
    $Session = $_

    Invoke-Command -ScriptBlock $Session.Template -ArgumentList $Session | Write-Host -ForegroundColor Green
    return $Session
}

# Write current state to log file and state file
filter Write-CurrentState {
    # Avoid conflicts with catch
    $Session = $_

    # Writing current state to log file
    $LogPath = Join-Path -Path $Session.Path -ChildPath "Log_$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd-hhmmss'))_$($Session.CurrentState.Version).yaml"
    Write-Host -Object "$($Session.Name): Writing new state to log file $LogPath" -ForegroundColor Blue
    ConvertTo-Yaml -Data $Session.CurrentState -OutFile $LogPath -Force

    # Writing current state to state file
    $StatePath = Join-Path -Path $Session.Path -ChildPath 'State.yaml'
    Write-Host -Object "$($Session.Name): Writing new state to state file $StatePath" -ForegroundColor Blue
    ConvertTo-Yaml -Data $Session.CurrentState -OutFile $StatePath -Force

    return $Session
}

# Add, commit and push changes to repository
function Write-Repository {
    Write-Host -Object 'Panda: Pushing branches'
    git config user.name 'github-actions[bot]'
    git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
    git pull
    git add $Path
    git commit -m "Build: Update states [$env:GITHUB_RUN_NUMBER]"
    git push
}

# Automate tasks
if ($Automation) {
    $Results = $Path | Get-Tasks | Import-Task | Invoke-Task | Import-LastState | Compare-State | `
        Where-Object -Property 'Status' -Match -Value '(New|Changed)' | Write-Message | Write-CurrentState
    $Results | Where-Object -Property 'Status' -EQ -Value 'Changed' | Send-TelegramMessage | Out-Null

    # Push changes to repository
    if ($env:CI -and $Results.Count -gt 0 -and $NoPush -ne $true) {
        Write-Repository
    }
    else {
        Write-Host -Object 'Panda: Skip pushing branches'
    }
}

# Test tasks
if ($Test) {
    # If task names are specified, do test for those tasks only
    if ($Name.Count -gt 0) {
        $Name | ForEach-Object -Process {
            Join-Path -Path $Path -ChildPath $_ | Import-Task | Invoke-Task | Import-LastState | Compare-State | `
                Where-Object -Property 'Status' -Match -Value '(New|Changed)' | Write-Message | Out-Null
        }
    }
    # If not specified, do test for all tasks
    else {
        $Path | Get-Tasks | Import-Task | Invoke-Task | Import-LastState | Compare-State | `
            Where-Object -Property 'Status' -Match -Value '(New|Changed)' | Write-Message | Out-Null
    }
}

# Clean log files (and state files)
if ($Clean) {
    $Files = @()

    # If task names are specified, do cleaning for those tasks only
    if ($Name.Count -gt 0) {
        $Name | ForEach-Object -Process {
            $Files += Join-Path -Path $Path -ChildPath $_ | Get-ChildItem -Include 'Log*.yaml' -Recurse
            if ($IncludeStates) {
                $Files += Join-Path -Path $Path -ChildPath $_ | Get-ChildItem -Include 'State.yaml' -Recurse
            }
        }
    }
    # If not specified, do cleaning for all tasks
    else {
        $Files = $Path | Get-Tasks | Get-ChildItem -Include 'Log*.yaml' -Recurse
        if ($IncludeStates) {
            $Files += $Path | Get-Tasks | Get-ChildItem -Include 'State.yaml' -Recurse
        }
    }
    $Files | Remove-Item -ErrorAction SilentlyContinue -Verbose

    # Push changes to repository
    if ($env:CI -and $Files.Count -gt 0) {
        Write-Repository
    }
    else {
        Write-Host -Object 'Panda: Skip pushing branches'
    }
}
