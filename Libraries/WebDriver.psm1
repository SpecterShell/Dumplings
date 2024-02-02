# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'

$WebDriverPath = $DumplingsRoot ? (Join-Path $DumplingsRoot 'Assets' 'WebDriver.dll') : (Join-Path $PSScriptRoot '..' 'Assets' 'WebDriver.dll')
$WebDriverLoaded = $false
try {
  Add-Type -Path $WebDriverPath
  $WebDriverLoaded = $true
} catch {
  Write-Host 'Could not find WebDriver assembly. WebDriver functions will not be working'
}

#region Edge Driver
$EdgeDriver = $null
$EdgeDriverLoaded = $false
# https://github.com/actions/runner-images/blob/main/images/win/Windows2022-Readme.md
$EdgeDriverPath = $Env:EDGEWEBDRIVER ? $Env:EDGEWEBDRIVER : (Get-Command -Name 'msedgedriver.exe').Path

function New-EdgeDriver {
  <#
  .SYNOPSIS
    Initialize an Edge Driver instance
  .PARAMETER Headless
    Run Edge Driver in headless mode, with no window shown
  #>
  param (
    [parameter(HelpMessage = 'Run Edge Driver in headless mode, with no windows shown')]
    [switch]
    $Headless
  )

  if (-not $Script:WebDriverLoaded) { throw 'WebDriver is not loaded' }

  $EdgeOptions = [OpenQA.Selenium.Edge.EdgeOptions]::new()
  # Disable images downloading to speed up page loading
  $EdgeOptions.AddUserProfilePreference('profile.managed_default_content_settings.images', 2)
  if ($Headless) { $EdgeOptions.AddArgument('--headless=new') }

  $Script:EdgeDriver = [OpenQA.Selenium.Edge.EdgeDriver]::new($Script:EdgeDriverPath, $EdgeOptions)
  $Script:EdgeDriver.Manage().Window.Size = [System.Drawing.Size]::new(1920, 1080)
  $Script:EdgeDriverLoaded = $true
}

function Get-EdgeDriver {
  <#
  .SYNOPSIS
    Return the Edge Driver instance
  #>
  [OutputType([OpenQA.Selenium.Edge.EdgeDriver])]
  param ()

  if (-not $Script:EdgeDriverLoaded) { New-EdgeDriver }
  return $Script:EdgeDriver
}

function Stop-EdgeDriver {
  <#
  .SYNOPSIS
    Stop the Edge Driver instance
  #>

  if ($Script:EdgeDriverLoaded) {
    $Script:EdgeDriver.Quit()
    $Script:EdgeDriverLoaded = $false
  }
}
#endregion

#region FirefoxDriver
$FirefoxDriver = $null
$FirefoxDriverLoaded = $false
# https://github.com/actions/runner-images/blob/main/images/win/Windows2022-Readme.md
$FirefoxDriverPath = $Env:GECKOWEBDRIVER ? $Env:GECKOWEBDRIVER : (Get-Command -Name 'geckodriver.exe').Path

function New-FirefoxDriver {
  <#
  .SYNOPSIS
    Initialize an Firefox Driver instance
  .PARAMETER Headless
    Run Firefox Driver in headless mode, with no window shown
  #>
  param (
    [parameter(HelpMessage = 'Run Firefox Driver in headless mode, with no windows shown')]
    [switch]
    $Headless
  )

  if (-not $Script:WebDriverLoaded) { throw 'WebDriver is not loaded' }

  $FirefoxOptions = [OpenQA.Selenium.Firefox.FirefoxOptions]::new()
  # Disable images downloading to speed up page loading
  $FirefoxOptions.SetPreference('permissions.default.image', 2)
  if ($Headless) { $FirefoxOptions.AddArgument('--headless') }

  $Script:FirefoxDriver = [OpenQA.Selenium.Firefox.FirefoxDriver]::new($Script:FirefoxDriverPath, $FirefoxOptions)
  $Script:FirefoxDriver.Manage().Window.Size = [System.Drawing.Size]::new(1920, 1080)
  $Script:FirefoxDriverLoaded = $true
}

function Get-FirefoxDriver {
  <#
  .SYNOPSIS
    Return the Firefox Driver instance
  #>
  [OutputType([OpenQA.Selenium.Firefox.FirefoxDriver])]
  param ()

  if (-not $Script:FirefoxDriverLoaded) { New-FirefoxDriver }
  return $Script:FirefoxDriver
}

function Stop-FirefoxDriver {
  <#
  .SYNOPSIS
    Stop the Firefox Driver instance
  #>

  if ($Script:FirefoxDriverLoaded) {
    $Script:FirefoxDriver.Quit()
    $Script:FirefoxDriverLoaded = $false
  }
}
#endregion

# Stop drivers when the module is unloading
$ExecutionContext.SessionState.Module.OnRemove += {
  Stop-EdgeDriver -ErrorAction Ignore
  Stop-FirefoxDriver -ErrorAction Ignore
}

Export-ModuleMember -Function *
