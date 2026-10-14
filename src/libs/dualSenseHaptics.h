#ifndef KYTY_LIBS_DUALSENSE_HAPTICS_H_
#define KYTY_LIBS_DUALSENSE_HAPTICS_H_

#include <cstdint>
#include <string>

// The DualSense's own output endpoint and its haptic actuators.
//
// Windows lists the pad's USB audio interface as an output device of its own, with FOUR channels:
// the first pair plays on the pad's speaker, the second pair drives its haptic actuators. The
// emulator never opened it, so the guest's vibration port (AUDIO_OUT_PORT_TYPE_VIBRATION) went
// nowhere and the pad never vibrated.
//
// This is the Windows implementation (WASAPI, through the endpoint the pad's USB ID names). The
// endpoint cannot be picked by name: Windows calls the pad's endpoint and the machine's speakers
// both "Speakers"/"扬声器" (see the notes). Linux keeps using SDL's device list.
//
// Environment:
//   KYTY_DUALSENSE_HAPTICS=0|1     off when 0 (default: on)
//   KYTY_DUALSENSE_HAPTICS_CHANNELS=23|01|all   which of the endpoint's channels take the signal
//                                  (default: 23, the actuator pair; 01 is the speaker pair)
//   KYTY_DUALSENSE_HAPTICS_GAIN=<float>         applied to the samples (default: 1.0)
//   KYTY_DUALSENSE_HAPTICS_LOG=1   prints what it finds and what it writes (default: off)
namespace Libs::Controller::DualSenseHaptics {

// True when the host has a usable DualSense output endpoint (found once, then cached).
bool Available();

// The endpoint's own sample rate and channel count, 0 when there is no endpoint.
uint32_t SampleRate();
uint32_t EndpointChannels();

// Opens the endpoint for one of its routes: the pad speaker port plays on the endpoint's FIRST
// channel pair, the vibration port on its second (the actuators). Several routes share the one
// stream, and it stays open while any route is. False when there is no endpoint, when it cannot
// take the format, or when that route is already open: the caller then leaves the port as it was.
bool Open(bool speaker);
// Closes the route, and tears the stream down once no route is left.
void Close(bool speaker);

// Writes `frames` frames of `source_channels`-channel audio (signed 16-bit, or float when
// `is_float`) at `source_rate` into the route's channels of the endpoint, resampling when the rates
// differ and applying the route's gain. `gains`, when the guest set them, scales each source channel
// (its AudioOut2 gain attribute is where a pad's speaker and vibration levels live). Never waits:
// when the endpoint's queue is behind, the audio is dropped (haptics are best effort, and the caller
// is the guest's audio thread).
bool Write(const void* data, uint32_t frames, uint32_t source_rate, uint32_t source_channels,
           bool is_float, bool speaker, const float* gains);

} // namespace Libs::Controller::DualSenseHaptics

#endif /* KYTY_LIBS_DUALSENSE_HAPTICS_H_ */
