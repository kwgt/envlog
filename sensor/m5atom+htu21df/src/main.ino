/*
 * Sensor device control for environment data logger
 *
 *  Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmai.com>
 */
#undef USE_BLE
#define USE_WIFI

#define ENABLE_LED

/* GPIO assign */
#define SDA_PORT              25
#define SCL_PORT              21

#ifdef USE_BLE
#define MANUFACTURER_ID       55229
#define DEVICE_NAME           "ENVLOG sensor (M5Atom)"
#endif /* defined(USE_BLE) */

#ifdef USE_WIFI
#define AP_SSID               "XXXXXXXXXXXXXXXX"
#define AP_PASSWD             "XXXXXXXXXXXXXXXX"
#define SERVER_ADDR           "192.168.0.30"
#define SERVER_PORT           1234
#endif /* defined(USE_WIFI) */

#include <M5Atom.h>
#include <Wire.h>

#include <Adafruit_HTU21DF.h>
#include <esp_sleep.h>
#include <esp_system.h>

#ifdef USE_BLE
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <esp_bt_main.h>
#endif /* defined(USE_BLE) */

#ifdef USE_WIFI
#include <WiFi.h>
#include <WiFiUdp.h>
#include <esp_wifi.h>
#endif /* defined(USE_WIFI) */

#define DATA_FORMAT_VERSION   3
#define T_PERIOD              1         // Transmission period
#define S_PERIOD              119       // Sleeping period
                             
#define LO_BYTE(x)            (uint8_t)(((x) >> 0) & 0xff)
#define HI_BYTE(x)            (uint8_t)(((x) >> 8) & 0xff)

#if defined(USE_BLE) && defined(USE_WIFI)
#error "specify either USE_BLE or USE_WIFI."
#elif !defined(USE_BLE) && !defined(USE_WIFI)
#error "specify either USE_BLE or USE_WIFI."
#endif /* defined(USE_BLE) && defined(USE_WIFI) */

Adafruit_HTU21DF htu;
RTC_DATA_ATTR int boot_count = 0;
RTC_DATA_ATTR uint8_t seq;

#ifdef USE_BLE
BLEServer* server;
BLEAdvertising* advertising;
#endif /* defined(USE_BLE) */

#ifdef USE_WIFI
WiFiClient client;
WiFiUDP udp;
#endif /* defined(USE_WIFI) */

int16_t temp;
uint16_t hum;
uint16_t pres;
uint16_t vbat;
uint16_t vbus;
 
#ifdef ENABLE_LED
void
set_led(CRGB c)
{
  M5.dis.drawpix(0, c);
  delay(50);
  M5.update();
}
#endif /* defined(ENABLE_LED) */

#ifdef USE_BLE
void
setup_comm()
{
  BLEDevice::init(DEVICE_NAME);

  server      = BLEDevice::createServer();
  advertising = server->getAdvertising(); 
}

void
send_data()
{
  BLEAdvertisementData adat = BLEAdvertisementData();
  std::string data;
  uint8_t mac[6];

  adat.setFlags(0x06);

  esp_efuse_mac_get_default(mac);

  data = "";
  data += (uint8_t)21;
  data += (uint8_t)0xff; // AD Type 0xFF: Manufacturer specific data
  data += LO_BYTE(MANUFACTURER_ID);
  data += HI_BYTE(MANUFACTURER_ID);
  data += (uint8_t)DATA_FORMAT_VERSION;
  data += (uint8_t)seq;
  data += mac[0];
  data += mac[1];
  data += mac[2];
  data += mac[3];
  data += mac[4];
  data += mac[5];
  data += LO_BYTE(temp);
  data += HI_BYTE(temp);
  data += LO_BYTE(hum);
  data += HI_BYTE(hum);
  data += LO_BYTE(pres);
  data += HI_BYTE(pres);
  data += LO_BYTE(vbat);
  data += HI_BYTE(vbat);
  data += LO_BYTE(vbus);
  data += HI_BYTE(vbus);

  adat.addData(data);
  advertising->setAdvertisementData(adat);

  advertising->start();
  delay(T_PERIOD * 1000);
  advertising->stop();
}

void
stop_comm()
{
  esp_bluedroid_disable();
  esp_bt_controller_disable();
}
#endif /* defined(USE_BLE) */

#ifdef USE_WIFI
void
setup_comm()
{
  WiFi.begin(AP_SSID, AP_PASSWD);

  while (WiFi.status() != WL_CONNECTED) {
#ifdef ENABLE_LED
    set_led(0x00f000);
#endif /* defined(ENABLE_LED) */
    delay(500);
#ifdef ENABLE_LED
    set_led(0x000000);
#endif /* defined(ENABLE_LED) */
  }

#ifdef ENABLE_LED
  set_led(0x0000f0);
#endif /* defined(ENABLE_LED) */
}

void
send_data()
{
  uint8_t buf[18];

  buf[0]  = (uint8_t)DATA_FORMAT_VERSION;
  buf[1]  = (uint8_t)seq;

  esp_efuse_mac_get_default(buf + 2);

  buf[8]  = LO_BYTE(temp);
  buf[9]  = HI_BYTE(temp);
  buf[10] = LO_BYTE(hum);
  buf[11] = HI_BYTE(hum);
  buf[12] = LO_BYTE(pres);
  buf[13] = HI_BYTE(pres);
  buf[14] = LO_BYTE(vbat);
  buf[15] = HI_BYTE(vbat);
  buf[16] = LO_BYTE(vbus);
  buf[17] = HI_BYTE(vbus);

  udp.beginPacket(SERVER_ADDR, SERVER_PORT);
  udp.write(buf, sizeof(buf));
  udp.endPacket();
}

void
stop_comm()
{
  esp_wifi_stop();
}
#endif /* defined(USE_WIFI) */

void
setup()
{
  bool led;

#ifdef ENABLE_LED
  led    = true;
#endif /* defined(ENABLE_LED) */

  M5.begin(false, true, led);

  esp_sleep_enable_timer_wakeup(S_PERIOD * 1000000);
  setCpuFrequencyMhz(80);

  Wire.begin(SDA_PORT, SCL_PORT);

  while (!htu.begin()) {
#ifdef ENABLE_LED
    set_led(0x00f000);
#endif /* defined(ENABLE_LED) */

    delay(10);

#ifdef ENABLE_LED
    set_led(0xf0f0f0);
#endif /* defined(ENABLE_LED) */
  }

#ifdef ENABLE_LED
  set_led(0x000000);
#endif /* defined(ENABLE_LED) */

  setup_comm();

  boot_count++;
}

void
read_sensor()
{
  dht12.read();
  temp = (int16_t)(htu.readTemperature() * 100);
  hum  = (uint16_t)(htu.readHumidity() * 100);
  pres = (uint16_t)0xffff;
  vbat = (uint16_t)0;
  vbus = (uint16_t)500;
}

void
loop()
{
  read_sensor();

#ifdef ENABLE_LED
  set_led(0xf00000);
#endif /* defined(ENABLE_LED) */

  send_data();

#ifdef ENABLE_LED
  set_led(0x000000);
#endif /* defined(ENABLE_LED) */

  seq++;

  stop_comm();

  esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
  esp_deep_sleep(S_PERIOD * 1000000);
}
