function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    $Object5 = Invoke-WebRequest -Uri 'https://www.ccleaner.com/ccleaner/version-history' | ConvertFrom-Html

    $Object5.SelectNodes('//h6').ForEach({ $_.InnerHtml = $_.InnerHtml -replace '(?<=^|\.)0+(?=\d)' })
    $ReleaseNotesTitleNode = $Object5.SelectSingleNode("//h6[contains(., 'v$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
    if ($ReleaseNotesTitleNode) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h6' -and -not $Node.InnerText.Contains('download CCleaner for Android and iOS'); $Node = $Node.NextSibling) { $Node }
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Object1 = Get-TempFile -Uri 'https://honzik.avcdn.net/defs/piriform-ccl/release.xml.lzma'
$Object1Extracted = New-TempFolder
7z.exe e -aoa -ba -bd -y '-t#' -o"${Object1Extracted}" $Object1 '1.lzma' | Out-Host
$Object3 = 7z.exe e -y -so (Join-Path $Object1Extracted '1.lzma') | Join-String -Separator "`n" | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object3.'product-info'.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://bits.avcdn.net/productfamily_CCLEANER7/insttype_FREE/platform_WIN/installertype_ONLINE/build_RELEASE'
}

$Object4 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# Content Length
$this.CurrentState.ContentLength = $Object4.Headers.'Content-Length'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

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

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The version has changed
switch -Regex ($this.Check()) {
  'Updated|Rollbacked' {
    Read-Installer
    Get-ReleaseNotes

    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
  }
}

# Case 3: The version and Content Length are unchanged
if ($this.CurrentState.ContentLength -eq $this.LastState.ContentLength) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer
Get-ReleaseNotes

# Case 4: The Content Length has changed, but the hash is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The Content Length has changed, but the SHA256 is not', 'Info')

  $this.Write()
  return
}

# Case 5: Both the Content Length and the hash have changed
$this.Log('The Content Length and the hash have changed', 'Info')
$this.Config.IgnorePRCheck = $true
$this.Print()
$this.Write()
$this.Message()
$this.Submit()
