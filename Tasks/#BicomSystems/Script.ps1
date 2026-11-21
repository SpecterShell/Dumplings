$Global:DumplingsStorage.BicomSystemsDownloadRoot = 'https://downloads.bicomsystems.com/desktop/glocom/public/'
$Global:DumplingsStorage.BicomSystemsChangelogRoot = 'https://www.bicomsystems.com/files/public/'

# The public site builds its picker with JavaScript, but the backing directory index is a plain fancyindex listing.
$Object1 = Invoke-WebRequest -Uri $Global:DumplingsStorage.BicomSystemsDownloadRoot -UserAgent $DumplingsBrowserUserAgent

$Global:DumplingsStorage.BicomSystemsVersions = $(foreach ($Link in $Object1.Links) {
    if ($Link.href -match '^(\d+(?:\.\d+)+)/$') {
      [pscustomobject]@{
        Version = [ChunkVersion]$Matches[1]
        Name    = $Matches[1]
      }
    }
  }) | Sort-Object -Property Version -Descending | ForEach-Object Name
