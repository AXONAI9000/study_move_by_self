# Day 32 - MEV策略与防护
# 部署和测试脚本

# 编译项目
Write-Host "=== 编译 Move 项目 ===" -ForegroundColor Green
aptos move compile --save-metadata

if ($LASTEXITCODE -ne 0) {
    Write-Host "编译失败！" -ForegroundColor Red
    exit 1
}

Write-Host "编译成功！" -ForegroundColor Green

# 运行测试
Write-Host "`n=== 运行测试 ===" -ForegroundColor Green
aptos move test

if ($LASTEXITCODE -ne 0) {
    Write-Host "测试失败！" -ForegroundColor Red
    exit 1
}

Write-Host "所有测试通过！" -ForegroundColor Green

# 显示统计
Write-Host "`n=== 项目统计 ===" -ForegroundColor Cyan
$moveFiles = Get-ChildItem -Path "sources" -Filter "*.move" -Recurse
Write-Host "Move 文件数量: $($moveFiles.Count)"

$totalLines = 0
foreach ($file in $moveFiles) {
    $lines = (Get-Content $file.FullName | Measure-Object -Line).Lines
    $totalLines += $lines
    Write-Host "  - $($file.Name): $lines 行"
}
Write-Host "总代码行数: $totalLines" -ForegroundColor Yellow

Write-Host "`n=== 完成！===" -ForegroundColor Green
Write-Host "你现在可以开始实践任务了！"
