<#
.SYNOPSIS
  Initialize WebDriver and return the object on demand
#>

$EdgeDriver = $null
$IsEdgeDriverLoaded = $false

Add-Type -Path (Join-Path $PSScriptRoot '..' 'Assets' 'WebDriver.dll' -Resolve)

function New-EdgeDriver {
  <#
  .SYNOPSIS
    Initialize an Edge Driver instance
  .PARAMETER Headless
    Run Edge Driver in headless mode, with no windows shown
  #>
  param (
    [parameter(
      HelpMessage = 'Run Edge Driver in headless mode, with no windows shown'
    )]
    [switch]
    $Headless
  )

  $EdgeOptions = [OpenQA.Selenium.Edge.EdgeOptions]::new()
  # Disable images downloading to speed up page loading
  $EdgeOptions.AddUserProfilePreference('profile.managed_default_content_settings.images', 2)
  if ($Headless) {
    $EdgeOptions.AddArgument('--headless')
  }
  if ($Env:EDGEWEBDRIVER) {
    # https://github.com/actions/runner-images/blob/main/images/win/Windows2022-Readme.md
    $Script:EdgeDriver = [OpenQA.Selenium.Edge.EdgeDriver]::new($Env:EDGEWEBDRIVER, $EdgeOptions)
  } else {
    $Script:EdgeDriver = [OpenQA.Selenium.Edge.EdgeDriver]::new($EdgeOptions)
  }
  $Script:EdgeDriver.Manage().Window.Size = [System.Drawing.Size]::new(1920, 1080)
  $Script:IsEdgeDriverLoaded = $true
}

function Get-EdgeDriver {
  <#
  .SYNOPSIS
    Return Edge Driver instance
  .PARAMETER Headless
    Run Edge Driver in headless mode, with no windows shown
  #>
  [OutputType([OpenQA.Selenium.Edge.EdgeDriver])]
  param ()

  if (-not $Script:IsEdgeDriverLoaded) {
    New-EdgeDriver
  }
  return $Script:EdgeDriver
}

function Stop-EdgeDriver {
  <#
  .SYNOPSIS
    Stop Edge Driver instance
  #>

  if ($Script:IsEdgeDriverLoaded) {
    $Script:EdgeDriver.Quit()
    $Script:IsEdgeDriverLoaded = $false
  }
}

Export-ModuleMember -Function New-EdgeDriver, Get-EdgeDriver, Stop-EdgeDriver
