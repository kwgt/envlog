/*
 * Sensor device control for environment data logger
 *
 *  Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmai.com>
 */

#include <M5StickC.h>
#include <Wire.h>

#include "DHT12.h"
#include "Adafruit_Sensor.h"
#include "Adafruit_BMP280.h"
#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLEUtils.h"
#include "esp_sleep.h"

#undef ENABLE_LCD
#define ENABLE_LED

#define MANUFACTURER_ID       55229
#define DATA_FORMAT_VERSION   2
#define DEVICE_NAME           "ENVLOG sensor"
                         
#define T_PERIOD              1         // Transmission period
#define S_PERIOD              119       // Sleeping period
                             
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

void
setup()
{
#ifdef ENABLE_LCD
  M5.begin(true, false, false);
  M5.Axp.ScreenBreath(8);
  M5.Lcd.setRotation(3);
  M5.Lcd.setTextFont(4);
  M5.Lcd.setTextSize(1);
  M5.Lcd.fillScreen(BLACK);
#else /* defined(ENABLE_LCD) */
  M5.begin(false, false, false);
  M5.Axp.ScreenBreath(0);
  M5.Axp.SetLDO2(false);
#endif /* defined(ENABLE_LCD) */

  esp_sleep_enable_timer_wakeup(S_PERIOD * 1000000);
  setCpuFrequencyMhz(80);

  Wire.begin(0, 26);

#ifdef ENABLE_LED
  pinMode(M5STICK_PIN_LED, OUTPUT);
#else /* defined(ENABLE_LED) */
  pinMode(M5STICK_PIN_LED, INPUT_PULLDOWN);
#endif /* defined(ENABLE_LED) */

  while (!bme.begin(0x76)) {
#ifdef ENABLE_LCD
    M5.Lcd.println("BMP280 init fail");
#endif /* defined(ENABLE_LCD) */
    delay(10);
  }

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
  vbat = (uint16_t)(M5.Axp.GetBatVoltage() * 100);
  vbus = (uint16_t)(M5.Axp.GetVBusVoltage() * 100);
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

#ifdef ENABLE_LCD
  M5.Lcd.setCursor(0, 0, 1);
  M5.Lcd.printf("Temp: %4.1f'C Hum: %4.1f%%\n", temp / 100.0, hum / 100.0);
  M5.Lcd.printf("Air-pressure: %4.0fhPa\n", pres / 10.0);
  M5.Lcd.printf("VBat: %4.1fV VBus: %4.1fV\n", vbat / 100.0, vbus / 100.0);
#endif /* !defined(ENABLE_LCD) */

  set_advertising_data();

#ifdef ENABLE_LED
  digitalWrite(M5STICK_PIN_LED, LOW);
#endif /* !defined(ENABLE_LED) */

  advertising->start();
  delay(T_PERIOD * 1000);
  advertising->stop();

#ifdef ENABLE_LED
  digitalWrite(M5STICK_PIN_LED, HIGH);
#endif /* !defined(ENABLE_LED) */

  seq++;

  esp_deep_sleep_start();
}
