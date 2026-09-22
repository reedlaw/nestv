#include <Arduino.h>
#include <ArduinoOTA.h>
#include <ESPmDNS.h>
#include <Preferences.h>
#include <WebServer.h>
#include <WiFi.h>
#include <ctype.h>
#include <string.h>
#include <esp_system.h>

// Grove Base D0/A0: BL616 ISP strap. Grove Base D1/A1: unwired power relay test.
// The Dock must be unpowered before closing or opening the ISP strap.
constexpr uint8_t kBootRelayPin = D0;
constexpr uint8_t kPowerRelayPin = D1;
constexpr size_t kCommandCapacity = 160;
constexpr size_t kWebPasswordLength = 16;
constexpr size_t kOtaPasswordLength = 24;

char command[kCommandCapacity];
size_t commandLength = 0;
bool commandOverflow = false;
bool bootRelayClosed = false;
bool powerRelayClosed = false;
bool wifiReady = false;
bool wifiStation = false;
bool otaReady = false;
char apSsid[24];
String webPassword;
String otaPassword;
String wifiSsid;
String csrfToken;
WebServer webServer(80);

void startOta();

bool setBootRelay(bool close) {
  // Once the power relay is wired, the ISP strap must only change unpowered.
  if (powerRelayClosed && close != bootRelayClosed) return false;
  if (close && otaReady) {
    ArduinoOTA.end();
    otaReady = false;
  }
  digitalWrite(kBootRelayPin, close ? HIGH : LOW);
  bootRelayClosed = close;
  if (!close && wifiStation && !otaReady) startOta();
  return true;
}

void setPowerRelay(bool close) {
  if (close && otaReady) {
    ArduinoOTA.end();
    otaReady = false;
  }
  digitalWrite(kPowerRelayPin, close ? HIGH : LOW);
  powerRelayClosed = close;
  if (!close && wifiStation && !bootRelayClosed && !otaReady) startOta();
}

void printStatus() {
  Serial.print("BOOT=");
  Serial.print(bootRelayClosed ? "CLOSED" : "OPEN");
  Serial.print(" POWER=");
  Serial.println(powerRelayClosed ? "HIGH" : "LOW");
}

void printWifiInfo() {
  if (!wifiReady) {
    Serial.println("ERR Wi-Fi unavailable");
    return;
  }
  Serial.print("WIFI_MODE=");
  Serial.print(wifiStation ? "STA" : "AP");
  Serial.print(" WIFI_SSID=");
  Serial.print(wifiStation ? wifiSsid : String(apSsid));
  Serial.print(" WEB_USER=operator");
  Serial.print(" WEB_PASSWORD=");
  Serial.print(webPassword);
  if (!wifiStation) {
    Serial.print(" AP_PASSWORD=");
    Serial.print(webPassword);
  }
  Serial.print(" WIFI_URL=http://");
  Serial.print(wifiStation ? WiFi.localIP() : WiFi.softAPIP());
  if (otaReady) Serial.print("/ OTA=READY");
  else Serial.print("/ OTA=OFF");
  Serial.println();
}

void printOtaInfo() {
  if (!otaReady) {
    Serial.println("ERR OTA unavailable; connect Wi-Fi and open both relays");
    return;
  }
  Serial.print("OTA_HOST=");
  Serial.print(WiFi.localIP());
  Serial.print(" OTA_PORT=3232 OTA_PASSWORD=");
  Serial.println(otaPassword);
}

void startOta() {
  if (!wifiStation || bootRelayClosed || powerRelayClosed ||
      otaPassword.length() != kOtaPasswordLength) return;
  ArduinoOTA.setHostname("nestv-relay-s3");
  // mDNS serves the web page even when the OTA listener is stopped.
  ArduinoOTA.setMdnsEnabled(false);
  ArduinoOTA.setPassword(otaPassword.c_str());
  ArduinoOTA.onStart([]() {
    // Keep both outputs inactive throughout an update and the following reboot.
    digitalWrite(kBootRelayPin, LOW);
    digitalWrite(kPowerRelayPin, LOW);
    bootRelayClosed = false;
    powerRelayClosed = false;
    Serial.println("OTA update started; both relays open");
  });
  ArduinoOTA.onError([](ota_error_t error) {
    Serial.print("OTA error ");
    Serial.println(static_cast<int>(error));
  });
  ArduinoOTA.begin();
  otaReady = true;
}

