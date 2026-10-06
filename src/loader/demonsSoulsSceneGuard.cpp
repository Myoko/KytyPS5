// Demon's Souls' scene nodes keep their children in an eastl::vector (node + 0x30); three traversals of that tree
// read node + 0x98 / + 0xa0 first and crashed on a null child in job workers while areas streamed in (eboot+0x8daff8
// 10-03 and 10-05, eboot+0xb9d1e1 10-05, eboot+0xc5cabf 10-06; the 10-06 parent held three null children that
// stayed null). What writes them is not known: the child list mutators (AddChild 0x8da6f0, RemoveChild 0x8dae50,
// InsertChild 0x8daee0) never ran concurrently on one parent nor left a null in an instrumented 1-1 walk. Each of
// the three treats a null node as an empty one here (a find returns nothing, a visit visits nothing) and the first
// skips are printed with the registers that locate the parent's vector.
#include "loader/demonsSoulsSceneGuard.h"

#include "common/logging/log.h"
#include "common/virtualMemory.h"
#include "graphics/host_gpu/hostMemory.h"
#include "graphics/host_gpu/renderer/demonsSouls.h"
#include "kernel/memory.h"
#include "loader/demonsSoulsIdle.h"
#include "loader/runtimeLinker.h"

#include <array>
#include <atomic>
#include <cstdio>
#include <cstring>

namespace Loader::DemonsSoulsSceneGuard {
namespace {
constexpr uint64_t PageSize = 0x4000, CaveOffset = 0x8000000 + 2 * PageSize;

struct Traversal {
	uint64_t               offset;
	std::array<uint8_t, 6> prologue; // push rbp; mov rbp, rsp; push r15
};
constexpr std::array<Traversal, 3> Traversals {{
    {0x8dafd0, {0x55, 0x48, 0x89, 0xe5, 0x41, 0x57}}, // find a node by id (returns it or null)
    {0xb9d1d0, {0x55, 0x48, 0x89, 0xe5, 0x41, 0x57}}, // visit a subtree
    {0xc5ca90, {0x55, 0x48, 0x89, 0xe5, 0x41, 0x57}}, // visit a subtree
}};

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
	for (const auto& traversal: Traversals) {
		const auto entry = program->base_vaddr + traversal.offset;
		if (!Libs::Graphics::HostMemoryRangeIsReadable(entry, traversal.prologue.size()) ||
		    std::memcmp(reinterpret_cast<const void*>(entry), traversal.prologue.data(), traversal.prologue.size()) != 0) {
			LOGF("Demon's Souls scene guard: code differs at eboot+0x%llx; retaining guest code\n",
			     static_cast<unsigned long long>(traversal.offset));
			return;
		}
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
		const auto entry = program->base_vaddr + Traversals[i].offset;
		Xbyak::Label skip;
		c.align(16);
		stubs[i] = c.getCurr();
		c.test(rdi, rdi); // (flags are not preserved across a call)
		c.jz(skip);
		c.db(Traversals[i].prologue.data(), Traversals[i].prologue.size());
		c.jmp(reinterpret_cast<const void*>(entry + Traversals[i].prologue.size()));
		// A null node: printed (registers, flags and FP state kept), then nothing found or visited.
		c.L(skip);
		c.pushfq();
		for (const auto& reg: {rax, rcx, rdx, rsi, rdi, r8, r9, r10, r11})
			c.push(reg);
		c.mov(rsi, ptr[rsp + 80]); // the return address
		c.mov(rdi, Traversals[i].offset);
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
		const auto             entry = program->base_vaddr + Traversals[i].offset;
		std::array<uint8_t, 5> jump {0xe9};
		const auto             displacement = static_cast<int32_t>(reinterpret_cast<uint64_t>(stubs[i]) - (entry + 5));
		std::memcpy(jump.data() + 1, &displacement, sizeof(displacement));
		std::memcpy(reinterpret_cast<void*>(entry), jump.data(), jump.size());
		Common::VirtualMemory::FlushInstructionCache(entry, jump.size());
	}
	LOGF("Demon's Souls scene guard: installed (3 traversals skip a null node)\n");
#endif
}
} // namespace Loader::DemonsSoulsSceneGuard
