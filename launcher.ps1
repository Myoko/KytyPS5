param([switch]$DryRun)
# A small settings window in front of run-windows.ps1 and precompile-windows.ps1 (launcher.cmd opens it). The
# settings and the console language names follow the KytyPS5 launcher (src/launcher, by the KytyPS5 developers);
# they are kept in launcher-settings.json next to this script. -DryRun prints the commands without a window.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$settingsPath = Join-Path $root 'launcher-settings.json'
$languages = '日语', '英语（美国）', '法语（法国）', '西班牙语（西班牙）', '德语', '意大利语', '荷兰语',
	'葡萄牙语（葡萄牙）', '俄语', '韩语', '中文（繁体）', '中文（简体）', '芬兰语', '瑞典语',
	'丹麦语', '挪威语', '波兰语', '葡萄牙语（巴西）', '英语（英国）', '土耳其语', '西班牙语（拉丁美洲）',
	'阿拉伯语', '法语（加拿大）', '捷克语', '匈牙利语', '希腊语', '罗马尼亚语', '泰语', '越南语', '印尼语'
$resolutions = '1280x720', '1920x1080', '2560x1440', '3840x2160'
# The height Demon's Souls renders its 3D at (run-windows.ps1 -RenderHeight); its output and UI stay 3840x2160.
$renderHeights = '1440 (PS5)', '1296', '1152', '1080', '900'
# Demon's Souls' own settings for what a frame draws (run-windows.ps1 -Quality): simpler shadows and distant detail.
$qualities = 'Standard (PS5)', 'Low', 'Lowest'
# DLSS frame generation (run-windows.ps1 -FrameGen: the generated frames per rendered one, the multiplier less one).
$frameGens = '关闭', '2x', '3x', '4x', '5x', '6x'
# The emulator's own panel at the top right of the game image (KYTY_FPS_HUD 0, 1, 2).
$overlays = '关闭', '帧率', '详细'

