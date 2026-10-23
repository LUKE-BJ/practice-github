# out/의 .md에 에이전트가 쓴 판정(합격·불합격 등)이 있는지 기계적으로 확인한다. 읽기 전용이며 raw/는 보지 않는다.
# 규칙: 결과 파일에는 측정값만 적고, 표의 '판정' 칸은 비워 둔다. 판정은 사용자가 한다.
# 확인하는 것: (1) 머리글에 '판정'이 있는 표에서 그 칸이 비어 있어야 한다. (2) '판정: 합격'처럼 판정 문구가 붙은 줄이 없어야 한다.
# 한계: 문장 속에 섞인 "통과했다" 같은 표현은 잡지 못한다. out/도구/ 안의 파일은 검사하지 않는다.
# 종료 코드: 0 = 위반 없음, 1 = 위반 있음
param(
    [string]$OutDir = (Join-Path (Get-Location).Path 'out')
)
$ErrorActionPreference = 'Stop'
$verdict = '판정\s*[:：]\s*(합격|불합격|통과|미통과|OK|PASS|FAIL)'
$skipDir = (Join-Path $OutDir '도구') + '\'
$files = Get-ChildItem -LiteralPath $OutDir -Recurse -File -Filter '*.md' | Where-Object { -not $_.FullName.StartsWith($skipDir) }

$violations = New-Object System.Collections.Generic.List[string]
foreach ($f in $files) {
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
    $col = -1                                   # -1: 표 밖, -2: 판정 열이 없는 표, 0 이상: 판정 열 번호
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $t = $line.Trim()
        if ($t.StartsWith('|')) {
            if ($t.EndsWith('|') -and $t.Length -ge 2) { $inner = $t.Substring(1, $t.Length - 2) } else { $inner = $t.Substring(1) }
            $cells = @($inner -split '\|' | ForEach-Object { $_.Trim() })
            if ($col -eq -1) {                  # 표의 첫 줄 = 머리글
                $idx = [array]::IndexOf($cells, '판정')
                $col = if ($idx -ge 0) { $idx } else { -2 }
                continue
            }
            if ($t -match '^\|[\s\-:|]+\|?$') { continue }   # 구분선
            if ($col -ge 0 -and $col -lt $cells.Count -and $cells[$col] -ne '') {
                $violations.Add("$($f.Name):$($i + 1): 판정 칸이 비어 있지 않음 -> '$($cells[$col])'")
            }
        } else {
            $col = -1
        }
        if ($line -match $verdict) {
            $violations.Add("$($f.Name):$($i + 1): 판정 문구 -> '$($Matches[0])'")
        }
    }
}

"검사한 파일: $($files.Count)개 (대상 폴더: $OutDir)"
if ($violations.Count -eq 0) {
    '위반 없음'
    exit 0
}
"위반 $($violations.Count)건"
$violations | ForEach-Object { '  ' + $_ }
exit 1
