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
    Run Automation on all tasks
.EXAMPLE
    .\Index.ps1 -Test
    Run automation on all tasks without writing files or sending messages
.EXAMPLE
    .\Index.ps1 -Test -Name '115.115'
    Run automation on task "115.115" without writing files or sending messages
.EXAMPLE
    .\Index.ps1 -Clean
    Delete log files for all tasks
.EXAMPLE
    .\Index.ps1 -Clean -Name '115.115'
    Delete log files for task "115.115"
#>
param (
    [Parameter(
        ParameterSetName = 'Automation',
        HelpMessage = 'Run script in Automation mode'
    )]
    [switch]
    $Automation = $false,

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
        ParameterSetName = 'Test',
        HelpMessage = 'The name of the task to be tested. Leave blank to test all tasks'
    )]
    [Parameter(
        ParameterSetName = 'Clean',
        HelpMessage = 'The name of the task to be cleaned. Leave blank to clean all tasks'
    )]
    [ArgumentCompleter({ (Get-ChildItem -Path ($args[4].Path ?? (Join-Path -Path $PSScriptRoot -ChildPath 'tasks')) -Include 'Task.ps1' -Recurse -File).Directory.Name | Select-String -Pattern "^$([regex]::Escape($args[2])).*" -Raw })]
    [string[]]
    $Name = @(),

    [Parameter(
        HelpMessage = 'The path containing tasks'
    )]
    [string]
    $Path = (Join-Path -Path $PSScriptRoot -ChildPath 'tasks')
)

# Install required modules
@('powershell-yaml', 'PowerHTML') | ForEach-Object -Process {
    if (-not (Get-Module -Name $_ -ListAvailable)) {
        Write-Host -Object "Panda: Installing $_"
        Install-Module -Name $_ -Scope CurrentUser -Force
        if (-not (Get-Module -Name $_ -ListAvailable)) {
            throw "Panda: Failed to install $_"
        }
        Write-Host -Object "Panda: $_ has been installed"
    }
}

# Import config
Join-Path -Path $PSScriptRoot -ChildPath 'Config.psm1' | Import-Module -Force

$PSDefaultParameterValues = @{
    'Invoke-WebRequest:TimeoutSec'        = 500
    'Invoke-WebRequest:MaximumRetryCount' = 5
    'Invoke-WebRequest:RetryIntervalSec'  = 5
    'Invoke-RestMethod:TimeoutSec'        = 500
    'Invoke-RestMethod:MaximumRetryCount' = 5
    'Invoke-RestMethod:RetryIntervalSec'  = 5
}

# Import modules
Join-Path -Path $PSScriptRoot -ChildPath 'modules' | Get-ChildItem -Include '*.psm1' -Recurse -File | Import-Module -Force

# Continue on error
$ErrorActionPreference = 'Continue'
# Hide progress bar for Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

function Read-Yaml {
    param (
        [parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileInfo]
        $Path
    )

    process {
        $Object = Get-Content -Path $Path | ConvertFrom-Yaml -Ordered
        # Change the kind of the DateTime object inside the PSObject to Utc
        $Object.GetEnumerator().Where({ $_.Value -is [System.DateTime] }).ForEach({ $Object[$_.Name] = $_.Value.ToUniversalTime() })
        return $Object
    }
}

filter Invoke-ScriptBlock {
    param (
        [scriptblock]
        $ScriptBlock
    )

    Invoke-Command -ScriptBlock $ScriptBlock -NoNewScope | Out-Null

    return $_
}

# Probe tasks from specified path
filter Get-Tasks {
    $TaskPaths = (Get-ChildItem -Path "${_}/*/Task.ps1" -File).DirectoryName
    if ($TaskPaths.Length -eq 0) {
        Write-Error -Message "No tasks found in ${_}" -CategoryActivity 'Panda'
    }

    return $TaskPaths
}

# Initialize task session, and then import the task and its state from files
filter Initialize-Task {
    $Session = [pscustomobject]@{
        Name               = Split-Path -Path $_ -Leaf
        Path               = $_
        Config             = $null
        Ping               = $null
        Pong               = $null
        Status             = $null
        LastState          = $null
        CurrentState       = $null
        Template           = $DefaultTemplate
        ComparedProperties = $DefaultComparedProperties
    }

    # Import task
    try {
        Add-Member -NotePropertyMembers (& (Join-Path -Path $Session.Path -ChildPath 'Task.ps1')) -InputObject $Session -Force
    }
    catch {
        Write-Error -ErrorRecord $_ -CategoryActivity 'Panda'
        return
    }

    # Validate task
    if (-not ($Session -and $Session.Config -and $Session.Ping)) {
        Write-Error -Message 'Invalid task' -CategoryActivity $Session.Name
        return
    }

    # Skip task on demand
    if ($Session.Config.Skip -eq $true) {
        Write-Host -Object "$($Session.Name): Skipped" -ForegroundColor DarkGray
        return
    }

    # Import last state
    $StateFilePath = Join-Path -Path $Session.Path -ChildPath 'State.yaml'
    if (Test-Path -Path $StateFilePath) {
        try {
            $Session.LastState = Read-Yaml -Path $StateFilePath
        }
        catch {
            Write-Error -ErrorRecord $_ -CategoryActivity $Session.Name
            return
        }
    }
    else {
        $Session.Status = 'New'
        Write-Host -Object "$($Session.Name): New task" -ForegroundColor Yellow
    }

    return $Session
}

