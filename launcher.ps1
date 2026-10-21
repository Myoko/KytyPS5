param([switch]$DryRun)
# A small settings window in front of run-windows.ps1 and precompile-windows.ps1 (launcher.cmd opens it). The
# settings and the console language names follow the KytyPS5 launcher (src/launcher, by the KytyPS5 developers);
# they are kept in launcher-settings.json next to this script. -DryRun prints the commands without a window.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
# cmd.exe by its full path: Start-Process with a bare "cmd" opens whatever "cmd" it finds first, and a file of that
# name without an extension (in the working folder or on the PATH) made Windows ask which app should open it (issue #47).
$cmd = if ($env:ComSpec -and (Test-Path -LiteralPath $env:ComSpec)) { $env:ComSpec } else { Join-Path ([Environment]::SystemDirectory) 'cmd.exe' }
# Windows PowerShell by its path too: on a PC whose PATH lacks its folder, cmd.exe did not know "powershell" (issue #55).
$powershellExe = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
$powershellCommand = if (Test-Path -LiteralPath $powershellExe) { "`"$powershellExe`"" } else { 'powershell' }
$settingsPath = Join-Path $root 'launcher-settings.json'
$languages = '日语', '英语（美国）', '法语（法国）', '西班牙语（西班牙）', '德语', '意大利语', '荷兰语',
	'葡萄牙语（葡萄牙）', '俄语', '韩语', '中文（繁体）', '中文（简体）', '芬兰语', '瑞典语',
	'丹麦语', '挪威语', '波兰语', '葡萄牙语（巴西）', '英语（英国）', '土耳其语', '西班牙语（拉丁美洲）',
	'阿拉伯语', '法语（加拿大）', '捷克语', '匈牙利语', '希腊语', '罗马尼亚语', '泰语', '越南语', '印尼语'
$resolutions = '1280x720', '1920x1080', '2560x1440', '3840x2160', '2560x1080', '3440x1440', '3840x1600', '5120x2160',
	'3840x1080', '5120x1440'
# The height Demon's Souls renders its 3D at (run-windows.ps1 -RenderHeight); its output and UI stay 3840x2160.
$renderHeights = '2160 (native 4K)', '1800', '1620', '1512 (PS5 Pro)', '1440 (PS5)', '1296', '1152', '1080', '900'
# What makes the 3840x2160 image of the 3D (run-windows.ps1 -Upscaler): the game's TAA and stretch (the PS5's), or DLSS in
# place of Sony's PS5 Pro upscaler on the game's PS5 Pro path (NVIDIA's Streamline runtime, as frame generation).
$upscalers = '游戏自带 (PS5)', 'DLSS（PS5 Pro 路径）'
# Demon's Souls' own settings for what a frame draws (run-windows.ps1 -Quality): simpler shadows and distant detail.
$qualities = 'Standard (PS5)', 'Low', 'Lowest'
# DLSS frame generation (run-windows.ps1 -FrameGen: the generated frames per rendered one, the multiplier less one).
$frameGens = '关闭', '2x', '3x', '4x', '5x', '6x'
# The emulator's own panel at the top right of the game image (KYTY_FPS_HUD 0, 1, 2).
$overlays = '关闭', '帧率', '详细'

$settings = [ordered]@{ game = ''; resolution = '2560x1440'; fullscreen = $false; aspect = $true; language = 1; redzone = $true;
	ecores = $false; cheats = $true; fps120 = $false; render = 1440; ratio = '16:9'; quality = 'standard'; vsync = $false; hdr = $false; framegen = 0; hud = 0; streamline = ''; safegpu = $false; upscaler = ''; fsr = $false }
if (Test-Path $settingsPath) {
	$saved = Get-Content $settingsPath -Raw | ConvertFrom-Json
	foreach ($property in $saved.PSObject.Properties) { if ($settings.Contains($property.Name)) { $settings[$property.Name] = $property.Value } }
}
if (!$settings.game -and (Test-Path "$root\game-path.txt")) { $settings.game = (Get-Content "$root\game-path.txt" -TotalCount 1).Trim() }

# The efficiency cores (the lowest efficiency class of a hybrid CPU) as an affinity mask, or 0.
function Get-EfficiencyMask {
	Add-Type -Namespace KytyLauncher -Name CpuSets -MemberDefinition @'
[DllImport("kernel32.dll")]
static extern bool GetSystemCpuSetInformation(IntPtr information, uint length, out uint returned, IntPtr process, uint flags);
// Group 0's logical processors as (index, efficiency class) pairs.
public static int[] Query() {
	var result = new System.Collections.Generic.List<int>();
	uint length;
	GetSystemCpuSetInformation(IntPtr.Zero, 0, out length, IntPtr.Zero, 0);
	if (length == 0) return result.ToArray();
	IntPtr buffer = Marshal.AllocHGlobal((int)length);
	try {
		if (!GetSystemCpuSetInformation(buffer, length, out length, IntPtr.Zero, 0)) return result.ToArray();
		for (int offset = 0; offset < length; offset += Marshal.ReadInt32(buffer, offset)) {
			if (Marshal.ReadInt32(buffer, offset + 4) != 0 || Marshal.ReadInt16(buffer, offset + 12) != 0) continue;
			result.Add(Marshal.ReadByte(buffer, offset + 14));
			result.Add(Marshal.ReadByte(buffer, offset + 18));
		}
	} finally {
		Marshal.FreeHGlobal(buffer);
	}
	return result.ToArray();
}
'@
	$values = [KytyLauncher.CpuSets]::Query()
	$sets = for ($i = 0; $i + 1 -lt $values.Count; $i += 2) { [pscustomobject]@{ Cpu = $values[$i]; Class = $values[$i + 1] } }
	if (@($sets | ForEach-Object Class | Sort-Object -Unique).Count -lt 2) { return [int64]0 }
	$slowest = ($sets | Measure-Object Class -Minimum).Minimum
	$mask = [int64]0
	foreach ($set in $sets | Where-Object { $_.Class -eq $slowest -and $_.Cpu -lt 63 }) { $mask = $mask -bor ([int64]1 -shl $set.Cpu) }
	return $mask
}
$efficiencyMask = Get-EfficiencyMask
# Frame generation needs NVIDIA's Streamline runtime, which no release ships: the Streamline SDK
# (github.com/NVIDIA-RTX/Streamline/releases) chosen with "Streamline..." (settings: streamline), else a "streamline"
# folder next to the emulator, else the SDK beside a local build (_Build\deps\streamline\sdk). The emulator loads
# only NVIDIA's own sl.interposer.dll (run-windows -StreamlineDir).
$exe = if (Test-Path "$root\kyty_emulator.exe") { "$root\kyty_emulator.exe" } else { "$root\_Build\windows\kyty_emulator.exe" }
$streamlineSdkUrl = 'https://github.com/NVIDIA-RTX/Streamline/releases'
# The runtime's folder in $dir (the folder itself or its bin\x64) when its sl.interposer.dll is signed by NVIDIA;
# $null otherwise.
function Find-Streamline([string]$dir) {
	if (!$dir) { return $null }
	foreach ($folder in @($dir, (Join-Path $dir 'bin\x64'))) {
		$file = Join-Path $folder 'sl.interposer.dll'
		if (Test-Path -LiteralPath $file) {
			$signature = Get-AuthenticodeSignature -LiteralPath $file
			if ($signature.Status -eq 'Valid' -and $signature.SignerCertificate.Subject -match 'O=NVIDIA Corporation') { return $folder }
			return $null
		}
	}
	return $null
}
function Resolve-Streamline {
	if ($settings.streamline) { return Find-Streamline $settings.streamline }
	if ($env:KYTY_STREAMLINE_DIR) { return Find-Streamline $env:KYTY_STREAMLINE_DIR }
	foreach ($dir in @((Join-Path (Split-Path $exe) 'streamline'), (Join-Path (Split-Path (Split-Path $exe)) 'deps\streamline\sdk'))) {
		$found = Find-Streamline $dir
		if ($found) { return $found }
	}
	return $null
}
$streamline = Resolve-Streamline
$frameGenAvailable = [bool]$streamline
# FSR 3.1 frame generation (run-windows -Fsr), any GPU: AMD's signed amd_fidelityfx_vk.dll next to the emulator.
$fsrDll = Join-Path (Split-Path $exe) 'amd_fidelityfx_vk.dll'
$fsrAvailable = (Test-Path -LiteralPath $fsrDll) -and
	((Get-AuthenticodeSignature -LiteralPath $fsrDll).SignerCertificate.Subject -match 'O=Advanced Micro Devices')

# The emulator's own launcher (src/launcher) applies _Patches\<title id>.json by itself; run-windows.ps1
# passes one only when told to, so the title id is read here the way the title label reads it and the
# file beside it is offered. Empty when the game has no such patch, so -Patch is then not passed.
# The title id is remembered per path: for a .zar archive it takes one helper run (Read-GameParam).
$cheatTitleIds = @{}
function Get-CheatFile([string]$game) {
	if (!$game) { return '' }
	try {
		if (!$cheatTitleIds.ContainsKey($game)) {
			$param = Read-GameParam $game
			$cheatTitleIds[$game] = if ($param -and $param.titleId) { [string]$param.titleId } else { '' }
		}
		$id = $cheatTitleIds[$game]
		if (!$id) { return '' }
		$file = Join-Path $root "_Patches\$id.json"
		if (Test-Path -LiteralPath $file) { return $file }
	} catch {}
	return ''
}
# ── 金手指（_Patches\<title id>.json）────────────────────────────────────────────
# The engine already honours mods[].enabled (src/loader/gamePatch.cpp reads it), so the launcher can
# turn each entry on and off on its own instead of only passing or not passing the whole file.
function Read-CheatFile([string]$file) {
	# The file is UTF-8 and its names are Chinese. Get-Content would read it as ANSI, which turns some
	# characters into '?' and can break the JSON's quotes, so it is read with the encoding it was
	# written in.
	return [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
}

function Get-CheatData([string]$file) {
	return (Read-CheatFile $file | ConvertFrom-Json)
}

function Get-CheatCounts([string]$file) {
	$counts = @{ on = 0; total = 0 }
	if (!$file -or !(Test-Path -LiteralPath $file)) { return $counts }
	try {
		$mods = @((Get-CheatData $file).mods)
		$counts.total = $mods.Count
		foreach ($mod in $mods) {
			if ($mod.enabled -ne $false) { $counts.on++ }
		}
	} catch {}
	return $counts
}

function Save-CheatMods([string]$file, [string]$before, [bool[]]$wanted) {
	# Refuse to write over a file that changed while the dialog was open.
	if ((Read-CheatFile $file) -ne $before) { return 'file-changed' }
	$data = Read-CheatFile $file | ConvertFrom-Json
	$mods = @($data.mods)
	if ($mods.Count -ne $wanted.Count) { return 'count-changed' }
	for ($i = 0; $i -lt $mods.Count; $i++) {
		$mods[$i] | Add-Member -NotePropertyName enabled -NotePropertyValue ([bool]$wanted[$i]) -Force
	}
	$data.mods = $mods
	$json = $data | ConvertTo-Json -Depth 32
	Copy-Item -LiteralPath $file -Destination ($file + '.bak') -Force
	[System.IO.File]::WriteAllText($file, $json, (New-Object System.Text.UTF8Encoding($false)))
	# Read the file back: if it no longer holds the same names and flags, put the backup back.
	try {
		$check = @((Read-CheatFile $file | ConvertFrom-Json).mods)
		if ($check.Count -ne $mods.Count) { throw 'count' }
		for ($i = 0; $i -lt $check.Count; $i++) {
			if ([string]$check[$i].name -ne [string]$mods[$i].name) { throw 'name' }
			if ([bool]$check[$i].enabled -ne [bool]$wanted[$i]) { throw 'enabled' }
		}
	} catch {
		Copy-Item -LiteralPath ($file + '.bak') -Destination $file -Force
		return 'verify-failed'
	}
	return ''
}

function Show-CheatDialog([string]$file) {
	$data = $null
	try { $data = Get-CheatData $file } catch {
		[void][System.Windows.Forms.MessageBox]::Show("读不出金手指文件：`n$file`n`n$($_.Exception.Message)", '金手指')
		return
	}
	$mods = @($data.mods)
	if ($mods.Count -eq 0) {
		[void][System.Windows.Forms.MessageBox]::Show("这个文件里没有金手指条目：`n$file", '金手指')
		return
	}
	$before = Read-CheatFile $file

	$cheatForm = New-Object System.Windows.Forms.Form -Property @{
		Text = '金手指 - ' + $(if ($data.name) { [string]$data.name } else { [string]$data.id })
		StartPosition = 'CenterParent'
		FormBorderStyle = 'FixedDialog'
		MaximizeBox = $false
		MinimizeBox = $false
		ClientSize = New-Object System.Drawing.Size(600, 480)
		Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
	}
	$cheatList = New-Object System.Windows.Forms.CheckedListBox -Property @{
		Location = New-Object System.Drawing.Point(12, 12)
		Size = New-Object System.Drawing.Size(576, 330)
		CheckOnClick = $true
	}
	foreach ($mod in $mods) { [void]$cheatList.Items.Add([string]$mod.name, ($mod.enabled -ne $false)) }
	$cheatForm.Controls.Add($cheatList)

	$cheatDesc = New-Object System.Windows.Forms.TextBox -Property @{
		Location = New-Object System.Drawing.Point(12, 348)
		Size = New-Object System.Drawing.Size(576, 78)
		Multiline = $true
		ReadOnly = $true
		ScrollBars = 'Vertical'
	}
	$cheatForm.Controls.Add($cheatDesc)

	# Event handlers run in their own scope, so what they read is kept in the script's.
	$script:cheatDialogList = $cheatList
	$script:cheatDialogDesc = $cheatDesc
	$script:cheatDialogMods = $mods
	$cheatList.Add_SelectedIndexChanged({
		$index = $script:cheatDialogList.SelectedIndex
		if ($index -ge 0) {
			$script:cheatDialogDesc.Text = [string]$script:cheatDialogMods[$index].description
		}
	})

	$all = New-Object System.Windows.Forms.Button -Property @{ Text = '全选'; Location = New-Object System.Drawing.Point(12, 436); Size = New-Object System.Drawing.Size(90, 28) }
	$all.Add_Click({
		for ($i = 0; $i -lt $script:cheatDialogList.Items.Count; $i++) { $script:cheatDialogList.SetItemChecked($i, $true) }
	})
	$none = New-Object System.Windows.Forms.Button -Property @{ Text = '全不选'; Location = New-Object System.Drawing.Point(110, 436); Size = New-Object System.Drawing.Size(90, 28) }
	$none.Add_Click({
		for ($i = 0; $i -lt $script:cheatDialogList.Items.Count; $i++) { $script:cheatDialogList.SetItemChecked($i, $false) }
	})
	$ok = New-Object System.Windows.Forms.Button -Property @{ Text = '确定'; Location = New-Object System.Drawing.Point(408, 436); Size = New-Object System.Drawing.Size(90, 28); DialogResult = 'OK' }
	$cancel = New-Object System.Windows.Forms.Button -Property @{ Text = '取消'; Location = New-Object System.Drawing.Point(504, 436); Size = New-Object System.Drawing.Size(90, 28); DialogResult = 'Cancel' }
	$cheatForm.Controls.AddRange(@($all, $none, $ok, $cancel))
	$cheatForm.AcceptButton = $ok
	$cheatForm.CancelButton = $cancel

	if ($cheatForm.ShowDialog($form) -ne 'OK') { return }

	$wanted = @()
	foreach ($i in 0..($mods.Count - 1)) { $wanted += [bool]$cheatList.GetItemChecked($i) }
	$result = Save-CheatMods $file $before $wanted
	if ($result -eq 'file-changed') {
		[void][System.Windows.Forms.MessageBox]::Show('金手指文件在对话框打开期间被改动过，这次没有写入。', '金手指')
	} elseif ($result -eq 'count-changed') {
		[void][System.Windows.Forms.MessageBox]::Show('金手指条目数量对不上，这次没有写入。', '金手指')
	} elseif ($result -eq 'verify-failed') {
		[void][System.Windows.Forms.MessageBox]::Show('写入后校验失败，已自动还原备份文件。', '金手指')
	}
}

