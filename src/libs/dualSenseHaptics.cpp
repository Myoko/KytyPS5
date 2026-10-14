#include "libs/dualSenseHaptics.h"

#include "common/logging/log.h"

#if defined(_WIN32)

#include <atomic>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <vector>

#define WIN32_LEAN_AND_MEAN
#include <audioclient.h>
#include <mmdeviceapi.h>
#include <windows.h>

namespace Libs::Controller::DualSenseHaptics {

namespace {

// PKEY_DeviceInterface_FriendlyName: the device's own name, "USB\VID_054C&PID_0CE6&MI_00" for the
// pad's audio interface. The endpoint's own name (PKEY_Device_FriendlyName) is just "Speakers".
constexpr PROPERTYKEY PKEY_INTERFACE_FRIENDLY_NAME = {
    {0xb3f8fa53, 0x0004, 0x438e, {0x90, 0x03, 0x51, 0xa4, 0x6e, 0x13, 0x9b, 0xfc}}, 2};

// The pad's USB interface path, as both the audio driver and the registry report it.
constexpr const char* PAD_DEVICE_PATH = "VID_054C&PID_0CE6";

IMMDevice*       g_device   = nullptr;
IAudioClient*    g_client   = nullptr;
IAudioRenderClient* g_render = nullptr;
WAVEFORMATEX*    g_mix      = nullptr;
uint32_t         g_buffer_frames = 0;
bool             g_started  = false;

std::mutex g_mutex;
int        g_found    = -1; // -1 unknown, 0 no endpoint, 1 yes
bool       g_enabled  = true;
bool       g_log      = false;
float      g_gain     = 1.0f;
bool       g_all_channels = false;
uint32_t   g_first_channel = 2;
uint32_t   g_channel_count = 2;

std::string Narrow(const wchar_t* text) {
	std::string out;
	if (text == nullptr) {
		return out;
	}
	for (; *text != L'\0'; text++) {
		out.push_back(*text < 128 ? static_cast<char>(*text) : '?');
	}
	return out;
}

void ReadSettings() {	static bool read = false;
	if (read) {
		return;
	}
	read = true;

	if (const char* value = std::getenv("KYTY_DUALSENSE_HAPTICS"); value != nullptr) {
		g_enabled = std::string(value) != "0";
	}
	if (const char* value = std::getenv("KYTY_DUALSENSE_HAPTICS_CHANNELS"); value != nullptr) {
		const std::string channels(value);
		if (channels == "all") {
			g_all_channels = true;
		} else if (channels == "01") {
			g_first_channel = 0;
			g_channel_count = 2;
		} else if (channels == "23") {
			g_first_channel = 2;
			g_channel_count = 2;
		} else if (!channels.empty()) {
			g_first_channel = static_cast<uint32_t>(channels[0] - '0');
			g_channel_count = channels.size() > 1 ? static_cast<uint32_t>(channels[1] - '0') : 1;
			g_channel_count = g_channel_count > g_first_channel
			                      ? g_channel_count - g_first_channel + 1
			                      : 1;
		}
	}
	if (const char* value = std::getenv("KYTY_DUALSENSE_HAPTICS_GAIN"); value != nullptr) {
		const auto gain = std::strtof(value, nullptr);
		if (gain > 0.0f && gain <= 4.0f) {
			g_gain = gain;
		}
	}
	if (const char* value = std::getenv("KYTY_DUALSENSE_HAPTICS_LOG"); value != nullptr) {
		g_log = std::string(value) != "0";
	}
}

// COM is initialized per thread and never uninitialized: the stream outlives any single call, and
// releasing its last reference after CoUninitialize is not allowed. S_FALSE (already initialized)
// and RPC_E_CHANGED_MODE (another apartment) are both fine here.
void EnsureCom() {
	static thread_local bool done = false;
	if (!done) {
		done = true;
		(void)CoInitializeEx(nullptr, COINIT_MULTITHREADED);
	}
}

// The pad's output endpoint: exactly one active render device whose interface path is the pad's.
IMMDevice* FindEndpoint() {
	IMMDeviceEnumerator* enumerator = nullptr;
	auto hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_INPROC_SERVER,
	                           __uuidof(IMMDeviceEnumerator), reinterpret_cast<void**>(&enumerator));
	if (FAILED(hr)) {
		if (g_log) {
			LOGF("DualSenseHaptics: CoCreateInstance failed: 0x%08x\n", static_cast<uint32_t>(hr));
		}
		return nullptr;
	}

