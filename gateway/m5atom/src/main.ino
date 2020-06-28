/*
 * Sensor gateway for environment data logger
 *
 *  Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmai.com>
 */

#include <M5Atom.h>
#include <BLEDevice.h>
#include <ESPRandom.h>

#define ENABLE_LED

#define MANUFACTURER_ID     55229
#define DATA_FORMAT_VERSION 2
#define MAX_SENSORS         16

#define N(x)                (sizeof(x)/sizeof(*(x)))
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
  int y;

  std::string dat;
  int seq;
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

  for (i = 0, y = 33; i < nf; i++) {
    dev = list.getDevice(i);
    if (!dev.haveManufacturerData()) continue;

    dat = dev.getManufacturerData();

    if (U16(dat.c_str() + 0) != MANUFACTURER_ID) continue;
    if (dat.c_str()[2] != DATA_FORMAT_VERSION) continue;

    seq  = (int)((uint8_t)dat.c_str()[3]);
    temp = U16(dat.c_str() + 4)  / 100.0;
    hum  = U16(dat.c_str() + 6)  / 100.0;
    pres = U16(dat.c_str() + 8)  / 10.0;
    vbat = U16(dat.c_str() + 10) / 100.0;
    vbus = U16(dat.c_str() + 12) / 100.0;

    Serial.printf("{");
    Serial.printf("\"addr\":\"%s\",", dev.getAddress().toString().c_str());
    Serial.printf("\"seq\":%d,",      seq);
    Serial.printf("\"temp\":%.1f,",   temp);
    Serial.printf("\"hum\":%.1f,",    hum);
    Serial.printf("\"a/p\":%.0f,",    pres);
    Serial.printf("\"rssi\":%d,",     dev.getRSSI());
    Serial.printf("\"vbat\":%.2f,",   vbat);
    Serial.printf("\"vbus\":%.2f",    vbus);
    Serial.printf("}\r\n");

    y += 45;
    ns++;
  }

  Serial.flush();

#ifdef ENABLE_LED 
  boot_count++;
  delay(50);
#endif /* defined(ENABLE_LED) */
}