function Get-PlayCommand {
	$size = $settings.resolution -split 'x'
	# -Prompt is left out. Its version dialog has no don't-ask-again - only the precompile offer reads
	# no-precompile-prompt.txt - so for a title run-windows.ps1 does not consider tested it would appear
	# on every launch. The precompile has its own button below, so nothing is lost.
	$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$root\run-windows.ps1`"", '-Follow',
		'-Width', $size[0], '-Height', $size[1], '-Language', $settings.language)
	if ($settings.fullscreen) { $arguments += '-Fullscreen'; if ($settings.aspect) { $arguments += '-AspectFit' } }
	if (!$settings.redzone) { $arguments += '-NoRedZone' }
	if ($settings.fps120) { $arguments += '-Fps120' }
	$dlss = $frameGenAvailable -and $settings.upscaler -eq 'dlss'
	# (With DLSS 1440 is passed too: the PS5 Pro path's own height is 1512.)
	if ([int]$settings.render -gt 0 -and ([int]$settings.render -ne 1440 -or $dlss)) { $arguments += @('-RenderHeight', [int]$settings.render) }
	if ($settings.ratio -in '21:9', '32:9') { $arguments += @('-Aspect', $settings.ratio) }
	# Presents wait for the display's refresh (Vulkan FIFO): no tearing, and G-SYNC/FreeSync displays keep adapting.
	if ($settings.vsync) { $arguments += @('-PresentMode', 'Fifo') }
# Demon's Souls' own settings for what a frame draws (run-windows.ps1 -Quality): shorter shadows, simpler distant detail;
# and smaller textures (run-windows.ps1 -TextureReduce: Low 1, Lowest 2; Standard leaves it to the emulator: 1 below
# 12 GB of video memory, else 0).
if ($settings.quality -in 'low', 'lowest') {
	$arguments += @('-Quality', $settings.quality, '-TextureReduce', $(if ($settings.quality -eq 'lowest') { 2 } else { 1 }))
}
	# HDR10 output when Windows HDR is on for the display; SDR otherwise.
	if ($settings.hdr) { $arguments += '-Hdr' }
	$fsrOn = $fsrAvailable -and $settings.fsr
	if ($fsrOn) { $arguments += '-Fsr' }
	if (!$fsrOn -and $frameGenAvailable -and [int]$settings.framegen -ge 2) { $arguments += @('-FrameGen', ([int]$settings.framegen - 1)) }
	if ($dlss) { $arguments += @('-Upscaler', 'dlss') }
	if ($frameGenAvailable -and ((!$fsrOn -and [int]$settings.framegen -ge 2) -or $dlss)) { $arguments += @('-StreamlineDir', "`"$streamline`"") }
	# The emulator's panel (KYTY_FPS_HUD) at the top right of the game image: the frame rate and frame times, or with
	# the GPU, processor and memory too.
	# Switches of the config, one -Set argument (run-windows.ps1 splits it at the commas).
	$sets = @()
	if ([int]$settings.hud -ge 1) { $sets += "KYTY_FPS_HUD=$([Math]::Min([int]$settings.hud, 2))" }
	# Safe GPU mode: no overlapping compute dispatches (KYTY_COMPUTE_CHAIN=0).
	if ($settings.safegpu) { $sets += 'KYTY_COMPUTE_CHAIN=0' }
	if ($sets.Count) { $arguments += @('-Set', ($sets -join ',')) }
	if ($settings.game) { $arguments += @('-Game', "`"$($settings.game)`"") }
	# run-windows.ps1 passes --game-patch only for -Patch, and the emulator rejects it twice, so the
	# file is added here rather than left to the emulator's own _Patches lookup.
	if ($settings.cheats) { $patch = Get-CheatFile $settings.game; if ($patch) { $arguments += @('-Patch', "`"$patch`"") } }
	# The console stays for the live log; after a crash it waits for a key.
	return "$powershellCommand " + ($arguments -join ' ') + ' & if !errorlevel! neq 0 pause'
}
function Get-PrecompileCommand([string]$switch = '') {
	$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$root\precompile-windows.ps1`"")
	if ($switch) { $arguments += $switch }
	if ($settings.ecores -and $efficiencyMask -ne 0) { $arguments += @('-Affinity', $efficiencyMask) }
	if ($settings.game) { $arguments += @('-Game', "`"$($settings.game)`"") }
	return "$powershellCommand " + ($arguments -join ' ') + ' & pause'
}
function Save-Settings { $settings | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8 }
if ($DryRun) {
	"play:       cmd /v:on /s /c `"$(Get-PlayCommand)`""
	"precompile: cmd /s /c `"$(Get-PrecompileCommand)`""
	"hints:      cmd /s /c `"$(Get-PrecompileCommand '-ExportHints')`""
	"efficiency cores: 0x{0:X}" -f $efficiencyMask
	"frame generation: $(if ($frameGenAvailable) { "NVIDIA's Streamline runtime in $streamline" } else { "no NVIDIA-signed Streamline runtime (settings: '$($settings.streamline)')" })"
	return
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace KytyLauncher -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[KytyLauncher.Dpi]::SetProcessDPIAware() | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form -Property @{
	Text = 'KytyPS5 启动器'; FormBorderStyle = 'FixedDialog'; MaximizeBox = $false; StartPosition = 'CenterScreen'
	AutoSize = $true; AutoSizeMode = 'GrowAndShrink'; Font = New-Object System.Drawing.Font('Segoe UI', 9); Padding = '12,12,12,8'
}
$grid = New-Object System.Windows.Forms.TableLayoutPanel -Property @{ ColumnCount = 2; AutoSize = $true; Dock = 'Fill' }
$form.Controls.Add($grid)
# A row: a label, then the controls side by side.
function Add-Row($label, [object[]]$controls) {
	$grid.Controls.Add((New-Object System.Windows.Forms.Label -Property @{ Text = $label; AutoSize = $true; Anchor = 'Left'; Margin = '0,6,8,6' }))
	$row = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{ AutoSize = $true; WrapContents = $false; Margin = '0,0,0,0' }
	$row.Controls.AddRange($controls)
	$grid.Controls.Add($row)
}

$game = New-Object System.Windows.Forms.TextBox -Property @{ Text = $settings.game; Width = 440 }
$browse = New-Object System.Windows.Forms.Button -Property @{ Text = '浏览…'; AutoSize = $true }
$browseZar = New-Object System.Windows.Forms.Button -Property @{ Text = '选 .zar…'; AutoSize = $true }
Add-Row '游戏目录' @($game, $browse, $browseZar)
$title = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray' }
Add-Row '' @($title)
# A game: its folder (eboot.bin and sce_sys) or the folder packed into a ZArchive (a .zar file).
function Read-GameParam([string]$game) {
	if (!$game) { return $null }
	if (Test-Path -LiteralPath "$game\sce_sys\param.json") { return Get-Content -LiteralPath "$game\sce_sys\param.json" -Raw -Encoding UTF8 | ConvertFrom-Json }
	$tool = @("$root\kyty_shader_precompile.exe", "$root\_Build\windows\kyty_shader_precompile.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
	if ($game -notmatch '\.zar$' -or !(Test-Path -LiteralPath $game -PathType Leaf) -or !$tool) { return $null }
	$copy = [IO.Path]::GetTempFileName()
	try {
		& $tool --game $game --param $copy 2>$null | Out-Null
		if ($LASTEXITCODE -eq 0) { return Get-Content -LiteralPath $copy -Raw -Encoding UTF8 | ConvertFrom-Json }
	} catch {
	} finally {
		Remove-Item -LiteralPath $copy -ErrorAction SilentlyContinue
	}
	return $null
}
function Update-Title {
	$title.Text = '请选择含 eboot.bin 与 sce_sys 的游戏目录（游戏转储），或它的 .zar 打包档'
	try {
		$json = Read-GameParam $game.Text.Trim()
		if ($json) {
			$title.Text = '{0} ({1} {2})' -f $json.localizedParameters.($json.localizedParameters.defaultLanguage).titleName,
				$json.titleId, $json.contentVersion
		}
	} catch {}
	# The cheat line is about the folder as it is being typed, not about the last saved setting.
	if ($cheatNote) {
		$patch = Get-CheatFile $game.Text.Trim()
		$cheatCounts = if ($patch) { Get-CheatCounts $patch } else { $null }
		$cheatNote.Text = if ($patch) {
			'套用 ' + [System.IO.Path]::GetFileName($patch) + "（$($cheatCounts.on)/$($cheatCounts.total) 条启用）"
		} else { '此处没有 _Patches\<title id>.json' }
	}
}
$browse.Add_Click({
	$dialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{ Description = '游戏目录（含 eboot.bin、sce_sys）' }
	if ($game.Text -and (Test-Path -LiteralPath $game.Text -PathType Container)) { $dialog.SelectedPath = $game.Text }
	if ($dialog.ShowDialog($form) -eq 'OK') { $game.Text = $dialog.SelectedPath }
})
# The game folder packed into a ZArchive (zarchive.exe <folder> <file.zar>): read without extracting it.
$browseZar.Add_Click({
	$dialog = New-Object System.Windows.Forms.OpenFileDialog -Property @{ Title = '选择打包成 ZArchive 的游戏目录'; Filter = 'ZArchive (*.zar)|*.zar' }
	if ($game.Text -and (Test-Path -LiteralPath $game.Text -PathType Leaf)) { $dialog.InitialDirectory = Split-Path $game.Text }
	if ($dialog.ShowDialog($form) -eq 'OK') { $game.Text = $dialog.FileName }
})
$game.Add_TextChanged({ Update-Title })
Update-Title

$resolution = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 160 }
$resolution.Items.AddRange($resolutions)
$resolution.SelectedItem = if ($resolutions -contains $settings.resolution) { $settings.resolution } else { '2560x1440' }
Add-Row '分辨率' @($resolution)
$fullscreen = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '全屏'; AutoSize = $true; Checked = [bool]$settings.fullscreen }
$aspect = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '保持 16:9（黑边）'; AutoSize = $true; Checked = [bool]$settings.aspect }
$aspect.Enabled = $fullscreen.Checked
$fullscreen.Add_CheckedChanged({ $aspect.Enabled = $fullscreen.Checked })
Add-Row '' @($fullscreen, $aspect)
$language = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 320 }
$language.Items.AddRange($languages)
$language.SelectedIndex = [Math]::Max(0, [Math]::Min($languages.Count - 1, [int]$settings.language))
Add-Row '主机语言' @($language)
$redzone = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '红区保护（推荐）'; AutoSize = $true; Checked = [bool]$settings.redzone }
Add-Row '' @($redzone)
$fps120 = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '最高 120 fps（游戏自身的帧；过场动画保持 60）'; AutoSize = $true; Checked = [bool]$settings.fps120 }
Add-Row '' @($fps120)
$vsync = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '垂直同步（不撕裂；自适应同步显示器保持生效）'; AutoSize = $true; Checked = [bool]$settings.vsync }
Add-Row '' @($vsync)
$hdr = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'HDR（需先在 Windows 显示设置里打开"使用 HDR"）'; AutoSize = $true; Checked = [bool]$settings.hdr }
Add-Row '' @($hdr)
# 当前画面比例的 3D 宽高比（与 run-windows.ps1 -Aspect 一致）。
function Get-RatioAspect {
	switch ((($ratio.SelectedItem -split ' ')[0])) {
		'21:9' { 64.0 / 27.0 }
		'32:9' { 32.0 / 9.0 }
		default { 16.0 / 9.0 }
	}
}
# 该比例下游戏渲染目标显存能容纳的最高渲染高度：瓦片数不超过 3840x2160 所用的（超过会开机崩或画面变红）。
function Get-MaxRenderHeight {
	$aspectValue = Get-RatioAspect
	for ($h = 2160; $h -ge 720; $h -= 8) {
		$w = [Math]::Floor($h * $aspectValue / 8.0 + 0.5) * 8
		$fits = $true
		foreach ($tile in @(@(256, 128), @(128, 128), @(128, 64), @(64, 64))) {
			$tiles = [Math]::Ceiling($w / $tile[0]) * [Math]::Ceiling($h / $tile[1])
			if ($tiles -gt [Math]::Ceiling(3840 / $tile[0]) * [Math]::Ceiling(2160 / $tile[1])) { $fits = $false }
		}
		if ($fits) { return $h }
	}
	720
}
# 只把当前比例允许的渲染高度放进下拉列表。
function Fill-RenderHeights {
	$most = Get-MaxRenderHeight
	$allowed = @($renderHeights | Where-Object { [int](($_ -split ' ')[0]) -le $most })
	$render.Items.Clear()
	$render.Items.AddRange($allowed)
}
$render = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 160 }
	Fill-RenderHeights
$render.SelectedItem = ($renderHeights | Where-Object { ($_ -split ' ')[0] -eq [string][int]$settings.render } | Select-Object -First 1)
if ($render.SelectedIndex -lt 0) { $render.SelectedItem = '1440 (PS5)' }
$renderNote = New-Object System.Windows.Forms.Label -Property @{ Text = '《恶魔之魂》的 3D；越高越清晰、越吃显卡'; AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
$upscaler = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 160; Enabled = $frameGenAvailable }
$upscaler.Items.AddRange($upscalers)
$upscaler.SelectedIndex = if ($frameGenAvailable -and $settings.upscaler -eq 'dlss') { 1 } else { 0 }
$upscalerNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
function Update-UpscalerNote {
	$upscalerNote.Text = if ($frameGenAvailable) { 'DLSS：NVIDIA RTX；1440 = 画质、1080 = 性能、2160 = DLAA' } else {
		'需要 NVIDIA 的 Streamline SDK（在「帧生成」那里选它的文件夹）' }
}
Update-UpscalerNote
(New-Object System.Windows.Forms.ToolTip -Property @{ AutoPopDelay = 30000 }).SetToolTip($upscaler,
	"游戏自带：PS5 的性能模式 —— 3D 在设定高度由游戏自己的 TAA 抗锯齿，再拉伸到 4K。`n" +
	"DLSS：走游戏自己的 PS5 Pro 模式，把索尼的上采样器（PSSR）换成 NVIDIA DLSS —— 3D 按设定高度渲染`n" +
	"（1512 时是 PS5 Pro 的 2688x1512；最低 1080），由 DLSS 生成 3840x2160，再由游戏补完到 4K（泛光、景深、HUD）。`n" +
	"比拉伸更清晰，代价是吃一些显卡性能。游戏内的电影模式仍是原生 4K、不走 DLSS。")
Add-Row '渲染高度' @($render, $renderNote)
Add-Row '上采样' @($upscaler, $upscalerNote)
$ratios = '16:9 (PS5)', '21:9', '32:9'
$ratio = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 160 }
$ratio.Items.AddRange($ratios)
$ratio.SelectedItem = ($ratios | Where-Object { ($_ -split ' ')[0] -eq [string]$settings.ratio } | Select-Object -First 1)
if ($ratio.SelectedIndex -lt 0) { $ratio.SelectedIndex = 0 }
$ratio.Add_SelectedIndexChanged({
	$kept = [string]$render.SelectedItem
	Fill-RenderHeights
	$render.SelectedItem = if ($render.Items -contains $kept) { $kept } else { $render.Items[0] }
})
$ratioNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0'
	Text = '3D 画面更宽（两侧看得更多）；HUD 保持形状、菜单会被拉伸、过场保持 16:9' }
