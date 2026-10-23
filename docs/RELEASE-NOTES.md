## New in this build

Your precompiled shaders stay valid: the shaders are the same as in v20261023.

- **Flicker, black screen tiles and dark areas since v20261023b, fixed on PCs with more than 20 GB of RAM** (#157,
  #158, #159): the guard pages that
  v20261023b used against the blue screen let the game read some of its data while the emulator was still bringing it
  up to date, so whole areas could lose their light, tiles of the screen or textures turned black, or the picture
  showed at twice its size (reproduced at the Tower of Latria). Guard pages are now used only on PCs with 20 GB of RAM
  or less, where the blue screen comes from; PCs with more RAM are back to the protection of v20261023 and show the
  picture as before. You can choose either way:
  - 20 GB of RAM or less: `run.cmd -Set KYTY_READ_GUARD=0` gives the right picture back, but the blue screen can
    return when the RAM runs full (close other programs then).
  - More RAM, and the PC blue-screens with MEMORY_MANAGEMENT when its RAM runs full: `run.cmd -Set KYTY_READ_GUARD=1`.

  We're working on a fix that needs neither.
- Everything of v20261023c below is in this build too.

## New in v20261023c

Your precompiled shaders stay valid: the shaders are the same as in v20261023.

- **Picture glitches and black textures since v20261023b** (#158, #157, #159): v20261023b's fix for the blue screen
  keeps the memory the emulator watches behind guard pages, and on some PCs the picture flickers with them: lights go
  out, tiles of the screen or textures turn black, the picture shows at twice its size. This build puts a page's guard
  back faster, but players still see it in places such as the Tower of Latria, and we're still on it. Until then,
  `run.cmd -Set KYTY_READ_GUARD=0` avoids it; on a PC whose RAM runs full it brings back the blue screen risk.
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

## 本版本的变化

已有的预编译着色器继续有效：着色器与 v20261023 相同。

- **v20261023b 以来的画面闪烁、屏幕成块变黑和区域变暗，在内存大于 20 GB 的电脑上已修复**（#157、#158、#159）：v20261023b 为防蓝屏使用的 guard
  页，会让游戏在模拟器还没更新完数据时就读到它，导致整片区域失去光照、屏幕上成块的区域或贴图变黑，或画面放大两倍（已在
  Tower of Latria 复现）。现在只有内存 20 GB 及以下的电脑（蓝屏出现在这类电脑上）才使用 guard 页；内存更大的电脑恢复
  v20261023 的保护方式，画面恢复正常。也可以自行选择：
  - 内存 20 GB 及以下：`run.cmd -Set KYTY_READ_GUARD=0` 可以恢复正确的画面，但内存被占满时可能再次蓝屏（此时请关闭其他程序）。
  - 内存更大，但内存被占满时出现 MEMORY_MANAGEMENT 蓝屏：`run.cmd -Set KYTY_READ_GUARD=1`。

  我们正在做一个两者都不需要的修复。
- 下面 v20261023c 的内容也都包含在本版本中。

## v20261023c 的变化

已有的预编译着色器继续有效：着色器与 v20261023 相同。

- **v20261023b 以来的画面闪烁和黑色贴图**（#158、#157、#159）：v20261023b 为修复蓝屏改用 guard 页保护模拟器需要监视的内存，
  在部分电脑上会导致画面闪烁：灯光熄灭、屏幕上成块的区域或贴图变黑、画面放大两倍。本版本让 guard 更快放回，但在
  Tower of Latria 等地方仍有玩家遇到，我们还在继续修。在此之前，`run.cmd -Set KYTY_READ_GUARD=0` 可以避开；在内存被占满
  的电脑上它会重新带来蓝屏风险。
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
