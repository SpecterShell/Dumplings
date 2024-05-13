$Prefix = 'https://imagemagick.org/archive/binaries/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}digest.rdf"

$InstallerObjects = $Object1.RDF.Content |
  Where-Object -FilterScript { $_.about.EndsWith('.exe') -and $_.about.Contains('Q8') -and -not $_.about.Contains('HDRI') -and $_.about.Contains('dll') } |
  Sort-Object -Property { $_.about -replace '\d+', { $_.Value.PadLeft(20) } }

$InstallerObjectX86 = $InstallerObjects.Where({ $_.about.Contains('x86') }, 'Last')[0]
$VersionX86 = [regex]::Match($InstallerObjectX86.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value
$InstallerX86 = $Prefix + $InstallerObjectX86.about

$InstallerObjectX64 = $InstallerObjects.Where({ $_.about.Contains('x64') }, 'Last')[0]
$VersionX64 = [regex]::Match($InstallerObjectX64.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value
$InstallerX64 = $Prefix + $InstallerObjectX64.about

$InstallerObjectArm64 = $InstallerObjects.Where({ $_.about.Contains('arm64') }, 'Last')[0]
$VersionArm64 = [regex]::Match($InstallerObjectArm64.about, '(\d+\.\d+\.\d+-\d+)').Groups[1].Value
$InstallerArm64 = $Prefix + $InstallerObjectArm64.about

$Identical = $true
if (@(@($VersionX86, $VersionX64, $VersionArm64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

$LatestVersion = @($VersionX86, $VersionX64, $VersionArm64) | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $LatestVersion.Replace('-', '.')

if ($VersionX86 -eq $LatestVersion) {
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture    = 'x86'
    InstallerUrl    = $InstallerX86
    InstallerSha256 = $InstallerObjectX86.sha256.ToUpper()
    ProductCode     = "ImageMagick $($LatestVersion.Split('-')[0]) Q8 (32-bit)_is1"
  }
}
if ($VersionX64 -eq $LatestVersion) {
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture    = 'x64'
    InstallerUrl    = $InstallerX64
    InstallerSha256 = $InstallerObjectX64.sha256.ToUpper()
    ProductCode     = "ImageMagick $($LatestVersion.Split('-')[0]) Q8 (64-bit)_is1"
  }
}
if ($VersionArm64 -eq $LatestVersion) {
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture    = 'arm64'
    InstallerUrl    = $InstallerArm64
    InstallerSha256 = $InstallerObjectArm64.sha256.ToUpper()
    ProductCode     = "ImageMagick $($LatestVersion.Split('-')[0]) Q8 (arm64)_is1"
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/ImageMagick/Website/main/ChangeLog.md' | ConvertFrom-Markdown).Html | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h2[contains(.//text(), '${LatestVersion}')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://github.com/ImageMagick/Website/blob/main/ChangeLog.md#' + ($ReleaseNotesTitleNode.InnerText -creplace '[^a-zA-Z0-9\-\s]+', '' -creplace '\s+', '-').ToLower()
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://github.com/ImageMagick/Website/blob/main/ChangeLog.md'
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://github.com/ImageMagick/Website/blob/main/ChangeLog.md'
      }
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