bool authenticateWeb() {
  if (webServer.authenticate("operator", webPassword.c_str())) return true;
  webServer.requestAuthentication();
  return false;
}

void sendPage() {
  if (!authenticateWeb()) return;
  String page;
  page.reserve(2700);
  page += F("<!doctype html><html lang=en><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'>");
  page += F("<title>Primer Dock relays</title><style>body{font:18px sans-serif;max-width:30em;margin:2em auto;padding:0 1em;color:#17212b}h1{font-size:1.5em}.relay{display:flex;align-items:center;justify-content:space-between;gap:1em;padding:1em;border:1px solid #b8c4ce;border-radius:.6em;margin:.8em 0;cursor:pointer}.relay small{display:block;color:#52606d;margin-top:.25em}input[type=checkbox]{appearance:none;flex:none;width:3.3em;height:1.9em;border-radius:1em;background:#83919d;cursor:pointer;margin:0;position:relative}input[type=checkbox]:before{content:'';position:absolute;top:.2em;left:.2em;width:1.5em;height:1.5em;border-radius:50%;background:white;transition:transform .15s}input[type=checkbox]:checked{background:#176c46}input[type=checkbox]:checked:before{transform:translateX(1.4em)}input[type=checkbox]:disabled{opacity:.45;cursor:not-allowed}.relay:has(input:disabled){opacity:.6;cursor:not-allowed}input:focus-visible{outline:3px solid #245dba;outline-offset:3px}.note{line-height:1.4}</style>");
  page += F("<h1>Primer Dock relays</h1><p class=note>Turn the power relay off before changing programming mode. Set the mode, then turn power on.</p>");
  page += F("<form method=post><input type=hidden name=csrf value='");
  page += csrfToken;
  page += F("'><label class=relay for=boot><span><strong>Programming mode</strong><small>");
  page += bootRelayClosed ? F("ISP strap closed") : F("Normal boot; ISP strap open");
  page += F("</small></span><input id=boot type=checkbox role=switch autocomplete=off onchange=\"this.form.action=this.checked?'/on':'/off';this.disabled=true;this.form.submit()\"");
  if (bootRelayClosed) page += F(" checked");
  if (powerRelayClosed) page += F(" disabled");
  page += F("></label></form>");
  page += F("<form method=post><input type=hidden name=csrf value='");
  page += csrfToken;
  page += F("'><label class=relay for=power><span><strong>Power relay</strong><small>");
  page += powerRelayClosed ? F("Contacts closed") : F("Contacts open");
  page += F("</small></span><input id=power type=checkbox role=switch autocomplete=off onchange=\"this.form.action=this.checked?'/poweron':'/poweroff';this.disabled=true;this.form.submit()\"");
  if (powerRelayClosed) page += F(" checked");
  page += F("></label></form>");
  if (powerRelayClosed) page += F("<p class=note>Turn the power relay off to change programming mode.</p>");
  page += F("<p class=note><strong>Test setup:</strong> The power relay load is unwired. It does not disconnect Dock power. Disconnect Dock power manually before changing programming mode.</p></html>");
  webServer.sendHeader("Cache-Control", "no-store");
  webServer.send(200, "text/html", page);
}

void changeFromWeb(bool close) {
  if (!authenticateWeb()) return;
  if (webServer.arg("csrf") != csrfToken) {
    webServer.send(403, "text/plain", "Invalid form token");
    return;
  }
  if (!setBootRelay(close)) {
    webServer.send(409, "text/plain", "Open the power relay before changing the boot relay");
    return;
  }
  webServer.sendHeader("Location", "/");
  webServer.send(303, "text/plain", "");
}

