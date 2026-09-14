$Document = Invoke-WebRequest -Uri 'https://www.memoq.com/release-notes/' | ConvertFrom-Html

# The first release card whose download menu contains the memoQ translator pro installer
$Item = $null
$InstallerUrl = $null
foreach ($Node in $Document.SelectNodes("//div[contains(concat(' ', normalize-space(@class), ' '), ' list-item ')]")) {
  $DownloadButton = $Node.SelectSingleNode(".//button[@data-download]")
  if (-not $DownloadButton) { continue }

  $DataDownload = [System.Net.WebUtility]::HtmlDecode($DownloadButton.Attributes['data-download'].Value) | ConvertFrom-Json
  $DownloadEntry = $DataDownload.PSObject.Properties | Where-Object { $_.Value.name -eq 'memoQ translator pro' } | Select-Object -First 1
  if ($DownloadEntry) {
    # The thank-you link carries a Base64 token whose tail is the real installer URL
    $DownloadToken = [regex]::Match([string]$DownloadEntry.Value.download_link.url, 'download=([^&]+)').Groups[1].Value
    $DecodedDownload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($DownloadToken))
    $Item = $Node
    $InstallerUrl = ($DecodedDownload -split '--')[-1]
    break
  }
}
if (-not $Item) { throw 'No memoQ translator pro release was found on the release notes page.' }

# Version
$this.CurrentState.Version = $Item.SelectSingleNode(".//div[@class='title']").InnerText.Trim() -replace '^memoQ\s+'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Item.SelectSingleNode(".//div[@class='date']").InnerText.Trim(), 'yyyy\.MM\.dd\.', [cultureinfo]::InvariantCulture).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://www.memoq.com/release-notes/'
      }

      $ReleaseNotesCard = $Document.SelectSingleNode("//div[contains(concat(' ', normalize-space(@class), ' '), ' releases-accordion__item ')][.//p[contains(@class, 'js-accordion-title')][normalize-space(text()) = '$($this.CurrentState.Version)']]")
      if ($ReleaseNotesCard) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCard.SelectSingleNode(".//div[contains(@class, 'release-card__body')]") | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://www.memoq.com/release-notes/#' + $Item.Attributes['id'].Value
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