$settings = [ordered]@{ game = ''; resolution = '2560x1440'; fullscreen = $false; aspect = $true; language = 1; redzone = $true;
	ecores = $false; cheats = $true; fps120 = $false; render = 1440; quality = 'standard'; vsync = $false; hdr = $false; framegen = 0; hud = 0; streamline = '' }
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
	if ([int]$settings.render -gt 0 -and [int]$settings.render -ne 1440) { $arguments += @('-RenderHeight', [int]$settings.render) }
	# Presents wait for the display's refresh (Vulkan FIFO): no tearing, and G-SYNC/FreeSync displays keep adapting.
	if ($settings.vsync) { $arguments += @('-PresentMode', 'Fifo') }
	# Demon's Souls' own settings for what a frame draws (run-windows.ps1 -Quality): simpler shadows and distant detail.
	if ($settings.quality -in 'low', 'lowest') { $arguments += @('-Quality', $settings.quality) }
	# HDR10 output when Windows HDR is on for the display; SDR otherwise.
	if ($settings.hdr) { $arguments += '-Hdr' }
	if ($frameGenAvailable -and [int]$settings.framegen -ge 2) {
		$arguments += @('-FrameGen', ([int]$settings.framegen - 1), '-StreamlineDir', "`"$streamline`"")
	}
	# The emulator's panel (KYTY_FPS_HUD) at the top right of the game image: the frame rate and frame times, or with
	# the GPU, processor and memory too.
	if ([int]$settings.hud -ge 1) { $arguments += @('-Set', "KYTY_FPS_HUD=$([Math]::Min([int]$settings.hud, 2))") }
	if ($settings.game) { $arguments += @('-Game', "`"$($settings.game)`"") }
	# run-windows.ps1 passes --game-patch only for -Patch, and the emulator rejects it twice, so the
	# file is added here rather than left to the emulator's own _Patches lookup.
	if ($settings.cheats) { $patch = Get-CheatFile $settings.game; if ($patch) { $arguments += @('-Patch', "`"$patch`"") } }
	# The console stays for the live log; after a crash it waits for a key.
	return 'powershell ' + ($arguments -join ' ') + ' & if !errorlevel! neq 0 pause'
}
function Get-PrecompileCommand([string]$switch = '') {
	$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$root\precompile-windows.ps1`"")
	if ($switch) { $arguments += $switch }
	if ($settings.ecores -and $efficiencyMask -ne 0) { $arguments += @('-Affinity', $efficiencyMask) }
	if ($settings.game) { $arguments += @('-Game', "`"$($settings.game)`"") }
	return 'powershell ' + ($arguments -join ' ') + ' & pause'
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
		$cheatNote.Text = if ($patch) { '套用 ' + [System.IO.Path]::GetFileName($patch) } else { '此处没有 _Patches\<title id>.json' }
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
$fps120 = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '最高 120 fps（用游戏自身的帧；过场动画会放快）'; AutoSize = $true; Checked = [bool]$settings.fps120 }
Add-Row '' @($fps120)
$vsync = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '垂直同步（不撕裂；自适应同步显示器保持生效）'; AutoSize = $true; Checked = [bool]$settings.vsync }
Add-Row '' @($vsync)
$hdr = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'HDR（需先在 Windows 显示设置里打开"使用 HDR"）'; AutoSize = $true; Checked = [bool]$settings.hdr }
Add-Row '' @($hdr)
$render = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 160 }
$render.Items.AddRange($renderHeights)
$render.SelectedItem = ($renderHeights | Where-Object { ($_ -split ' ')[0] -eq [string][int]$settings.render } | Select-Object -First 1)
if ($render.SelectedIndex -lt 0) { $render.SelectedIndex = 0 }
$renderNote = New-Object System.Windows.Forms.Label -Property @{ Text = '《恶魔之魂》的 3D 渲染高度；越低越快、越模糊'; AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
Add-Row '渲染高度' @($render, $renderNote)
$quality = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 205 }
$quality.Items.AddRange($qualities)
$quality.SelectedItem = ($qualities | Where-Object { ($_ -split ' ')[0] -eq [string]$settings.quality } | Select-Object -First 1)
if ($quality.SelectedIndex -lt 0) { $quality.SelectedIndex = 0 }
$qualityNote = New-Object System.Windows.Forms.Label -Property @{ Text = '更简单的阴影与远景细节；CPU 受限时更快'; AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
Add-Row '' @($quality, $qualityNote)
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
$frameGenTips.SetToolTip($frameGen, "Shown frames = the game's frames x the multiplier. With VSync on, they are capped at the display's refresh`n(a 60 Hz display at 2x runs the game at 30 fps).")
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
	$frameGen.Enabled = $true
	Update-FrameGenNote
})
Add-Row '帧生成' @($frameGen, $frameGenFolder, $frameGenNote)
$hud = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 160 }
$hud.Items.AddRange($overlays)
# (An older launcher saved true for the frame rate.)
$hud.SelectedIndex = [Math]::Max(0, [Math]::Min($overlays.Count - 1, [int]$settings.hud))
$hudNote = New-Object System.Windows.Forms.Label -Property @{ Text = '右上角：帧率与帧时间；详细：GPU、CPU、内存'; AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
Add-Row '覆盖层' @($hud, $hudNote)
$ecores = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '只用能效核预编译（更慢，但电脑保持流畅）'; AutoSize = $true
	Checked = ([bool]$settings.ecores -and $efficiencyMask -ne 0); Enabled = ($efficiencyMask -ne 0) }
Add-Row '' @($ecores)
$cheats = New-Object System.Windows.Forms.CheckBox -Property @{ Text = '金手指 (_Patches\<title id>.json)'; AutoSize = $true
	Checked = [bool]$settings.cheats }
Add-Row '' @($cheats)
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
	Start-Process cmd -ArgumentList "/s /c `"$(Get-PrecompileCommand '-ExportHints')`"" -WorkingDirectory $root
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
	$settings.render     = [int](([string]$render.SelectedItem -split ' ')[0])
	$settings.quality    = ([string]$quality.SelectedItem -split ' ')[0].ToLowerInvariant()
	# (Kept as it was where the DLLs are missing.)
	if ($frameGenAvailable) { $settings.framegen = if ($frameGen.SelectedIndex -gt 0) { $frameGen.SelectedIndex + 1 } else { 0 } }
	$settings.ecores     = $ecores.Checked
	$settings.cheats     = $cheats.Checked
	Save-Settings
}
$play.Add_Click({
	Read-Form
	Start-Process cmd -ArgumentList "/v:on /s /c `"$(Get-PlayCommand)`"" -WorkingDirectory $root
	$form.Close()
})
$precompile.Add_Click({
	Read-Form
	Start-Process cmd -ArgumentList "/s /c `"$(Get-PrecompileCommand)`"" -WorkingDirectory $root
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
