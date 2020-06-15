/*
 * Environemnt data logger 
 *
 *   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
 */

(function () {
  var session;
  var sensorId;

  function setSensorValue(info) {
    $('div#temperature > div.value > span.number').text(info["temp"]);
    $('div#humidity > div.value > span.number').text(info["hum"]);
    $('div#air-pressure > div.value > span.number').text(info["a/p"]);
  }

  function plotTimeSeriesData(info) {
    var trace1;
    var trace2;
    var trace3;
    var data;
    var layout;

    Plotly.setPlotConfig({locale: 'ja-JP'})

    /*
     * 気温
     */

    trace1 = {
      type: "scatter",
      mode: "lines",
      x: info["time"],
      y: info["temp"]
    };

    data   = [trace1]

    layout = {
      title: "気温",

      xaxis: {
        type: "date"
      },

      yaxis: {
        autorange: false,
        type: "linear",
        ticksuffix: "\u00B0C",
        range: [5, 40],
      }
    }

    Plotly.newPlot('temp-graph', data, layout);

    /*
     *  湿度
     */
    trace2 = {
      type: "scatter",
      mode: "lines",
      x: info["time"],
      y: info["hum"]
    };

    data   = [trace2]

    layout = {
      title: "湿度",

      xaxis: {
        type: "date"
      },

      yaxis: {
        autorange: false,
        type: "linear",
        ticksuffix: "%",
        range: [30, 90]
      }
    }

    Plotly.newPlot('hum-graph', data, layout);

    /*
     *  気圧
     */
    trace3 = {
      type: "scatter",
      mode: "lines",
      x: info["time"],
      y: info["a/p"]
    };

    data   = [trace3]

    layout = {
      title: "気圧",

      xaxis: {
        type: "date"
      },

      yaxis: {
        autorange: false,
        type: "linear",
        ticksuffix: "hpa",
        range: [950, 1100]
      }
    }

    Plotly.newPlot('air-graph', data, layout);
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

        return session.getTimeSeriesData(sensorId, 0, 24 * 3600)
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
