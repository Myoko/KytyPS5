// Demon's Souls' scene nodes keep their children in an eastl::vector (node + 0x30); three traversals of that tree
// read node + 0x98 / + 0xa0 first and crashed on a null child in job workers while areas streamed in (01.007.000
// eboot+0x8daff8 10-03 and 10-05, eboot+0xb9d1e1 10-05, eboot+0xc5cabf 10-06; the 10-06 parent held three null
// children that stayed null). What writes them is not known: the child list mutators (AddChild 0x8da6f0,
// RemoveChild 0x8dae50, InsertChild 0x8daee0) never ran concurrently on one parent nor left a null in an
// instrumented 1-1 walk. Each of the three treats a null node as an empty one here (a find returns nothing, a
// visit visits nothing) and the first skips are printed with the registers that locate the parent's vector.
#include "loader/demonsSoulsSceneGuard.h"

#include "common/logging/log.h"
#include "common/virtualMemory.h"
#include "graphics/host_gpu/hostMemory.h"
#include "graphics/host_gpu/renderer/demonsSouls.h"
#include "kernel/memory.h"
#include "loader/demonsSoulsIdle.h"
#include "loader/guestCode.h"
#include "loader/runtimeLinker.h"

#include <array>
#include <atomic>
#include <cstdio>
#include <cstring>

