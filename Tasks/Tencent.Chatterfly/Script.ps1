# The download URL is embedded in a hashed JavaScript chunk of the official page
$Page = Invoke-WebRequest -Uri 'https://chatterfly.tencent.com/'
$Base = 'https://ife.gtimg.com/chatterfly/assets/'

$Seen = [System.Collections.Generic.HashSet[string]]::new()
$Queue = [System.Collections.Generic.List[string]]::new()
foreach ($Match in [regex]::Matches($Page.Content, 'https://ife\.gtimg\.com/chatterfly/assets/[\w-]+\.js')) {
  if ($Seen.Add($Match.Value)) { $Queue.Add($Match.Value) }
}

$InstallerUrl = $null
for ($i = 0; $i -lt $Queue.Count -and -not $InstallerUrl; $i++) {
  $Content = (Invoke-WebRequest -Uri $Queue[$i]).Content
  $Match = [regex]::Match($Content, 'https://chatterfly\.gtimg\.com/fe/pkg/\d{8}/Chatterfly_V[\d.]+\.exe')
  if ($Match.Success) {
    $InstallerUrl = $Match.Value
    break
  }
  foreach ($Chunk in [regex]::Matches($Content, '"\./([\w-]+\.js)"')) {
    $Url = $Base + $Chunk.Groups[1].Value
    if ($Seen.Add($Url)) { $Queue.Add($Url) }
  }
}
if (-not $InstallerUrl) { throw 'Installer URL not found in page scripts' }

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'Chatterfly_V([\d.]+)\.exe').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
