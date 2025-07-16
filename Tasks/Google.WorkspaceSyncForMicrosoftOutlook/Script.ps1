function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromMsi
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  # ProductCode
  $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
  # AppsAndFeaturesEntries
  $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
    }
  )
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    $Object2 = Invoke-WebRequest -Uri 'https://support.google.com/a/answer/153463?hl=en' | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='cc']//h2[contains(text(), '$($this.CurrentState.Version)')]")
    if ($ReleaseNotesTitleNode) {
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node; $Node = $Node.NextSibling) {
        if ($Node.InnerText -match '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
        } else {
          $Node
        }
      }
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
    $Object3 = Invoke-WebRequest -Uri 'https://support.google.com/a/answer/153463?hl=zh-Hans' | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[@class='cc']//h2[contains(text(), '$($this.CurrentState.Version)')]")
    if ($ReleaseNotesTitleNode) {
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node; $Node = $Node.NextSibling) {
        if ($Node.InnerText -match '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})' -or $Node.InnerText -match '(20\d{2}\s*年\s*\d{1,2}\s*月\s*\d{1,2}\s*日)') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
        } else {
          $Node
        }
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# x86
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://dl.google.com/dl/google-apps-sync/enterprise_gsync.msi'
}
$Object1 = Invoke-WebRequest -Uri $InstallerX86.InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

# x64
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://dl.google.com/dl/google-apps-sync/x64/enterprise_gsync.msi'
}
$Object2 = Invoke-WebRequest -Uri $InstallerX64.InstallerUrl -Method Head
$ETagX64 = $Object2.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagX64 = @($ETagX64)

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagX64 = @($ETagX64)

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (MSI)", 'Info')
  return
}
if ($ETagX64 -in $this.LastState.ETagX64) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (EXE)", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 4: The ETag has changed, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag
  $this.CurrentState.ETagX64 = $this.LastState.ETagX64 + $ETagX64

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)
$this.CurrentState.ETagX64 = @($ETagX64)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