namespace Loader::DemonsSoulsSceneGuard {
namespace {
constexpr uint64_t PageSize = 0x4000, CaveOffset = 0x8000000 + 2 * PageSize;

// The traversals' first bytes as both builds seen have them (01.007.000 eboot+0x8dafd0, +0xb9d1d0 and +0xc5ca90;
// 01.005.000 +0x8bf620, +0xb7dd20 and +0xc3bf90), up to their reads of node + 0x98 / + 0xa0, with what a build
// moves (displacements, the frame size) left out.
struct Traversal {
	const char* what;
	const char* code;
};
constexpr std::array<Traversal, 3> Traversals {{
    {"find a node by id (returns it or null)",
     "55 48 89 e5 41 57 41 56 41 55 41 54 53 50 89 c8 89 d3 41 89 f6 49 89 ff 48 89 4d d0 83 e0 fd 83 f8 04 0f 84 ?? ?? "
     "?? ?? 4d 8b a7 98 00 00 00 4d 3b a7 a0 00 00 00 0f 84 ?? ?? ?? ?? 41 83 fe ff"},
    {"visit a subtree", "55 48 89 e5 41 57 41 56 41 55 41 54 53 48 83 ec 58 48 8b 87 a0 00 00 00 4c 8b bf 98 00 00 00 89 75 "
                        "d4 48 89 7d c8 48 89 45 b0 49 39 c7 74 60 48 8d 45 10 48 8b 48 28 48 8b 10 4c 8b 60 08 4c 8b 68 10"},
    {"visit a subtree", "55 48 89 e5 41 57 41 56 41 55 41 54 53 48 81 ec ?? ?? ?? ?? 48 8b 05 ?? ?? ?? ?? 89 b5 5c ff ff ff 48 "
                        "8b 00 48 89 45 d0 48 89 bd 50 ff ff ff 4c 8b af 98 00 00 00 4c 8b a7 a0 00 00 00 4d 39 e5"},
}};
// Each begins with push rbp; mov rbp, rsp; push r15: its stub runs them, the jump to the stub replaces them.
constexpr std::array<uint8_t, 6> Prologue {0x55, 0x48, 0x89, 0xe5, 0x41, 0x57};

uint64_t              g_base = 0;
std::atomic<uint32_t> g_skips {0};

void KYTY_SYSV_ABI Skipped(uint64_t offset, uint64_t caller, uint64_t rbx, uint64_t r14) {
	if (g_skips.fetch_add(1, std::memory_order_relaxed) >= 32) return;
	// (At the recursive visits' call sites rbx points at the null element of the parent's vector, r14 at its end.)
	std::printf("Demon's Souls scene guard: a null node skipped by eboot+0x%llx (caller eboot+0x%llx, rbx 0x%llx, r14 "
	            "0x%llx)\n",
	            static_cast<unsigned long long>(offset), static_cast<unsigned long long>(caller - g_base),
	            static_cast<unsigned long long>(rbx), static_cast<unsigned long long>(r14));
}
} // namespace

void Install(Program* program) {
#if defined(__x86_64__) || defined(_M_X64)
	if (program == nullptr || !Libs::Graphics::DemonsSouls::IsSupportedGame() || program->file_name.filename() != "eboot.bin" ||
	    program->mapped_size > CaveOffset || program->base_vaddr > UINT64_MAX - CaveOffset - PageSize)
		return;
	std::array<uint64_t, Traversals.size()> entries {};
	for (size_t i = 0; i < Traversals.size(); i++) {
		const auto entry = GuestCode::FindUnique(*program, GuestCode::Pattern(Traversals[i].code));
		if (!entry || std::memcmp(reinterpret_cast<const void*>(*entry), Prologue.data(), Prologue.size()) != 0) {
			std::printf("Demon's Souls scene guard: no single '%s' traversal of a known build found; retaining guest "
			            "code\n",
			            Traversals[i].what);
			return;
		}
		entries[i] = *entry;
	}
	const auto requested = program->base_vaddr + CaveOffset;
	const auto allocated = Libs::LibKernel::Memory::AllocateRuntimeMemory(
	    requested, PageSize, Common::VirtualMemory::Mode::ExecuteReadWrite, "demons_souls_scene_guard", true);
	if (allocated != requested) {
		if (allocated) Libs::LibKernel::Memory::FreeGuestMemory(allocated, PageSize);
		return;
	}
	g_base = program->base_vaddr;
	using namespace Xbyak::util;
	Xbyak::ClearError();
	Xbyak::CodeGenerator c(PageSize, reinterpret_cast<void*>(allocated));
	std::array<const uint8_t*, Traversals.size()> stubs {};
	for (size_t i = 0; i < Traversals.size(); i++) {
		const auto   entry = entries[i];
		Xbyak::Label skip;
		c.align(16);
		stubs[i] = c.getCurr();
		c.test(rdi, rdi); // (flags are not preserved across a call)
		c.jz(skip);
		c.db(Prologue.data(), Prologue.size());
		c.jmp(reinterpret_cast<const void*>(entry + Prologue.size()));
		// A null node: printed (registers, flags and FP state kept), then nothing found or visited.
		c.L(skip);
		c.pushfq();
		for (const auto& reg: {rax, rcx, rdx, rsi, rdi, r8, r9, r10, r11})
			c.push(reg);
		c.mov(rsi, ptr[rsp + 80]); // the return address
		c.mov(rdi, entry - program->base_vaddr);
		c.mov(rdx, rbx);
		c.mov(rcx, r14);
		c.sub(rsp, 520); // entry rsp is 8 mod 16: 80 + 520 bytes align it for FXSAVE
		constexpr uint8_t save_fp[] {0x48, 0x0f, 0xae, 0x04, 0x24}; // FXSAVE64 [rsp]
		c.db(save_fp, sizeof(save_fp));
		c.mov(rax, reinterpret_cast<uint64_t>(&Skipped));
		c.call(rax);
		c.fxrstor64(ptr[rsp]);
		c.add(rsp, 520);
		for (const auto& reg: {r11, r10, r9, r8, rdi, rsi, rdx, rcx, rax})
			c.pop(reg);
		c.popfq();
		c.xor_(eax, eax);
		c.ret();
	}
	c.ready();
	if (Xbyak::GetError() || !Common::VirtualMemory::FlushInstructionCache(allocated, c.getSize()) ||
	    !Libs::LibKernel::Memory::ProtectGuestMemory(allocated, PageSize, Common::VirtualMemory::Mode::ExecuteRead, nullptr)) {
		Libs::LibKernel::Memory::FreeGuestMemory(allocated, PageSize);
		return;
	}
	// Installation occurs before module initializers or guest worker threads run.
	for (size_t i = 0; i < Traversals.size(); i++) {
		const auto             entry = entries[i];
		std::array<uint8_t, 5> jump {0xe9};
		const auto             displacement = static_cast<int32_t>(reinterpret_cast<uint64_t>(stubs[i]) - (entry + 5));
		std::memcpy(jump.data() + 1, &displacement, sizeof(displacement));
		std::memcpy(reinterpret_cast<void*>(entry), jump.data(), jump.size());
		Common::VirtualMemory::FlushInstructionCache(entry, jump.size());
	}
	std::printf("Demon's Souls scene guard: installed (traversals at eboot+0x%llx, 0x%llx and 0x%llx skip a null node)\n",
	            static_cast<unsigned long long>(entries[0] - program->base_vaddr),
	            static_cast<unsigned long long>(entries[1] - program->base_vaddr),
	            static_cast<unsigned long long>(entries[2] - program->base_vaddr));
#endif
}
} // namespace Loader::DemonsSoulsSceneGuard
