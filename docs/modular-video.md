# Modular video architecture

Analog video is an optional expansion function. The base carrier always
supports HDMI and exposes a versioned digital video-module interface. Installing
the analog module adds S-Video and composite; removing it requires no bitstream
change.

The boundary is deliberately narrower than the internal core-video interface.
The base performs palette lookup, overlay composition, Y/C encoding, sync
insertion, and quantization. The module receives continuously updated Y and C
codes and implements only conversion and analog conditioning.

This arrangement avoids making module support dependent on FPGA partial
reconfiguration. Any compatible module may consume the documented sample
stream. More complex future modules may use the reserved sample clock, sync,
data-enable, and identification signals, but must not require NES-specific
internal state.

The authoritative revision-0 definition is in
`hardware/video-module-rev0/`. The temporary Primer harness is not part of the
module standard.
