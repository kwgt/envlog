/*
 * Sample for v4l2-ruby
 *
 *   Copyright (C) 2019 Hiroshi Kuwagata <kgt9221@gmail.com>
 */

if (!msgpack || !msgpack.rpc) {
  throw "msgpack-lite.js and msgpack-rpc.js is not load yet"
}

(function () {
  Session = class extends msgpack.rpc {
    constructor(url) {
      super(url)
    }

    hello() {
      return this.remoteCall('hello');
    }

    addNotifyRequest(...args) {
      return this.remoteCall('add_notify_request', ...args);
    }

    getSensorList() {
      return this.remoteCall('get_sensor_list');
    }

    getLatestSensorValue(id) {
      return this.remoteCall('get_latest_sensor_value', id);
    }

    getTimeSeriesData(id, time, span) {
      return this.remoteCall('get_time_series_data', id, time, span);
    }

    pollSensor() {
      return this.remoteCall('poll_sensor');
    }
  }
})();
