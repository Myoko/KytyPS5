## New in this build

A fix release for v20261025. Your precompiled shaders stay valid: the shaders are the same as in v20261023.

- **Stutter on PCs with 16-20 GB of RAM** (#5): v20261025 gives the memory the game's engine has freed back to
  Windows, and holds the engine's own memory lock while it does. On a PC short of memory, Windows was slow at each
  step and the game waited for that lock most of the time: 10-15 fps for many seconds, and short freezes. Now the
  give-back holds the lock at most 2.5% of the time, pauses for 30 seconds to 2 minutes while Windows is slow, and
  only takes back memory that has stayed free for 30 seconds. If you added `-Set KYTY_ENGINE_FREE=0` because of this,
  you can remove it.
- **About 0.5 GB less RAM on PCs with 20 GB or less**: the background shader preparation kept a ready-made part (the
  code that reads a shader's descriptors) for every one of the game's ~22,000 shaders, of which a session uses a few
  thousand. It now makes it when the game first uses a shader (~0.4 ms each).
- **AMD: fullscreen as fast as a window** (#166): on AMD graphics cards the emulator now asks the driver not to use
  exclusive fullscreen, which ran ~10% slower than a window on an RX 9060 XT. `run.cmd -Set KYTY_FULLSCREEN_EXCLUSIVE=1`
  allows it again.
- **Thanks** to @sklektr and @berkocevik-del for their reports and tests.

## New in v20261025

Your precompiled shaders stay valid: the shaders are the same as in v20261023.

- **Much less memory in use** (#183): the emulator kept every game file it had read open until it exited, and Windows
  counts what was read from open files as memory in use: 6-8 GB more after a few worlds, the main reason the game
  seemed to need 32 GB. Files now close 10 s after their last read; Windows still caches their data, but as available
  memory. After 1-1 and four other worlds, the PC's memory in use went up by 15 GB instead of 21 GB.
- **Less memory over play**: Demon's Souls is told it has 12 GiB of memory, as a PS5 gives it (12.5 before). The game
  fills what it is told it has with texture cache, so this is about 0.5 GB less RAM after a few areas, at the same
  frame rates. `run.cmd -Set KYTY_DIRECT_MEMORY_MB=0` gives it the 12.5 GiB of before.
- **Less memory in use on PCs with 20 GB of RAM or less** (Windows): the game's engine keeps the memory it frees for
  its next allocations, so those pages stayed in the PC's RAM (2-4 GB in the other worlds after Boletaria). The
  emulator now gives back the pages of the engine's free blocks once they have stayed free for ~10 s, under the
  engine's own lock so the game never notices: 1.7-2.0 GB less memory in use in the other worlds, ~1 GB back in
  Boletaria, same frame rates. `run.cmd -Set KYTY_ENGINE_FREE=0` turns it off; `-Set KYTY_ENGINE_FREE=giveback` turns
  it on with more RAM.
- **Black textures and stalls on PCs with 20 GB of RAM or less** (#5, #157, #159): the texture offload (which dropped
  copies of textures from RAM and brought them back when needed) is now off by default. With it off, textures that
  went black at a distance and characters that lost their hair were mostly gone, and so are its waits while it brought
  textures back (17-51 s in a session, up to 1.7 s at once in two 16 GB logs). The ~0.5 GB it saved is more than
  covered by the savings above. `run.cmd -Set KYTY_TEXTURE_OFFLOAD=1` turns it back on.
- **Less video memory and shorter hitches where the game's texture pools are large** (#174): the game samples its
  texture pools through views from a texture's slot to the pool's last layer, up to 2,255 layers, held as images of up
  to 1 GB. Its shaders can only reach 256 layers past the slot (the layer is a byte), which the emulator now proves
  when it translates them, so it keeps those 256 only: 64 to 256 MB instead of up to 1 GB, uploaded in a fraction of
  the time. On an 8 GB card that had its video memory full this was the image just before the driver lost the device.
  When a pool grew, its image grew with it (up to 1.5 GB: frames of up to ~190 ms at 2-2 and 5-2); in our 16-map tour
  no frame there takes 100 ms now. `run.cmd -Set KYTY_TEXTURE_LAYER_BOUND=0` keeps every layer as before.
- **Less video memory on graphics cards under 12 GB** (#85): the texture pools (large arrays of textures) are now held
  without their largest level too, as single textures already were: about 0.35 GB less at Boletaria, the picture the
  same at 1080p and below. `run.cmd -Set KYTY_TEXTURE_REDUCE=0` keeps every texture whole.
- **Fewer hitches on cards with little video memory** (#85): over its budget, the emulator evicted pipelines no draw
  had used for 3 minutes, and rebuilt them when the game used them again: an RTX 2060 (6 GB) rebuilt 5,599 of them in
  one session (9.3 s of stalls) while the video memory used stayed the same. Once a quarter of the evicted ones come
  back, it stops evicting them for that session.
- **Fewer hitches after travelling on PCs with more than 20 GB of RAM** (#129): when you changed worlds, the emulator
  dropped the pipelines of the worlds you left to save RAM, and remade them when the game used them again (an RTX 2080
  Ti remade 1,096 of them, up to 137 ms each). It now does this only on PCs with 20 GB of RAM or less, where the RAM is
  needed.
- **A quick precompile on a fresh store** (#189): `precompile.cmd -Quick` / `./precompile-linux.sh --quick` on a store
  made from nothing marked it as made without the translation features it actually used, and the game then missed
  most of the store and compiled thousands of pipelines in play (a 5 s compile at the prologue boss). If you made your
  store that way, precompile once more after updating.
- **Interface at the 1080p and 1440p outputs** (#187): the health and stamina bars are filled up to the emblem as at 4K
  (their end pieces came twice as wide and covered the bars' left ends), and at 1440p the menus' glow behind the
  selected slot no longer shows as a green box above and left of it.
- **F11 with FSR frame generation** (#174): going full screen no longer freezes the picture while the game runs on (a
  window already the size of the screen gave AMD's swapchain no reason to be made again).
- **FSR 3 frame generation at the 1440p output**: the HUD no longer flickers (the emulator now finds the interface
  there and keeps it out of the generated frames; #170).
- **Launcher**: "Back to the launcher after the game" on the Advanced page (#85): the launcher waits in the background
  and comes back when the game ends. 16:9 windows have 1600x900 too (#129).
- **DualSense**: the Game page has sliders for the controller speaker's volume and the vibration's strength (motors
  and actuators) and length (@Myoko, PR #177). `dualsense-haptics.txt` is no longer read: use the sliders, or the
  `KYTY_DUALSENSE_*` variables (@Myoko, PR #178). A DualSense Edge connected by USB vibrates now, and so does a wired
  DualSense whose audio device Windows lists under a path the emulator did not recognize: it is now also found by its
  name (#146).
- **Mouse cursor** (#188): moves of a few pixels (some mice report them while resting) no longer bring the cursor back
  or keep it shown; it hides 3 s after the mouse last really moved.
- **EU and Asian editions** (PPSA01342, PPSA01340): the release's recording of the game's file opens serves them too
  (only the US edition used it), so their first loads open the game's files ahead as the US edition's do.
- **Logs** (#129): when frames are lost on the way to the screen, the log says how many every 30 s and how long the
  present call took, to find what limits what you see.
- **Releases**: the Windows and Linux packages share one release page with the right title, whichever build finishes
  first.
- **Thanks** to @Myoko for the DualSense pull requests, and to @AudaxTenebra, @Xerion1991, @ft1704, @2mg,
  @tao755-maker, @brokeneggg, @kvothe3323, @Angeluz01, @zhuyijun1573, @sklektr and @thxnk420 for their reports and
  tests.

## 本版本的变化

v20261025 的修正版。已有的预编译着色器继续有效：着色器与 v20261023 相同。

- **16-20 GB 内存电脑上的卡顿**（#5）：v20261025 会把游戏引擎释放的内存还给 Windows，并在此期间持有引擎自己的内存锁。在
  内存紧张的电脑上，Windows 处理每一步都很慢，游戏大部分时间都在等这把锁：连续很多秒只有 10-15 fps，还有短暂的卡死。现在
  归还内存最多占用这把锁 2.5% 的时间，Windows 忙时暂停 30 秒到 2 分钟，并且只回收空闲了 30 秒的内存。如果你因为这个问题
  加了 `-Set KYTY_ENGINE_FREE=0`，现在可以去掉。
- **20 GB 及以下内存的电脑少用约 0.5 GB**：后台着色器准备为游戏的约 22000 个着色器都预先生成了一部分（读取着色器描述符的
  代码），而一次游戏只会用到其中几千个。现在改为游戏第一次使用某个着色器时再生成（每个约 0.4 毫秒）。
- **AMD：全屏和窗口一样快**（#166）：在 AMD 显卡上，模拟器现在请求驱动不使用独占全屏；在 RX 9060 XT 上独占全屏比窗口慢约
  10%。`run.cmd -Set KYTY_FULLSCREEN_EXCLUSIVE=1` 恢复允许独占全屏。
- **感谢** @sklektr 和 @berkocevik-del 的报告和测试。

## v20261025 的变化

已有的预编译着色器继续有效：着色器与 v20261023 相同。

- **占用的内存大幅减少**（#183）：模拟器会让读过的游戏文件一直保持打开直到退出，而 Windows 把从打开的文件读到的数据算作
  “使用中”的内存：去过几个世界后多出 6-8 GB，这是游戏看起来需要 32 GB 内存的主要原因。现在文件在最后一次读取 10 秒后
  关闭；Windows 仍然缓存这些数据，但算作可用内存。1-1 加另外四个世界之后，电脑使用中的内存增加 15 GB，以前是 21 GB。
- **游玩中占用的内存更少**：现在告诉《恶魔之魂》它有 12 GiB 内存，与 PS5 给它的相同（以前是 12.5）。游戏会用纹理缓存填满
  它得到的内存，所以去过几个区域后少占约 0.5 GB 内存，帧率不变。`run.cmd -Set KYTY_DIRECT_MEMORY_MB=0` 恢复以前的 12.5 GiB。
- **20 GB 及以下内存的电脑占用更少**（Windows）：游戏引擎会把自己释放的内存留给之后的分配，这些页一直占着电脑的内存（从
  波雷塔利亚去其他世界后有 2-4 GB）。模拟器现在会把空闲约 10 秒以上的引擎内存块还给系统，并在引擎自己的锁下进行，游戏
  不会察觉：在其他世界少占 1.7-2.0 GB，回到波雷塔利亚少占约 1 GB，帧率不变。`run.cmd -Set KYTY_ENGINE_FREE=0` 关闭；
  内存更大的电脑可用 `-Set KYTY_ENGINE_FREE=giveback` 打开。
- **20 GB 及以下内存电脑上的黑色贴图和卡顿**（#5、#157、#159）：纹理卸载（把贴图的副本移出内存，需要时再取回）现在默认
  关闭。关闭后，远处变黑的贴图和角色头发消失的问题基本没有了，它取回贴图时的等待也没有了（两份 16 GB 电脑的日志中，一次
  游玩共等待 17-51 秒，单次最长 1.7 秒）。它节省的约 0.5 GB 内存已被上面的改进抵消有余。
  `run.cmd -Set KYTY_TEXTURE_OFFLOAD=1` 可以重新打开。
- **游戏纹理池较大的地方显存更少、卡顿更短**（#174）：游戏通过“从某张贴图的槽位到纹理池最后一层”的视图采样纹理池，最多
  2,255 层，模拟器要为此保留最多 1 GB 的图像。而这些着色器从槽位往后最多只能访问 256 层（层号是一个字节），模拟器现在
  在翻译着色器时证明这一点，只保留这 256 层：64 到 256 MB，而不是最多 1 GB，上传时间也短得多。在一张显存已满的 8 GB
  显卡上，驱动丢失设备之前上传的正是这样一张图像。纹理池变大时，它的图像也跟着变大（最大 1.5 GB：2-2 和 5-2 会出现最长
  约 190 ms 的帧）；现在 16 张地图的巡游中，这两处没有一帧超过 100 ms。`run.cmd -Set KYTY_TEXTURE_LAYER_BOUND=0` 恢复保留
  全部层。
- **12 GB 以下显卡的显存更少**（#85）：纹理池（大型纹理数组）现在也和单张纹理一样，去掉最大的一级 mip：波雷塔利亚约省
  0.35 GB，1080p 及以下画面看不出区别。`run.cmd -Set KYTY_TEXTURE_REDUCE=0` 保留全部纹理。
- **小显存显卡卡顿更少**（#85）：显存超出预算时，模拟器会把 3 分钟没用过的管线移出显存，游戏再用到时重建：一张 RTX 2060
  （6 GB）一次游玩中重建了 5,599 条（共 9.3 秒卡顿），而显存占用并没有减少。现在被移出的管线有四分之一以上又被用到时，
  本次游玩就不再移出。
- **内存大于 20 GB 的电脑在切换世界后卡顿更少**（#129）：切换世界时，模拟器会丢弃离开的世界的管线以节省内存，游戏再用到时
  重新创建（一台 RTX 2080 Ti 重建了 1,096 条，单条最长 137 ms）。现在只在内存 20 GB 及以下、确实需要节省内存的电脑上这样做。
- **在全新存储上做快速预编译**（#189）：在没有旧存储时运行 `precompile.cmd -Quick` / `./precompile-linux.sh --quick`，会把
  存储标记成没有使用实际用到的翻译特性，游戏随后几乎用不上这份存储，游玩中要编译数千条管线（序章 Boss 处一条编译 5 秒）。
  如果你的存储是这样生成的，更新后请再预编译一次。
- **1080p 与 1440p 输出下的界面**（#187）：血条和精力条现在像 4K 一样一直填到徽记处（之前两端部件宽了一倍，盖住了左端）；
  1440p 下菜单选中格的光晕不再在左上方显示成一个绿色方框。
- **FSR 帧生成时按 F11**（#174）：切到全屏不再出现画面冻结而游戏仍在运行（窗口本来就和屏幕一样大时，AMD 的交换链没有被
  重建）。
- **1440p 输出下的 FSR 3 帧生成**：HUD 不再闪烁（模拟器现在能找到这时的界面画布，不再把 HUD 拿去插帧；#170）。
- **启动器**：「高级」页新增「游戏结束后回到启动器」（#85）：游戏运行时启动器在后台等待，游戏结束后重新出现。16:9 窗口
  新增 1600x900（#129）。
- **DualSense**：「游戏」页新增手柄扬声器音量、振动强度（马达与致动器）和振动余韵的滑块（@Myoko，PR #177）。不再读取
  `dualsense-haptics.txt`：请使用滑块或 `KYTY_DUALSENSE_*` 环境变量（@Myoko，PR #178）。DualSense Edge 用 USB 连接时现在会
  振动；Windows 用模拟器不认识的路径列出手柄音频设备的有线 DualSense 也一样：现在也按名字找它（#146）。
- **鼠标光标**（#188）：几个像素的微小移动（有些鼠标静止时也会报告）不再让光标重新出现或一直显示；鼠标真正停下 3 秒后
  光标隐藏。
- **欧版和亚洲版**（PPSA01342、PPSA01340）：发布包里的游戏文件打开顺序记录现在也用于这两个版本（以前只有美版使用），首次
  读取时同样会提前打开游戏文件。
- **日志**（#129）：画面在送往屏幕途中丢帧时，日志每 30 秒记录一次丢了多少帧、呈现调用花了多久，便于找出限制画面的原因。
- **发布页**：Windows 和 Linux 两个包现在共用一个标题正确的发布页，无论哪个先构建完成。
- **感谢** @Myoko 的 DualSense PR，以及 @AudaxTenebra、@Xerion1991、@ft1704、@2mg、@tao755-maker、@brokeneggg、
  @kvothe3323、@Angeluz01、@zhuyijun1573、@sklektr 和 @thxnk420 的反馈与测试。
