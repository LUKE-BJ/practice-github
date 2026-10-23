# raw/의 사업 자료에서 글자만 꺼내 out/중간기록/에 저장한다. (설치 없음: PowerShell 기본 기능 + 이미 있는 pdftotext)
# raw/ 파일은 읽기 전용으로만 연다. 쓰기는 OutDir 안에만 한다.
param(
    [string]$RawDir = (Join-Path (Get-Location).Path 'raw'),
    [string]$OutDir = (Join-Path (Get-Location).Path 'out\중간기록'),
    [switch]$Layout
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$pdftotext = 'C:\Program Files\Git\mingw64\bin\pdftotext.exe'
if (-not (Test-Path -LiteralPath $pdftotext)) {
    $cmd = Get-Command pdftotext -ErrorAction SilentlyContinue
    $pdftotext = if ($cmd) { $cmd.Source } else { $null }
}

function Get-ZipXmlText([string]$Path, [string]$EntryPattern, [string]$ParaEnd, [string]$TextRegex) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $sb = New-Object System.Text.StringBuilder
        $entries = $zip.Entries | Where-Object { $_.FullName -match $EntryPattern } | Sort-Object FullName
        foreach ($e in $entries) {
            $reader = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
            $xml = $reader.ReadToEnd(); $reader.Close()
            foreach ($para in ($xml -split $ParaEnd)) {
                $line = ([regex]::Matches($para, $TextRegex) | ForEach-Object { [System.Net.WebUtility]::HtmlDecode($_.Groups[1].Value) }) -join ''
                if ($line.Trim()) { [void]$sb.AppendLine($line) }
            }
        }
        return $sb.ToString()
    } finally { $zip.Dispose() }
}

$rows = @()
$files = Get-ChildItem -LiteralPath $RawDir -File | Sort-Object Name
foreach ($f in $files) {
    $ext = $f.Extension.ToLower()
    $outTxt = Join-Path $OutDir ("1_원문_" + [IO.Path]::GetFileNameWithoutExtension($f.Name) + '.txt')
    $status = ''; $chars = 0
    try {
        switch ($ext) {
            '.pdf' {
                if (-not $pdftotext) { $status = '읽기 불가: pdftotext 없음'; break }
                $args = @('-enc', 'UTF-8'); if ($Layout) { $args += '-layout' }
                & $pdftotext @args $f.FullName $outTxt
                if ($LASTEXITCODE -ne 0) { $status = "읽기 불가: pdftotext 종료코드 $LASTEXITCODE"; break }
                $status = '성공'
            }
            '.hwpx' {
                $t = Get-ZipXmlText $f.FullName '^Contents/section\d+\.xml$' '</hp:p>' '<hp:t[^>]*>(.*?)</hp:t>'
                [System.IO.File]::WriteAllText($outTxt, $t, (New-Object System.Text.UTF8Encoding($false)))
                $status = '성공'
            }
            '.docx' {
                $t = Get-ZipXmlText $f.FullName '^word/document\.xml$' '</w:p>' '<w:t[^>]*>(.*?)</w:t>'
                [System.IO.File]::WriteAllText($outTxt, $t, (New-Object System.Text.UTF8Encoding($false)))
                $status = '성공'
            }
            '.hwp'  { $status = '읽기 불가: 구형 한글(.hwp)은 설치 없이 읽을 수 없음 〔확인필요〕' }
            default { $status = "읽기 불가: 지원하지 않는 형식($ext)" }
        }
        if ($status -eq '성공') { $chars = ([System.IO.File]::ReadAllText($outTxt, [System.Text.Encoding]::UTF8)).Length }
    } catch {
        $status = '읽기 불가: ' + $_.Exception.Message
    }
    $rows += [pscustomobject]@{ 파일 = $f.Name; 형식 = $ext; 결과 = $status; 글자수 = $chars; 원문 = $(if ($status -eq '성공') { Split-Path $outTxt -Leaf } else { '' }) }
}

$md = @('# 1. 읽기 결과', '', '| 파일 | 형식 | 결과 | 글자 수 | 원문 파일 |', '|---|---|---|---|---|')
foreach ($r in $rows) { $md += "| $($r.파일) | $($r.형식) | $($r.결과) | $($r.글자수) | $($r.원문) |" }
[System.IO.File]::WriteAllText((Join-Path $OutDir '1_읽기결과.md'), (($md -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
$rows | Format-Table -AutoSize | Out-String -Width 200
