# The hash part of the URL is the SHA256 hash of the machine GUID from HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography\MachineGuid
# Use a random hash here
$Hash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes([guid]::NewGuid().Guid))).ToLower()
# x64 user
$Object1 = Invoke-RestMethod -Uri "https://api2.cursor.sh/updates/api/update/win32-x64-user/cursor/$($this.Status.Contains('New') ? '0.46.10' : $this.LastState.Version)/${Hash}/stable" -StatusCodeVariable 'StatusCodeX64User'
if ($StatusCodeX64User -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# x64 machine
$Object2 = Invoke-RestMethod -Uri "https://api2.cursor.sh/updates/api/update/win32-x64/cursor/$($this.Status.Contains('New') ? '0.46.10' : $this.LastState.Version)/${Hash}/stable" -StatusCodeVariable 'StatusCodeX64Machine'
if ($StatusCodeX64Machine -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# arm64 user
$Object3 = Invoke-RestMethod -Uri "https://api2.cursor.sh/updates/api/update/win32-arm64-user/cursor/$($this.Status.Contains('New') ? '0.46.10' : $this.LastState.Version)/${Hash}/stable" -StatusCodeVariable 'StatusCodeARM64User'
if ($StatusCodeARM64User -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# arm64 machine
$Object4 = Invoke-RestMethod -Uri "https://api2.cursor.sh/updates/api/update/win32-arm64/cursor/$($this.Status.Contains('New') ? '0.46.10' : $this.LastState.Version)/${Hash}/stable" -StatusCodeVariable 'StatusCodeARM64Machine'
if ($StatusCodeARM64Machine -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

if (@(@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.productVersion } -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x64 user: $($Object1.productVersion), x64 machine: $($Object2.productVersion), arm64 user: $($Object3.productVersion), arm64 machine: $($Object4.productVersion)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.productVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object1.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'machine'
  InstallerUrl = $Object2.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'user'
  InstallerUrl = $Object3.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'machine'
  InstallerUrl = $Object4.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $EdgeDriver = Get-EdgeDriver -Headless
      $EdgeDriver.Navigate().GoToUrl('https://www.cursor.com/changelog')
      $ReleaseNotesObject = [OpenQA.Selenium.Support.UI.WebDriverWait]::new($EdgeDriver, [timespan]::FromSeconds(30)).Until(
        [System.Func[OpenQA.Selenium.IWebDriver, string]] {
          param([OpenQA.Selenium.IWebDriver]$WebDriver)
          try { $WebDriver.FindElements([OpenQA.Selenium.By]::XPath("//main//article[contains(.//span[@class='label'], '$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]//button[@data-state='closed']")).ForEach({ $_.Click() }) } catch {}
          try { $WebDriver.FindElement([OpenQA.Selenium.By]::XPath("//main//article[contains(.//span[@class='label'], '$($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")).GetAttribute('innerHTML') } catch {}
        }
      ) | ConvertFrom-Html

      if ($ReleaseNotesObject) {
        # # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesObject.SelectSingleNode('.//time').Attributes['datetime'].Value | Get-Date -AsUTC

        # Remove video players
        $ReleaseNotesObject.SelectNodes('.//*[contains(@aria-label, "Video player container")]').ForEach({ $_.Remove() })
        # Remove accordion buttons
        $ReleaseNotesObject.SelectNodes('.//span[contains(@class, "group-data-[state=open]:")]').ForEach({ $_.Remove() })
        # Remove anchor icons
        $ReleaseNotesObject.SelectNodes('.//*[contains(@class, "anchor-icon")]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectNodes('.//div[contains(@class, "prose")]') | Get-TextContent | Format-Text
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
