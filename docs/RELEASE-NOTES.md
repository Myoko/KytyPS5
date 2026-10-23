## New in this build

Your precompiled shaders stay valid: the shaders are the same as in v20261023.

- **The MEMORY_MANAGEMENT blue screen is fixed** (#50, #5): PCs whose RAM ran full (16 GB, or 32 GB with a browser
  open) could stop with this blue screen after 10 minutes to an hour, often during a load or after a death. The cause
  is Windows mishandling "no access" pages of a mapped file when it pages them out; the emulator now keeps guest memory
  from reads with guard pages instead. On a test laptop with its RAM taken by a test program, the old way blue-screened
  within 7 minutes of world trips and the new one ran 2 x 22 minutes, at the same frame rates. The launcher's
  "Keep memory resident" test option is not needed for this any more.
- **DualSense:** the pad's speaker no longer crackles (it was amplified 8 times and clipped inside the pad, #146), a
  wired pad's speaker and vibration no longer overwrite each other, and a DualSense connected over Bluetooth gets its
  speaker and haptic vibration too. Vibration on wired pads is stronger than before (`KYTY_DUALSENSE_HAPTICS_GAIN`
  sets it). A contribution by @Myoko (PR #148).
- **Sound:** where the processor is at its limit and the game makes its sound too late, the sound is stretched a
  little instead of cutting in and out (#85; `run.cmd -Set KYTY_AUDIO_STRETCH=0` turns that off).
- **DLSS:** it no longer turns off after a while on cards whose video memory is full (6 GB cards, #85), and where DLSS
  cannot run (no RTX card, or FSR 3.1 frame generation on), FSR 3 upscaling takes its place instead of the game's TAA.
- **Smoother on PCs with few cores:** the emulator's helper threads no longer keep processor cores busy waiting when
  the game needs them (4 cores of the test PC at Boletaria's start: 43-50 -> 57-63 fps, far fewer long frames);
  PCs with many cores run as before.
- **Shorter hitches entering new areas:** big texture pools no longer upload their empty layers (about 1 GB less in a
  round of world trips), most of all on 8 GB graphics cards. The README's 8 GB numbers are measured again: the heavy
  areas run about as fast as with all the video memory.
- **Precompile:**
  - After a precompile, the launcher no longer keeps offering it again (PCs west of UTC, #143).
  - A slow compile no longer restarts its shard over and over (@intellq, PR #145: an RX 6600's 5-hour loop is now
    69 minutes).
  - A graphics card the emulator cannot use (GeForce GTX 10 series and older: no fragment shader barycentrics) is
    named as such instead of "merge failed" (#149).
- **FSR 3 frame generation:** the HUD stays in place after level loads (@intellq, PR #142); on Linux it works with HDR10
  output too (@intellq, PR #140).
- **Thanks** to @Myoko, @intellq, and everyone who posted bug check lines and dumps of the blue screen (#5, #50).

## New in v20261023

Your precompiled shaders stay valid: the shaders are the same as in v20261022. The release's hints now hold two
more whole playthroughs, so the launcher offers the precompile once more: only the new part is compiled (minutes).

- **FSR 3 upscaling for every graphics card:** in the launcher, Graphics > Upscaler > **FSR 3 (PS5 Pro path)**
  (`run.cmd -Upscaler fsr`). AMD's FSR 3 replaces Sony's PS5 Pro upscaler, as DLSS does: AMD, Intel and GeForce GTX
  cards get a real upscaler, built in, nothing to download. On an RTX 5090 at Boletaria's start, 1080 to 4K looked close
  to DLSS at the same height.
- **DLSS and FSR 3 for 1080p screens:** with Game output 1080p they make the 1080p picture directly (no 4K step), from
  render heights down to 360. Each render height in the launcher shows the mode it runs in (Quality, Balanced,
  Performance, Ultra Performance, DLAA); with the 4K output, 720 is DLSS's Ultra Performance. Graphics > **DLSS model**:
  Automatic, Transformer (preset K), or CNN (preset E, lighter on RTX 20 and 30 cards).
- **Game output "Automatic"** (the new default): the game's own 1080p output for a 16:9 game window (or screen, in
  full screen) at most 1080 lines high, 4K otherwise. On 1080p screens the picture is pixel for pixel and the graphics
  card saves the 4K post-processing (RTX 5090: 69.8 -> 78.3 fps; RX 9070 XT on Linux: +4.6%). Choose 4K to keep it
  (`run.cmd -Set KYTY_HD_OUTPUT=0`).
- **Every language in every release:** the game's language settings offer the text of all 23 languages (Chinese,
  Japanese and Korean too) and all 9 voices, whatever the release; no `param.json` edit (a contribution by @noir39,
  PR #139).
- **Sound:** no more crackling, and no delay that slowly grew in long sessions (#85).
- **Launcher:**
  - Experimental page: **Lock to 30 fps** (steady 30 at the normal game speed, for slower PCs), direct presentation
    for variable refresh rate displays (#37), **Keep memory resident** (a test against MEMORY_MANAGEMENT blue screens,
    #50), AMD Anti-Lag (#80).
  - Advanced: a **Command-line options** box (as after `run.cmd`), and a **Graphics card** choice on PCs with more than
    one (#132).
  - `KytyLauncher.exe --play` starts the game with the launcher's settings, without its window: for Steam's "Add a
    Non-Steam Game" with the Launch Options `--play` (#130).
  - Export shader hints writes a `.zip`, which GitHub takes as an attachment.
- **Fixes:**
  - With the 1080p output at render height 1080, the menus' 3D was black (the character in the equipment menu and in
    character creation) (#138).
  - PCs with two graphics cards ran the game on the one Windows' graphics settings did not choose, and the precompile
    on the other (#132). `run.cmd -Gpu 4090` (a number or part of the name) picks one.
  - A precompile that hung on an old graphics driver: a pipeline the driver never finishes is now left out after 5
    minutes, and the files such a run left behind no longer make every start offer the precompile (#126).
  - `kyty_emulator.exe` carries version information (Microsoft Defender's machine learning took the bare file for a
    trojan, #135).
- **Shader hints:** two whole playthroughs added, by @DevList1454 (#124) and @Mvii7 (#134): fewer first-time
  stutters in places our own recordings missed.
- **Linux:** the package is built with a Linux PGO profile (+3.4%, @the2ndday, PR #133); the render thread's locks and
  memory protection are cheaper (`KYTY_LINUX_FAST_LOCKS`, `KYTY_LINUX_COALESCE_MPROTECT`, on by default; +8% on an
  i5-14400, @the2ndday, PR #125); the texture offload for 16 GB PCs runs on Linux too (@Bios2000, PRs #136 and #137);
  FSR 3 upscaling is as sharp as it should be (@Bios2000, PR #131).
- **Thanks** to @noir39, @the2ndday, @Bios2000, @DevList1454, @Mvii7 and everyone who reported problems and tested.

## 本版本的变化

已有的预编译着色器继续有效：着色器与 v20261023 相同。

- **修复了 MEMORY_MANAGEMENT 蓝屏**（#50、#5）：内存被占满的电脑（16 GB，或开着浏览器的 32 GB）可能在玩 10 分钟到 1
  小时后蓝屏，常出现在载入或死亡之后。原因是 Windows 在换出映射文件的"禁止访问"页面时处理有误；模拟器现在改用 guard
  页来拦截对客户机内存的读取。在一台被测试程序占满内存的笔记本上，旧方式在世界往返 7 分钟内蓝屏，新方式连续跑了 2 次
  各 22 分钟都没有蓝屏，帧数相同。启动器里"常驻内存"这个试验选项不再需要。
- **DualSense：** 手柄扬声器不再爆音（之前放大 8 倍，在手柄内部削波，#146）；USB 连接时扬声器和振动不再互相覆盖；
  蓝牙连接的 DualSense 也支持扬声器和触觉振动。有线手柄的振动比以前更强（可用 `KYTY_DUALSENSE_HAPTICS_GAIN` 调整）。
  由 @Myoko 贡献（PR #148）。
- **声音：** CPU 跑满、游戏声音生成太晚时，声音会被略微拉伸，不再断断续续（#85；
  `run.cmd -Set KYTY_AUDIO_STRETCH=0` 可关闭）。
- **DLSS：** 显存占满的显卡（6 GB，#85）上不再过一段时间就失效；DLSS 不可用时（非 RTX 显卡，或开着 FSR 3.1 插帧），
  改用 FSR 3 超分，而不是游戏自带的 TAA。
- **核心少的电脑更流畅：** 游戏需要 CPU 时，模拟器的辅助线程不再空转占着核心（测试机限 4 核，Boletaria 起点：43-50 ->
  57-63 fps，长帧大幅减少）；核心多的电脑不受影响。
- **进入新区域的卡顿更短：** 大纹理池不再上传其中的空层（一轮世界往返少上传约 1 GB），8 GB 显卡上最明显。README 中
  8 GB 显存的数据已重新测量：重场景的速度与显存充足时基本相同。
- **预编译：**
  - 预编译完成后，启动器不再反复提示重新预编译（UTC 以西时区的电脑，#143）。
  - 慢的编译不再让分片一遍遍重来（@intellq，PR #145：RX 6600 上 5 小时的循环缩短到 69 分钟）。
  - 模拟器无法使用的显卡（GeForce GTX 10 系列及更早：不支持 fragment shader barycentrics）会直接报出，而不是
    "merge failed"（#149）。
- **FSR 3 插帧：** 读取关卡后 HUD 不再错位（@intellq，PR #142）；Linux 上 HDR10 输出也能用（@intellq，PR #140）。
- **感谢** @Myoko、@intellq，以及所有贴出蓝屏代码和转储文件的用户（#5、#50）。

## v20261023 的变化

已经预编译的着色器继续有效：着色器与 v20261022 相同。发布包的提示新增了两份完整通关的记录，所以启动器会再提示一次预编译：只编译新增的部分（几分钟）。

- **FSR 3 超分，任何显卡都可用：** 启动器「画质」>「超分辨率」>「FSR 3（PS5 Pro 路径）」（`run.cmd -Upscaler fsr`）。和 DLSS 一样，用 AMD 的 FSR 3 替代索尼的 PS5 Pro 超分：AMD、Intel 和 GeForce GTX 显卡也有了真正的超分，已内置，无需下载。在 RTX 5090 上的波雷塔利亚起点，从 1080 到 4K 的画面接近同高度的 DLSS。
- **1080p 屏幕的 DLSS 和 FSR 3：** 游戏输出选 1080p 时，它们直接生成 1080p 画面（不再经过 4K），渲染高度最低可到 360。启动器中每个渲染高度都标出对应的模式（质量、平衡、性能、超级性能、DLAA）；4K 输出时 720 是 DLSS 的超级性能模式。「画质」>「DLSS 模型」：自动、Transformer（预设 K）或 CNN（预设 E，在 RTX 20/30 系显卡上更轻）。
- **游戏输出「自动」**（新的默认）：16:9 且游戏窗口（全屏时为屏幕）高度不超过 1080 时使用游戏自己的 1080p 输出，否则 4K。1080p 屏幕上画面逐像素显示，显卡也省掉了 4K 后处理（RTX 5090：69.8 → 78.3 fps；Linux 上的 RX 9070 XT：+4.6%）。想保持 4K 请选 4K（`run.cmd -Set KYTY_HD_OUTPUT=0`）。
- **所有版本都能选所有语言：** 无论哪个区服版本，游戏的语言设置都提供全部 23 种文字（包括中文、日文、韩文）和全部 9 种语音，不再需要修改 `param.json`（@noir39 的贡献，PR #139）。
- **声音：** 不再有爆音，长时间游玩时声音逐渐延迟的问题也已修正（#85）。
- **启动器：**
  - 「实验性」页：**锁定 30 帧**（稳定 30 帧、游戏速度正常，适合较慢的电脑）、可变刷新率显示器的直接呈现（#37）、**保持内存常驻**（针对 MEMORY_MANAGEMENT 蓝屏的测试，#50）、AMD Anti-Lag（#80）。
  - 「高级」：**命令行参数**输入框（写法同 `run.cmd` 后面的参数），以及多显卡电脑上的**显卡**选择（#132）。
  - `KytyLauncher.exe --play` 用启动器的设置直接启动游戏、不显示启动器窗口：适合在 Steam「添加非 Steam 游戏」里使用，启动选项填 `--play`（#130）。
  - 导出着色器提示会生成 `.zip`，可以直接作为 GitHub 附件上传。
- **修正：**
  - 1080p 输出且渲染高度为 1080 时，菜单里的 3D 是黑的（装备菜单和捏人界面里的角色）（#138）。
  - 装有两块显卡的电脑上，游戏用的不是 Windows 图形设置选择的那块，预编译却用了另一块（#132）。可用 `run.cmd -Gpu 4090`（编号或名称的一部分）指定。
  - 旧显卡驱动导致预编译卡住：驱动始终编译不完的管线现在 5 分钟后跳过，这类运行留下的文件也不会再让每次启动都提示预编译（#126）。
  - `kyty_emulator.exe` 带上了版本信息（微软 Defender 的机器学习曾把没有版本信息的文件误判为木马，#135）。
- **着色器提示：** 加入了 @DevList1454（#124）和 @Mvii7（#134）的两份完整通关记录：在我们自己的录制没有覆盖到的地方，首次出现的卡顿更少。
- **Linux：** 发布包用 Linux 的 PGO 配置文件构建（+3.4%，@the2ndday，PR #133）；渲染线程的锁和内存保护更省（`KYTY_LINUX_FAST_LOCKS`、`KYTY_LINUX_COALESCE_MPROTECT`，默认开启；i5-14400 上 +8%，@the2ndday，PR #125）；面向 16 GB 电脑的纹理卸载在 Linux 上也启用了（@Bios2000，PR #136 和 #137）；FSR 3 超分恢复了应有的清晰度（@Bios2000，PR #131）。
- **感谢** @noir39、@the2ndday、@Bios2000、@DevList1454、@Mvii7 以及所有报告问题和帮忙测试的玩家。
