## New in this build

Your precompiled shaders stay valid: the shaders are the same as in v20261027.

- **Crash at a world load on PCs short of RAM** (#228): at a teleport, an RX 9070 with 5.4 GB of its video memory free
  could not get a new 108 MB GPU buffer while the PC's RAM was nearly full, and the emulator exited at once. It now
  tries again for up to 10 seconds, and the log says what refused it: the driver's answer in video and in system
  memory, and the RAM and commit left.
- **DLSS sharpening** (#224): the game's own TAA sharpens its picture; DLSS in its place does not, so fine detail such
  as the engravings on armour looked softer with it. The launcher's Graphics page has "DLSS sharpening": Off by
  default, then Low, Medium and High. It runs RCAS, the sharpening FSR 3 uses, on DLSS's picture
  (`run.cmd -Set KYTY_DLSS_SHARPNESS=0.6`, 0 to 1). At DLAA, Medium brought the fine detail on the armour from about
  78% of the TAA's to about 91%.
- **Sharper textures below the output's size** (#224): when DLSS or FSR 3 renders below the output's height, textures
  are now read with the detail of the output's size (a texture LOD bias of log2(render height / output height), as
  NVIDIA's DLSS guide recommends): about 13% more fine detail from 1080 to 4K. `-Set KYTY_UPSCALE_LOD_BIAS=0` turns
  it off.
- **Full textures on 16 GB cards** (#215, #224): v20261027 chose Texture reduce from the budget left after the frame
  generation and upscaler reserve, so a 16 GB card close to its budget could get half-resolution textures as soon as
  DLSS or frame generation was on. It now goes by the card's own video memory: 12 GB or less reduces, more keeps full
  textures.
- **Version 1.005: 1080p output and DLSS** (#226): with Demon's Souls 1.005 (European and US editions), "Game output:
  1080p", DLSS's 1080p output and DLSS's render heights now work as with 1.07.
- **DLSS slowing down over time** (#129): with DLSS (without DLSS frame generation) every rendered frame now reaches
  the present of NVIDIA's Streamline, as it requires. Frames replaced by newer ones before they were shown made its
  present calls grow on an RTX 2080 Ti until only 4-10 frames a second were shown. `-Set KYTY_PRESENT_EVERY_FRAME=0`
  goes back to the old way.
- **Grainy Nexus runes on Linux** (#222): v20261027's readbacks of neighbouring buffers (PR #219) are off by default
  again: on Linux they made the floor runes around the player in the Nexus grainy. `-Set KYTY_READBACK_SPAN=1` turns
  them back on.
- **Fewer slow frames near the video memory budget** (#215): a game buffer of 64 MB or more that keeps growing is now
  made with an eighth more room, so it is made again whole about half as often (one went from 638 to 910 MB in five
  steps in a session, each a frame of 100-135 ms). The texture collector also counts its ages in seconds at any vblank
  rate (at 240 Hz they were four times as long).
- **DLSS frame generation on Linux** (#215): when NGX could not make DLSS frame generation (video memory full), it is
  tried again later instead of staying off for the session, and short drops of the render size (menus) no longer
  make it again. Not tested on our side (no Linux PC with an NVIDIA card).
- **Mouse wheel** (#91): `Mouse:WheelUp` and `Mouse:WheelDown` can be mapped to controls
  (`"--keymap", "Up=Mouse:WheelUp"`), each notch a short press; a control takes one key and one mouse input.
- **Back to Big Picture** (#217): when the window that had the focus at the start is gone (Big Picture makes its window
  again), the focus goes to Steam's largest window instead.
- **Precompile** (#225): on a FAT32 drive (at most 4 GB a file; the store is about 5.5 GB) the precompile now stops
  before it starts and says so, less than 12 GB free gets a warning, a store that antivirus or the indexer holds for a
  moment is put in place again for up to 5 s, and a failed merge says why.
- **Linux launcher** (#90): extra options given more than once (`--keymap`) are all passed on.
- **Thanks** to @AudaxTenebra, @HybOj, @theunholy, @Zaza26262, @2mg, @Psychowarden, @theraineydaze, @javsp,
  @ededaelita1-afk and @arhaaaaaaaa-ux for their reports and tests.

## New in v20261027

Your precompiled shaders stay valid: for as long as you keep them, the shaders are translated as in v20261023. Your
next precompile (a new install, or after a graphics driver update) brings lighter shaders (first item).

- **Lighter shaders** (with your next precompile): a PS5 shader's register writes are masked lane by lane, and the
  emulator kept the old value of every lane outside the mask with an extra instruction: 20-32% of all instructions in
  the heaviest shaders. Where nothing reads those lanes, that instruction is now left out. The game's translated
  shaders are 8.5% smaller, the heaviest compute shaders run 4-14% fewer instructions on NVIDIA (one of them 128
  registers instead of 168), and an RTX 5090 at 4K does 3% less GPU work a frame at Boletaria: up to 3% more fps where
  the graphics card is the limit. Shaders precompiled by earlier versions stay in use and up to date, so no precompile
  is offered for this alone. `run.cmd -Set KYTY_EXEC_SELECTS=0` turns it off (precompile again after that).
- **VRR displays** (#221): on a G-SYNC or FreeSync display, put `-Set KYTY_VRR=1` in the launcher's Advanced page,
  Command-line options (or `run.cmd -Set KYTY_VRR=1`). Each frame is then shown as soon as it is done, as a PS5 does on
  a VRR display, instead of at the next tick of the emulator's 60 Hz clock. Below 60 fps the frames stayed on screen
  for 16.7 or 33.3 ms by turns while the game moved by its real frame time: uneven motion even on a VRR display. At
  1-1 with the graphics card as the limit, the difference between one frame's time on screen and the next went from
  8.3 ms to 0.9 ms. Off by default; the log's `Flips:` line every 30 s shows how even the frames were.
- **Freezes after menus at 120 fps** (#221): with the 120 fps option and the card's video memory full, a menu kept open
  for 5 seconds let the textures of the world be dropped, and they were made again as it closed: frames of 1-5 s
  (about 1.3 GB). The texture collector now counts its ages in seconds (10 and 20 s) at any frame rate.
- **No anti-aliasing** (#220): the launcher's Upscaler list has "Off (no anti-aliasing)": Demon's Souls without its
  TAA and the camera jitter TAA needs, a sharper picture with jagged edges (`run.cmd -Antialiasing off`).
- **Video memory for frame generation and upscaling** (#215): DLSS frame generation, Linux's built-in FSR 3 frame
  generation, and DLSS or FSR 3 upscaling now get room in the card's video memory budget (1.5 GB for frame
  generation, 0.5 GB more for upscaling), as FSR frame generation on Windows already did. An RTX 5080 (16 GB) with DLSS
  and DLSS frame generation at 3440x1440 had counted as a card with plenty of memory and ran out of it late in a
  session. `KYTY_FSR_VRAM_RESERVE_MB` sets the frame generation share; the log says what was set aside.
- **Less RAM with Texture reduce**: Texture reduce (on by default for cards under 12 GB) keeps the largest level of
  big textures out of video memory; now the game no longer loads those levels either. At Boletaria the textures it
  streams went from 2.7 to 1.8 GB, about 1 GB less RAM, with the same picture.
- **Memory back to Windows sooner on 16 GB PCs** (#174): after a trip between worlds, the memory the game freed goes
  back to Windows twice as fast (2.3 GB instead of 1.1 GB on our test route). On a PC that pages hard, giving it back
  no longer holds the game up for up to a second at a time while Windows is slow.
- **Read-back pages on 16 GB PCs** (#159, #174): below 2 GB of free RAM, v20261026 protected the pages read back from
  the graphics card with guard pages (the blue screen fix). Guard pages let another thread read an old page now and
  then (a texture flickering for a moment), and 16 GB PCs sit around 2 GB free most of a session. They now take over
  only below 1.5 GB (every reported blue screen came with less than that) and give way again at 2 GB (was 3 GB).
- **Fewer readbacks on PCs with more than 20 GB of RAM** (PR #219, @DevList1454): when the game reads memory the
  graphics card wrote, neighbouring buffers now come back in the same copy. At Boletaria 1-3 the readbacks went from
  about 51 to 19 a frame, and the frame rate from 50.2 to 52.2 fps in @DevList1454's measurements.
- **Back to Big Picture** (#217): started from Steam's Big Picture, quitting the game hands the focus back to Big
  Picture, which takes the controller again without a click.
- **Steam Deck** (Linux package): the Deck's GPU now runs the game's 64-wide compute shaders natively (23% less GPU
  time in them; 20.6 to 22.1 fps at 1-1 with the GPU held at 1600 MHz), and the emulator's own GPU work for its memory
  tracking is lighter on every graphics card (7.2 to 0.9 ms a frame on the Deck). Not 30 fps yet.
- **Thanks** to @DevList1454 for PR #219, and to @crni20zd, @Psychowarden, @javsp, @ft1704, @thxnk420, @Myoko and @brokeneggg for
  their reports and tests.

## 本版本的变化

已有的预编译着色器继续有效：着色器与 v20261027 相同。

- **内存不足的电脑在载入世界时崩溃**（#228）：一张 RX 9070 在传送时显存还剩 5.4 GB，但电脑内存几乎用尽，新的 108 MB
  显卡缓冲区创建失败，模拟器随即退出。现在会在最多 10 秒内反复重试，日志也会写出是什么拒绝了分配：驱动在显存和系统内存中的
  回应，以及剩余的内存和可提交内存。
- **DLSS 锐化**（#224）：游戏自带的 TAA 会锐化画面；DLSS 取代 TAA 后不会，所以铠甲花纹之类的细节看起来偏软。启动器「画质」
  页新增「DLSS 锐化」：默认关闭，可选低、中、高。它对 DLSS 的画面运行 RCAS（FSR 3 使用的锐化）
  （`run.cmd -Set KYTY_DLSS_SHARPNESS=0.6`，0 到 1）。在 DLAA 下，「中」让铠甲上的细节从 TAA 的约 78% 提高到约 91%。
- **低于输出分辨率时纹理更清晰**（#224）：DLSS 或 FSR 3 的渲染高度低于输出高度时，纹理现在按输出尺寸的精细度读取（纹理 LOD
  偏移 log2(渲染高度 / 输出高度)，即 NVIDIA DLSS 指南推荐的值）：从 1080 到 4K，细节多约 13%。
  `-Set KYTY_UPSCALE_LOD_BIAS=0` 可以关闭。
- **16 GB 显卡保持完整纹理**（#215、#224）：v20261027 按扣除插帧和超分预留之后的显存预算决定是否缩减纹理，接近预算的
  16 GB 显卡一开 DLSS 或插帧，纹理就可能只剩一半分辨率。现在按显卡本身的显存决定：12 GB 及以下缩减，更大的保持完整纹理。
- **1.005 版本的 1080p 输出和 DLSS**（#226）：《恶魔之魂》1.005（欧版和美版）现在也能使用「游戏输出：1080p」、DLSS 的
  1080p 输出和 DLSS 的渲染高度，与 1.07 相同。
- **DLSS 越玩越慢**（#129）：使用 DLSS（不开 DLSS 插帧）时，现在每一帧渲染结果都会送到 NVIDIA Streamline 的呈现，这是它
  的要求。以前等待显示的帧会被更新的帧替换，在一张 RTX 2080 Ti 上让每次呈现越来越慢，最后每秒只显示 4-10 帧。
  `-Set KYTY_PRESENT_EVERY_FRAME=0` 可以恢复旧方式。
- **Linux 上要石神殿的地面符文出现颗粒**（#222）：v20261027 的相邻缓冲区一并读回（PR #219）重新默认关闭：在 Linux 上它让
  要石神殿里玩家周围的地面符文出现颗粒。`-Set KYTY_READBACK_SPAN=1` 可以重新打开。
- **接近显存预算时卡顿帧更少**（#215）：64 MB 以上且持续增长的游戏缓冲区，现在会多留八分之一的空间，整体重建的次数约减半
  （一局中曾有一个缓冲区分五步从 638 MB 长到 910 MB，每一步都有一帧 100-135 ms）。纹理回收在任何刷新率设置下也都按秒计时
  （240 Hz 时原来要长四倍）。
- **Linux 的 DLSS 插帧**（#215）：NGX 无法创建 DLSS 插帧（显存已满）时，稍后会再试，而不是整局关闭；渲染尺寸短暂变小
  （菜单）时也不再重建插帧。我们没有装 NVIDIA 显卡的 Linux 电脑，这项未经测试。
- **鼠标滚轮**（#91）：`Mouse:WheelUp` 和 `Mouse:WheelDown` 可以映射到按键（`"--keymap", "Up=Mouse:WheelUp"`），滚轮每格
  相当于一次短按；一个按键可以同时对应一个键盘键和一个鼠标输入。
- **回到 Big Picture**（#217）：启动时拥有焦点的窗口已经不存在时（Big Picture 会重建自己的窗口），焦点改为交给 Steam 最大的
  窗口。
- **预编译**（#225）：在 FAT32 磁盘上（单个文件最大 4 GB，而存储文件约 5.5 GB）预编译现在会在开始前停止并说明原因；可用空间
  少于 12 GB 时给出提醒；存储文件被杀毒软件或索引服务短暂占用时，最多再试 5 秒；合并失败时会写出原因。
- **Linux 启动器**（#90）：多次给出的额外参数（`--keymap`）现在全部传给模拟器。
- **感谢** @AudaxTenebra、@HybOj、@theunholy、@Zaza26262、@2mg、@Psychowarden、@theraineydaze、@javsp、@ededaelita1-afk
  和 @arhaaaaaaaa-ux 的反馈与测试。

## v20261027 的变化

已有的预编译着色器继续有效：只要保留它们，着色器就按 v20261023 的方式翻译。下次预编译（新安装，或更新显卡驱动之后）会得到
更轻量的着色器（第一项）。

- **更轻量的着色器**（下次预编译后生效）：PS5 着色器写寄存器时按通道屏蔽，模拟器以前用一条额外指令为屏蔽之外的每个通道保留
  旧值，占最重着色器全部指令的 20-32%。现在只要没有地方读取这些通道，就省掉这条指令。游戏翻译后的着色器小了 8.5%，最重的
  计算着色器在 NVIDIA 上少执行 4-14% 的指令（其中一个寄存器从 168 降到 128），RTX 5090 在 4K、波雷塔利亚每帧的 GPU 工作少
  3%：在显卡是瓶颈的场合，帧率最多高约 3%。旧版本预编译的着色器继续使用、仍算最新，不会因为这一项提示重新预编译。
  `run.cmd -Set KYTY_EXEC_SELECTS=0` 可以关闭（关闭后请重新预编译）。
- **VRR 显示器**（#221）：在 G-SYNC 或 FreeSync 显示器上，把 `-Set KYTY_VRR=1` 填进启动器「高级」页的「命令行参数」（或
  `run.cmd -Set KYTY_VRR=1`）。每一帧画完就立即显示，和 PS5 在 VRR 显示器上一样，而不是等模拟器 60 Hz 时钟的下一拍。低于
  60 fps 时，以前每帧轮流停留 16.7 或 33.3 ms，而游戏按实际帧时间推进画面：即使在 VRR 显示器上，动作也不均匀。在 1-1、显卡
  为瓶颈时，相邻两帧显示时长之差从 8.3 ms 降到 0.9 ms。默认关闭；日志每 30 秒的 `Flips:` 行会显示帧是否均匀。
- **120 fps 下关闭菜单后的卡顿**（#221）：开启 120 fps 选项且显存已满时，菜单打开 5 秒就会让场景的纹理被回收，关闭菜单时
  再重新生成：出现 1-5 秒的帧（约 1.3 GB）。纹理回收现在在任何帧率下都按秒计算（10 秒和 20 秒）。
- **关闭抗锯齿**（#220）：启动器「超分辨率」列表新增「关闭（无抗锯齿）」：去掉《恶魔之魂》自带的 TAA 及其所需的镜头抖动，
  画面更锐利，但边缘有锯齿（`run.cmd -Antialiasing off`）。
- **为插帧和超分留出显存**（#215）：DLSS 插帧、Linux 内置的 FSR 3 插帧，以及 DLSS 或 FSR 3 超分，现在都在显卡的显存预算里
  留有空间（插帧 1.5 GB，超分再加 0.5 GB），与 Windows 上的 FSR 插帧原有的做法相同。一张 RTX 5080（16 GB）在 3440x1440 下
  开 DLSS 和 DLSS 插帧时，以前被当作显存充裕的显卡，游玩后期显存耗尽。`KYTY_FSR_VRAM_RESERVE_MB` 可以设定插帧所留的大小；
  日志会写出预留了多少。
- **纹理缩减时内存更少**：纹理缩减（显存小于 12 GB 的显卡默认开启）不把大纹理的最大一级放进显存；现在游戏本身也不再加载
  这些级别。在波雷塔利亚，游戏加载的纹理从 2.7 GB 降到 1.8 GB，内存少用约 1 GB，画面不变。
- **16 GB 电脑更快归还内存**（#174）：在世界之间往返后，游戏释放的内存归还给 Windows 的速度快了一倍（我们的测试路线上
  2.3 GB，原来 1.1 GB）。在频繁换页的电脑上，归还内存也不再在 Windows 变慢时让游戏每次停住最多一秒。
- **16 GB 电脑上的读回页**（#159、#174）：v20261026 在可用内存少于 2 GB 时，用保护页保护从显卡读回的内存页（蓝屏修复）。
  保护页偶尔会让另一个线程读到旧的页（某个纹理闪一下），而 16 GB 电脑大部分时间可用内存都在 2 GB 左右。现在低于 1.5 GB
  才改用保护页（所有报告的蓝屏都发生在这个值以下），回到 2 GB 后恢复（原为 3 GB）。
- **内存超过 20 GB 的电脑读回更少**（PR #219，@DevList1454）：游戏读取显卡写入的内存时，相邻的缓冲区现在在同一次复制中
  一起读回。在波雷塔利亚 1-3，每帧读回从约 51 次降到 19 次；在 @DevList1454 的测量中，帧率从 50.2 提高到 52.2 fps。
- **回到 Big Picture**（#217）：从 Steam 的 Big Picture 启动时，退出游戏后焦点会交还给 Big Picture，无需点击即可继续用
  手柄操作。
- **Steam Deck**（Linux 版）：Deck 的 GPU 现在原生运行游戏的 64 宽计算着色器（这些着色器的 GPU 时间少 23%；GPU 固定
  1600 MHz 时，1-1 从 20.6 提升到 22.1 fps）；模拟器用于内存跟踪的 GPU 工作在所有显卡上都更轻（Deck 上每帧 7.2 降到
  0.9 ms）。离 30 fps 还有距离。
- **感谢** @DevList1454 的 PR #219，以及 @crni20zd、@Psychowarden、@javsp、@ft1704、@thxnk420、@Myoko 和 @brokeneggg 的反馈与测试。
