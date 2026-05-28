param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RegexValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
    $match = [System.Text.RegularExpressions.Regex]::Match($Content, $Pattern, $options)
    if ($match.Success) {
        return $match.Groups["value"].Value.Trim()
    }

    return $null
}

function Normalize-Whitespace {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return ([System.Text.RegularExpressions.Regex]::Replace($Value, "\s+", " ")).Trim()
}

function Strip-Html {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $withoutTags = [System.Text.RegularExpressions.Regex]::Replace($Value, "<[^>]+>", " ")
    return Normalize-Whitespace -Value ([System.Net.WebUtility]::HtmlDecode($withoutTags))
}

function Normalize-TopicTitle {
    param(
        [AllowNull()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Fallback
    )

    $normalized = Strip-Html -Value $Value
    if (-not [string]::IsNullOrWhiteSpace($normalized)) {
        $normalized = [System.Text.RegularExpressions.Regex]::Replace($normalized, "\s*\|\s*Learning\.Faster\s*$", "")
        $normalized = Normalize-Whitespace -Value $normalized
    }

    if ([string]::IsNullOrWhiteSpace($normalized)) {
        $normalized = $Fallback
    }

    return $normalized
}

function Get-FallbackTitle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Slug
    )

    $spaced = $Slug -replace "[-_]+", " "
    if ($spaced -match "^[a-z0-9 ]+$") {
        $textInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo
        return $textInfo.ToTitleCase($spaced)
    }

    return $spaced
}

function Get-TopicMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Directory
    )

    $indexPath = Join-Path $Directory.FullName "index.html"
    $content = Get-Content -LiteralPath $indexPath -Raw
    $slug = $Directory.Name
    $fallbackTitle = Get-FallbackTitle -Slug $slug

    $title = Normalize-TopicTitle -Value (Get-RegexValue -Content $content -Pattern "<title>\s*(?<value>.*?)\s*</title>") -Fallback $fallbackTitle
    $description = Strip-Html -Value (Get-RegexValue -Content $content -Pattern '<meta[^>]*name="description"[^>]*content="(?<value>[^"]*)"[^>]*>')

    if ([string]::IsNullOrWhiteSpace($description)) {
        $description = Strip-Html -Value (Get-RegexValue -Content $content -Pattern '<meta[^>]*property="og:description"[^>]*content="(?<value>[^"]*)"[^>]*>')
    }

    if ([string]::IsNullOrWhiteSpace($description)) {
        $description = Strip-Html -Value (Get-RegexValue -Content $content -Pattern "<h1[^>]*>(?<value>.*?)</h1>")
    }

    if ([string]::IsNullOrWhiteSpace($description)) {
        $description = "Guida disponibile su Learning.Faster."
    }

    return [pscustomobject]@{
        Slug = $slug
        Title = $title
        Description = $description
        RelativeUrl = "./topics/$slug/"
    }
}

function Convert-ToTopicCardHtml {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Topic
    )

    $encodedTitle = [System.Net.WebUtility]::HtmlEncode($Topic.Title)
    $encodedDescription = [System.Net.WebUtility]::HtmlEncode($Topic.Description)
    $encodedSlug = [System.Net.WebUtility]::HtmlEncode($Topic.Slug)
    $encodedUrl = [System.Net.WebUtility]::HtmlEncode($Topic.RelativeUrl)

    return @"
        <article class="topic-card">
          <p class="topic-slug">$encodedSlug</p>
          <h2><a href="$encodedUrl">$encodedTitle</a></h2>
          <p class="topic-description">$encodedDescription</p>
          <a class="topic-link" href="$encodedUrl">Apri topic</a>
        </article>
"@
}

$docsPath = Join-Path $RepositoryRoot "docs"
$topicsPath = Join-Path $docsPath "topics"
$outputPath = Join-Path $docsPath "index.html"

if (-not (Test-Path -LiteralPath $topicsPath)) {
    throw "Topics directory not found: $topicsPath"
}

$topicDirectories = Get-ChildItem -LiteralPath $topicsPath -Directory | Sort-Object Name
$topics = @(
    foreach ($directory in $topicDirectories) {
    $topicIndexPath = Join-Path $directory.FullName "index.html"
    if (Test-Path -LiteralPath $topicIndexPath) {
        Get-TopicMetadata -Directory $directory
    }
}
)

$topicCards = if ($topics.Count -gt 0) {
    ($topics | ForEach-Object { Convert-ToTopicCardHtml -Topic $_ }) -join "`n"
}
else {
    @"
        <article class="topic-card empty-state">
          <p class="topic-slug">topics</p>
          <h2>Nessun topic pubblicato</h2>
          <p class="topic-description">Aggiungi una cartella in <code>docs\topics\</code> con il suo <code>index.html</code> per farla apparire automaticamente qui.</p>
        </article>
"@
}

$metaDescription = "Homepage essenziale di Learning.Faster generata automaticamente dai topic pubblicati."

