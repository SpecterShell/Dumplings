$Locales = @('en-US', 'de', 'es-ES', 'fr', 'it', 'ja', 'nl', 'pt-BR', 'ru')
$ArchMap = [ordered]@{
  x86   = 'win32'
  x64   = 'win64'
  arm64 = 'win64-aarch64'
}
$Prefix = 'https://www.betterbird.eu/downloads/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}index.php"

# Version
$VersionMatches = [regex]::Match($Object1.Content, 'Betterbird (((\d+)(?:\.\d+)+)[a-zA-Z0-9\-]+)')
$OriginalVersion = $VersionMatches.Groups[1].Value
$MajorVersion = $VersionMatches.Groups[3].Value
$this.CurrentState.Version = $ShortVersion = $VersionMatches.Groups[2].Value

$Object2 = [ordered]@{}
Invoke-RestMethod -Uri "${Prefix}sha256-${MajorVersion}.txt" | Split-LineEndings |
  Where-Object -FilterScript { $_.Contains($OriginalVersion) -and $_.EndsWith('.exe') } |
  ForEach-Object -Process {
    $Entries = $_ -split '\s+'
    $Object2[$Entries[1].TrimStart('*')] = $Entries[0].ToUpper()
  }

# Installer
foreach ($Locale in $Locales) {
  foreach ($Arch in @('x64')) {
    $Installer = $Object2.GetEnumerator().Where({ $_.Key.Contains($Locale) -and $_.Key.Contains($ArchMap[$Arch]) }, 'First')[0]
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerLocale = $Locale
      Architecture    = $Arch
      InstallerType   = 'nullsoft'
      InstallerUrl    = "${Prefix}WindowsInstaller/$($Installer.Key)"
      InstallerSha256 = $Installer.Value
      ProductCode     = "Betterbird ${ShortVersion} (${Arch} ${Locale})"
    }
  }
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
