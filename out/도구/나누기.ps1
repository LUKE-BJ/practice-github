# 읽기.ps1이 만든 원문에서 사업 번호별로 쪽을 나눠 out/중간기록/2_사업정리.md를 만든다.
# 정리 항목이 정해지지 않았으므로(〔확인필요〕) 사업명·소관 단·PDF 쪽 범위와 원문 그대로만 싣는다. 요약·재작성은 하지 않는다.
param(
    [int]$From = 1,
    [int]$To = 10,
    [string]$OutDir = (Join-Path (Get-Location).Path 'out\중간기록')
)
$ErrorActionPreference = 'Stop'
$txtPath = (Get-ChildItem -LiteralPath $OutDir -Filter '1_원문_*.txt' | Select-Object -First 1).FullName
$pages = ([System.IO.File]::ReadAllText($txtPath, [System.Text.Encoding]::UTF8)) -split "`f"

# 목차(앞 4쪽)에서 사업 번호 → 사업명
$toc = ($pages[0..3] -join "`n")
$titles = @{}
foreach ($m in [regex]::Matches($toc, '(?m)^\s*(\d{1,3})\.\s+(.+?)\s*$')) {
    $n = [int]$m.Groups[1].Value
    if ($n -le 400 -and -not $titles.ContainsKey($n)) { $titles[$n] = $m.Groups[2].Value }
}

function Find-StartPage([int]$n) {
    $compact = ($titles[$n] -replace '\s+', '')
    $key = $compact.Substring(0, [Math]::Min(8, $compact.Length))
    for ($i = 4; $i -lt $pages.Count; $i++) {
        foreach ($l in ($pages[$i] -split "`n" | Select-Object -First 6)) {
            if ($l -match "^\s*$n\s+\S" -and (($l -replace '\s+', '') -like "$n*$key*")) { return $i }
        }
    }
    return -1
}

$starts = @{}
foreach ($n in $From..($To + 1)) { $starts[$n] = Find-StartPage $n }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# 2. 사업 정리 (사업 $From~$To)")
[void]$sb.AppendLine()
[void]$sb.AppendLine("- 원문 파일: $(Split-Path $txtPath -Leaf)")
[void]$sb.AppendLine('- 쪽 번호는 PDF 쪽(1부터) 기준이다. 사업 번호와 사업명은 목차, 시작 쪽은 본문 첫머리에서 찾았다.')
[void]$sb.AppendLine('- 정리 항목은 정해지지 않았다(〔확인필요〕). 그래서 원문을 요약하거나 고쳐 쓰지 않고 그대로 싣는다.')
[void]$sb.AppendLine()
$index = @()
foreach ($n in $From..$To) {
    $s = $starts[$n]; $e = $starts[$n + 1] - 1
    if ($s -lt 0 -or $starts[$n + 1] -lt 0) {
        [void]$sb.AppendLine("## 사업 $n. $($titles[$n])"); [void]$sb.AppendLine(); [void]$sb.AppendLine('본문에서 시작 쪽을 찾지 못했다. 〔확인필요〕'); [void]$sb.AppendLine(); continue
    }
    $first = ($pages[$s] -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1).Trim()
    $index += [pscustomobject]@{ 번호 = $n; 사업명 = $titles[$n]; 소관 = $first; 시작 = $s + 1; 끝 = $e + 1 }
    [void]$sb.AppendLine("## 사업 $n. $($titles[$n])")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("- 소관(본문 첫머리 표기): $first")
    [void]$sb.AppendLine("- PDF 쪽 범위: $($s + 1)~$($e + 1)쪽")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('### 원문')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('~~~text')
    for ($i = $s; $i -le $e; $i++) { [void]$sb.AppendLine("[PDF $($i + 1)쪽]"); [void]$sb.AppendLine($pages[$i].TrimEnd()) }
    [void]$sb.AppendLine('~~~')
    [void]$sb.AppendLine()
}
[System.IO.File]::WriteAllText((Join-Path $OutDir '2_사업정리.md'), $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
$index | Format-Table -AutoSize | Out-String -Width 200
