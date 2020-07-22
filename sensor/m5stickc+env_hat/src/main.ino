/*
 * Sensor device control for environment data logger
 *
 *  Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmai.com>
 */

#define USE_BLE
#undef USE_WIFI

#undef ENABLE_LCD
#define ENABLE_LED

#include <M5StickC.h>
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
#include <esp_bt_main.h>
#endif /* defined(USE_BLE) */

#ifdef USE_WIFI
#include <WiFi.h>
#include <WiFiUdp.h>
#include <esp_wifi.h>
#endif /* defined(USE_WIFI) */

#include "../../include/sensor_common.h"

#define F_VALUE          (F_TEMP | F_HUMIDITY | F_AIRPRES | F_VBAT | F_VBUS)
 
#define M5STICK_PIN_LED  10

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
  data += (uint8_t)23;
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
  int i;

  for (i = 0; i < AP_RETRY_LIMIT; i++) {
    WiFi.begin(AP_SSID, AP_PASSWD);
    if (WiFi.status() == WL_CONNECTED) break;

#ifdef ENABLE_LCD
    M5.Lcd.setCursor(0, 0, 1);
    M5.Lcd.printf("Trying connect to %s", AP_SSID);
#endif /* defined(ENABLE_LCD) */
    delay(1000);
  }

  if (i == AP_RETRY_LIMIT) {
    // 限度数を超えて接続に失敗した場合はここでdeep sleep
    // ※ 起床時はリセットがかかるのでここに入るとこのターンはこれで終了
    esp_deep_sleep(S_PERIOD * 1000000);
  }

#ifdef ENABLE_LCD
  M5.Lcd.setCursor(0, 0, 1);
  M5.Lcd.printf("connected to %s", AP_SSID);
#endif /* defined(ENABLE_LCD) */
}

void
send_data()
{
  uint8_t buf[20];
  
  buf[0]  = (uint8_t)DATA_FORMAT_VERSION;
  buf[1]  = (uint8_t)seq;

  esp_efuse_mac_get_default(buf + 2);

  buf[8]  = LO_BYTE(F_VALUE);
  buf[9]  = HI_BYTE(F_VALUE);
  buf[10] = LO_BYTE(temp);
  buf[11] = HI_BYTE(temp);
  buf[12] = LO_BYTE(hum);
  buf[13] = HI_BYTE(hum);
  buf[14] = LO_BYTE(pres);
  buf[15] = HI_BYTE(pres);
  buf[16] = LO_BYTE(vbat);
  buf[17] = HI_BYTE(vbat);
  buf[18] = LO_BYTE(vbus);
  buf[19] = HI_BYTE(vbus);

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
#ifdef ENABLE_LCD
  M5.begin(true, true, false);
  M5.Axp.ScreenBreath(8);
  M5.Lcd.setRotation(3);
  M5.Lcd.setTextFont(4);
  M5.Lcd.setTextSize(1);
  M5.Lcd.fillScreen(BLACK);
#endif /* defined(ENABLE_LCD) */

#ifndef ENABLE_LCD
  M5.begin(false, false, false);
  M5.Axp.ScreenBreath(0);
  M5.Axp.SetLDO2(false);
#endif /* !defined(ENABLE_LCD) */

  esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
  setCpuFrequencyMhz(80);

  Wire.begin(0, 26);

#ifdef ENABLE_LED
  pinMode(M5STICK_PIN_LED, OUTPUT);
#endif /* defined(ENABLE_LED) */

#ifndef ENABLE_LED
  pinMode(M5STICK_PIN_LED, INPUT_PULLDOWN);
#endif /* !defined(ENABLE_LED) */

  while (!bme.begin(0x76)) {
#ifdef ENABLE_LCD
    M5.Lcd.setCursor(0, 0, 1);
    M5.Lcd.println("BMP280 init fail");
#endif /* defined(ENABLE_LCD) */
    delay(10);
  }

  setup_comm();

  boot_count++;
}

void
read_sensor()
{
  dht12.read();
  temp = (uint16_t)(dht12.temperature * 100);
  hum  = (uint16_t)(dht12.humidity * 100);
  pres = (uint16_t)(bme.readPressure() / 10);
  vbat = (uint16_t)(M5.Axp.GetBatVoltage() * 100);
  vbus = (uint16_t)(M5.Axp.GetVBusVoltage() * 100);
}

void
loop()
{
  read_sensor();

#ifdef ENABLE_LCD
  M5.Lcd.setCursor(0, 0, 1);
  M5.Lcd.printf("Temp: %4.1f'C Hum: %4.1f%%\n",
                temp / 100.0, hum / 100.0);

  M5.Lcd.printf("Air-pressure: %4.0fhPa\n",
                pres / 10.0);

  M5.Lcd.printf("VBat: %4.1fV VBus: %4.1fV\n",
                vbat / 100.0, vbus / 100.0);
#endif /* !defined(ENABLE_LCD) */

#ifdef ENABLE_LED
  digitalWrite(M5STICK_PIN_LED, LOW);
#endif /* !defined(ENABLE_LED) */

  send_data();

#ifdef ENABLE_LED
  digitalWrite(M5STICK_PIN_LED, HIGH);
#endif /* !defined(ENABLE_LED) */

  seq++;

  stop_comm();

  esp_deep_sleep(S_PERIOD * 1000000);
}