Add-Row '画面比例' @($ratio, $ratioNote)
$quality = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 205 }
$quality.Items.AddRange($qualities)
$quality.SelectedItem = ($qualities | Where-Object { ($_ -split ' ')[0] -eq [string]$settings.quality } | Select-Object -First 1)
if ($quality.SelectedIndex -lt 0) { $quality.SelectedIndex = 0 }
$qualityNote = New-Object System.Windows.Forms.Label -Property @{ Text = '更短的阴影、更简的细节、更小的纹理；弱机上更快'; AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
$qualityTips = New-Object System.Windows.Forms.ToolTip
$qualityTips.SetToolTip($quality, "标准：PS5 的画面。显存不足 12 GB 时，大纹理省掉最大的一级（每边减半）以便放得下。`n低：更短的太阳阴影、更简单的远景细节，纹理每边减半。`n最低：阴影更短，且不再有环境遮蔽与火把阴影，纹理每边减为四分之一。")
Add-Row '画质' @($quality, $qualityNote)
$frameGen = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 160; Enabled = $frameGenAvailable }
$frameGen.Items.AddRange($frameGens)
$frameGen.SelectedItem = if ($frameGenAvailable -and [int]$settings.framegen -ge 2) { "$([int]$settings.framegen)x" } else { 'Off' }
if ($frameGen.SelectedIndex -lt 0) { $frameGen.SelectedIndex = 0 }
$frameGenFolder = New-Object System.Windows.Forms.Button -Property @{ Text = 'Streamline...'; AutoSize = $true }
$frameGenNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
function Update-FrameGenNote {
	$frameGenNote.Text = if ($frameGenAvailable) { 'DLSS；需要 NVIDIA RTX 40 或更新（3x 及以上：RTX 50）' } else {
		'需要 NVIDIA 的 Streamline SDK：下载后用「Streamline...」选择它的文件夹' }
}
Update-FrameGenNote
$frameGenTips = New-Object System.Windows.Forms.ToolTip
$frameGenTips.SetToolTip($frameGen, "Shown frames = the game's frames x the multiplier. With VSync on, they are capped at the display's refresh`n(a 60 Hz display at 2x runs the game at 30 fps). The game's frames stay at 60 with 'Up to 120 fps' too:`nframe generation needs them evenly spaced.")
$frameGenTips.SetToolTip($frameGenFolder, "The NVIDIA Streamline SDK (a release zip from $streamlineSdkUrl), unpacked: its folder or its bin\x64.`nOnly NVIDIA-signed files are used; nothing of NVIDIA's comes with the emulator.")
$frameGenFolder.Add_Click({
	$dialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
		Description = "The unpacked NVIDIA Streamline SDK ($streamlineSdkUrl), or its bin\x64 folder" }
	if ($settings.streamline -and (Test-Path -LiteralPath $settings.streamline)) { $dialog.SelectedPath = $settings.streamline }
	if ($dialog.ShowDialog($form) -ne 'OK') { return }
	$found = Find-Streamline $dialog.SelectedPath
	if (!$found) {
		[void][System.Windows.Forms.MessageBox]::Show($form, "No sl.interposer.dll signed by NVIDIA in that folder or its bin\x64.`nDownload the Streamline SDK from $streamlineSdkUrl and choose the unpacked folder.", 'Frame generation')
		return
	}
	$settings.streamline = $dialog.SelectedPath
	$script:streamline = $found
	$script:frameGenAvailable = $true
	$upscaler.Enabled = $true
	Update-UpscalerNote
	$frameGen.Enabled = $true
	Update-FrameGenNote
})
$fsr = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'AMD FSR 3 帧生成（2x，任何显卡；替代 DLSS）'; AutoSize = $true
	Checked = ($fsrAvailable -and [bool]$settings.fsr); Enabled = $fsrAvailable }
