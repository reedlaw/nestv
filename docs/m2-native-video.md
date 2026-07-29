# M2 native-video integration

NESTang is pinned as a submodule at `rtl/core/nestang`. Its native video
contract is the `color`, `cycle`, and `scanline` output of `NES` in
`src/nestang_top.sv`. The PPU advances once per four 21.477272 MHz NES master
clocks, while the Y/C encoder runs at twice the master clock. A native pixel is
therefore held for eight encoder samples.

`nestang_video_adapter` is the output split:

1. `nes_palette` performs NESTang's existing 6-bit palette lookup.
2. The native-coordinate overlay is composited in RGB.
3. That same RGB value fans out to the HDMI capture input and directly to
   `yc_out`; the analog path has no connection to `nes2hdmi`'s framebuffer.

The adapter defines visible video as dots 0–255 on scanlines 0–239. Horizontal
sync is active high on dots 280–304 (25 dots, approximately 4.66 us), vertical
sync is active high on scanlines 241–243, and composite sync is their OR.
These polarities match `yc_out`.

The final board top should connect `hdmi_rgb` to the HDMI framebuffer write
side, and connect the returned `overlay_x`/`overlay_y` to the existing menu
generator. The current upstream `nes2hdmi` module remains untouched, so its
known-good TMDS implementation is retained for that integration step.

Run `make validate-m2`. The test checks all 64 palette indices, shared overlay
composition, native blanking/sync boundaries, encoder activity, and equality
of the HDMI-side and Y/C-side RGB at the split.
