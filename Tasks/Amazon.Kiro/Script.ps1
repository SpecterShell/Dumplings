# x64 user
$Object1 = Invoke-RestMethod -Uri 'https://prod.download.desktop.kiro.dev/stable/metadata-win32-x64-user-stable.json'
# x64 machine
$Object3 = Invoke-RestMethod -Uri 'https://prod.download.desktop.kiro.dev/stable/metadata-win32-x64-system-stable.json'
# arm64 user
$Object4 = Invoke-RestMethod -Uri 'https://prod.download.desktop.kiro.dev/stable/metadata-win32-arm64-user-stable.json'
# arm64 machine
$Object5 = Invoke-RestMethod -Uri 'https://prod.download.desktop.kiro.dev/stable/metadata-win32-arm64-system-stable.json'

if (@(@($Object1, $Object3, $Object4, $Object5) | Sort-Object -Property { $_.currentRelease } -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x64 user: $($Object1.currentRelease), x64 machine: $($Object3.currentRelease), arm64 user: $($Object4.currentRelease), arm64 machine: $($Object5.currentRelease)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.currentRelease

$Object2 = $Object1.releases.Where({ $_.updateTo.version -eq $this.CurrentState.Version }, 'First')[0]

# Installer
# WinGetReplaceMode builds every entry from the existing x64 user installer, so each
# entry sets its own Scope, ProductCode (Inno AppId + _is1) and install location.
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  Scope                = 'user'
  InstallerUrl         = $Object2.updateTo.url
  ProductCode          = '{A2CA08B5-C756-463E-B13D-F051F4F11F0B}_is1'
  InstallationMetadata = [ordered]@{ DefaultInstallLocation = '%LocalAppData%\Programs\Kiro' }
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  Scope                = 'machine'
  InstallerUrl         = $Object3.releases.Where({ $_.updateTo.version -eq $this.CurrentState.Version }, 'First')[0].updateTo.url
  ProductCode          = '{ECDD7648-5B69-4BDC-9D21-C3452CE76CD2}_is1'
  InstallationMetadata = [ordered]@{ DefaultInstallLocation = '%ProgramFiles%\Kiro' }
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  Scope                = 'user'
  InstallerUrl         = $Object4.releases.Where({ $_.updateTo.version -eq $this.CurrentState.Version }, 'First')[0].updateTo.url
  ProductCode          = '{C178CB1C-7689-4F22-B8CF-0952EC832496}_is1'
  InstallationMetadata = [ordered]@{ DefaultInstallLocation = '%LocalAppData%\Programs\Kiro' }
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  Scope                = 'machine'
  InstallerUrl         = $Object5.releases.Where({ $_.updateTo.version -eq $this.CurrentState.Version }, 'First')[0].updateTo.url
  ProductCode          = '{CF58DB1E-C697-42DB-9C64-722B37182E61}_is1'
  InstallationMetadata = [ordered]@{ DefaultInstallLocation = '%ProgramFiles%\Kiro' }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.updateTo.pub_date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = 'https://kiro.dev/changelog/ide/'
      }

      $BrowserResult = Use-PlaywrightPage -Stealth -Headless {
        param($Page)

        $null = Open-PlaywrightPage -Page $Page -Uri $ReleaseNotesUrl
        $ReleaseNotesSelector = "xpath=//div[contains(./div[1]/div/div/span[2], 'IDE') and (contains(./div[1]/div/div/span[1], '$($this.CurrentState.Version -replace '(\.0+)+$')') or contains(./div[1]/div/div/span[1], '$('{0}.{1}' -f $this.CurrentState.Version.Split('.'))'))]"
        $ReleaseNotesNode = $Page.Locator($ReleaseNotesSelector).First
        $null = Wait-PlaywrightTask -Task $ReleaseNotesNode.WaitForAsync()
        $MainHtml = [string](Wait-PlaywrightTask -Task $ReleaseNotesNode.InnerHTMLAsync())
        $MainObject = $MainHtml | ConvertFrom-Html
        $DetailUrl = if ($MainObject) { Join-Uri $ReleaseNotesUrl $MainObject.SelectSingleNode('.//a[./h2]').Attributes['href'].Value }

        [pscustomobject]@{
          DetailUrl = $DetailUrl
          MainHtml  = $MainHtml
          PatchHtml = $null
        }
      }
      if ($BrowserResult.DetailUrl) {
        # Re-enter the FIFO queue for the detail page so each browser lease stays
        # inside the 30-second contention quantum.
        $BrowserResult.PatchHtml = Use-PlaywrightPage -Stealth -Headless {
          param($Page)
          $null = Open-PlaywrightPage -Page $Page -Uri $BrowserResult.DetailUrl
          Read-PlaywrightLocator -Page $Page -Selector "xpath=//*[contains(@id, 'patch-$($this.CurrentState.Version.Replace('.', '-'))')]/p/following-sibling::*[1]" -Optional -TimeoutMilliseconds 10000
        }
      }
      $ReleaseNotesObject = $BrowserResult.MainHtml | ConvertFrom-Html

      if ($ReleaseNotesObject) {
        # Remove "Learn more" links
        $ReleaseNotesObject.SelectNodes('.//a[contains(text(), "Learn more")]').ForEach({ $_.Remove() })
        # Remove anchor links
        $ReleaseNotesObject.SelectNodes('.//a[@class="anchor-link"]').ForEach({ $_.Remove() })
        # Remove "Video unavailable"
        $ReleaseNotesObject.SelectNodes('./*/div[contains(., "Video unavailable")]').ForEach({ $_.Remove() })
        # Remove figures
        $ReleaseNotesObject.SelectNodes('./*/div[figure]').ForEach({ $_.Remove() })
        # Remove buttons
        $ReleaseNotesObject.SelectNodes('.//button[@data-state="open" and count(*)>1]/div[last()]').ForEach({ $_.Remove() })
        $ReleaseNotesObject.SelectNodes('.//div[count(*)=1 and contains(./button/@aria-label, "Copy command")]').ForEach({ $_.Remove() })
        # Remove empty p
        $ReleaseNotesObject.SelectNodes('.//p[not(*) and not(normalize-space())]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectNodes('./div[1]/following-sibling::node()') | Get-TextContent | Format-Text
        }
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = $BrowserResult.DetailUrl
        }

        # ReleaseNotes (en-US)
        if ($BrowserResult.PatchHtml) {
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $BrowserResult.PatchHtml | ConvertFrom-Html | Get-TextContent | Format-Text
          }
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