(New-Object System.Windows.Forms.ToolTip).SetToolTip($fsr, "AMD FidelityFX FSR 3.1：在游戏的两帧之间生成一帧，用它的深度和运动信息。`n" +
	"开了垂直同步时，显示帧数受显示器刷新率限制（60 Hz 显示器下游戏按 30 fps 跑）。`n" +
	"需要把 amd_fidelityfx_vk.dll 放在模拟器旁边。")
Add-Row '' @($fsr)
Add-Row '帧生成' @($frameGen, $frameGenFolder, $frameGenNote)
$hud = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 160 }
$hud.Items.AddRange($overlays)
# (An older launcher saved true for the frame rate.)
$hud.SelectedIndex = [Math]::Max(0, [Math]::Min($overlays.Count - 1, [int]$settings.hud))
$hudNote = New-Object System.Windows.Forms.Label -Property @{ Text = '右上角：帧率与帧时间；详细：GPU、CPU、内存。游戏内按 F8 切换'; AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
Add-Row '覆盖层' @($hud, $hudNote)
$safeGpuTip = "避免显卡挂死造成的崩溃与蓝屏：'device lost'、驱动重启时黑屏（TDR）、或 VIDEO_TDR_FAILURE 蓝屏。`n" +
	"开启后模拟器把恶魔之魂的计算工作一步一步串行执行，不再让显卡重叠执行。`n" +
	"代价是帧率约低 37%（笔记本 RTX 3080 在波雷塔利亚：27 → 17 fps）。`n" +
	"它不能解决 MEMORY_MANAGEMENT 蓝屏（那是内存塞满，见 README）。`n" +
	"如果游戏本来不出现这类崩溃就别开；更新显卡驱动也有帮助。"
$safeGpu = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '安全 GPU 模式：避免显卡挂死导致的崩溃与蓝屏，但帧率约低 37%'; AutoSize = $true; Checked = [bool]$settings.safegpu }
(New-Object System.Windows.Forms.ToolTip -Property @{ AutoPopDelay = 30000 }).SetToolTip($safeGpu, $safeGpuTip)
Add-Row '安全 GPU 模式' @($safeGpu)
$ecores = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '只用能效核预编译（更慢，但电脑保持流畅）'; AutoSize = $true
	Checked = ([bool]$settings.ecores -and $efficiencyMask -ne 0); Enabled = ($efficiencyMask -ne 0) }
