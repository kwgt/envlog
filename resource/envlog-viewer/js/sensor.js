/*
 * Environemnt data logger 
 *
 *   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
 */

(function () {
  var graphConfig; 
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

  function plot2Day(name, targ, info, key, fmt, suffix, yMin, yMax) {
    var trace1;
    var trace2;
    var trace3;
    var data;
    var head;
    var tail;
    var min;
    var max;
    var tmMin;
    var tmMax;
    var layout;

    trace1 = {
      name:          "測定値",
      type:          "scatter",
      mode:          "lines",
      shape:         "spline",
      marker:        {size:2},
      x:             info["time"],
      y:             info[key],
      hovertemplate: `${fmt}${suffix}`,
    };

    head   = moment(now).subtract(2, 'days').format("YYYY-MM-DD HH:mm:ss");
    tail   = now;
    min    = _.min(info[key]);
    max    = _.max(info[key]);
    tmMin  = _.get(info, ["time", _.indexOf(info[key], min)]);
    tmMax  = _.get(info, ["time", _.indexOf(info[key], max)]);

    trace2 = {
      name:          "期間最低",
      type:          "scatter",
      x:             [tmMin],
      y:             [min],
      opacity:       0.75,
      mode:          "markers+text",
      marker:        {color:'blue', symbol:"circle-open-dot", size: 10},
      hoverinfo:     "skip",
      texttemplate:  `期間最低 ${fmt}${suffix}`,
      textposition:  "bottom center",
      textfont:      {family:"Roboto mono", color:"blue"},
    };

    trace3 = {
      name:          "期間最高",
      type:          "scatter",
      x:             [tmMax],
      y:             [max],
      opacity:       0.75,
      mode:          "markers+text",
      marker:        {color:'red', symbol:"circle-open-dot", size: 10},
      hoverinfo:     "skip",
      texttemplate:  `期間最高 ${fmt}${suffix}`,
      textposition:  "top center",
      textfont:      {family:"Roboto mono", color:"red"},
    };

    data   = [trace1, trace2, trace3]

    layout = {
      title:        {text:name, side:"left", x:"auto", y:0.95},
      modebar:      {orientation:"h"},
      showlegend:   false,
      xaxis: {
        range:      [head, tail],
        tickfont:   {family:"Roboto mono"},
        type:       "date",
      },
      yaxis: {
        autorange:  false,
        type:       "linear",
        ticksuffix: suffix,
        tickfont:   {family:"Roboto mono"},
        range:      [yMin, yMax],
      },
      margin:       {t:40, b:70, r:20},
      shapes: [
        {
          type:     "line",
          x0:       head,
          y0:       min,
          x1:       tail,
          y1:       min,
          opacity:  0.75,
          line:     {color:"blue", dash:"dashdot", width:0.5}
        },{        
          type:     "line",
          x0:       head,
          y0:       max,
          x1:       tail,
          y1:       max,
          opacity:  0.75,
          line:     {color:"red", dash:"dashdot", width:0.5}
        }
      ]
    }

    opt = {
      displaylogo: false,
      showLink: false,
    }

    Plotly.newPlot(targ, data, layout, opt);
  }

  function fillupChasm(src) {
    var t0;
    var t1;
    var tl;
    var a;
    var i;

    tl = src["time"];
    a  = [];

    t0 = moment(tl[0]);
    for (i = 1; i < tl.length; i++) {
      t1 = moment(tl[i]);

      if (t1.unix() - t0.unix() > 300) a.push(i);
      t0 = t1;
    }

    _.eachRight(a, (i) => {
      t0 = moment(tl[i - 1]).add(2, "m").format("YYYY-MM-DD HH:mm:ss");
      src["time"].splice(i, 0, t0)

      if (src["temp"]) {
        src["temp"].splice(i, 0, null)
      }

      if (src["hum"]) {
        src["hum"].splice(i, 0, null)
      }

      if (src["a/p"]) {
        src["a/p"].splice(i, 0, null)
      }
    });
  }

  function plotDayData(info) {
    Plotly.setPlotConfig({locale: 'ja-JP'})

    fillupChasm(info);

    /*
     * 気温
     */
    if (info["temp"]) {
      plot2Day("気温",
               "temp-graph",
               info,
               "temp",
               "%{y:.1f}",
               "\u00B0C",
               _.get(graphConfig, ["range", "temp", "min"]),
               _.get(graphConfig, ["range", "temp", "max"]));
    } else {
      $("div#temp-graph").remove();
    }

    /*
     *  湿度
     */
    if (info["hum"]) {
      plot2Day("湿度",
               "hum-graph",
               info,
               "hum",
               "%{y:.1f}",
               "%",
               _.get(graphConfig, ["range", "hum", "min"]),
               _.get(graphConfig, ["range", "hum", "max"]));
    } else {
      $("div#hum-graph").remove();
    }

    /*
     *  気圧
     */
    if (info["a/p"]) {
      plot2Day("気圧",
               "air-graph",
               info,
               "a/p",
               "%{y:.0f}",
               "hpa",
               _.get(graphConfig, ["range", "a/p", "min"]),
               _.get(graphConfig, ["range", "a/p", "max"]));
    } else {
      $("div#air-graph").remove();
    }
  }

  function plotAbstractHourCore(name, targ, info, key,
                                fmt, suffix, xMin, xMax, yMin, yMax) {
    var trace1;
    var trace2;
    var trace3;
    var trace4;
    var trace5;
    var min;
    var max;
    var dtMin;
    var dtMax;
    var data;
    var layout;

    min    = _.min(info[key]["min"]);
    max    = _.max(info[key]["max"]);
    dtMin  = info["date"][_.indexOf(info[key]["min"], min)];
    dtMax  = info["date"][_.indexOf(info[key]["max"], max)];

    trace1 = {
      name:          "平均",
      type:          "scatter",
      mode:          "lines",
      line:          {shape:"spline"},
      x:             info["time"],
      y:             _.get(info, [key, "avg"]),
      hovertemplate: `${fmt}${suffix}`
    };

    trace2 = {
      name:          "最低",
      type:          "scatter",
      mode:          "lines",
      line:          {color:'blue', width: 0.5, shape:"hv"},
      x:             info["date"],
      y:             _.get(info, [key, "min"]),
      hovertemplate: `${fmt}${suffix}`
    };

    trace3 = {
      name:          "最高",
      type:          "scatter",
      mode:          "lines",
      line:          {color:'red', width: 0.5, shape:"hv"},
      x:             info["date"],
      y:             _.get(info, [key, "max"]),
      hovertemplate: `${fmt}${suffix}`
    };

    trace4 = {
      name:          "期間最低",
      type:          "scatter",
      x:             [dtMin.concat(" 12:00:00")],
      y:             [min],
      opacity:       0.75,
      mode:          "markers+text",
      marker:        {color:'blue', symbol:"circle-open-dot", size: 10},
      hoverinfo:     "skip",
      texttemplate:  `期間最低 ${fmt}${suffix}`,
      textposition:  "bottom center",
      textfont:      {family:"Roboto mono", color:"blue"},
    };

    trace5 = {
      name:          "期間最高",
      type:          "scatter",
      x:             [dtMax.concat(" 12:00:00")],
      y:             [max],
      opacity:       0.75,
      mode:          "markers+text",
      marker:        {color:'red', symbol:"circle-open-dot", size: 10},
      hoverinfo:     "skip",
      texttemplate:  `期間最高 ${fmt}${suffix}`,
      textposition:  "top center",
      textfont:      {family:"Roboto mono", color:"red"},
    };

    data   = [trace1, trace2, trace3, trace4, trace5];

    layout = {
      title:        {text:name, side:"left", x:"auto", y:0.95},
      modebar:      {orientation:"h"},
      showlegend:   false,
      xaxis: {
        range:      [xMin, xMax],
        tickfont:   {family:"Roboto mono"},
        type:       "date",
      },
      yaxis: {
        autorange:  false,
        range:      [yMin, yMax],
        type:       "linear",
        ticksuffix: suffix,
        tickfont:   {family:"Roboto mono"},
      },
      margin:       {t:40, b:70, r:20},
      shapes: [
        {
          type:     "line",
          x0:       xMin,
          y0:       min,
          x1:       xMax,
          y1:       min,
          opacity:  0.5,
          line:     {color:"blue", dash:"dashdot", width:0.5}
        },{        
          type:     "line",
          x0:       xMin,
          y0:       max,
          x1:       xMax,
          y1:       max,
          opacity:  0.5,
          line:     {color:"red", dash:"dashdot", width:0.5}
        }
      ]
    };

    Plotly.newPlot(targ, data, layout);
  }

  function checkChasmByDate(index, head, tail) {
    var ret;
    var dt;
    var s;

    dt  = moment(head);
    ret = [];

    while ((s = dt.format("YYYY-MM-DD")) <= tail) {
      if (!_.includes(index, s)) {
        ret.push(s);
      }

      dt = dt.add(1, "days");
    }

    return ret;
  }

  function checkChasmByHour(index, head, tail) {
    var ret;
    var dt;
    var s;

    dt  = moment(head);
    ret = [];

    while (dt.format("YYYY-MM-DD") <= tail) {
      s = dt.format("YYYY-MM-DD HH:00:00");
      if (!_.includes(index, s)) {
        ret.push(s);
      }

      dt = dt.add(1, "hours");
    }

    return ret;

  }

  function duplicateTail(a) {
    a.push(_.last(a));
  }

  function plotAbstractHourData(info, span) {
    var head;
    var tail;
    var chams;

    head   = moment(now).subtract(span - 1, "days").format("YYYY-MM-DD");
    tail   = moment(now).add(1, "days").format("YYYY-MM-DD");

    info["date"].push(now);
    if (_.isArray(_.get(info, ["temp", "avg"]))) {
      duplicateTail(info["temp"]["min"]);
      duplicateTail(info["temp"]["max"]);
    }

    if (_.isArray(_.get(info, ["hum", "avg"]))) {
      duplicateTail(info["hum"]["min"]);
      duplicateTail(info["hum"]["max"]);
    }

    if (_.isArray(_.get(info, ["a/p", "avg"]))) {
      duplicateTail(info["a/p"]["min"]);
      duplicateTail(info["a/p"]["max"]);
    }

    /*
     * 欠損部分のマーキング(時別データ)
     */
    chams  = checkChasmByHour(info["time"], head, tail);
    _.each(chams, (tm) => {
      let i;

      i = _.sortedIndex(info["time"], tm);

      info["time"].splice(i, 0, tm);

      if (_.isArray(_.get(info, ["temp", "avg"]))) {
        info["temp"]["avg"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["hum", "avg"]))) {
        info["hum"]["avg"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["a/p", "avg"]))) {
        info["a/p"]["avg"].splice(i, 0, null);
      }
    });

    /*
     * 欠損部分のマーキング(日別データ)
     */
    chams  = checkChasmByDate(info["date"], head, tail);
    _.each(chams, (dt) => {
      let i;

      i = _.sortedIndex(info["date"], dt);

      info["date"].splice(i, 0, dt);

      if (_.isArray(_.get(info, ["temp", "avg"]))) {
        info["temp"]["min"].splice(i, 0, null);
        info["temp"]["max"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["hum", "avg"]))) {
        info["hum"]["min"].splice(i, 0, null);
        info["hum"]["max"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["a/p", "avg"]))) {
        info["a/p"]["min"].splice(i, 0, null);
        info["a/p"]["max"].splice(i, 0, null);
      }
    });

    /*
     * 気温
     */
    if (info["temp"]) {
      plotAbstractHourCore("気温",
                           "temp-graph",
                           info,
                           "temp",
                           "%{y:.1f}",
                           "\u00B0C",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "temp", "min"]),
                           _.get(graphConfig, ["range", "temp", "max"]));
    }

    /*
     *  湿度
     */
    if (info["hum"]) {
      plotAbstractHourCore("湿度",
                           "hum-graph",
                           info,
                           "hum",
                           "%{y:.1f}",
                           "%",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "hum", "min"]),
                           _.get(graphConfig, ["range", "hum", "max"]));
    }

    /*
     *  気圧
     */
    if (info["a/p"]) {
      plotAbstractHourCore("気圧",
                           "air-graph",
                           info,
                           "a/p",
                           "%{y:.0f}",
                           "hpa",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "a/p", "min"]),
                           _.get(graphConfig, ["range", "a/p", "max"]));
    }
  }

  function plotAbstractDateCore(name, targ, info, key, fmt,
                                suffix, xMin, xMax, yMin, yMax) {
    var trace1;
    var trace2;
    var trace3;
    var trace4;
    var trace5;
    var min;
    var max;
    var dtMin;
    var dtMax;
    var data;
    var layout;

    min    = _.min(info[key]["min"]);
    max    = _.max(info[key]["max"]);
    dtMin  = info["date"][_.indexOf(info[key]["min"], min)];
    dtMax  = info["date"][_.indexOf(info[key]["max"], max)];

    trace1 = {
      name:          "平均",
      type:          "scatter",
      mode:          "lines",
      line:          {shape:"spline"},
      x:             info["date"],
      y:             _.get(info, [key, "avg"]),
      hovertemplate: `${fmt}${suffix}`
    };

    trace2 = {
      name:          "最低",
      type:          "scatter",
      mode:          "lines",
      line:          {color:'blue', width: 0.5, shape:"hvh"},
      x:             info["date"],
      y:             _.get(info, [key, "min"]),
      hovertemplate: `${fmt}${suffix}`
    };

    trace3 = {
      name:          "最高",
      type:          "scatter",
      mode:          "lines",
      line:          {color:'red', width: 0.5, shape:"hvh"},
      x:             info["date"],
      y:             _.get(info, [key, "max"]),
      hovertemplate: `${fmt}${suffix}`
    };

    trace4 = {
      name:          "期間最低",
      type:          "scatter",
      x:             [dtMin],
      y:             [min],
      opacity:       0.75,
      mode:          "markers+text",
      marker:        {color:'blue', symbol:"circle-open-dot", size: 10},
      hoverinfo:     "skip",
      texttemplate:  `期間最低 ${fmt}${suffix}`,
      textposition:  "bottom center",
      textfont:      {family:"Roboto mono", color:"blue"},
    };

    trace5 = {
      name:          "期間最高",
      type:          "scatter",
      x:             [dtMax],
      y:             [max],
      opacity:       0.75,
      mode:          "markers+text",
      marker:        {color:'red', symbol:"circle-open-dot", size: 10},
      hoverinfo:     "skip",
      texttemplate:  `期間最高 ${fmt}${suffix}`,
      textposition:  "top center",
      textfont:      {family:"Roboto mono", color:"red"},
    };

    data   = [trace1, trace2, trace3, trace4, trace5];

    layout = {
      title:        {text:name, side:"left", x:"auto", y:0.95},
      modebar:      {orientation:"h"},
      showlegend:   false,
      xaxis: {
        range:      [xMin, xMax],
        tickfont:   {family:"Roboto mono"},
        type:       "date",
      },
      yaxis: {
        autorange:  false,
        range:      [yMin, yMax],
        type:       "linear",
        ticksuffix: suffix,
        tickfont:   {family:"Roboto mono"},
      },
      margin:       {t:40, b:70, r:20},
      shapes: [
        {
          type:     "line",
          x0:       xMin,
          y0:       min,
          x1:       xMax,
          y1:       min,
          opacity:  0.5,
          line:     {color:"blue", dash:"dashdot", width:0.5}
        },{        
          type:     "line",
          x0:       xMin,
          y0:       max,
          x1:       xMax,
          y1:       max,
          opacity:  0.5,
          line:     {color:"red", dash:"dashdot", width:0.5}
        }
      ]
    };

    Plotly.newPlot(targ, data, layout);
  }

  function plotAbstractDateData(info, span) {
    var head;
    var tail;
    var chams;

    head   = moment(now).subtract(span - 1, "days").format("YYYY-MM-DD");
    tail   = moment(now).format("YYYY-MM-DD");

    /*
     * 欠損部分のマーキング
     */
    chams  = checkChasmByDate(info["date"], head, tail);
    _.each(chams, (dt) => {
      let i;

      i = _.sortedIndex(info["date"], dt);

      info["date"].splice(i, 0, dt);

      if (_.isArray(_.get(info, ["temp", "avg"]))) {
        info["temp"]["avg"].splice(i, 0, null);
        info["temp"]["min"].splice(i, 0, null);
        info["temp"]["max"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["hum", "avg"]))) {
        info["hum"]["avg"].splice(i, 0, null);
        info["hum"]["min"].splice(i, 0, null);
        info["hum"]["max"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["a/p", "avg"]))) {
        info["a/p"]["avg"].splice(i, 0, null);
        info["a/p"]["min"].splice(i, 0, null);
        info["a/p"]["max"].splice(i, 0, null);
      }
    });

    /*
     * 気温
     */
    if (info["temp"]) {
      plotAbstractDateCore("気温",
                           "temp-graph",
                           info,
                           "temp",
                           "%{y:.1f}",
                           "\u00B0C",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "temp", "min"]),
                           _.get(graphConfig, ["range", "temp", "max"]));
    }

    /*
     *  湿度
     */
    if (info["hum"]) {
      plotAbstractDateCore("湿度",
                           "hum-graph",
                           info,
                           "hum",
                           "%{y:.1f}",
                           "%",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "hum", "min"]),
                           _.get(graphConfig, ["range", "hum", "max"]));
    }

    /*
     *  気圧
     */
    if (info["a/p"]) {
      plotAbstractDateCore("気圧",
                           "air-graph",
                           info,
                           "a/p",
                           "%{y:.0f}",
                           "hpa",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "a/p", "min"]),
                           _.get(graphConfig, ["range", "a/p", "max"]));
    }
  }

  function lockUpdate () {
    $('div.pretty > input').prop("disabled", true);
    updateGraph.locked = true;
  }

  function unlockUpdate() {
    updateGraph.locked = false;
    $('div.pretty > input').prop("disabled", false);
  }

  function updateGraph() {
    if (!updateGraph.locked) {
      lockUpdate();

      switch ($('input[name=mode]:checked').val()) {
      case "day":
        session.getTimeSeriesData(sensorId, now, 48 * 3600)
          .then((info) => {
            plotDayData(info);
            unlockUpdate();
          });
        break;

      case "week":
        session.getWeekData(sensorId, now)
          .then((info) => {
            plotAbstractHourData(info, 14);
            unlockUpdate();
          });
        break;

      case "1month":
        session.getMonthData(sensorId, now)
          .then((info) => {
            plotAbstractHourData(info, 30)
            unlockUpdate();
          });
        break;

      case "3months":
        session.getSeasonData(sensorId, now)
          .then((info) => {
            plotAbstractDateData(info, 90)
            unlockUpdate();
          });
        break;

      case "year":
        session.getYearData(sensorId, now)
          .then((info) => {
            plotAbstractDateData(info, 365)
            unlockUpdate();
          });
        break;

      default:
        unlockUpdate();
        throw("Really?");
      }
    }
  }

  function setupHandler() {
    $('input[name=mode]')
      .on('click', () => updateGraph());
  }

  function startSession() {
    session
      .on('update_sensor', (id) => {
        if (id == sensorId) {
          session.getLatestSensorValue(sensorId)
            .then((info) => setSensorValue(info));

          if ($('input#auto-update').is(":checked")) {
            now = moment().format("YYYY-MM-DD HH:mm:ss");
            updateGraph();
          }
        }
      })
      .on('session_closed', () => {
        Utils.showAbortShield("session closed");
      });

    session.start()
      .then(() => {
        return session.getGraphConfig()
      })
      .then((config) => {
        graphConfig = config;

        return session.getLatestSensorValue(sensorId)
      })
      .then((info) => {
        setSensorValue(info);

        return session.getTimeSeriesData(sensorId, now, 48 * 3600)
      })
      .then((info) => {
        plotDayData(info);

        return session.addNotifyRequest("update_sensor");
      })
      .fail((error) => {
        Utils.showAbortShield(error);
      });
  }

  function initialize() {
    session  = new Session(WEBSOCK_URL);
    sensorId = window.location.pathname.split('/')[2];
    now      = moment().format("YYYY-MM-DD HH:mm:ss");

    setupHandler();
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
      "/js/lodash.min.js",

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
