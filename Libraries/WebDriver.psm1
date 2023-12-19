<#
.SYNOPSIS
  Initialize WebDriver and return the object on demand
#>

Add-Type -Path (Join-Path $PSScriptRoot '..' 'Assets' 'WebDriver.dll' -Resolve)

$EdgeDriver = $null
$IsEdgeDriverLoaded = $false

function New-EdgeDriver {
  <#
  .SYNOPSIS
    Initialize an Edge Driver instance
  .PARAMETER Headless
    Run Edge Driver in headless mode, with no window shown
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
    $Script:EdgeDriver = [OpenQA.Selenium.Edge.EdgeDriver]::new((Get-Command -Name 'msedgedriver.exe').Path, $EdgeOptions)
  }
  $Script:EdgeDriver.Manage().Window.Size = [System.Drawing.Size]::new(1920, 1080)
  $Script:IsEdgeDriverLoaded = $true
}

function Get-EdgeDriver {
  <#
  .SYNOPSIS
    Return Edge Driver instance
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

$FirefoxDriver = $null
$IsFirefoxDriverLoaded = $false

function New-FirefoxDriver {
  <#
  .SYNOPSIS
    Initialize an Firefox Driver instance
  .PARAMETER Headless
    Run Firefox Driver in headless mode, with no window shown
  #>
  param (
    [parameter(
      HelpMessage = 'Run Firefox Driver in headless mode, with no windows shown'
    )]
    [switch]
    $Headless
  )

  $FirefoxOptions = [OpenQA.Selenium.Firefox.FirefoxOptions]::new()
  # Disable images downloading to speed up page loading
  $FirefoxOptions.SetPreference('permissions.default.image', 2)
  if ($Headless) {
    $FirefoxOptions.AddArgument('--headless')
  }
  if ($Env:GECKOWEBDRIVER) {
    # https://github.com/actions/runner-images/blob/main/images/win/Windows2022-Readme.md
    $Script:FirefoxDriver = [OpenQA.Selenium.Firefox.FirefoxDriver]::new($Env:GECKOWEBDRIVER, $FirefoxOptions)
  } else {
    $Script:FirefoxDriver = [OpenQA.Selenium.Firefox.FirefoxDriver]::new((Get-Command -Name 'geckodriver.exe').Path, $FirefoxOptions)
  }
  $Script:FirefoxDriver.Manage().Window.Size = [System.Drawing.Size]::new(1920, 1080)
  $Script:IsFirefoxDriverLoaded = $true
}

function Get-FirefoxDriver {
  <#
  .SYNOPSIS
    Return Firefox Driver instance
  #>
  [OutputType([OpenQA.Selenium.Firefox.FirefoxDriver])]
  param ()

  if (-not $Script:IsFirefoxDriverLoaded) {
    New-FirefoxDriver
  }
  return $Script:FirefoxDriver
}

function Stop-FirefoxDriver {
  <#
  .SYNOPSIS
    Stop Firefox Driver instance
  #>

  if ($Script:IsFirefoxDriverLoaded) {
    $Script:FirefoxDriver.Quit()
    $Script:IsFirefoxDriverLoaded = $false
  }
}

# Stop Firefox Driver when the module is being unloaded
$ExecutionContext.SessionState.Module.OnRemove += {
  Stop-EdgeDriver -ErrorAction Ignore
  Stop-FirefoxDriver -ErrorAction Ignore
}

Export-ModuleMember -Function *
