# Builds ThrowPortalsForCreatures.rbxlx from src/ (same mapping as default.project.json).
# Run:  powershell -ExecutionPolicy Bypass -File .\build-place.ps1
#       add -Test to build ThrowPortalsForCreatures_Test.rbxlx with the automated play-test scripts
#       add -Sanctuary for the focused lobby/nine-portal test build (isolated Studio data)
param([switch]$Test, [switch]$Sanctuary)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root "src"
$isTestBuild = $Test -or $Sanctuary
$out = Join-Path $root ($(if ($Sanctuary) { "ThrowPortalsForCreatures_SanctuaryTest.rbxlx" } elseif ($Test) { "ThrowPortalsForCreatures_Test.rbxlx" } else { "ThrowPortalsForCreatures.rbxlx" }))
$script:ref = 0
function Next-Ref { $script:ref++; return "RBX$($script:ref)" }
function Esc([string]$s) { return [System.Security.SecurityElement]::Escape($s) }

function Script-Item([System.IO.FileInfo]$f) {
    $name = $f.Name
    if ($name -like "*.server.lua") { $class = "Script"; $name = $name -replace "\.server\.lua$", "" }
    elseif ($name -like "*.client.lua") { $class = "LocalScript"; $name = $name -replace "\.client\.lua$", "" }
    else { $class = "ModuleScript"; $name = $name -replace "\.lua$", "" }
    $code = [System.IO.File]::ReadAllText($f.FullName).Replace("`r`n", "`n")
    $code = $code.Replace("]]>", "]]]]><![CDATA[>")
    return "<Item class=`"$class`" referent=`"$(Next-Ref)`"><Properties><string name=`"Name`">$(Esc $name)</string><ProtectedString name=`"Source`"><![CDATA[$code]]></ProtectedString></Properties></Item>`n"
}

function Folder-Item([string]$path, [string]$name) {
    $sb = "<Item class=`"Folder`" referent=`"$(Next-Ref)`"><Properties><string name=`"Name`">$(Esc $name)</string></Properties>`n"
    foreach ($f in Get-ChildItem $path -File -Filter *.lua | Sort-Object Name) { $sb += Script-Item $f }
    foreach ($d in Get-ChildItem $path -Directory | Sort-Object Name) { $sb += Folder-Item $d.FullName $d.Name }
    return $sb + "</Item>`n"
}

function Service([string]$class, [string]$inner) {
    return "<Item class=`"$class`" referent=`"$(Next-Ref)`"><Properties><string name=`"Name`">$class</string></Properties>`n$inner</Item>`n"
}

$xml = "<roblox xmlns:xmime=`"http://www.w3.org/2005/05/xmlmime`" version=`"4`">`n"
$marker = ""
if ($isTestBuild) {
    $markerName = if ($Sanctuary) { "SanctuaryTest" } else { "AutoTest" }
    $marker = "<Item class=`"BoolValue`" referent=`"$(Next-Ref)`"><Properties><string name=`"Name`">$markerName</string><bool name=`"Value`">true</bool></Properties></Item>"
}
$xml += "<Item class=`"Workspace`" referent=`"$(Next-Ref)`"><Properties><string name=`"Name`">Workspace</string><bool name=`"StreamingEnabled`">false</bool></Properties>$marker</Item>`n"
$xml += "<Item class=`"Lighting`" referent=`"$(Next-Ref)`"><Properties><string name=`"Name`">Lighting</string><token name=`"Technology`">4</token><token name=`"LightingStyle`">0</token><bool name=`"PrioritizeLightingQuality`">true</bool><bool name=`"GlobalShadows`">true</bool></Properties></Item>`n"
$xml += Service "ReplicatedStorage" (Folder-Item "$src\ReplicatedStorage\Shared" "Shared")
$sss = Folder-Item "$src\ServerScriptService\Server" "Server"
if ($isTestBuild) { foreach ($f in Get-ChildItem "$root\tests\server" -File -Filter *.lua) { $sss += Script-Item $f } }
$xml += Service "ServerScriptService" $sss
$sps = "<Item class=`"StarterPlayerScripts`" referent=`"$(Next-Ref)`"><Properties><string name=`"Name`">StarterPlayerScripts</string></Properties>`n"
$sps += Folder-Item "$src\StarterPlayer\StarterPlayerScripts\Client" "Client"
if ($isTestBuild) { foreach ($f in Get-ChildItem "$root\tests\client" -File -Filter *.lua) { $sps += Script-Item $f } }
$sps += "</Item>`n"
$xml += Service "StarterPlayer" $sps
$xml += "</roblox>`n"
[System.IO.File]::WriteAllText($out, $xml, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "Wrote $out ($([math]::Round((Get-Item $out).Length / 1KB)) KB)"