# Invoke the first scriptblock of the task to fetch required data
filter Invoke-Ping {
    # Avoid conflicts with catch
    $Session = $_

    Write-Host -Object "$($Session.Name): Ping!"
    try {
        $Session.CurrentState = Invoke-Command -ScriptBlock $Session.Ping
    }
    catch {
        Write-Error -ErrorRecord $_ -CategoryActivity $Session.Name
        return
    }

    return $Session
}

# Compare current state with last state
filter Compare-State {
    # If last state exists, compare states
    if ($_.LastState) {
        $Changes = Compare-Object -ReferenceObject ([pscustomobject]$_.LastState) -DifferenceObject ([pscustomobject]$_.CurrentState) -Property $_.ComparedProperties
        # If the state is changed, mark the task as "Changed"
        if ($Changes.Length -gt 0) {
            Write-Host -Object "$($_.Name): Something changed" -ForegroundColor Green
            $_.Status = 'Changed'
            return $_
        }
        # If the state is not changed, do nothing
        else {
            Write-Host -Object "$($_.Name): Nothing changed"
            return $_
        }
    }

    return $_
}

# Invoke the second scriptblock of the task to fetch necessary data
filter Invoke-Pong {
    # Avoid conflicts with catch
    $Session = $_

    if ($Session.Pong) {
        Write-Host -Object "$($Session.Name): Pong!"
        try {
            Invoke-Command -ScriptBlock $Session.Pong -ArgumentList $Session.CurrentState
        }
        catch {
            Write-Error -ErrorRecord $_ -CategoryActivity $Session.Name
            return
        }
    }

    return $Session
}

# Print message using the template of the task
filter Write-Message {
    Invoke-Command -ScriptBlock $_.Template -ArgumentList $_ | Write-Host -ForegroundColor Green

    return $_
}

# Write current state to log file and state file
filter Write-CurrentState {
    # Writing current state to log file
    $LogPath = Join-Path -Path $_.Path -ChildPath "Log_$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd-HHmmss'))_$($_.CurrentState.Version).yaml"
    Write-Host -Object "$($_.Name): Writing new state to log file $LogPath" -ForegroundColor Blue
    ConvertTo-Yaml -Data $_.CurrentState -OutFile $LogPath -Force

    # Writing current state to state file
    $StatePath = Join-Path -Path $_.Path -ChildPath 'State.yaml'
    Write-Host -Object "$($_.Name): Writing new state to state file $StatePath" -ForegroundColor Blue
    ConvertTo-Yaml -Data $_.CurrentState -OutFile $StatePath -Force

    return $_
}

# Add, commit and push changes to repository
function Write-Repository {
    Write-Host -Object 'Panda: Committing changes'
    git config user.name 'github-actions[bot]'
    git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
    git pull
    git add $Path
    git commit -m "Build: Update states [$env:GITHUB_RUN_NUMBER]"
    git push
}

# Automate tasks
if ($Automation) {
    $Modified = @()

    $Path | Get-Tasks | Initialize-Task | Invoke-Ping | Compare-State | `
        Where-Object -Property 'Status' -Match -Value '(New|Changed)' | Invoke-Pong | Write-Message | Write-CurrentState | Invoke-ScriptBlock -ScriptBlock { $script:Modified += $_ } | `
        Where-Object -Property 'Status' -EQ -Value 'Changed' | Send-TelegramMessage | Out-Null

    if ($Modified.Length -gt 0) {
        Write-Host -Object "Panda: Modified tasks: $($Modified.Name -join ', ')"
        if ($env:CI) {
            Write-Repository
        }
        else {
            Write-Host -Object 'Panda: Skip committing changes'
        }
    }
}

# Test tasks
if ($Test) {
    $Modified = @()

    # If task names are specified, test these tasks only
    if ($Name.Length -gt 0) {
        $Name | ForEach-Object -Process {
            Join-Path -Path $Path -ChildPath $_ | Initialize-Task | Invoke-Ping | Compare-State | Invoke-Pong | Write-Message | Out-Null
        }
    }
    # If task names are not specified, test all tasks
    else {
        $Path | Get-Tasks | Initialize-Task | Invoke-Ping | Compare-State | `
            Where-Object -Property 'Status' -Match -Value '(New|Changed)' | Invoke-Pong | Write-Message | Invoke-ScriptBlock -ScriptBlock { $script:Modified += $_ } | Out-Null
        if ($Modified.Length -gt 0) {
            Write-Host -Object "Panda: Modified tasks: $($Modified.Name -join ', ')"
        }
    }
}

# Clean log files
if ($Clean) {
    $Removed = 0

    # If task names are specified, do cleaning for those tasks only
    if ($Name.Length -gt 0) {
        $Tasks = $Name | ForEach-Object -Process { Join-Path -Path $Path -ChildPath $_ }
    }
    # If not specified, do cleaning for all tasks
    else {
        $Tasks = $Path | Get-Tasks
    }

    $Tasks | Get-ChildItem -Include 'Log*.yaml' | Invoke-Command -ScriptBlock { ++$script:Removed } | Remove-Item -ErrorAction SilentlyContinue -Verbose

    if ($env:CI -and $Removed -gt 0) {
        Write-Repository
    }
    else {
        Write-Host -Object 'Panda: Skip committing changes'
    }
}
