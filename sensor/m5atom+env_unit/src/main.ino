/*
 * Sensor device control for environment data logger
 *
 *  Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmai.com>
 */

#include <M5Atom.h>
#include <Wire.h>

#include "DHT12.h"
#include "Adafruit_Sensor.h"
#include "Adafruit_BMP280.h"
#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "esp_sleep.h"

#define ENABLE_SERIAL
#define ENABLE_LED

#define MANUFACTURER_ID       55229
#define DATA_FORMAT_VERSION   2
#define DEVICE_NAME           "ENVLOG sensor (M5Atom)"
                         
#define T_PERIOD              1         // Transmission period
#define S_PERIOD              9       // Sleeping period
                             
#define M5STICK_PIN_LED       10

#define LO_BYTE(x)            (uint8_t)(((x) >> 0) & 0xff)
#define HI_BYTE(x)            (uint8_t)(((x) >> 8) & 0xff)

DHT12 dht12;
Adafruit_BMP280 bme;
RTC_DATA_ATTR int boot_count = 0;
RTC_DATA_ATTR uint8_t seq;

BLEServer* server;
BLEAdvertising* advertising;

uint16_t temp;
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

void
setup()
{
  bool serial;
  bool led;

  serial = false;
  led    = false;

#ifdef ENABLE_SERIAL
  serial = true;
#endif /* defined(ENABLE_SERIAL) */

#ifdef ENABLE_LED
  led    = true;
#endif /* defined(ENABLE_LED) */

  M5.begin(serial, true, led);

#ifdef ENABLE_SERIAL
  Serial.begin(115200);
#endif /* defined(ENABLE_SERIAL) */

  esp_sleep_enable_timer_wakeup(S_PERIOD * 1000000);
  setCpuFrequencyMhz(80);

  Wire.begin(26, 32);

  while (!bme.begin(0x76)) {
#ifdef ENABLE_SERIAL
    Serial.printf("BMP280 init fail\n");
#endif /* defined(ENABLE_LCD) */

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

  BLEDevice::init(DEVICE_NAME);

  server      = BLEDevice::createServer();
  advertising = server->getAdvertising(); 

  boot_count++;
}

void
read_sensor()
{
  dht12.read();
  temp = (uint16_t)(dht12.temperature * 100);
  hum  = (uint16_t)(dht12.humidity * 100);
  pres = (uint16_t)(bme.readPressure() / 10);
  vbat = (uint16_t)0;
  vbus = (uint16_t)500;
}

void
set_advertising_data()
{
  BLEAdvertisementData adat = BLEAdvertisementData();

  adat.setFlags(0x06);

  std::string data;

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
}

void
loop()
{
  read_sensor();

#ifdef ENABLE_SERIAL
  Serial.printf("Temp: %4.1f'C Hum: %4.1f%%\n", temp / 100.0, hum / 100.0);
  Serial.printf("Air-pressure: %4.0fhPa\n", pres / 10.0);
  Serial.printf("VBat: %4.1fV VBus: %4.1fV\n", vbat / 100.0, vbus / 100.0);
#endif /* !defined(ENABLE_LCD) */

  set_advertising_data();

#ifdef ENABLE_SERIAL
  Serial.printf("Advertise start\n");
#endif /* !defined(ENABLE_SERIAL) */

#ifdef ENABLE_LED
  set_led(0x00f000);
#endif /* defined(ENABLE_LED) */

  advertising->start();
  delay(T_PERIOD * 1000);
  advertising->stop();

#ifdef ENABLE_SERIAL
  Serial.printf("Advertise stop\n");
#endif /* !defined(ENABLE_SERIAL) */

#ifdef ENABLE_LED
  set_led(0x000000);
#endif /* defined(ENABLE_LED) */

  seq++;

  esp_deep_sleep_start();
}
