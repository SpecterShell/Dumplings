# This module restores the exact PowerShell module versions required by GitHub Actions.

function Test-DumplingsPowerShellModuleCache {
  <#
  .SYNOPSIS
  Validates all PowerShell modules declared in a module lock file.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [System.Collections.IDictionary]$Lock,

    [Parameter(Mandatory)]
    [string]$CachePath
  )

  foreach ($Module in $Lock.Modules) {
    $ModuleName = [string]$Module.Name
    $ModuleVersion = [version]$Module.Version
    $ManifestPath = [System.IO.Path]::Combine($CachePath, $ModuleName, $ModuleVersion.ToString(), "${ModuleName}.psd1")
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
      throw "The cached PowerShell module manifest does not exist: ${ManifestPath}"
    }

    $Manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath
    if ([version]$Manifest.ModuleVersion -ne $ModuleVersion) {
      throw "The cached PowerShell module '${ModuleName}' has version '$($Manifest.ModuleVersion)' instead of '${ModuleVersion}'"
    }

    $ImportedModule = Import-Module -Name $ManifestPath -Force -PassThru -ErrorAction Stop
    foreach ($CommandName in $Module.RequiredCommands) {
      $Command = Get-Command -Name $CommandName -ErrorAction SilentlyContinue
      if (-not $Command -or $Command.Source -ne $ImportedModule.Name) {
        throw "The cached PowerShell module '${ModuleName}' does not export the required command '${CommandName}'"
      }
    }
  }
}

function Save-DumplingsPowerShellModuleCache {
  <#
  .SYNOPSIS
  Downloads the locked PowerShell module versions from PowerShell Gallery.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [System.Collections.IDictionary]$Lock,

    [Parameter(Mandatory)]
    [string]$CachePath,

    [ValidateRange(1, 10)]
    [int]$MaximumRetryCount = 3
  )

  foreach ($Module in $Lock.Modules) {
    $ModuleName = [string]$Module.Name
    $ModuleVersion = [string]$Module.Version
    $LastError = $null

    for ($Attempt = 1; $Attempt -le $MaximumRetryCount; $Attempt++) {
      try {
        Save-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Repository PSGallery -Path $CachePath -Force -AcceptLicense -ErrorAction Stop
        $LastError = $null
        break
      } catch {
        $LastError = $_
        if ($Attempt -lt $MaximumRetryCount) {
          Start-Sleep -Seconds ([Math]::Min($Attempt * 3, 10))
        }
      }
    }

    if ($LastError) {
      throw "Failed to save PowerShell module '${ModuleName}' version '${ModuleVersion}' after ${MaximumRetryCount} attempts: $($LastError.Exception.Message)"
    }
  }
}

function Initialize-DumplingsPowerShellModuleCache {
  <#
  .SYNOPSIS
  Populates or validates the module cache and exposes it to later workflow steps.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$LockPath,

    [Parameter(Mandatory)]
    [string]$CachePath,

    [Parameter(Mandatory)]
    [bool]$CacheHit,

    [string]$GitHubEnvironmentPath
  )

  $Lock = Import-PowerShellDataFile -LiteralPath $LockPath
  if (-not $Lock.Modules -or $Lock.Modules.Count -eq 0) {
    throw "The PowerShell module lock file does not contain any modules: ${LockPath}"
  }

  $ResolvedCachePath = [System.IO.Path]::GetFullPath($CachePath)
  if (-not $CacheHit) {
    $null = New-Item -Path $ResolvedCachePath -ItemType Directory -Force
    Save-DumplingsPowerShellModuleCache -Lock $Lock -CachePath $ResolvedCachePath
  }

  $ModulePaths = @($env:PSModulePath -split [System.IO.Path]::PathSeparator | Where-Object { $_ })
  if ($ResolvedCachePath -notin $ModulePaths) {
    $env:PSModulePath = $ResolvedCachePath + [System.IO.Path]::PathSeparator + $env:PSModulePath
  }

  Test-DumplingsPowerShellModuleCache -Lock $Lock -CachePath $ResolvedCachePath

  if ($GitHubEnvironmentPath) {
    "PSModulePath=$env:PSModulePath" | Add-Content -LiteralPath $GitHubEnvironmentPath -Encoding utf8
  }
}

Export-ModuleMember -Function Initialize-DumplingsPowerShellModuleCache
