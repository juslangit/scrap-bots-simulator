# Packs the Luau files in src\ into ScrapBots.rbxlx, which Roblox Studio opens directly.
# If Assets.rbxmx is present (Toolbox models saved from Studio), it is packed in as ReplicatedStorage.Assets.
# Run:  powershell -ExecutionPolicy Bypass -File build.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ref = 0

function New-Item-Xml([string]$class, [string]$name, [string]$inner) {
    $script:ref++
    return '<Item class="{0}" referent="RBX{1}"><Properties><string name="Name">{2}</string></Properties>{3}</Item>' -f $class, $script:ref, $name, $inner
}

function New-Script-Xml([string]$class, [string]$name, [string]$file) {
    $code = [IO.File]::ReadAllText((Join-Path $root "src\$file"))
    if ($code.Contains(']]>')) { throw "$file contains ']]>' which cannot be stored in the place file." }
    $script:ref++
    return '<Item class="{0}" referent="RBX{1}"><Properties><string name="Name">{2}</string><ProtectedString name="Source"><![CDATA[{3}]]></ProtectedString></Properties></Item>' -f $class, $script:ref, $name, $code
}

# Toolbox models. Any script inside them is dropped here, so a free model can never run code in the game.
$assets = ''
$shared = ''
$assetsPath = Join-Path $root 'Assets.rbxmx'
if (Test-Path $assetsPath) {
    $doc = New-Object Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($assetsPath)
    $scripts = @($doc.SelectNodes("//Item[@class='Script' or @class='LocalScript' or @class='ModuleScript']"))
    foreach ($node in $scripts) { [void]$node.ParentNode.RemoveChild($node) }
    $folder = $doc.SelectSingleNode("/roblox/Item[@class='Folder']")
    if (-not $folder) { throw 'Assets.rbxmx must hold one Folder named Assets.' }
    $assets = $folder.OuterXml
    $sharedNode = $doc.SelectSingleNode('/roblox/SharedStrings')
    if ($sharedNode) { $shared = $sharedNode.OuterXml }
    Write-Output ("Packed Assets.rbxmx ({0} scripts removed)" -f $scripts.Count)
}

$replicated = New-Item-Xml 'ReplicatedStorage' 'ReplicatedStorage' (
    (New-Script-Xml 'ModuleScript' 'Config' 'Config.lua') +
    (New-Script-Xml 'ModuleScript' 'Props' 'Props.lua') +
    $assets)

$server = New-Item-Xml 'ServerScriptService' 'ServerScriptService' (
    (New-Script-Xml 'ModuleScript' 'Data' 'Data.lua') +
    (New-Script-Xml 'ModuleScript' 'World' 'World.lua') +
    (New-Script-Xml 'ModuleScript' 'Bots' 'Bots.lua') +
    (New-Script-Xml 'Script' 'Main' 'Main.server.lua'))

$starter = New-Item-Xml 'StarterPlayer' 'StarterPlayer' (
    New-Item-Xml 'StarterPlayerScripts' 'StarterPlayerScripts' (
        (New-Script-Xml 'LocalScript' 'Hud' 'Hud.client.lua') +
        (New-Script-Xml 'LocalScript' 'Inventory' 'Inventory.client.lua') +
        (New-Script-Xml 'LocalScript' 'BotFollow' 'BotFollow.client.lua') +
        (New-Script-Xml 'LocalScript' 'Rebirth' 'Rebirth.client.lua') +
        (New-Script-Xml 'LocalScript' 'Dev' 'Dev.client.lua')))

$xml = '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">' +
    $replicated + $server + $starter + $shared + '</roblox>'

$out = Join-Path $root 'ScrapBots.rbxlx'
[IO.File]::WriteAllText($out, $xml, (New-Object Text.UTF8Encoding($false)))
Write-Output "Built $out"