void changePowerFromWeb(bool close) {
  if (!authenticateWeb()) return;
  if (webServer.arg("csrf") != csrfToken) {
    webServer.send(403, "text/plain", "Invalid form token");
    return;
  }
  setPowerRelay(close);
  webServer.sendHeader("Location", "/");
  webServer.send(303, "text/plain", "");
}

void startWifi() {
  // Running the Wi-Fi radio supplies entropy for the generated local password.
  WiFi.mode(WIFI_STA);
  Preferences preferences;
  if (!preferences.begin("relay-test", false)) {
    Serial.println("ERR Wi-Fi password storage unavailable");
    return;
  }
  webPassword = preferences.getString("ap_pass", "");
  if (webPassword.length() != kWebPasswordLength) {
    static const char alphabet[] = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
    webPassword = "";
    for (size_t i = 0; i < kWebPasswordLength; ++i) {
      webPassword += alphabet[esp_random() % (sizeof(alphabet) - 1)];
    }
    if (preferences.putString("ap_pass", webPassword) != kWebPasswordLength) {
      Serial.println("ERR Wi-Fi password storage failed");
      preferences.end();
      return;
    }
  }
  otaPassword = preferences.getString("ota_pass", "");
  if (otaPassword.length() != kOtaPasswordLength) {
    static const char alphabet[] = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
    otaPassword = "";
    for (size_t i = 0; i < kOtaPasswordLength; ++i) {
      otaPassword += alphabet[esp_random() % (sizeof(alphabet) - 1)];
    }
    if (preferences.putString("ota_pass", otaPassword) != kOtaPasswordLength) {
      Serial.println("ERR OTA password storage failed");
      otaPassword = "";
    }
  }
  wifiSsid = preferences.getString("ssid", "");
  String wifiPassword = preferences.getString("password", "");
  preferences.end();

  if (wifiSsid.length() > 0 && wifiPassword.length() > 0) {
    WiFi.setAutoReconnect(true);
    WiFi.begin(wifiSsid.c_str(), wifiPassword.c_str());
    const unsigned long deadline = millis() + 20000;
    while (WiFi.status() != WL_CONNECTED && static_cast<long>(millis() - deadline) < 0) {
      delay(100);
    }
    wifiStation = WiFi.status() == WL_CONNECTED;
    if (!wifiStation) Serial.println("Wi-Fi join failed; starting recovery access point");
  }

  if (!wifiStation) {
    WiFi.mode(WIFI_AP);
    snprintf(apSsid, sizeof(apSsid), "NestV-Relay-%06lX",
             static_cast<unsigned long>(ESP.getEfuseMac() & 0xFFFFFF));
    if (!WiFi.softAP(apSsid, webPassword.c_str())) {
      Serial.println("ERR Wi-Fi access point start failed");
      return;
    }
  }

  char nonce[17];
  snprintf(nonce, sizeof(nonce), "%08lX%08lX",
           static_cast<unsigned long>(esp_random()),
           static_cast<unsigned long>(esp_random()));
  csrfToken = nonce;

  webServer.on("/", HTTP_GET, sendPage);
  webServer.on("/on", HTTP_POST, []() { changeFromWeb(true); });
  webServer.on("/off", HTTP_POST, []() { changeFromWeb(false); });
  webServer.on("/poweron", HTTP_POST, []() { changePowerFromWeb(true); });
  webServer.on("/poweroff", HTTP_POST, []() { changePowerFromWeb(false); });
  webServer.onNotFound([]() { webServer.send(404, "text/plain", "Not found"); });
  webServer.begin();
  wifiReady = true;
  if (wifiStation) {
    if (MDNS.begin("nestv-relay-s3")) {
      MDNS.addService("http", "tcp", 80);
    } else {
      Serial.println("ERR mDNS start failed");
    }
  }
  startOta();
  Serial.println(wifiStation ? "Wi-Fi joined existing network" : "Wi-Fi recovery access point ready");
  printWifiInfo();
}

