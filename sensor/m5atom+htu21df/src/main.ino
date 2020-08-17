/*
 * Sensor device control for environment data logger
 *
 *  Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmai.com>
 */
#undef USE_BLE
#undef USE_UDP
#define USE_TCP

#define ENABLE_LED

/* GPIO assign */
#define SDA_PORT              25
#define SCL_PORT              21

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

#if defined(USE_UDP) || defined(USE_TCP)
#define USE_WIFI
#include <WiFi.h>
#include <WiFiUdp.h>
#include <esp_wifi.h>
#endif /* defined(USE_UDP) || defined(USE_TCP) */

#include "../../include/sensor_common.h"

#define F_VALUE         (F_TEMP | F_HUMIDITY)

#if defined(USE_TCP) && defined(USE_UDP)
#error "both USE_TCP and USE_UDP are selected."
#endif /* defined(USE_BLE) && defined(USE_WIFI) */

#if defined(USE_BLE) && defined(USE_WIFI)
#error "both USE_BLE and either USE_TCP or USE_UDP are selected."
#endif /* defined(USE_BLE) && defined(USE_WIFI) */

#if !defined(USE_BLE) && !defined(USE_WIFI)
#error "output method is not selected."
#endif /* !defined(USE_BLE) && !defined(USE_WIFI) */

Adafruit_HTU21DF htu;
RTC_DATA_ATTR int boot_count = 0;
RTC_DATA_ATTR uint8_t seq;

#ifdef USE_BLE
BLEServer* server;
BLEAdvertising* advertising;
#endif /* defined(USE_BLE) */

#ifdef USE_TCP
WiFiClient tcp;
#endif /* defined(USE_TCP) */

#ifdef USE_UDP
WiFiUDP udp;
#endif /* defined(USE_UDP) */

int16_t temp;
uint16_t hum;
 
void
into_sleep()
{
  int64_t t;

  t = (S_PERIOD * 1000000) - micros();
  if (t < 10000000) t = 10000000; 

  esp_deep_sleep(t);
}
 
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
  data += (uint8_t)17;
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
  data += LO_BYTE(F_VALUE);
  data += HI_BYTE(F_VALUE);
  data += LO_BYTE(temp);
  data += HI_BYTE(temp);
  data += LO_BYTE(hum);
  data += HI_BYTE(hum);

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
  int i;

  WiFi.begin(AP_SSID, AP_PASSWD);

  for (i = 0; i < AP_RETRY_LIMIT; i++) {
    if (WiFi.status() == WL_CONNECTED) break;

#ifdef ENABLE_LED
    set_led(0x00f000);
    delay(500);
    set_led(0x000000);
    delay(500);
#endif /* defined(ENABLE_LED) */

#ifndef ENABLE_LED
    delay(1000);
#endif /* !defined(ENABLE_LED) */
  }

  if (i == AP_RETRY_LIMIT) {
    // 限度数を超えて接続に失敗した場合はここでdeep sleep
    // ※ 起床時はリセットがかかるのでここに入るとこのターンはこれで終了
    into_sleep();
  }

#ifdef ENABLE_LED
  set_led(0x0000f0);
#endif /* defined(ENABLE_LED) */
}

void
send_data()
{
  uint8_t buf[14];

  buf[0]  = (uint8_t)DATA_FORMAT_VERSION;
  buf[1]  = (uint8_t)seq;

  esp_efuse_mac_get_default(buf + 2);

  buf[8]  = LO_BYTE(F_VALUE);
  buf[9]  = HI_BYTE(F_VALUE);
  buf[10] = LO_BYTE(temp);
  buf[11] = HI_BYTE(temp);
  buf[12] = LO_BYTE(hum);
  buf[13] = HI_BYTE(hum);

#ifdef USE_UDP
  udp.beginPacket(SERVER_ADDR, SERVER_PORT);
  udp.write(buf, sizeof(buf));
  udp.endPacket();
  udp.flush();
#endif /* defined(USE_UDP) */

#ifdef USE_TCP
  if (tcp.connect(SERVER_ADDR, SERVER_PORT, CONNECT_TIMEOUT)) {
    tcp.write(buf, sizeof(buf));
    tcp.flush();

    while (tcp.connected()) {
      delay(50);
    }
    
    tcp.stop();

#ifdef ENABLE_LED
  }  else {
    set_led(0x808000);
#endif /* defined(ENABLE_LED) */
  }
#endif /* defined(USE_TCP) */
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

  esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
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

  boot_count++;
}

void
read_sensor()
{
  int n;

	/*
   * HTU21DFのhumidity responseは最大10sかかる。
   * m5atomの場合は消費電力や本体温度の上昇を気にする必要が無いので真面目に
   * 待ってみる。
   */
	n = 5;

	while (n-- > 0) {
#ifdef ENABLE_LED
    set_led(0x000000);
#endif /* defined(ENABLE_LED) */

		htu.readTemperature();

    delay(500);
#ifdef ENABLE_LED
    set_led(0xf0f000);
#endif /* defined(ENABLE_LED) */
    delay(1500);
	}

  temp = (int16_t)(htu.readTemperature() * 100);
  hum  = (uint16_t)(htu.readHumidity() * 100);
}

void
loop()
{
  read_sensor();
  setup_comm();

#ifdef ENABLE_LED
  set_led(0xf00000);
#endif /* defined(ENABLE_LED) */

  send_data();

#ifdef ENABLE_LED
  set_led(0x000000);
#endif /* defined(ENABLE_LED) */

  seq++;

  stop_comm();

  into_sleep();
}
