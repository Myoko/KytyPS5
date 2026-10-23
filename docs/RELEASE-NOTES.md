## New in this build

Your precompiled shaders stay valid: the shaders are the same as in v20261023.

- **Picture glitches and black textures from v20261023b fixed** (#158, #157): with v20261023b the picture could show
  its top-left quarter at twice the size for seconds, and black textures could pile up until a restart (a 16 GB PC).
  v20261023b's fix for the blue screen keeps the memory the emulator watches behind guard pages. Windows lifts a page's
  guard the moment it reports a read, and the emulator could take long to put it back while the game streamed, so
  other threads read stale or dropped data meanwhile. The guard is now put back at once; the blue screen fix stays. If
  you still see either, please tell us on #158. `run.cmd -Set KYTY_READ_GUARD=0` avoids it, but on a PC whose RAM runs
  full it brings back the blue screen risk.
- **Crash on graphics cards with less than 12 GB fixed** (in every build since v20261020): a buffer freed on a helper
  thread while the emulator compacted video memory could stop the game with an access violation (in 1 of 2 tours on an
  8 GB laptop). Found and fixed first by @Bios2000 (PR #151). The compaction also takes at most about 5 ms of a frame
  on that laptop now (it was up to 18 ms).
- **Fewer long hitches in Stonefang 2-2 and the Valley of Defilement 5-2** (graphics cards with 12 GB or more): the
  game's big texture pools are kept while you stay in a world instead of being uploaded again whole (150-460 ms
  frames).
- **Texture offload** (on by default with 20 GB of RAM or less): fixes for writes over dropped textures, a race when a
  texture is taken, write-backs, and a hang in copies (@Bios2000, PR #152).
- **DualSense on Bluetooth:** a hit's vibration stops with the hit instead of lasting over a second (@Myoko, PR #156,
  #146).
- **Linux:** an opt-in file offload, `KYTY_FILE_OFFLOAD=1`, drops guest memory that still equals the game's files from
  RAM (about 1 GB on a 16 GB PC; @Bios2000, PR #153).
- New settings for PCs short of RAM: `KYTY_STAGING_MB` (the upload ring's size), `KYTY_STAGING_STATS=1` (its use) and
  `KYTY_HEAP_TRIM=1` (freed heap memory given back; @Bios2000, PR #154). Nothing changes unless you set them.
- **Thanks** to @Bios2000 and @Myoko for their fixes, and to @kvothe3323, @i-pseudo and @lukefela for the quick
  reports.

## New in v20261023b

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

## 本版本的变化

已有的预编译着色器继续有效：着色器与 v20261023 相同。

- **修复了 v20261023b 带来的画面错乱和黑色贴图**（#158、#157）：v20261023b 中，画面可能会有几秒钟只显示左上角的四分之一
  并放大两倍；一台 16 GB 内存的电脑上黑色贴图越来越多，直到重启。v20261023b 为修复蓝屏改用 guard 页保护模拟器需要监视的
  内存。Windows 在页面第一次被读取时会立刻撤掉它的 guard，而模拟器在游戏加载资源时可能要过很久才把 guard 放回去，这段
  时间里其他线程会读到过期或已被释放的数据。现在 guard 会立刻放回，蓝屏修复保持不变。如果仍然遇到，请在 #158 告诉我们。
  `run.cmd -Set KYTY_READ_GUARD=0` 可以避开，但在内存被占满的电脑上会重新带来蓝屏风险。
- **修复了显存小于 12 GB 的显卡上的崩溃**（v20261020 以来的所有版本）：模拟器整理显存时，辅助线程释放的缓冲区可能让游戏
  因访问违规而退出（8 GB 笔记本上两次巡回中出现一次）。由 @Bios2000 最先发现并修复（PR #151）。整理显存现在在那台笔记本
  上每帧最多占用约 5 ms（之前最多 18 ms）。
- **Stonefang 2-2 和 Valley of Defilement 5-2 的长卡顿更少**（12 GB 及以上显存）：游戏的大纹理池在同一个世界内会保留，
  不再整体重新上传（150–460 ms 的长帧）。
- **纹理卸载**（内存 20 GB 及以下时默认开启）：修复了写入已卸载的贴图、取用贴图时的竞争、回写，以及复制时的卡死
  （@Bios2000，PR #152）。
- **蓝牙 DualSense：** 受击的振动会随受击结束，不再持续一秒多（@Myoko，PR #156，#146）。
- **Linux：** 新增可选的文件卸载 `KYTY_FILE_OFFLOAD=1`，把与游戏文件内容相同的客户机内存从内存中释放（16 GB 电脑上约
  1 GB；@Bios2000，PR #153）。
- 面向内存不足电脑的新设置：`KYTY_STAGING_MB`（上传环的大小）、`KYTY_STAGING_STATS=1`（其使用情况）和
  `KYTY_HEAP_TRIM=1`（归还释放的堆内存；@Bios2000，PR #154）。不设置则没有任何变化。
- **感谢** @Bios2000 和 @Myoko 的修复，以及 @kvothe3323、@i-pseudo、@lukefela 的及时反馈。

## v20261023b 的变化

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
