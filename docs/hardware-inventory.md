# Hardware purchases and test-harness inventory

Updated 2026-09-06; initially recorded 2026-09-05 from the user's order details and cart. The second order was confirmed placed on 2026-09-06; the first order date,
shipping, and tax were not supplied. Prices below are USD merchandise prices.
Do not treat cart items or discussed accessories as purchased.

## First Seeed order — purchased

The user explicitly confirms the Grove Base is already on hand. The C3 and
Debug Mate have also been used or discussed as existing hardware; delivery
status of the remaining individual modules was not separately recorded.

| Item | SKU | Quantity | Subtotal | Relevance to NesTV harness |
| --- | --- | ---: | ---: | --- |
| XIAO ESP32-C3 (Pre-Soldered) | 102010633 | 1 | $5.90 | Available for Wi-Fi UART logging and relay control |
| Grove Piezo / Active Buzzer | 107020000 | 1 | $1.90 | Optional audible status |
| Grove Base for XIAO, with battery management | 103020312 | 1 | $3.90 | Already owned; provides Grove sockets; do not buy a duplicate |
| Grove Adjustable PIR Motion Sensor | 101020617 | 1 | $7.00 | No current harness role |
| Grove Time of Flight Distance Sensor (VL53L0X) | 101020532 | 1 | $7.90 | No current harness role |
| XIAO Debug Mate | 109990585 | 1 | $22.90 | Existing debugging accessory |
| **Merchandise total** | | **6** | **$49.50** | |

## Second Seeed order — placed, confirmed 2026-09-06

User confirmed ordering the items below from the United States warehouse.
The S3 Plus and relays are now in use in the test harness; delivery of the
conversion cable packs was not separately confirmed. Prices are from the
supplied cart.

| Item | SKU | Quantity | Unit price | Subtotal |
| --- | --- | ---: | ---: | ---: |
| Grove Relay | 103020005 | 2 | $2.99 | $5.98 |
| XIAO ESP32-S3 Plus | 102010671 | 1 | $7.99 | $7.99 |
| Grove to 4-pin male jumper conversion cables, five-pack | 110990210 | 1 pack | $2.00 | $2.00 |
| Grove to 4-pin female jumper conversion cables, five-pack | 110990028 | 1 pack | $3.99 | $3.99 |
| **Merchandise total** | | | | **$19.96** |

Planned uses:

- S3 Plus: Wi-Fi control and UART logging, with a partition of its 16 MB flash
  backing an emulated USB drive. This requires new firmware and TangCore
  hardware validation; it is not an implemented feature.
- Two relays: independent Dock power switching and boot-pin closure. Verify
  the delivered relay revision and repeated low-current boot-contact operation.
- Female conversion cable: Grove Base UART socket to Dock J7 through a
  soldered male header. Connect XIAO RX (D7) to J7 pin 2 and ground to J7 pin 6;
  leave TX and power disconnected. Current source firmware still needs J7
  diagnostic output restored.
- Male conversion cables: optional prototyping spares, not required for the
  proposed Base-to-relay connections.
- Each Grove relay is documented as including a Grove cable; its exact length
  was not confirmed. Extra Grove-to-Grove cables are optional.

## Discussed accessories and availability

The user believes the remaining wiring, headers, and general accessories below
are already on hand; individual quantities have not been checked. Jumper caps
are the possible exception and may be salvaged from an old motherboard. This
does not resolve the still-undesigned USB routing and power-isolation arrangement.

- Dock J7: 2×4 male header, 2.54 mm pitch, plus jumper caps for manually
  connecting pin 5 (TDO) to pin 7 (3V3) during boot entry.
- XIAO: two 1×7 male headers if not supplied with the S3 Plus.
- Female-to-female jumper leads for boot contacts (strip one end for relay
  screw terminals), power wiring, heat-shrink, and strain relief.
- USB data cable for S3-to-hub connection; independent harness power.
- M281 optocoupler relay was considered, then replaced in the cart by a second
  ordinary Grove relay because of warehouse availability.
- OLED expansion base and separate Grove OLED were considered; neither is
  in the latest cart. The existing Grove Base is the current plan.
- Four-channel I²C relay was considered but not selected: its published
  schematic pulls Grove SDA/SCL to its 5 V supply, requiring voltage adaptation
  for the XIAO.

The full one-step flashing arrangement remains undesigned: USB routing to
the BL616 programmer and complete Dock power isolation (including potential
hub/laptop backfeed) still need concrete hardware choices. The second order
does not by itself complete that arrangement.

## References

- [Grove Base documentation](https://wiki.seeedstudio.com/Grove-Shield-for-Seeeduino-XIAO-embedded-battery-management-chip/)
- [Grove Relay documentation and included cable](https://wiki.seeedstudio.com/Grove-Relay/)
- [XIAO S3 model comparison](https://wiki.seeedstudio.com/xiao_esp32s3_getting_started/)
- [Female conversion cable](https://www.seeedstudio.com/Grove-4-pin-Female-Jumper-to-Grove-4-pin-Conversion-Cable-5-PCs-per-PAck.html)
- [Bring-up status](bringup.md)
