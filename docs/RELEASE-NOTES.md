## The shader precompile is made per PC and cannot be shared

The precompiled shader caches belong to **one graphics card model and one driver version**, on the PC that
made them:

- Every player precompiles once on their own PC: choose "Precompile first" when the launcher asks, or
  double-click `precompile.cmd`. It takes about 45 minutes with 22 CPU threads and about 2 hours with 8;
  closing the window stops it and running it again continues.
- A `_PipelineCache` folder or cache files from another PC do not work, even for the same game version:
  do not share them or download them from others.
- After a graphics driver update or a change of graphics card, precompile again (the launcher asks).
- Game versions 1.07 and 1.05 each have caches of their own.
- Precompiled with v20261007 or older? Run the precompile again: newer builds compile more pipeline
  variants (what is already compiled is kept). The launcher says when the precompile is out of date.
- The game also runs without the precompile, but stutters the first time an area or effect appears.
- The package holds no list of the game's shaders: the first launch makes it from your own game files.

## New in this build

- **Games packed into a ZArchive (`.zar`)**, optional: the game folder stays the default. A `.zar` of the
  folder (about two thirds of its size) is read without extracting it: choose it with the launcher's
  `.zar...` button, or `run.cmd -Game "D:\Games\PPSA01341-app0.zar"`. Make one with
  `zarchive.exe <folder> <file.zar>` (https://github.com/Exzap/ZArchive/releases). It loads about as fast as
  the folder.
- **Game folders with non-ASCII names** (Chinese, for example) start now; before, the game failed to load.
- **AMD graphics cards**: an RDNA2 card (RX 6700 XT) crashed in its driver at start-up. Compute shaders now
  run as on NVIDIA except on RDNA3 and later, and GPUs other than NVIDIA's build new pipelines optimized
  before their first use. (Untested here: the test PC has no AMD GPU.)
- **Fewer pauses and hitches**: the random 0.2-0.5 s pauses in play (audio streams read from disk piece by
  piece) are gone; streamed textures upload only the mip levels that are drawn, and a texture rewritten
  before its upload ran is not uploaded twice; the render thread runs above the game's threads.
- **8-12 GB graphics cards and 16 GB PCs**: video memory goes to render targets first, and unused images
  are freed again (the collector freed none): Boletarian Palace 1-1 with 8 GB (simulated on the test PC)
  about 22 -> 45-52 fps. With under 24 GB of RAM the start-up no longer translates the recorded shaders up
  front (3 GB less RAM, in the game about 10 s sooner).
- Fixes: a crash in indirect draws (seen on Linux) and smaller ones.

## Frame rates on the test PC

i9-14900K + RTX 5090, 2560×1440, precompiled, with "Up to 120 fps" on so the numbers show the headroom:
average fps over 10 seconds (1% low in brackets) standing still, walking around and turning the camera at
one spot of each area. With the default 60 fps cap, values of about 62 and more are a steady 60.

| World | Standing | Moving | Turning the camera |
| --- | ---: | ---: | ---: |
| 1-1 Boletarian Palace | 60 (54) | 77 (51) | 84 (54) |
| 1-2 Boletarian Palace | 69 (57) | 74 (47) | 82 (58) |
| 1-3 Boletarian Palace | 70 (61) | 70 (33) | 78 (59) |
| 1-4 Boletarian Palace | 67 (60) | 72 (56) | 76 (64) |
| 2-1 Stonefang Tunnel | 86 (71) | 86 (57) | 92 (66) |
| 2-2 Stonefang Tunnel | 120 (93) | 119 (69) | 120 (86) |
| 3-1 Tower of Latria | 61 (53) | 60 (36) | 65 (43) |
| 3-2 Tower of Latria | 85 (70) | 75 (41) | 75 (53) |
| 4-1 Shrine of Storms | 77 (67) | 88 (60) | 88 (48) |
| 4-2 Shrine of Storms | 95 (74) | 88 (59) | 93 (67) |
| 5-1 Valley of Defilement | 83 (68) | 94 (47) | 103 (67) |
| 5-2 Valley of Defilement | 104 (83) | 90 (41) | 92 (62) |
| Nexus | 88 (73) | 82 (41) | 84 (60) |

2-2: the test spot is at a fog gate where almost nothing is drawn.

## 着色器预编译只对本机有效，不能共享

预编译生成的着色器缓存只对应**生成它的那台电脑的显卡型号和驱动版本**：

- 每位玩家都需要在自己的电脑上预编译一次：启动器询问时选择 "Precompile first"，或者双击 `precompile.cmd`。
  22 线程约 45 分钟，8 线程约 2 小时；关闭窗口会中止，再次运行会从中断处继续。
- 从别人电脑复制来的 `_PipelineCache` 文件夹或缓存文件无法使用（即使游戏版本相同），请不要分享或下载。
- 更新显卡驱动或更换显卡后需要重新预编译（启动器会提示）。
- 游戏 1.07 和 1.05 各有自己的缓存。
- 用 v20261007 或更早的版本预编译过的，请重新运行一次预编译：之后的版本会编译更多的管线变体（已编译的部分会保留）。启动器会提示预编译是否需要更新。
- 不预编译也能玩，但第一次进入新区域或出现新特效时会卡顿。
- 发布包里不包含游戏的着色器列表：第一次启动时会从你自己的游戏文件生成。

## 本版本新增

- **支持打包成 ZArchive（`.zar`）的游戏**（可选，游戏目录仍是默认方式）：游戏目录打包成的 `.zar`（约为目录大小的三分之二）无需解压即可直接运行：在启动器里点 `.zar...` 按钮选择，或者运行 `run.cmd -Game "D:\Games\PPSA01341-app0.zar"`。用 `zarchive.exe <目录> <文件.zar>` 打包（https://github.com/Exzap/ZArchive/releases）。加载速度与目录基本相同。
- **游戏目录路径含中文等非 ASCII 字符**时现在可以启动了（之前会加载失败）。
- **AMD 显卡**：RDNA2 显卡（RX 6700 XT）启动时在驱动内崩溃。现在除 RDNA3 及更新的显卡外，计算着色器的运行方式与 NVIDIA 相同；NVIDIA 以外的显卡在首次使用前编译优化过的管线。（测试机没有 AMD 显卡，未实测。）
- **停顿和卡顿更少**：游戏中随机出现的 0.2-0.5 秒停顿（音频流逐块从硬盘读取）已消除；流送的纹理只上传正在绘制的 mip 层级，上传执行前又被改写的纹理不再重复上传；渲染线程的优先级高于游戏线程。
- **8-12 GB 显存的显卡和 16 GB 内存的电脑**：显存优先留给渲染目标，不再使用的图像会被回收（此前回收器一个也没有回收）：1-1 波雷塔利亚王城在 8 GB 显存下（测试机上模拟）约 22 -> 45-52 帧。内存不足 24 GB 时，启动时不再预先翻译录制的着色器（内存少用 3 GB，约早 10 秒进入游戏）。
- 修复：间接绘制中的一个崩溃（在 Linux 上出现）以及若干小问题。

## 测试机上的帧率

i9-14900K + RTX 5090，2560×1440，已预编译，开启 "Up to 120 fps" 以显示性能余量：每个区域的一个位置上站立、走动、转动镜头各 10 秒的平均帧率（括号内为 1% low）。默认 60 帧上限时，约 62 以上的数值都是稳定的 60 帧。

| 世界 | 站立 | 移动 | 转动镜头 |
| --- | ---: | ---: | ---: |
| 1-1 Boletarian Palace | 60 (54) | 77 (51) | 84 (54) |
| 1-2 Boletarian Palace | 69 (57) | 74 (47) | 82 (58) |
| 1-3 Boletarian Palace | 70 (61) | 70 (33) | 78 (59) |
| 1-4 Boletarian Palace | 67 (60) | 72 (56) | 76 (64) |
| 2-1 Stonefang Tunnel | 86 (71) | 86 (57) | 92 (66) |
| 2-2 Stonefang Tunnel | 120 (93) | 119 (69) | 120 (86) |
| 3-1 Tower of Latria | 61 (53) | 60 (36) | 65 (43) |
| 3-2 Tower of Latria | 85 (70) | 75 (41) | 75 (53) |
| 4-1 Shrine of Storms | 77 (67) | 88 (60) | 88 (48) |
| 4-2 Shrine of Storms | 95 (74) | 88 (59) | 93 (67) |
| 5-1 Valley of Defilement | 83 (68) | 94 (47) | 103 (67) |
| 5-2 Valley of Defilement | 104 (83) | 90 (41) | 92 (62) |
| Nexus | 88 (73) | 82 (41) | 84 (60) |

2-2：测试位置在雾门前，几乎不绘制任何东西。
