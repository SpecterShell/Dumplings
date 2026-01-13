$Object1 = Invoke-RestMethod -Uri 'https://download.eclipse.org/technology/epp/downloads/release/release.xml'
$Global:DumplingsStorage.EclipseVersion = $Object1.packages.present.Split('/')[0]
