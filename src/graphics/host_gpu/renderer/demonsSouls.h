#pragma once

#include <cstdint>
#include <string_view>

namespace Libs::Graphics {
class BufferCache;
struct ShaderComputeInputInfo;
namespace DemonsSouls {
// Compatibility policy.
//
// The guest-code patches - the idle wait, the coherent copy and the GPU buffer pages - and the
// linear-copy stand-in each verify what they are about to replace before touching it. The first
// three read the guest bytes and compare them with the signatures recorded in
// loader/demonsSoulsIdle.h and in their own files; TryLinearCopy matches the shader hash and the
// descriptor fields. A build that differs fails that check, logs it and keeps the guest code, so
// for those the title alone is the right gate and another version of the same game can still
// benefit.
constexpr bool IsSameTitle(std::string_view title) {
	return title == "PPSA01341" || title == "PPSA01340";
}
// The barrier-omission path in renderCompute.cpp has no such guard: it decides at run time, from
// buffer state, whether a compute write-hazard barrier may be skipped. That is only known to hold
// for the build whose dispatch dependencies were analysed, so it keeps the exact title and
// version.
constexpr bool IsSupportedVersion(std::string_view title, std::string_view version) {
	return title == "PPSA01341" && version == "01.007.000";
}
// Gates the self-verifying patches above: same title, any version.
bool IsSupportedGame();
// Gates the barrier-omission path only: the exact title and version that were analysed.
bool IsAnalysedBuild();
bool TryLinearCopy(const ShaderComputeInputInfo& input, BufferCache& cache, uint32_t x, uint32_t y,
                   uint32_t z, uint32_t mode);
} // namespace DemonsSouls
} // namespace Libs::Graphics
