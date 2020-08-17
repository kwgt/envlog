/*
 * Environemnt data logger 
 *
 *   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
 */

(function () {
  var session;
  var sensorId;
  var now;

  function setSensorValue(info) {
    if (info["temp"]) {
      $('div#temperature > div.value > span.number')
        .text(sprintf("%.1f", info["temp"]));
    } else {
      $('div#temperature').remove();
    }

    if (info["hum"]) {
      $('div#humidity > div.value > span.number')
        .text(sprintf("%.1f", info["hum"]));
    } else {
      $('div#humidity').remove();
    }

    if (info["a/p"]) {
      $('div#air-pressure > div.value > span.number')
        .text(sprintf("%.0f", info["a/p"]));
    } else {
      $('div#air-pressure').remove();
    }
  }

  function plotTemperatureData(info) {
    var trace;
    var data;
    var head;
    var tail;
    var layout;

    trace  = {
      type:   "scatter",
      mode:   "markers",
      marker: {size:2},
      x:      info["time"],
      y:      info["temp"]
    };

    data   = [trace]
    head   = moment(now).subtract(1, 'days').format("YYYY-MM-DD HH:mm:ss");
    tail   = now.format("YYYY-MM-DD HH:mm:ss");

    layout = {
      title:        "気温",
      xaxis: {
        range:      [head, tail],
        type:       "date"
      },
      yaxis: {
        autorange:  false,
        type:       "linear",
        ticksuffix: "\u00B0C",
        range:      [5, 40],
      }
    }

    Plotly.newPlot('temp-graph', data, layout);
  }

  function plotHumidityData(info) {
    var trace;
    var data;
    var head;
    var tail;
    var layout;

    trace  = {
      type:   "scatter",
      mode:   "markers",
      marker: {size:2},
      x:      info["time"],
      y:      info["hum"]
    };

    data   = [trace]
    head   = moment(now).subtract(1, 'days').format("YYYY-MM-DD HH:mm:ss");
    tail   = now.format("YYYY-MM-DD HH:mm:ss");

    layout = {
      title:        "湿度",
      xaxis: {
        range:      [head, tail],
        type:       "date"
      },
      yaxis: {
        autorange:  false,
        type:       "linear",
        ticksuffix: "%",
        range:      [30, 90]
      }
    }

    Plotly.newPlot('hum-graph', data, layout);
  }

  function plotAirPressureData(info) {
    var trace;
    var data;
    var head;
    var tail;
    var layout;

    trace  = {
      type:   "scatter",
      mode:   "markers",
      marker: {size:2},
      x:      info["time"],
      y:      info["a/p"]
    };

    data   = [trace]
    head   = moment(now).subtract(1, 'days').format("YYYY-MM-DD HH:mm:ss");
    tail   = now.format("YYYY-MM-DD HH:mm:ss");

    layout = {
      title:        "気圧",
      xaxis: {
        range:      [head, tail],
        type:       "date"
      },
      yaxis: {
        autorange:  false,
        type:       "linear",
        ticksuffix: "hpa",
        range:      [950, 1100]
      }
    }

    Plotly.newPlot('air-graph', data, layout);
  }

  function plotTimeSeriesData(info) {
    Plotly.setPlotConfig({locale: 'ja-JP'})

    /*
     * 気温
     */
    if (info["temp"]) {
      plotTemperatureData(info);
    } else {
      $("div#temp-graph").remove();
    }

    /*
     *  湿度
     */
    if (info["hum"]) {
      plotHumidityData(info);
    } else {
      $("div#hum-graph").remove();
    }

    /*
     *  気圧
     */
    if (info["a/p"]) {
      plotAirPressureData(info);
    } else {
      $("div#air-graph").remove();
    }
  }

  function startSession() {
    session
      .on('session_closed', () => {
        Utils.showAbortShield("session closed");
      });

    session.start()
      .then(() => {
        return session.getLatestSensorValue(sensorId)
      })
      .then((info) => {
        setSensorValue(info);

        return session.getTimeSeriesData(sensorId, 0, 48 * 3600)
      })
      .then((info) => {
        plotTimeSeriesData(info);
      })
      .fail((error) => {
        Utils.showAbortShield(error);
      });
  }

  function initialize() {
    session  = new Session(WEBSOCK_URL);
    sensorId = window.location.pathname.split('/')[2];
    now      = moment();

    startSession();
  }

  /* エントリーポイントの設定 */
  $(window)
  .on('load', () => {
    let list = [
      "/css/bootstrap.min.css",
      "/css/ion.rangeSlider.min.css",
      "/css/pretty-checkbox.min.css",
      "/css/roboto.css",
      "/css/roboto-mono.css",

      "/js/popper.min.js",
      "/js/bootstrap.min.js",
      "/js/msgpack.min.js",
      "/js/jquery.nicescroll.min.js",
      "/js/ion.rangeSlider.min.js",
      "/js/sprintf.min.js",
      "/js/moment.min.js",
      "/js/plotly.min.js",
      "/js/plotly-locale-ja.js",

      "/css/sensor/style.scss",
      "/js/msgpack-rpc.js",
      "/js/session.js",
    ];

    Utils.require(list)
      .then(() => {
        initialize();
      });
  });

  /* デフォルトではコンテキストメニューをOFF */
  /*
  $(document)
    .on('contextmenu', (e) => {
      e.stopPropagation();
      return false;
    });
  */

  /* Drop&Dragを無効にしておく */
  $(document)
    .on('dragover', (e) => {
      e.stopPropagation();
      return false;
    })
    .on('dragenter', (e) => {
      e.stopPropagation();
      return false;
    })
    .on('drop', (e) => {
      e.stopPropagation();
      return false;
    });
})();
