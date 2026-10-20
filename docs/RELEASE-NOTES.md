## New in this build

- **Less memory on 16 GB PCs and 8 GB graphics cards:**
  - Game memory nothing ever wrote is no longer read when the GPU first uses it, only taken as zeros: 0.7-1.4 GB less
    RAM in use on a 16 GB PC (`KYTY_FRESH_MEMORY=0` turns it off).
  - On PCs with 16 GB of RAM, textures the game only reads keep one copy, in video memory, instead of a second one in
    RAM: about 0.5 GB less RAM in use (`KYTY_TEXTURE_OFFLOAD=0` turns it off, `=1` turns it on with more RAM).
  - The shaders of a world the game left are dropped a minute after it, on every graphics card. Before, they piled up
    for the whole session (the driver's memory went from 0.9 to 2 GB on a trip through five worlds).
  - The warm-up at start compiles the shaders recorded for the map the game loads, not those of every map (up to 4 GB
    of the driver's memory).
  - Video memory: the GPU's address table takes 64 MiB instead of 512 MiB, and game buffers no longer keep video
    memory for game memory the game freed. On cards with less than 12 GB, video memory is also allocated in smaller
    blocks and game buffers are compacted after the game frees memory: about 0.6 GB less video memory on an 8 GB card
    after travelling between worlds (`KYTY_BUFFER_DEFRAG=0` turns the compacting off).
- **AMD and Intel graphics cards:** pipelines compiled while playing are kept and loaded at the next start, instead of
  being compiled again every session (issue #78; `KYTY_PLAYED_PIPELINES=0` turns it off).
- **More shaders precompiled:** a player shared the shader hints of a whole 1.07 playthrough (issue #88, thanks
  @tscftw): 2,091 more shader programs and 2,213 more pipelines, from places our own test runs never reached. The
  launcher offers the precompile again at the first start; only the new part is compiled.
- **Smoother:** in places with many lights and enemies (Boletaria 1-3), reading a light table no longer waits for the
  GPU: a few more fps and fewer short stutters.
- **Fixes:**
  - On "lite" Windows builds that turn Control Flow Guard on for every program, the emulator ended within the first
    seconds without a line in the log (issue #56).
  - The save dialogs show Chinese, Japanese and Korean text with the system's font instead of "?" (a contribution by
    @Myoko, PR #75).
  - A save whose capacity record was all zeros (after a power cut) failed every time the game opened it; it now counts
    as empty (a contribution by @Vorshim92, PR #74).
  - The driver's shader caches: a small one is saved at least once a minute while shaders compile, and with the
    precompiled store one past 256 MiB starts over instead of growing.
- **README:** how to play in Chinese, Japanese or Korean (a value in the game's `param.json` picks the language list),
  and how to update to a newer package (extract it over the old folder; what is kept).
- **Thanks** to @nerdjb for the Linux port fixes and the Linux package, and to everyone who sent logs and tests.

## 本版本的变化

- **16 GB 内存的电脑和 8 GB 显卡占用更少：**
  - 游戏从未写过的内存，在 GPU 第一次使用时不再去读取，直接当作全零：16 GB 内存的电脑上少用 0.7-1.4 GB 内存（`KYTY_FRESH_MEMORY=0` 可关闭）。
  - 在 16 GB 内存的电脑上，游戏只读取的纹理只在显存里保留一份，不再在内存里多存一份：少用约 0.5 GB 内存（`KYTY_TEXTURE_OFFLOAD=0` 可关闭，`=1` 可在更大内存上开启）。
  - 游戏离开一个世界一分钟后，那个世界的着色器会被释放，所有显卡都是如此。之前它们会在整个游玩过程中一直累积（走一遍五个世界，驱动内存从 0.9 GB 涨到 2 GB）。
  - 启动时的预热只编译游戏正在加载的地图录到的着色器，不再编译所有地图的（之前最多占用驱动 4 GB 内存）。
  - 显存：GPU 地址表只占 64 MiB，不再是 512 MiB；游戏缓冲区不再为游戏已释放的内存保留显存。显存小于 12 GB 的显卡上，显存还会按更小的块分配，游戏释放内存后缓冲区会被整理紧凑：8 GB 显卡在几个世界之间来回之后显存少用约 0.6 GB（`KYTY_BUFFER_DEFRAG=0` 可关闭整理）。
- **AMD 和 Intel 显卡：** 游戏过程中编译的管线会被保存，下次启动直接载入，不再每次都重新编译（issue #78；`KYTY_PLAYED_PIPELINES=0` 可关闭）。
- **预编译的着色器更多了：** 一位玩家分享了他完整通关 1.07 版的着色器提示（issue #88，感谢 @tscftw）：多了 2,091 个着色器程序和 2,213 个管线，来自我们自己的测试路线没有走到的地方。第一次启动时启动器会再次提示预编译，只会编译新增的部分。
- **更流畅：** 在灯光和敌人很多的地方（波雷塔利亚 1-3），读取灯光表不再等待 GPU：帧率高几帧，短暂卡顿更少。
- **修正：**
  - 在对所有程序都开启控制流防护（CFG）的"精简版" Windows 上，模拟器会在开头几秒内退出，日志里没有任何记录（issue #56）。
  - 存档对话框里的中文、日文、韩文改用系统字体显示，不再显示为"?"（@Myoko 的贡献，PR #75）。
  - 容量记录全为零的存档（断电之后）以前每次打开都会失败，现在按空存档处理（@Vorshim92 的贡献，PR #74）。
  - 驱动的着色器缓存：编译着色器期间，较小的缓存至少每分钟保存一次；有预编译存储时，超过 256 MiB 的缓存会重新开始，不再一直增长。
- **README：** 如何用中文、日文或韩文游玩（游戏 `param.json` 里的一个值决定可选语言），以及如何更新到新的包（解压覆盖旧文件夹，哪些内容会保留）。
- **感谢** @nerdjb 完成 Linux 移植的修正和 Linux 安装包，也感谢所有提供日志和测试的玩家。
