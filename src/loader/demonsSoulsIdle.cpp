#include "loader/demonsSoulsIdle.h"

#include "common/logging/log.h"
#include "common/threads.h"
#include "common/virtualMemory.h"
#include "graphics/host_gpu/hostMemory.h"
#include "graphics/host_gpu/renderer/demonsSouls.h"
#include "kernel/memory.h"
#include "loader/runtimeLinker.h"

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <functional>
#include <span>

namespace Loader::DemonsSoulsIdle {
namespace {
constexpr uint64_t     PageSize = 0x4000, CaveOffset = 0x8000000;
// PollBytes[16..20) is the immediate of the poll's `sub rsp, imm32` (that instruction is 48 81 ec at
// [13,16)). The immediate is as build-specific as the RIP-relative displacement after it, which the
// prologue span already stops short of: PPSA01341 01.007.000 has 0x88 there and PPSA01340 01.005.000
// has 0x98, its frame 16 bytes larger. Both are passed over; everything else in the prologue still
// has to match, and since the call site's own bytes matched exactly and only one such call exists
// (checked against PPSA01340 01.005.000's eboot.bin: one candidate, at rva 0x82d1bb calling
// 0x82d4a0), the site stays unambiguous.
constexpr size_t       StackImmediate = 16, StackImmediateEnd = 20;
uint64_t               cave = 0, site = 0;
std::array<uint8_t, 5> installed_call {}, original_call {};

void KYTY_SYSV_ABI WaitForWork() {
	Common::Thread::SleepMicroWithoutSpinning(50);
}

bool Readable(uint64_t address, uint64_t size) {
	// Executable modules are private runtime allocations, not GPU backing aliases.
	return Libs::Graphics::HostMemoryRangeIsReadable(address, size);
}

// Another build of the game (another region or version) has the same code elsewhere: the call's
// bytes after its displacement, landing on the poll's prologue up to its RIP-relative displacement.
// Only a single such site counts.
bool FindSites(const Program& program, uint64_t* call, uint64_t* poll) {
	const std::span<const uint8_t> tail(CallBytes.data() + 5, CallBytes.size() - 5);
	const std::span<const uint8_t> prologue(PollBytes.data(), PollBytes.size() - 1);
	const std::boyer_moore_horspool_searcher searcher(tail.begin(), tail.end());
	const uint64_t                           base = program.base_vaddr, end = base + program.mapped_size;
	constexpr uint64_t                       Chunk = 0x100000;
	size_t                                   found = 0;
	for (uint64_t at = base; at < end; at += Chunk) {
		// Chunks overlap by a pattern less a byte: a match is in exactly one of them.
		const auto size = std::min(Chunk + tail.size() - 1, end - at);
		if (!Readable(at, size)) continue;
		const auto* bytes = reinterpret_cast<const uint8_t*>(at);
		for (const auto* match = std::search(bytes, bytes + size, searcher); match != bytes + size;
		     match           = std::search(match + 1, bytes + size, searcher)) {
			const auto from = reinterpret_cast<uint64_t>(match) - 5;
			if (from < base || !Readable(from, 5) || *reinterpret_cast<const uint8_t*>(from) != 0xe8) continue;
			int32_t displacement = 0;
			std::memcpy(&displacement, reinterpret_cast<const void*>(from + 1), sizeof(displacement));
			const auto to = from + 5 + static_cast<int64_t>(displacement);
			if (to < base || to > end - PollBytes.size() || !Readable(to, PollBytes.size())) continue;
			const auto* target = reinterpret_cast<const uint8_t*>(to);
			if (!std::equal(prologue.begin(), prologue.begin() + StackImmediate, target) ||
			    !std::equal(prologue.begin() + StackImmediateEnd, prologue.end(), target + StackImmediateEnd))
				continue;
			if (found++ != 0) {
				std::printf("Demon's Souls idle wait: more than one candidate call site; retaining guest code\n");
				return false;
			}
			*call = from;
			*poll = to;
		}
	}
	if (found != 1) {
		std::printf("Demon's Souls idle wait: %zu candidate call site(s) in %s, one expected\n", found,
		            program.file_name.filename().string().c_str());
	}
	return found == 1;
}
} // namespace

void Install(Program* program) {
#if defined(__x86_64__) || defined(_M_X64)
	if (cave != 0 || program == nullptr || !Libs::Graphics::DemonsSouls::IsSupportedGame() ||
	    program->file_name.filename() != "eboot.bin" || program->mapped_size > CaveOffset ||
	    program->base_vaddr > UINT64_MAX - CaveOffset - PageSize)
		return;
	auto call = program->base_vaddr + CallOffset;
	auto poll = program->base_vaddr + PollOffset;
	std::array<uint8_t, CallBytes.size()> call_bytes {};
	std::array<uint8_t, PollBytes.size()> poll_bytes {};
	const bool at_offsets = program->mapped_size >= PollOffset + PollBytes.size() &&
	                        Readable(call, call_bytes.size()) && Readable(poll, poll_bytes.size());
	if (at_offsets) {
		std::memcpy(call_bytes.data(), reinterpret_cast<const void*>(call), call_bytes.size());
		std::memcpy(poll_bytes.data(), reinterpret_cast<const void*>(poll), poll_bytes.size());
	}
	if (!(at_offsets && Matches(call_bytes, poll_bytes)) && !FindSites(*program, &call, &poll)) {
		std::printf("Demon's Souls idle wait: code signature differs; retaining guest code\n");
		return;
	}
	const auto requested = program->base_vaddr + CaveOffset;
	const auto allocated = Libs::LibKernel::Memory::AllocateRuntimeMemory(
	    requested, PageSize, Common::VirtualMemory::Mode::ExecuteReadWrite,
	    "demons_souls_idle_wait", true);
	if (allocated != requested) {
		if (allocated) Libs::LibKernel::Memory::FreeGuestMemory(allocated, PageSize);
		return;
	}
	Xbyak::ClearError();
	Xbyak::CodeGenerator code(PageSize, reinterpret_cast<void*>(allocated));
	EmitThunk(code, reinterpret_cast<const void*>(poll),
	          reinterpret_cast<const void*>(&WaitForWork));
	code.ready();
	if (Xbyak::GetError() ||
	    !Common::VirtualMemory::FlushInstructionCache(allocated, code.getSize()) ||
	    !Libs::LibKernel::Memory::ProtectGuestMemory(
	        allocated, PageSize, Common::VirtualMemory::Mode::ExecuteRead, nullptr)) {
		Libs::LibKernel::Memory::FreeGuestMemory(allocated, PageSize);
		return;
	}
	installed_call[0]       = 0xe8;
	const auto displacement = static_cast<int32_t>(allocated - (call + 5));
	std::memcpy(installed_call.data() + 1, &displacement, sizeof(displacement));
	std::memcpy(original_call.data(), reinterpret_cast<const void*>(call), original_call.size());
	// Installation occurs before module initializers or guest worker threads run.
	// An external patch with different bytes is deliberately left untouched.
	// SetProgramMemoryProtection keeps executable code writable for loader patches.
	std::memcpy(reinterpret_cast<void*>(call), installed_call.data(), installed_call.size());
	if (!Common::VirtualMemory::FlushInstructionCache(call, installed_call.size())) {
		std::memcpy(reinterpret_cast<void*>(call), original_call.data(), original_call.size());
		Common::VirtualMemory::FlushInstructionCache(call, installed_call.size());
		Libs::LibKernel::Memory::FreeGuestMemory(allocated, PageSize);
		return;
	}
	cave = allocated;
	site = call;
	std::printf("Demon's Souls idle wait: installed portable 50 us backoff (call at eboot+0x%llx)\n",
	     static_cast<unsigned long long>(call - program->base_vaddr));
#endif
}

void Clear() {
	if (!cave) return;
	std::array<uint8_t, 5> bytes {};
	std::memcpy(bytes.data(), reinterpret_cast<const void*>(site), bytes.size());
	if (bytes == installed_call) {
		std::memcpy(reinterpret_cast<void*>(site), original_call.data(), bytes.size());
		Common::VirtualMemory::FlushInstructionCache(site, bytes.size());
	}
	Libs::LibKernel::Memory::FreeGuestMemory(cave, PageSize);
	cave = site = 0;
}
} // namespace Loader::DemonsSoulsIdle
