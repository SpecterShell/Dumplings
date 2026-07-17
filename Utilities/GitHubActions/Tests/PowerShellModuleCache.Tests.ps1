BeforeAll {
  $Script:ModulePath = Join-Path $PSScriptRoot '..' 'PowerShellModuleCache.psm1'
  Import-Module $Script:ModulePath -Force

  function Write-TestPowerShellModule {
    param (
      [Parameter(Mandatory)][string]$Root,
      [Parameter(Mandatory)][string]$Name,
      [Parameter(Mandatory)][string]$Version,
      [Parameter(Mandatory)][string]$Command
    )

    $ModuleDirectory = [System.IO.Path]::Combine($Root, $Name, $Version)
    $null = New-Item -Path $ModuleDirectory -ItemType Directory -Force
    Set-Content -LiteralPath (Join-Path $ModuleDirectory "${Name}.psm1") -Value "function ${Command} { '${Name}' }; Export-ModuleMember -Function ${Command}"
    New-ModuleManifest -Path (Join-Path $ModuleDirectory "${Name}.psd1") -RootModule "${Name}.psm1" -ModuleVersion $Version -FunctionsToExport $Command
  }
}

Describe 'GitHub Actions PowerShell module cache' {
  BeforeEach {
    $CaseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $Script:CachePath = Join-Path $CaseRoot 'Modules'
    $Script:EnvironmentPath = Join-Path $CaseRoot 'github-env'
    $Script:LockPath = Join-Path $CaseRoot 'PowerShellModules.psd1'
    $null = New-Item -Path $CaseRoot -ItemType Directory
    Set-Content -LiteralPath $Script:LockPath -Value @'
@{
  Modules = @(
    @{
      Name = 'TestCacheModule'
      Version = '1.2.3'
      RequiredCommands = @('Get-TestCacheValue')
    }
  )
}
'@
  }

  AfterEach {
    Remove-Module -Name TestCacheModule -Force -ErrorAction SilentlyContinue
  }

  It 'uses a valid cache hit without accessing PowerShell Gallery' {
    Write-TestPowerShellModule -Root $Script:CachePath -Name TestCacheModule -Version 1.2.3 -Command Get-TestCacheValue
    Mock -ModuleName PowerShellModuleCache Save-Module { throw 'PowerShell Gallery must not be accessed' }

    Initialize-DumplingsPowerShellModuleCache -LockPath $Script:LockPath -CachePath $Script:CachePath -CacheHit $true -GitHubEnvironmentPath $Script:EnvironmentPath

    Should -Invoke -ModuleName PowerShellModuleCache Save-Module -Times 0
    Get-TestCacheValue | Should -BeExactly 'TestCacheModule'
    Get-Content -LiteralPath $Script:EnvironmentPath -Raw | Should -Match '^PSModulePath='
  }

  It 'downloads the exact locked version after a cache miss' {
    Mock -ModuleName PowerShellModuleCache Save-Module {
      param ($Name, $RequiredVersion, $Repository, $Path)

      $SavedName = [string]$Name[0]
      $SavedVersion = $RequiredVersion.ToString()
      $SavedName | Should -BeExactly 'TestCacheModule'
      $SavedVersion | Should -BeExactly '1.2.3'
      $Repository | Should -BeExactly 'PSGallery'

      $ModuleDirectory = [System.IO.Path]::Combine($Path, $SavedName, $SavedVersion)
      $null = New-Item -Path $ModuleDirectory -ItemType Directory -Force
      Set-Content -LiteralPath (Join-Path $ModuleDirectory "${SavedName}.psm1") -Value "function Get-TestCacheValue { '${SavedName}' }; Export-ModuleMember -Function Get-TestCacheValue"
      New-ModuleManifest -Path (Join-Path $ModuleDirectory "${SavedName}.psd1") -RootModule "${SavedName}.psm1" -ModuleVersion $SavedVersion -FunctionsToExport Get-TestCacheValue
    }

    Initialize-DumplingsPowerShellModuleCache -LockPath $Script:LockPath -CachePath $Script:CachePath -CacheHit $false

    Should -Invoke -ModuleName PowerShellModuleCache Save-Module -Times 1
    Get-TestCacheValue | Should -BeExactly 'TestCacheModule'
  }

  It 'rejects an incomplete cache hit without falling back to PowerShell Gallery' {
    Mock -ModuleName PowerShellModuleCache Save-Module { throw 'PowerShell Gallery must not be accessed' }

    { Initialize-DumplingsPowerShellModuleCache -LockPath $Script:LockPath -CachePath $Script:CachePath -CacheHit $true } |
      Should -Throw '*cached PowerShell module manifest does not exist*'

    Should -Invoke -ModuleName PowerShellModuleCache Save-Module -Times 0
  }
}
