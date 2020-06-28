/*
 * Sensor gateway for environment data logger
 *
 *  Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmai.com>
 */

#define LCD
#include <M5Stack.h>
#include <BLEDevice.h>

#define MANUFACTURER_ID     55229
#define DATA_FORMAT_VERSION 3

#define N(x)                (sizeof(x)/sizeof(*(x)))
#define U16(p) \
      (uint16_t)((((p)[1]<<8)&0xff00)|(((p)[0]<<0)&0x00ff))

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
  int y;

  std::string dat;
  uint8_t* cstr;
  char addr[16];
  int seq;
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
    cstr = (dat.c_str();)

    if (U16(cstr + 0) != MANUFACTURER_ID) continue;
    if (cstr[2] != DATA_FORMAT_VERSION) continue;

    seq  = (int)((uint8_t)cstr[3]);

    sprintf(addr, "%02x:%02x:%02x:%02x:%02x:%02x",
            cstr[4], cstr[5], cstr[6], cstr[7], cstr[8], cstr[9]);

    temp = U16(cstr + 10) / 100.0;
    hum  = U16(cstr + 12) / 100.0;
    pres = U16(cstr + 14) / 10.0;
    vbat = U16(cstr + 16) / 100.0;
    vbus = U16(cstr + 18) / 100.0;

    M5.Lcd.setCursor(20, y, 1);
    M5.Lcd.printf("sensor %s", addr);

    M5.Lcd.setCursor(30, y + 10, 1);
    M5.Lcd.printf("Temp: %4.1f'C Hum: %4.1f%%", temp, hum);

    M5.Lcd.setCursor(30, y + 20, 1);
    M5.Lcd.printf("Air-pressure: %4.0fhPa", pres);

    M5.Lcd.setCursor(30, y + 30, 1);
    M5.Lcd.printf("RSSI: %d, VBat: %3.1fV VBus: %3.1fV",
                  dev.getRSSI(), vbat, vbus);

    Serial.printf("{");
    Serial.printf("\"addr\":\"%s\",", addr);
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

  M5.Lcd.setCursor(10, 10, 1);

  if (ns > 0) {
    M5.Lcd.printf("update %d sensor(s)", ns);
  } else {
    M5.Lcd.printf("scanning...         ");
  }
}

