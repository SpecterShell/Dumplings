$Object1 = Invoke-WebRequest -Uri 'https://free.regify.com/downloads.php'

$Global:DumplingsStorage.RegifyClients = @{}
foreach ($Product in @('regipay', 'regify_client', 'regibox')) {
  $Match = [regex]::Match($Object1.Content, ('DOWNLOAD/windows/' + [regex]::Escape($Product) + '-(\d+(?:\.\d+)+)-\d+(\.x86)?\.exe'))
  if ($Match.Success) {
    $Global:DumplingsStorage.RegifyClients[$Product] = [ordered]@{
      InstallerUrl = "https://www.regify.com/$($Match.Value)"
      Version      = $Match.Groups[1].Value
    }
  }
}
