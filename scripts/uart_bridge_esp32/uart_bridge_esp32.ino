// Two roles, selected by MODE. Both run at 9600 8N1, matching the TangCore
// diagnostic build's bit-banged UART on Dock J7 pin 2.
//
//   MODE 0  BRIDGE  - receive on D7, forward to USB serial (115200).
//                     Use the ESP32 as a plain USB serial adapter.
//   MODE 1  SOURCE  - transmit "src N" on D6 once a second.
//                     Use the ESP32 as a known-good signal to validate a
//                     listener before trusting it with the Dock.
//
// Serial1 is bound explicitly to D7/D6 so this behaves the same whether or not
// "USB CDC On Boot" is enabled for your board.

#define MODE 1

static const int RX_PIN = D7;
static const int TX_PIN = D6;

void setup() {
  Serial.begin(115200);
  Serial1.begin(9600, SERIAL_8N1, RX_PIN, TX_PIN);
#if MODE == 0
  Serial.println("bridge: listening on D7 at 9600, echoing to USB");
#endif
}

void loop() {
#if MODE == 0
  while (Serial1.available()) Serial.write(Serial1.read());
#else
  static unsigned n = 0;
  Serial1.print("src ");
  Serial1.println(n++);
  delay(1000);
#endif
}