Add-Row '' @($ecores)
$cheats = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '金手指 (_Patches\<title id>.json)'; AutoSize = $true
	Checked = [bool]$settings.cheats }
$cheatButton = New-Object System.Windows.Forms.Button -Property @{ Text = '选择...'; AutoSize = $true }
$cheatButton.Add_Click({
	$cheatFile = Get-CheatFile $game.Text.Trim()
	if (!$cheatFile) {
		[void][System.Windows.Forms.MessageBox]::Show('没有找到 _Patches\<title id>.json。', '金手指')
		return
	}
	Show-CheatDialog $cheatFile
	Update-Title
})
Add-Row '' @($cheats, $cheatButton)
$cheatNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray' }
Add-Row '' @($cheatNote)
Update-Title

$buttons = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{ AutoSize = $true; Margin = '0,10,0,0' }
$play = New-Object System.Windows.Forms.Button -Property @{ Text = '开始游戏'; AutoSize = $true; Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold) }
$precompile = New-Object System.Windows.Forms.Button -Property @{ Text = '预编译着色器'; AutoSize = $true }
$share = New-Object System.Windows.Forms.Button -Property @{ Text = '导出着色器 hints'; AutoSize = $true }
(New-Object System.Windows.Forms.ToolTip).SetToolTip($share, ('把你这次游玩记录到的着色器导出为 my-hints-<game>.hints（不含游戏代码）：' +
	'附到 GitHub issue 里，下一个版本的预编译就会带上它们。'))
