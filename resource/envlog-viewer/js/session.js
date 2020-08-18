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

    getSensorInfo(id) {
      return this.remoteCall('get_sensor_info', id);
    }

    setDescription(addr, descr) {
      return this.remoteCall('set_description', addr, descr);
    }

    setPowerSource(addr, state) {
      return this.remoteCall('set_power_source', addr, state);
    }

    activate(addr) {
      return this.remoteCall('activate', addr);
    }

    pause(addr) {
      return this.remoteCall('pause', addr);
    }

    resume(addr) {
      return this.remoteCall('resume', addr);
    }

    removeDevice(addr) {
      return this.remoteCall('remove_device', addr);
    }

    getWeekData(id, tm) {
      return this.remoteCall('get_week_data', id, tm);
    }

    getMonthData(id, tm) {
      return this.remoteCall('get_month_data', id, tm);
    }

    getSeasonData(id, tm) {
      return this.remoteCall('get_season_data', id, tm);
    }

    getYearData(id, tm) {
      return this.remoteCall('get_year_data', id, tm);
    }
  }
})();
