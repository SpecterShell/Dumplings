$Locales = @('en-US', 'de', 'es-AR', 'fr', 'it', 'ja', 'nl', 'pt-BR')
$ArchMap = [ordered]@{
  x86   = 'win32'
  x64   = 'win64'
  arm64 = 'win64-aarch64'
}
$Prefix = 'https://www.betterbird.eu/downloads/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}index.php"

# Version
$VersionMatches = [regex]::Match($Object1.Content, 'Betterbird (((\d+)(?:\.\d+)+)-[a-zA-Z0-9]+)')
$OriginalVersion = $VersionMatches.Groups[1].Value
$MajorVersion = $VersionMatches.Groups[3].Value
$this.CurrentState.Version = $ShortVersion = $VersionMatches.Groups[2].Value

$Object2 = [ordered]@{}
Invoke-RestMethod -Uri "${Prefix}sha256-${MajorVersion}.txt" | Split-LineEndings |
  Where-Object -FilterScript { $_ -match [regex]::Escape($OriginalVersion) -and $_ -match '\.exe$' } |
  ForEach-Object -Process {
    $Entries = $_ -split '\s+'
    $Object2[$Entries[1].TrimStart('*')] = $Entries[0].ToUpper()
  }

# Installer
# https://www.betterbird.eu/downloads/WindowsInstaller/betterbird-115.16.1-bb34.nl.win64.installer.exe
foreach ($Locale in $Locales) {
  foreach ($Arch in @('x64')) {
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerLocale = $Locale
      Architecture    = $Arch
      InstallerType   = 'nullsoft'
      InstallerUrl    = "${Prefix}WindowsInstaller/betterbird-${OriginalVersion}.${Locale}.$($ArchMap[$Arch]).installer.exe"
      InstallerSha256 = $Object2["betterbird-${OriginalVersion}.${Locale}.$($ArchMap[$Arch]).installer.exe"]
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
