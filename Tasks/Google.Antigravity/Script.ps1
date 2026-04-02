# x64
$Object1 = Invoke-RestMethod -Uri 'https://antigravity-auto-updater-974169037036.us-central1.run.app/api/update/win32-x64-user/stable/latest'
$VersionX64 = [regex]::Match($Object1.url, '(\d+(?:\.\d+)+)').Groups[1].Value
# arm64
$Object2 = Invoke-RestMethod -Uri 'https://antigravity-auto-updater-974169037036.us-central1.run.app/api/update/win32-arm64-user/stable/latest'
$VersionArm64 = [regex]::Match($Object2.url, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX64 -ne $VersionArm64) {
  $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionArm64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  Scope           = 'user'
  InstallerUrl    = $Object1.url
  InstallerSha256 = $Object1.sha256hash.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  Scope           = 'user'
  InstallerUrl    = $Object2.url
  InstallerSha256 = $Object2.sha256hash.ToUpper()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.timestamp | ConvertFrom-UnixTimeSeconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $EdgeDriver = Get-EdgeDriver -Headless
      $EdgeDriver.Navigate().GoToUrl('https://antigravity.google/changelog')
      $ReleaseNotesObject = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
        [System.Func[OpenQA.Selenium.IWebDriver, OpenQA.Selenium.IWebElement]] {
          param([OpenQA.Selenium.IWebDriver]$WebDriver)
          try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath("//div[contains(@class, 'version')]/following-sibling::div[contains(@class, 'description')]")) } catch {}
        }
      ).GetAttribute('innerHTML') | ConvertFrom-Html

      if ($ReleaseNotesObject) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
