$ErrorActionPreference = 'Stop'

$siteRoot = $PSScriptRoot
$manifestPath = Join-Path $siteRoot 'legal-documents.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$utf8 = New-Object System.Text.UTF8Encoding($false)

foreach ($document in $manifest.documents) {
    $sourcePath = Join-Path $siteRoot ('documents\' + $document.id + '.txt')
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Missing canonical document: $sourcePath"
    }

    $bytes = [System.IO.File]::ReadAllBytes($sourcePath)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $actualHash = ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }

    if ($actualHash -ne $document.sha256.ToLowerInvariant()) {
        throw "SHA-256 mismatch for $($document.id): $actualHash != $($document.sha256)"
    }

    $plainText = $utf8.GetString($bytes)
    $encodedText = [System.Net.WebUtility]::HtmlEncode($plainText)
    $title = if ($document.id -eq 'privacy-policy') { 'Privacy Policy' } else { 'Terms of Use' }
    $otherId = if ($document.id -eq 'privacy-policy') { 'terms-of-use' } else { 'privacy-policy' }
    $otherTitle = if ($document.id -eq 'privacy-policy') { 'Terms of Use' } else { 'Privacy Policy' }
    $outputDirectory = Join-Path $siteRoot $document.id
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    $outputPath = Join-Path $outputDirectory 'index.html'

    $html = @"
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="index,follow">
    <meta name="legal-document-id" content="$($document.id)">
    <meta name="legal-document-version" content="$($document.version)">
    <meta name="legal-document-effective-date" content="$($document.effectiveDate)">
    <meta name="legal-document-sha256" content="$actualHash">
    <title>LuckyCat $title</title>
    <link rel="stylesheet" href="../assets/legal.css">
</head>
<body>
    <header class="site-header">
        <a href="../">LuckyCat Legal</a>
        <a href="../$otherId/">$otherTitle</a>
    </header>
    <main class="legal-page">
        <pre class="legal-copy">$encodedText</pre>
    </main>
    <footer class="site-footer">
        <a href="../documents/$($document.id).txt">Canonical plain text</a>
        · SHA-256: $actualHash<br>
        © 2026 Oleksandr Ukrainets. All rights reserved.
    </footer>
</body>
</html>
"@

    [System.IO.File]::WriteAllText($outputPath, $html, $utf8)
}

Write-Host 'LuckyCat legal pages generated and verified.'
