# x64
$Object1 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10" arch="x64" />
  <app appid="{6BBAE539-2232-434A-A4E5-9A33560C6283}" cohort="1:fj3:nir@0.5,nj9@0.05,nix@0.25,nj3@0.1">
    <updatecheck />
  </app>
</request>
'@

# arm64
$Object2 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10" arch="arm64" />
  <app appid="{6BBAE539-2232-434A-A4E5-9A33560C6283}" cohort="1:fj3:nir@0.5,nj9@0.05,nix@0.25,nj3@0.1">
    <updatecheck />
  </app>
</request>
'@

if ($Object1.response.app.updatecheck.manifest.version -ne $Object2.response.app.updatecheck.manifest.version) {
  $this.Log("x64 version: $($Object1.response.app.updatecheck.manifest.version)")
  $this.Log("arm64 version: $($Object2.response.app.updatecheck.manifest.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.response.app.updatecheck.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = ($Object1.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object1.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' }, 'First')[0].run
}

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = ($Object2.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object2.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' }, 'First')[0].run
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://support.google.com/a/answer/7577057?hl=en' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[contains(@class, 'devsite-article-body')]/p[contains(., 'Version $($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./preceding-sibling::h2').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = Invoke-WebRequest -Uri 'https://support.google.com/a/answer/7577057?hl=zh-Hans' | ConvertFrom-Html

      $ReleaseNotesCNTitleNode = $Object4.SelectSingleNode("//div[contains(@class, 'devsite-article-body')]/p[contains(., '版本 $($this.CurrentState.Version.Split('.')[0..1] -join '.')')]")
      if ($ReleaseNotesCNTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [regex]::Match($ReleaseNotesCNTitleNode.SelectSingleNode('./preceding-sibling::h2').InnerText, '(20\d{2}\s*年\s*\d{1,2}\s*月\s*\d{1,2}\s*日)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
