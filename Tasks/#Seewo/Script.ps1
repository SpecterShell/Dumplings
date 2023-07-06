$Temp.SeewoApps = [ordered]@{}

[regex]::Match(
  (Invoke-WebRequest -Uri 'https://e.seewo.com/').Content,
  "var apps_str = '(.+?)';"
).Groups[1].Value | ConvertTo-HtmlDecodedText | ConvertFrom-Json | ForEach-Object -Process {
  $Temp.SeewoApps[$_.packageCode] = $_
}
