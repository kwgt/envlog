/*
 * Sensor device control for environment data logger
 *
 *  Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmai.com>
 */
#undef USE_BLE
#define USE_WIFI

#define ENABLE_LED

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

#include <DHT12.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BMP280.h>
#include <esp_sleep.h>
#include <esp_system.h>

#ifdef USE_BLE
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#endif /* defined(USE_BLE) */

#ifdef USE_WIFI
#include <WiFi.h>
#include <WiFiUdp.h>
#endif /* defined(USE_WIFI) */

#define DATA_FORMAT_VERSION   2
#define T_PERIOD              1         // Transmission period
#define S_PERIOD              9       // Sleeping period
                             
#define M5STICK_PIN_LED       10

#define LO_BYTE(x)            (uint8_t)(((x) >> 0) & 0xff)
#define HI_BYTE(x)            (uint8_t)(((x) >> 8) & 0xff)

#if defined(USE_BLE) && defined(USE_WIFI)
#error "specify either USE_BLE or USE_WIFI."
#elif !defined(USE_BLE) && !defined(USE_WIFI)
#error "specify either USE_BLE or USE_WIFI."
#endif /* defined(USE_BLE) && defined(USE_WIFI) */

DHT12 dht12;
Adafruit_BMP280 bme;
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
  setup_ble();
  BLEDevice::init(DEVICE_NAME);

  server      = BLEDevice::createServer();
  advertising = server->getAdvertising(); 
}

void
send_data()
{
  BLEAdvertisementData adat = BLEAdvertisementData();
  std::string data;

  adat.setFlags(0x06);

  data = "";
  data += (uint8_t)0x0f;
  data += (uint8_t)0xff; // AD Type 0xFF: Manufacturer specific data
  data += LO_BYTE(MANUFACTURER_ID);
  data += HI_BYTE(MANUFACTURER_ID);
  data += (uint8_t)DATA_FORMAT_VERSION;
  data += (uint8_t)seq;
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

  
  esp_efuse_mac_get_default(buf + 0);

  buf[6]  = (uint8_t)DATA_FORMAT_VERSION;
  buf[7]  = (uint8_t)seq;
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

  Wire.begin(26, 32);

  while (!bme.begin(0x76)) {
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
  temp = (int16_t)(dht12.temperature * 100);
  hum  = (uint16_t)(dht12.humidity * 100);
  pres = (uint16_t)(bme.readPressure() / 10);
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

  esp_deep_sleep_start();
}
