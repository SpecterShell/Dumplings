# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'

#region WebDriver
$WebDriverLoaded = $false

function Initialize-WebDriver {
  <#
  .SYNOPSIS
    Initialize the WebDriver module
  #>

  if (-not $Script:WebDriverLoaded) {
    if (Test-Path -Path (Join-Path $PSScriptRoot '..' 'Assets' 'WebDriver.dll')) {
      $WebDriverPath = Join-Path $PSScriptRoot '..' 'Assets' 'WebDriver.dll' -Resolve
    } elseif ((Test-Path -Path Variable:\DumplingsRoot) -and (Test-Path -Path (Join-Path $DumplingsRoot 'Assets' 'WebDriver.dll'))) {
      $WebDriverPath = Join-Path $DumplingsRoot 'Assets' 'WebDriver.dll' -Resolve
    } else {
      throw 'The WebDriver assembly could not be found'
    }

    Add-Type -Path $WebDriverPath
    $Script:WebDriverLoaded = $true
  }
}
#endregion

# Silently initialize WebDriver when loading the module
try { Initialize-WebDriver } catch {}

#region Edge Driver
$EdgeDriver = $null
$EdgeDriverLoaded = $false

function New-EdgeDriver {
  <#
  .SYNOPSIS
    Initialize an Edge Driver instance
  .PARAMETER Headless
    Initialize the Edge Driver instance in headless mode, where no window pops up
  #>
  param (
    [parameter(HelpMessage = 'Initialize the Edge Driver instance in headless mode, where no window pops up')]
    [switch]$Headless
  )

  Initialize-WebDriver

  $EdgeOptions = [OpenQA.Selenium.Edge.EdgeOptions]::new()

  # Run Edge in the background with no window popping up
  if ($Headless) { $EdgeOptions.AddArgument('--headless=new') }
  # Disable images downloading to speed up page loading
  $EdgeOptions.AddUserProfilePreference('profile.managed_default_content_settings.images', 2)

  if (Test-Path -Path Env:\EDGEWEBDRIVER) {
    # https://github.com/actions/runner-images/blob/main/images/win/Windows2022-Readme.md
    $Script:EdgeDriver = [OpenQA.Selenium.Edge.EdgeDriver]::new($Env:EDGEWEBDRIVER, $EdgeOptions)
  } elseif (Get-Command -Name 'msedgedriver.exe' -ErrorAction SilentlyContinue) {
    $Script:EdgeDriver = [OpenQA.Selenium.Edge.EdgeDriver]::new((Get-Command -Name 'msedgedriver.exe').Path, $EdgeOptions)
  } else {
    throw 'Could not find msedgedriver.exe'
  }

  $Script:EdgeDriverLoaded = $true

  # Resize the window to 1920x1080 to ensure the page is not rendered in mobile mode
  $Script:EdgeDriver.Manage().Window.Size = [System.Drawing.Size]::new(1920, 1080)
  # Block images, videos, and other media files to speed up page loading and reduce resource consumption
  $Dict = [System.Collections.Generic.Dictionary[string, object]]::new()
  $Dict.Add('urls', @('*.jpg*', '*.jpeg*', '*.bmp*', '*.png*', '*.webp*', '*.gif*', '*.svg*', '*.mp4*', '*.webm*', '*.flv*'))
  $null = $Script:EdgeDriver.ExecuteCdpCommand('Network.setBlockedURLs', $Dict)
  $Dict = [System.Collections.Generic.Dictionary[string, object]]::new()
  $null = $Script:EdgeDriver.ExecuteCdpCommand('Network.enable', $Dict)
}

function Get-EdgeDriver {
  <#
  .SYNOPSIS
    Return the Edge Driver instance
  #>
  [OutputType([OpenQA.Selenium.Edge.EdgeDriver])]
  param ()

  if (-not $Script:EdgeDriverLoaded) { New-EdgeDriver @args }
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

function New-FirefoxDriver {
  <#
  .SYNOPSIS
    Initialize an Firefox Driver instance
  .PARAMETER Headless
    Initialize the Firefox Driver instance in headless mode, where no window pops up
  #>
  param (
    [parameter(HelpMessage = 'Initialize the Firefox Driver instance in headless mode, where no window pops up')]
    [switch]$Headless
  )

  Initialize-WebDriver

  $FirefoxOptions = [OpenQA.Selenium.Firefox.FirefoxOptions]::new()
  # Disable images downloading to speed up page loading
  $FirefoxOptions.SetPreference('permissions.default.image', 2)
  if ($Headless) { $FirefoxOptions.AddArgument('--headless') }

  if (Test-Path Env:\GECKOWEBDRIVER) {
    # https://github.com/actions/runner-images/blob/main/images/win/Windows2022-Readme.md
    $Script:FirefoxDriver = [OpenQA.Selenium.Firefox.FirefoxDriver]::new($Env:GECKOWEBDRIVER, $FirefoxOptions)
  } elseif (Get-Command -Name 'geckodriver.exe' -ErrorAction SilentlyContinue) {
    $Script:FirefoxDriver = [OpenQA.Selenium.Firefox.FirefoxDriver]::new((Get-Command -Name 'geckodriver.exe').Path, $FirefoxOptions)
  } else {
    throw 'Could not find geckodriver.exe'
  }
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

  if (-not $Script:FirefoxDriverLoaded) { New-FirefoxDriver @args }
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
  Stop-EdgeDriver -ErrorAction Continue
  Stop-FirefoxDriver -ErrorAction Continue
}

Export-ModuleMember -Function *