void configureWifi() {
  if (bootRelayClosed || powerRelayClosed) {
    Serial.println("ERR open both relays before configuring Wi-Fi");
    return;
  }
  char *ssid = command + 5;
  char *separator = strchr(ssid, '\t');
  if (separator == nullptr) {
    Serial.println("ERR invalid Wi-Fi configuration");
    return;
  }
  *separator = '\0';
  const char *password = separator + 1;
  const size_t ssidLength = strlen(ssid);
  const size_t passwordLength = strlen(password);
  if (ssidLength == 0 || ssidLength > 32 || passwordLength < 8 || passwordLength > 63) {
    Serial.println("ERR Wi-Fi SSID or password length invalid");
    return;
  }
  Preferences preferences;
  if (!preferences.begin("relay-test", false)) {
    Serial.println("ERR Wi-Fi configuration storage unavailable");
    return;
  }
  const bool saved = preferences.putString("ssid", ssid) == ssidLength &&
                     preferences.putString("password", password) == passwordLength;
  preferences.end();
  if (!saved) {
    Serial.println("ERR Wi-Fi configuration storage failed");
    return;
  }
  Serial.println("OK Wi-Fi configured; restarting");
  Serial.flush();
  delay(100);
  ESP.restart();
}

void runCommand() {
  if (commandOverflow) {
    Serial.println("ERR command too long");
    return;
  }
  command[commandLength] = '\0';
  if (strncmp(command, "WIFI\t", 5) == 0) {
    configureWifi();
    return;
  }
  for (size_t i = 0; i < commandLength; ++i) {
    command[i] = static_cast<char>(toupper(static_cast<unsigned char>(command[i])));
  }

  if (strcmp(command, "ON") == 0) {
    if (setBootRelay(true)) printStatus();
    else Serial.println("ERR open power relay before changing boot relay");
  } else if (strcmp(command, "OFF") == 0) {
    if (setBootRelay(false)) printStatus();
    else Serial.println("ERR open power relay before changing boot relay");
  } else if (strcmp(command, "POWERON") == 0) {
    setPowerRelay(true);
    printStatus();
  } else if (strcmp(command, "POWEROFF") == 0) {
    setPowerRelay(false);
    printStatus();
  } else if (strcmp(command, "STATUS") == 0) {
    printStatus();
  } else if (strcmp(command, "INFO") == 0) {
    printWifiInfo();
  } else if (strcmp(command, "OTAINFO") == 0) {
    printOtaInfo();
  } else if (strcmp(command, "HELP") == 0) {
    Serial.println("Commands: ON OFF POWERON POWEROFF STATUS INFO OTAINFO HELP");
  } else if (commandLength != 0) {
    Serial.println("ERR unknown command; send HELP");
  }
}

void setup() {
  // Set output latches low before switching either GPIO to output mode.
  digitalWrite(kBootRelayPin, LOW);
  digitalWrite(kPowerRelayPin, LOW);
  pinMode(kBootRelayPin, OUTPUT);
  pinMode(kPowerRelayPin, OUTPUT);

  Serial.begin(115200);
  Serial.println("Primer Dock relay test ready");
  Serial.println("Keep Dock power off when changing the boot strap.");
  Serial.println("Commands: ON OFF POWERON POWEROFF STATUS INFO OTAINFO HELP");
  printStatus();
  startWifi();
}

void loop() {
  if (wifiReady) webServer.handleClient();
  if (otaReady) ArduinoOTA.handle();
  while (Serial.available() > 0) {
    const char ch = static_cast<char>(Serial.read());
    if (ch == '\r' || ch == '\n') {
      if (commandLength != 0 || commandOverflow) runCommand();
      commandLength = 0;
      commandOverflow = false;
    } else if (commandLength < kCommandCapacity - 1) {
      command[commandLength++] = ch;
    } else {
      commandOverflow = true;
    }
  }
}