	IMMDeviceCollection* collection = nullptr;
	hr = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &collection);
	if (FAILED(hr) || collection == nullptr) {
		enumerator->Release();
		return nullptr;
	}

	UINT  count   = 0;
	collection->GetCount(&count);

	IMMDevice* matched = nullptr;
	for (UINT i = 0; i < count; i++) {
		IMMDevice* device = nullptr;
		if (FAILED(collection->Item(i, &device)) || device == nullptr) {
			continue;
		}

		IPropertyStore* store = nullptr;
		bool            is_pad = false;
		if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, &store)) && store != nullptr) {
			PROPVARIANT value;
			PropVariantInit(&value);
			if (SUCCEEDED(store->GetValue(PKEY_INTERFACE_FRIENDLY_NAME, &value)) &&
			    value.vt == VT_LPWSTR && value.pwszVal != nullptr) {
				const auto path = Narrow(value.pwszVal);
				is_pad          = path.find(PAD_DEVICE_PATH) != std::string::npos;
				if (g_log) {
					LOGF("DualSenseHaptics: endpoint %u: %s%s\n", i, path.c_str(),
					     is_pad ? "  <- the pad" : "");
				}
			}
			PropVariantClear(&value);
			store->Release();
		}

		if (is_pad) {
			if (matched != nullptr) {
				// Two pads: which one is playing is not knowable here, and driving the wrong one
				// would be worse than not driving any (the mainline refuses ambiguous endpoints too).
				matched->Release();
				matched = nullptr;
				if (g_log) {
					LOGF("DualSenseHaptics: more than one pad endpoint, none is used\n");
				}
				break;
			}
			matched = device;
			continue;
		}
		device->Release();
	}

	collection->Release();
	enumerator->Release();
	return matched;
}

} // namespace

bool Available() {
	ReadSettings();
	if (!g_enabled) {
		return false;
	}
	if (g_found >= 0) {
		return g_found == 1;
	}

	// COM is initialized here rather than assumed: the emulator's threads may not have it.
	EnsureCom();

	IMMDevice* device = FindEndpoint();
	g_found           = device != nullptr ? 1 : 0;
	if (device != nullptr) {
		device->Release();
	}
	if (g_log || g_found == 0) {
		LOGF("DualSenseHaptics: %s\n", g_found == 1 ? "the pad's audio endpoint is available"
		                                            : "no DualSense audio endpoint (no haptics)");
	}
	return g_found == 1;
}

uint32_t SampleRate() {
	std::lock_guard lock(g_mutex);
	return g_mix != nullptr ? g_mix->nSamplesPerSec : 0;
}

uint32_t EndpointChannels() {
	std::lock_guard lock(g_mutex);
	return g_mix != nullptr ? g_mix->nChannels : 0;
}

bool Open() {
	ReadSettings();
	if (!g_enabled) {
		return false;
	}

	std::lock_guard lock(g_mutex);
	if (g_client != nullptr) {
		return true; // already open: one stream serves every vibration port
	}

	EnsureCom();

	bool ok = false;
	do {
		IMMDevice* device = FindEndpoint();
		if (device == nullptr) {
			break;
		}
		g_found = 1;

		if (FAILED(device->Activate(__uuidof(IAudioClient), CLSCTX_INPROC_SERVER, nullptr,
		                            reinterpret_cast<void**>(&g_client))) ||
		    g_client == nullptr) {
			device->Release();
			break;
		}
		device->Release();

		if (FAILED(g_client->GetMixFormat(&g_mix)) || g_mix == nullptr) {
			break;
		}
		if (g_mix->wFormatTag != WAVE_FORMAT_IEEE_FLOAT && g_mix->wFormatTag != WAVE_FORMAT_EXTENSIBLE) {
			break;
		}
		if (g_mix->wBitsPerSample != 32) {
			break;
		}

		// 100 ms of buffer; the pad's own path starts about a second late, which the stream's
		// queue covers as long as the game keeps writing.
		if (FAILED(g_client->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 1000000LL, 0, g_mix, nullptr))) {
			break;
		}
		if (FAILED(g_client->GetBufferSize(&g_buffer_frames))) {
			break;
		}
		if (FAILED(g_client->GetService(__uuidof(IAudioRenderClient),
		                                reinterpret_cast<void**>(&g_render))) ||
		    g_render == nullptr) {
			break;
		}
		if (FAILED(g_client->Start())) {
			break;
		}
		g_started = true;
		ok        = true;

		if (g_log) {
			LOGF("DualSenseHaptics: opened: %u Hz, %u ch, buffer %u frames, gain %.2f, channels %s\n",
			     g_mix->nSamplesPerSec, g_mix->nChannels, g_buffer_frames, static_cast<double>(g_gain),
			     g_all_channels ? "all" : "pair");
		}
	} while (false);

	if (!ok) {
		Close();
	}
	return ok;
}

