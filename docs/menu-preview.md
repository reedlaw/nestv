# Firmware menu preview

`make preview-menu` renders the NESTang menu overlay without FPGA or BL616
hardware. The model consumes the same framed UART commands implemented by
`iosys_bl616.v`, maintains the same 32-by-28 character buffer, and uses the
pinned NESTang 8-by-8 font and 72-by-14 logo.

The deterministic sample is written to `build/menu-preview/menu.png`. It is a
protocol and renderer preview, not yet the TangCore firmware itself. When the
firmware is added for M5, its host-side menu state machine or captured UART
stream can replace the scripted commands without replacing this renderer.

`make menu-test` verifies byte-at-a-time UART framing, cursor movement,
right-edge clipping, overlay enable, font colors, and logo rendering.
