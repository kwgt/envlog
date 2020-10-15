/*
 * Sensor gateway for environment data logger
 *
 *  Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmai.com>
 */

#define LCD
#include <M5Stack.h>
#include <BLEDevice.h>

#include "../../include/gateway_common.h"

#define N(x)        (sizeof(x)/sizeof(*(x)))
#define U16(p) \
      (uint16_t)((((p)[1]<<8)&0xff00)|(((p)[0]<<0)&0x00ff))

#define FONT_WIDTH  6

BLEScan* scanner;

void
setup()
{
  M5.begin();
  M5.Power.begin();

  M5.Lcd.setTextSize(1);
  M5.Lcd.fillScreen(BLACK);

  Serial.begin(115200);

  BLEDevice::init("");

  scanner = BLEDevice::getScan();
  scanner->setActiveScan(false);
}

void
loop()
{
  BLEScanResults list;
  BLEAdvertisedDevice dev;
  int i;
  int nf;       // as Number of Found
  int ns;       // as Number of Sensor
  int x;
  int y;
  int yo;

  std::string dat;
  uint8_t* cstr;
  char addr[24];
  int seq;

  uint16_t f;
  int pos;
  char str[24];
  float temp;
  float hum;
  float pres;
  float vbat;
  float vbus;

  list = scanner->start(10);
  nf   = list.getCount();
  ns   = 0;

  M5.Lcd.fillScreen(BLACK);

  for (i = 0, y = 33; i < nf; i++) {
    dev = list.getDevice(i);
    if (!dev.haveManufacturerData()) continue;

    dat  = dev.getManufacturerData();
    cstr = (uint8_t*)dat.c_str();

    if (U16(cstr + 0) != MANUFACTURER_ID) continue;
    if (cstr[2] != DATA_FORMAT_VERSION) continue;

    seq  = (int)((uint8_t)cstr[3]);

    sprintf(addr, "%02x:%02x:%02x:%02x:%02x:%02x",
            cstr[4], cstr[5], cstr[6], cstr[7], cstr[8], cstr[9]);

    f    = U16(cstr + 10);
    pos  = 12;

    M5.Lcd.setCursor(20, y + 10, 1);
    M5.Lcd.printf("sensor %s", addr);

    Serial.printf("{");
    Serial.printf("\"addr\":\"%s\"", addr);
    Serial.printf(",\"seq\":%d", seq);

    yo = 20;

    /*
     * temperature & humidity
     */
    x  = 30;

    if (f & F_TEMP) {
      temp = U16(cstr + pos) / 100.0;

      sprintf(str, "Temp: %4.1f'C", temp);
      M5.Lcd.setCursor(x, y + yo, 1);
      M5.Lcd.print(str);

      Serial.printf(",\"temp\":%.1f", temp);

      pos += 2;
      x   += FONT_WIDTH * (strlen(str) + 1);
    }

    if (f & F_HUMIDITY) {
      hum  = U16(cstr + pos) / 100.0;

      sprintf(str, "Hum: %4.1f%%", hum);
      M5.Lcd.setCursor(x, y + yo, 1);
      M5.Lcd.print(str);

      Serial.printf(",\"r/h\":%.1f", hum);

      pos += 2;
    }

    if (f & (F_TEMP | F_HUMIDITY)) yo += 10;

    /*
     * air-pressure
     */
    if (f & F_AIRPRES) {
      pres = U16(cstr + pos) / 10.0;

      sprintf(str, "Air-pressure: %4.0fhPa", pres);
      M5.Lcd.setCursor(30, y + yo, 1);
      M5.Lcd.print(str);

      Serial.printf(",\"a/p\":%.1f", pres);

      pos += 2;
      yo  += 10;
    }

    /*
     * vbat & vbus & rssi
     */
    x = 30;

    if (f & F_VBAT) {
      vbat = U16(cstr + pos) / 100.0;

      sprintf(str, "VBat: %3.1fV", vbat);
      M5.Lcd.setCursor(x, y + yo, 1);
      M5.Lcd.print(str);

      Serial.printf(",\"vbat\":%.2f", vbat);

      pos += 2;
      x   += FONT_WIDTH * (strlen(str) + 1);
    }

    if (f & F_VBUS) {
      vbus = U16(cstr + pos) / 100.0;

      sprintf(str, "VBus: %3.1fV", vbus);
      M5.Lcd.setCursor(x, y + yo, 1);
      M5.Lcd.print(str);

      Serial.printf(",\"vbus\":%.2f", vbus);

      pos += 2;
      x   += FONT_WIDTH * (strlen(str) + 1);
    }

    M5.Lcd.setCursor(x, y + yo, 1);
    M5.Lcd.printf("RSSI: %d", dev.getRSSI());

    Serial.printf(",\"rssi\":%d",     dev.getRSSI());
    Serial.printf("}\r\n");

    y += (yo + 15);
    ns++;
  }

  Serial.flush();

  M5.Lcd.setCursor(10, 10, 1);

  if (ns > 0) {
    M5.Lcd.printf("update %d sensor(s)", ns);
  } else {
    M5.Lcd.printf("scanning...         ");
  }
}

