/*
 * Sensor gateway for environment data logger
 *
 *  Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmai.com>
 */

#define ENABLE_LED

#include <M5Atom.h>
#include <BLEDevice.h>
#include <ESPRandom.h>

#include "../include/gateway_common.h"

#define N(x)        (sizeof(x)/sizeof(*(x)))
#define U16(p) \
      (uint16_t)((((p)[1]<<8)&0xff00)|(((p)[0]<<0)&0x00ff))

BLEScan* scanner;
#ifdef ENABLE_LED 
RTC_DATA_ATTR int boot_count = 0;
#endif /* defined(ENABLE_LED) */

void
setup() {
  M5.begin(true, false, true);

  Serial.begin(115200);

  BLEDevice::init("");

  scanner = BLEDevice::getScan();
  scanner->setActiveScan(true);
}

void
loop()
{
  BLEScanResults list;
  BLEAdvertisedDevice dev;
  int i;
  int nf;       // as Number of Found
  int ns;       // as Number of Sensor

  std::string dat;
  uint8_t* cstr;
  char addr[24];
  int seq;
  int pos;
  uint16_t f;
  float temp;
  float hum;
  float pres;
  float vbat;
  float vbus;
#ifdef ENABLE_LED 
  int msk;
#endif /* defined(ENABLE_LED) */

  list = scanner->start(10);
  nf   = list.getCount();
  ns   = 0;

#ifdef ENABLE_LED 
  for (i = 0; i < 25; i++) {
    msk = 0xff0000 >> ((boot_count % 3) * 8);
    M5.dis.drawpix(i, ESPRandom::get() & msk);
  }
#endif /* defined(ENABLE_LED) */

  for (i = 0, i < nf; i++) {
    dev = list.getDevice(i);
    if (!dev.haveManufacturerData()) continue;

    dat  = dev.getManufacturerData();
    cstr = (uint8_t*)dat.c_str();

    if (U16(cstr + 0) != MANUFACTURER_ID) continue;
    if (cstr[2] != DATA_FORMAT_VERSION) continue;

    seq  = (int)(cstr[3]);

    sprintf(addr, "%02x:%02x:%02x:%02x:%02x:%02x",
            cstr[4], cstr[5], cstr[6], cstr[7], cstr[8], cstr[9]);

    f    = U16(cstr + 10);
    pos  = 12;

    Serial.printf("{");
    Serial.printf("\"addr\":\"%s\"", addr);
    Serial.printf(",\"seq\":%d", seq);

    if (f & F_TEMP) {
      temp = U16(cstr + pos) / 100.0;
      pos += 2;
      Serial.printf(",\"temp\":%.1f", temp);
    }

    if (f & F_HUMIDITY) {
      hum  = U16(cstr + pos) / 100.0;
      pos += 2;
      Serial.printf(",\"r/h\":%.1f", hum);
    }

    if (f & F_AIRPRES) {
      pres = U16(cstr + pos) / 10.0;
      pos += 2;
      Serial.printf(",\"a/p\":%.1f", pres);
    }

    if (f & F_VBAT) {
      vbat = U16(cstr + pos) / 100.0;
      pos += 2;
      Serial.printf(",\"vbat\":%.2f", vbat);
    }

    if (f & F_VBUS) {
      vbus = U16(cstr + pos) / 100.0;
      pos += 2;
      Serial.printf(",\"vbus\":%.2f", vbus);
    }

    Serial.printf(",\"rssi\":%d", dev.getRSSI());
    Serial.printf("}\r\n");

    ns++;
  }

  Serial.flush();

#ifdef ENABLE_LED 
  boot_count++;
  delay(50);
#endif /* defined(ENABLE_LED) */
}