void Close() {
	std::lock_guard lock(g_mutex);
	if (g_client != nullptr) {
		if (g_started) {
			g_client->Stop();
		}
		g_client->Release();
		g_client = nullptr;
	}
	if (g_render != nullptr) {
		g_render->Release();
		g_render = nullptr;
	}
	if (g_mix != nullptr) {
		CoTaskMemFree(g_mix);
		g_mix = nullptr;
	}
	g_buffer_frames = 0;
	g_started       = false;
}

bool Write(const void* data, uint32_t frames, uint32_t source_rate, uint32_t source_channels,
           bool is_float) {
	std::lock_guard lock(g_mutex);
	if (!g_started || data == nullptr || frames == 0 || source_channels == 0 || g_mix == nullptr) {
		return false;
	}

	const auto target_rate     = g_mix->nSamplesPerSec;
	const auto target_channels = g_mix->nChannels;
	if (target_rate == 0 || target_channels < 2) {
		return false;
	}

	// Resample (linear: enough for haptics) and put the signal in the chosen channels.
	const auto out_frames = source_rate == target_rate
	                            ? frames
	                            : static_cast<uint32_t>(static_cast<uint64_t>(frames) * target_rate /
	                                                    source_rate);
	if (out_frames == 0) {
		return false;
	}

	UINT32 padding = 0;
	if (FAILED(g_client->GetCurrentPadding(&padding))) {
		return false;
	}
	const auto free = g_buffer_frames > padding ? g_buffer_frames - padding : 0;
	if (free < out_frames) {
		return false; // behind: drop rather than delay the guest's audio thread
	}

	BYTE* buffer = nullptr;
	if (FAILED(g_render->GetBuffer(out_frames, &buffer)) || buffer == nullptr) {
		return false;
	}

	auto* out = reinterpret_cast<float*>(buffer);
	std::memset(out, 0, static_cast<size_t>(out_frames) * target_channels * sizeof(float));

	for (uint32_t i = 0; i < out_frames; i++) {
		const auto source_index =
		    source_rate == target_rate
		        ? i
		        : static_cast<uint32_t>(static_cast<uint64_t>(i) * source_rate / target_rate);
		if (source_index >= frames) {
			break;
		}

		// Mono goes to one channel, stereo to the pair (the actuator pair by default).
		for (uint32_t c = 0; c < source_channels && c < g_channel_count; c++) {
			float value = 0.0f;
			if (is_float) {
				value = reinterpret_cast<const float*>(data)[static_cast<size_t>(source_index) *
				                                             source_channels + c];
			} else {
				value = static_cast<float>(reinterpret_cast<const int16_t*>(data)[
				            static_cast<size_t>(source_index) * source_channels + c]) /
				        32768.0f;
			}
			value *= g_gain;
			if (value > 1.0f) {
				value = 1.0f;
			} else if (value < -1.0f) {
				value = -1.0f;
			}

			if (g_all_channels) {
				for (uint32_t target = 0; target < target_channels; target++) {
					out[static_cast<size_t>(i) * target_channels + target] = value;
				}
				continue;
			}

			const auto channel = g_first_channel + c;
			if (channel < target_channels) {
				out[static_cast<size_t>(i) * target_channels + channel] = value;
			}
		}
	}

	g_render->ReleaseBuffer(out_frames, 0);
	return true;
}

} // namespace Libs::Controller::DualSenseHaptics

#else

namespace Libs::Controller::DualSenseHaptics {

bool     Available() { return false; }
uint32_t SampleRate() { return 0; }
uint32_t EndpointChannels() { return 0; }
bool     Open() { return false; }
void     Close() {}
bool     Write(const void*, uint32_t, uint32_t, uint32_t, bool) { return false; }

} // namespace Libs::Controller::DualSenseHaptics

#endif