$logs = New-Object System.Windows.Forms.Button -Property @{ Text = '日志目录'; AutoSize = $true }
$readme = New-Object System.Windows.Forms.Button -Property @{ Text = '说明 (README)'; AutoSize = $true }
$buttons.Controls.AddRange(@($play, $precompile, $logs, $readme))
$share.Add_Click({
	Read-Form
	Start-Process $cmd -ArgumentList "/s /c `"$(Get-PrecompileCommand '-ExportHints')`"" -WorkingDirectory $root
})
$grid.Controls.Add($buttons)
$grid.SetColumnSpan($buttons, 2)
$credit = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '0,8,0,0'
	Text = '设置项沿用 KytyPS5 开发者的原版启动器（src/launcher）。' }
$grid.Controls.Add($credit)
$grid.SetColumnSpan($credit, 2)
$form.AcceptButton = $play

function Read-Form {
	$settings.game       = $game.Text.Trim()
	$settings.resolution = [string]$resolution.SelectedItem
	$settings.fullscreen = $fullscreen.Checked
	$settings.aspect     = $aspect.Checked
	$settings.language   = $language.SelectedIndex
	$settings.redzone    = $redzone.Checked
	$settings.fps120     = $fps120.Checked
	$settings.vsync      = $vsync.Checked
	$settings.hdr        = $hdr.Checked
	$settings.hud        = $hud.SelectedIndex
	$settings.safegpu    = $safeGpu.Checked
	$settings.render     = [int](([string]$render.SelectedItem -split ' ')[0])
	$settings.quality    = ([string]$quality.SelectedItem -split ' ')[0].ToLowerInvariant()
	$settings.ratio      = ([string]$ratio.SelectedItem -split ' ')[0]
	# (Kept as it was where the DLLs are missing.)
	if ($frameGenAvailable) { $settings.framegen = if ($frameGen.SelectedIndex -gt 0) { $frameGen.SelectedIndex + 1 } else { 0 } }
	if ($fsrAvailable) { $settings.fsr = $fsr.Checked }
	if ($frameGenAvailable) { $settings.upscaler = if ($upscaler.SelectedIndex -eq 1) { 'dlss' } else { '' } }
	$settings.ecores     = $ecores.Checked
	$settings.cheats     = $cheats.Checked
	Save-Settings
}
$play.Add_Click({
	Read-Form
	Start-Process $cmd -ArgumentList "/v:on /s /c `"$(Get-PlayCommand)`"" -WorkingDirectory $root
	$form.Close()
})
$precompile.Add_Click({
	Read-Form
	Start-Process $cmd -ArgumentList "/s /c `"$(Get-PrecompileCommand)`"" -WorkingDirectory $root
})
$logs.Add_Click({
	$folder = if (Test-Path "$root\_Build") { "$root\_Build\run-logs" } else { "$root\logs" }
	New-Item -ItemType Directory -Force $folder | Out-Null
	Start-Process explorer.exe $folder
})
$readme.Add_Click({
	$file = @("$root\README.md", "$root\docs\PORTABLE-README.md") | Where-Object { Test-Path $_ } | Select-Object -First 1
	if ($file) { Start-Process notepad.exe "`"$file`"" }
})
$form.Add_FormClosing({ Read-Form })
[void]$form.ShowDialog()
