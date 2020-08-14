#ifndef __SENSOR_COMMON_H__
#define __SENSOR_COMMON_H__

/*
 * data format
 */
#define DATA_FORMAT_VERSION   4

#define F_TEMP                0x0001
#define F_HUMIDITY            0x0002
#define F_AIRPRES             0x0004
#define F_VBAT                0x0008
#define F_VBUS                0x0010

#define LO_BYTE(x)            (char)(((x) >> 0) & 0xff)
#define HI_BYTE(x)            (char)(((x) >> 8) & 0xff)

/*
 * BLE
 */
#define MANUFACTURER_ID       55229
#define DEVICE_NAME           "ENVLOG sensor"

/*
 * WiFi
 */
#define AP_SSID               "BUFFALO-811F69_G"
#define AP_PASSWD             "dbiu6ichwuef4"
#define AP_RETRY_LIMIT        10
#define SERVER_ADDR           "192.168.0.39"
#define SERVER_PORT           1234
#define CONNECT_TIMEOUT       10000

/*
 * period
 */
#define T_PERIOD              1         // Transmission period
#define S_PERIOD              119       // Sleeping period

#endif /* !defined(__SENSOR_COMMON_H__) */