$html = @"
<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Learning.Faster</title>
  <meta name="description" content="$([System.Net.WebUtility]::HtmlEncode($metaDescription))" />
  <meta name="robots" content="index,follow" />
  <meta name="theme-color" content="#111827" />
  <link rel="canonical" href="https://martinabruni.github.io/Learning.Faster/" />
  <link rel="icon" href="./assets/favicon.svg" type="image/svg+xml" />
  <meta property="og:type" content="website" />
  <meta property="og:locale" content="it_IT" />
  <meta property="og:site_name" content="Learning.Faster" />
  <meta property="og:title" content="Learning.Faster" />
  <meta property="og:description" content="$([System.Net.WebUtility]::HtmlEncode($metaDescription))" />
  <meta property="og:url" content="https://martinabruni.github.io/Learning.Faster/" />
  <meta name="twitter:card" content="summary" />
  <meta name="twitter:title" content="Learning.Faster" />
  <meta name="twitter:description" content="$([System.Net.WebUtility]::HtmlEncode($metaDescription))" />
  <style>
    :root {
      --bg: #f5f5f4;
      --surface: #ffffff;
      --surface-alt: #f8fafc;
      --text: #0f172a;
      --muted: #475569;
      --border: #e2e8f0;
      --accent: #111827;
      --accent-soft: #f1f5f9;
      --shadow: 0 18px 45px rgba(15, 23, 42, 0.08);
      --radius-lg: 28px;
      --radius-md: 20px;
      --radius-sm: 14px;
      --page: min(1040px, calc(100% - 32px));
      --sans: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    * {
      box-sizing: border-box;
    }

    html {
      scroll-behavior: smooth;
    }

    body {
      margin: 0;
      font-family: var(--sans);
      color: var(--text);
      background:
        radial-gradient(circle at top, rgba(15, 23, 42, 0.05), transparent 28rem),
        linear-gradient(180deg, #ffffff 0%, var(--bg) 100%);
      line-height: 1.5;
    }

    a {
      color: inherit;
    }

    .page {
      width: var(--page);
      margin: 0 auto;
    }

    .site-header {
      padding: 22px 0 0;
    }

    .brand {
      display: inline-flex;
      align-items: center;
      gap: 12px;
      text-decoration: none;
      font-weight: 800;
      letter-spacing: -0.03em;
    }

    .brand-mark {
      width: 40px;
      height: 40px;
      border-radius: 12px;
      display: grid;
      place-items: center;
      background: var(--accent);
      color: #ffffff;
      font-size: 0.95rem;
    }

    main {
      padding: 52px 0 72px;
    }

    .hero {
      display: grid;
      gap: 18px;
      margin-bottom: 40px;
    }

    .topic-slug {
      display: inline-flex;
      align-items: center;
      width: fit-content;
      padding: 7px 11px;
      border-radius: 999px;
      background: var(--accent-soft);
      color: var(--muted);
      font-size: 0.8rem;
      font-weight: 700;
      letter-spacing: 0.04em;
      text-transform: uppercase;
    }

    h1,
    h2 {
      margin: 0;
      letter-spacing: -0.05em;
      line-height: 1;
    }

    h1 {
      font-size: clamp(2.8rem, 7vw, 5.4rem);
      max-width: 10ch;
    }

    .hero-copy {
      max-width: 58ch;
      color: var(--muted);
      font-size: 1.05rem;
      margin: 0;
    }

    .topics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 18px;
    }

    .topic-card {
      padding: 22px;
      border-radius: var(--radius-md);
      background: rgba(255, 255, 255, 0.92);
      border: 1px solid var(--border);
      box-shadow: var(--shadow);
      display: grid;
      gap: 14px;
      min-height: 220px;
    }

    .topic-card h2 {
      font-size: 1.45rem;
    }

    .topic-card h2 a {
      text-decoration: none;
    }

    .topic-card h2 a:hover,
    .topic-card h2 a:focus-visible,
    .topic-link:hover,
    .topic-link:focus-visible {
      text-decoration: underline;
      outline: none;
    }

    .topic-description {
      margin: 0;
      color: var(--muted);
      flex: 1;
    }

    .topic-link {
      text-decoration: none;
      font-weight: 700;
    }

    .footer-note {
      margin-top: 28px;
      color: var(--muted);
      font-size: 0.92rem;
    }

    code {
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 0.95em;
    }

    @media (max-width: 640px) {
      main {
        padding-top: 36px;
      }

      .topic-card {
        min-height: unset;
      }
    }
  </style>
</head>
<body>
  <div class="page">
    <header class="site-header">
      <a class="brand" href="./" aria-label="Learning.Faster homepage">
        <span class="brand-mark">LF</span>
        <span>Learning.Faster</span>
      </a>
    </header>

    <main>
      <section class="hero" aria-labelledby="home-title">
        <h1 id="home-title">Un topic, una pagina.</h1>
        <p class="hero-copy">
          Homepage generata automaticamente dai contenuti presenti in <code>docs\topics\</code>.
        </p>
      </section>

      <section aria-label="Topics pubblicati">
        <div class="topics-grid">
$topicCards
        </div>
      </section>

      <p class="footer-note">
        Per aggiungere un nuovo topic, crea <code>docs\topics\nome-topic\index.html</code>.
      </p>
    </main>
  </div>
</body>
</html>
"@

[System.IO.File]::WriteAllText($outputPath, $html, [System.Text.UTF8Encoding]::new($false))
Write-Host "Generated homepage: $outputPath"
