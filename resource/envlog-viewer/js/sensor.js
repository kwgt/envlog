/*
 * Environemnt data logger 
 *
 *   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
 */

(function () {
  var graphConfig; 
  var session;
  var sensorId;
  var today;
  var targetDate;

  const I18N_TABLE = {
    pikaday: {
      previousMonth: '前の月',
      nextMonth:     '次の月',

      months: [
        '1月', '2月', '3月',  '4月',  '5月',  '6月',
        '7月', '8月', '9月',' 10月', '11月', '12月',
      ],

      weekdays: [
        '日曜日','月曜日','火曜日','水曜日','木曜日','金曜日','土曜日'
      ],

      weekdaysShort : ['日','月','火','水','木','金','土']
    },

    yearSuffix: '年'
  }

  const VH_OPT_SHAPES = [
    {
      type:      "rect",
      xref:      "paper",
      x0:        0.0,
      y0:        0.0,
      x1:        1.0,
      y1:        7.0,
      opacity:   0.05,
      line:      {color: "rgba(0,0,0,0)", width:0},
      fillcolor: "rgb(255, 0, 0)"
    },{
      type:      "rect",
      xref:      "paper",
      x0:        0.0,
      y0:        0.7,
      x1:        1.0,
      y1:        11.0,
      opacity:   0.05,
      line:      {color: "rgba(0,0,0,0)", width:0},
      fillcolor: "rgb(255, 255, 0)"
    },{
      type:      "rect",
      xref:      "paper",
      x0:        0.0,
      y0:        11.0,
      x1:        1.0,
      y1:        17.0,
      opacity:   0.05,
      line:      {color: "rgba(0,0,0,0)", width:0},
      fillcolor: "rgb(0, 128, 255)"
    },{
      type:      "rect",
      xref:      "paper",
      x0:        0.0,
      y0:        17.0,
      x1:        1.0,
      y1:        100.0,
      opacity:   0.05,
      line:      {color: "rgba(0,0,0,0)", width:0},
      fillcolor: "rgb(0, 255, 255)"
    }
  ];

  function setSensorValue(info) {
    if (info["temp"]) {
      $('div#temperature > div.value > span.number')
        .text(sprintf("%.1f", info["temp"]));
    } else {
      $('div#temperature').remove();
    }

    if (info["r/h"]) {
      $('div#relative-humidity > div.value > span.number')
        .text(sprintf("%.1f", info["r/h"]));
    } else {
      $('div#relative-humidity').remove();
    }

    if (info["v/h"]) {
      $('div#volumetric-humidity > div.value > span.number')
        .text(sprintf("%.1f", info["v/h"]));
    } else {
      $('div#volumetric-humidity').remove();
    }

    if (info["a/p"]) {
      $('div#air-pressure > div.value > span.number')
        .text(sprintf("%.0f", info["a/p"]));
    } else {
      $('div#air-pressure').remove();
    }
  }

  function plot2Day(name, targ, info, key, fmt, suffix, yMin, yMax, optShapes) {
    var trace1;
    var trace2;
    var trace3;
    var data;
    var date;
    var head;
    var tail;
    var min;
    var max;
    var tmMin;
    var tmMax;
    var layout;
    var shapes;

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

    date   = targetDate || today;
    head   = moment(date).subtract(1, 'days').format("YYYY-MM-DD");
    tail   = moment(date).add(1, 'days').format("YYYY-MM-DD");
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

    shapes = [
      {
        type:     "line",
        xref:     "paper",
        x0:       0.0,
        y0:       min,
        x1:       1.0,
        y1:       min,
        opacity:  0.75,
        line:     {color:"blue", dash:"dashdot", width:0.5}
      },{        
        type:     "line",
        xref:     "paper",
        x0:       0.0,
        y0:       max,
        x1:       1.0,
        y1:       max,
        opacity:  0.75,
        line:     {color:"red", dash:"dashdot", width:0.5}
      }
    ];

    if (optShapes) {
      shapes = _.concat(optShapes, ...shapes);
    }

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
      shapes:       shapes,
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

      if (src["r/h"]) {
        src["r/h"].splice(i, 0, null)
      }

      if (src["v/h"]) {
        src["v/h"].splice(i, 0, null)
      }

      if (src["a/p"]) {
        src["a/p"].splice(i, 0, null)
      }
    });
  }

  function postPlotGraph(info) {
    /*
     * 描画するものがなかった場合はメッセージを表示
     */
    if (info["temp"] || info["r/h"] || info["v/h"] || info["a/p"]) {
      $('div#nodata-message').addClass("d-none");
    } else {
      $('div#nodata-message').removeClass("d-none");
    }
  }

  function plotDayData(info) {
    Plotly.setPlotConfig({locale: 'ja-JP'})

    fillupChasm(info);

    /*
     * 気温
     */
    if (info["temp"]) {
      $("div#temp-graph").show();

      plot2Day("気温",
               "temp-graph",
               info,
               "temp",
               "%{y:.1f}",
               "\u00B0C",
               _.get(graphConfig, ["range", "temp", "min"]),
               _.get(graphConfig, ["range", "temp", "max"]));

    } else {
      $("div#temp-graph").hide();
    }

    /*
     *  相対湿度
     */
    if (info["r/h"]) {
      $("div#rh-graph").show();

      plot2Day("湿度(RH)",
               "rh-graph",
               info,
               "r/h",
               "%{y:.1f}",
               "%",
               _.get(graphConfig, ["range", "r/h", "min"]),
               _.get(graphConfig, ["range", "r/h", "max"]));

    } else {
      $("div#rh-graph").hide();
    }

    /*
     *  絶対湿度(容積)
     */
    if (info["v/h"]) {
      $("div#vh-graph").show();

      plot2Day("湿度(VH)",
               "vh-graph",
               info,
               "v/h",
               "%{y:.1f}",
               "g/m\u00b3",
               _.get(graphConfig, ["range", "v/h", "min"]),
               _.get(graphConfig, ["range", "v/h", "max"]),
               VH_OPT_SHAPES);

    } else {
      $("div#vh-graph").hide();
    }

    /*
     *  気圧
     */
    if (info["a/p"]) {
      $("div#air-graph").show();

      plot2Day("気圧",
               "air-graph",
               info,
               "a/p",
               "%{y:.0f}",
               "hpa",
               _.get(graphConfig, ["range", "a/p", "min"]),
               _.get(graphConfig, ["range", "a/p", "max"]));

    } else {
      $("div#air-graph").hide();
    }

    postPlotGraph(info);
  }

  function plotAbstractHourCore(name, targ, info, key,
                                fmt, suffix, xMin, xMax, yMin, yMax,
                                optShapes) {
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
    var shapes;

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
    shapes = [
      {
        type:     "line",
        xref:     "paper",
        x0:       0.0,
        y0:       min,
        x1:       1.0,
        y1:       min,
        opacity:  0.5,
        line:     {color:"blue", dash:"dashdot", width:0.5}
      },{        
        type:     "line",
        xref:     "paper",
        x0:       0.0,
        y0:       max,
        x1:       1.0,
        y1:       max,
        opacity:  0.5,
        line:     {color:"red", dash:"dashdot", width:0.5}
      }
    ];

    if (optShapes) {
      shapes = _.concat(optShapes, ...shapes);
    }

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
      shapes:       shapes, 
    };

    Plotly.newPlot(targ, data, layout);
  }

  function checkChasmByWeek(index, head, tail) {
    var ret;
    var dt;
    var s;

    dt  = moment(head);

    // ISO週に合わせて月曜始まりで日付情報を丸める
    dt.subtract((dt.days() + 6) % 7, "days");

    ret = [];

    while ((s = dt.format("YYYY-MM-DD")) <= tail) {
      if (!_.includes(index, s)) {
        ret.push(s);
      }

      dt = dt.add(1, "weeks");
    }

    return ret;
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
    var date;
    var head;
    var tail;
    var chams;

    date   = targetDate || today;
    head   = moment(date).subtract(span - 1, "days").format("YYYY-MM-DD");
    tail   = moment(date).add(1, "days").format("YYYY-MM-DD");

    info["date"].push(date);

    if (_.isArray(_.get(info, ["temp", "avg"]))) {
      duplicateTail(info["temp"]["min"]);
      duplicateTail(info["temp"]["max"]);
    }

    if (_.isArray(_.get(info, ["r/h", "avg"]))) {
      duplicateTail(info["r/h"]["min"]);
      duplicateTail(info["r/h"]["max"]);
    }

    if (_.isArray(_.get(info, ["v/h", "avg"]))) {
      duplicateTail(info["v/h"]["min"]);
      duplicateTail(info["v/h"]["max"]);
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

      if (_.isArray(_.get(info, ["r/h", "avg"]))) {
        info["r/h"]["avg"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["v/h", "avg"]))) {
        info["v/h"]["avg"].splice(i, 0, null);
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

      if (_.isArray(_.get(info, ["r/h", "avg"]))) {
        info["r/h"]["min"].splice(i, 0, null);
        info["r/h"]["max"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["v/h", "avg"]))) {
        info["v/h"]["min"].splice(i, 0, null);
        info["v/h"]["max"].splice(i, 0, null);
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
      $("div#temp-graph").show();

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

    } else {
      $("div#temp-graph").hide();
    }

    /*
     *  相対湿度
     */
    if (info["r/h"]) {
      $("div#rh-graph").show();

      plotAbstractHourCore("湿度(RH)",
                           "rh-graph",
                           info,
                           "r/h",
                           "%{y:.1f}",
                           "%",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "r/h", "min"]),
                           _.get(graphConfig, ["range", "r/h", "max"]));

    } else {
      $("div#rh-graph").hide();
    }

    /*
     *  絶対湿度(容積)
     */
    if (info["v/h"]) {
      $("div#vh-graph").show();

      plotAbstractHourCore("湿度(VH)",
                           "vh-graph",
                           info,
                           "v/h",
                           "%{y:.1f}",
                           "g/m\u00b3",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "v/h", "min"]),
                           _.get(graphConfig, ["range", "v/h", "max"]),
                           VH_OPT_SHAPES);

    } else {
      $("div#vh-graph").hide();
    }

    /*
     *  気圧
     */
    if (info["a/p"]) {
      $("div#air-graph").show();

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

    } else {
      $("div#air-graph").hide();
    }

    postPlotGraph(info);
  }

  function plotAbstractDateCore(name, targ, info, key, fmt,
                                suffix, xMin, xMax, yMin, yMax,
                                optShapes) {
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
    var shapes;

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
    shapes = [
      {
        type:     "line",
        xref:     "paper",
        x0:       0.0,
        y0:       min,
        x1:       1.0,
        y1:       min,
        opacity:  0.5,
        line:     {color:"blue", dash:"dashdot", width:0.5}
      },{        
        type:     "line",
        xref:     "paper",
        x0:       0.0,
        y0:       max,
        x1:       1.0,
        y1:       max,
        opacity:  0.5,
        line:     {color:"red", dash:"dashdot", width:0.5}
      }
    ];

    if (optShapes) {
      shapes = _.concat(optShapes, ...shapes);
    }


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
      shapes:       shapes,
    };

    Plotly.newPlot(targ, data, layout);
  }

  function plotAbstractDateData(info, span) {
    var date;
    var head;
    var tail;
    var chams;

    date   = targetDate || today;
    head   = moment(date).subtract(span - 1, "days").format("YYYY-MM-DD");
    tail   = moment(date).add(1, "days").format("YYYY-MM-DD");

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

      if (_.isArray(_.get(info, ["r/h", "avg"]))) {
        info["r/h"]["avg"].splice(i, 0, null);
        info["r/h"]["min"].splice(i, 0, null);
        info["r/h"]["max"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["v/h", "avg"]))) {
        info["v/h"]["avg"].splice(i, 0, null);
        info["v/h"]["min"].splice(i, 0, null);
        info["v/h"]["max"].splice(i, 0, null);
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
      $("div#temp-graph").show();

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

    } else {
      $("div#temp-graph").hide();
    }

    /*
     * 相対湿度
     */
    if (info["r/h"]) {
      $("div#rh-graph").show();

      plotAbstractDateCore("湿度(RH)",
                           "rh-graph",
                           info,
                           "r/h",
                           "%{y:.1f}",
                           "%",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "r/h", "min"]),
                           _.get(graphConfig, ["range", "r/h", "max"]));

    } else {
      $("div#rh-graph").hide();
    }

    /*
     *  絶対湿度(容積)
     */
    if (info["v/h"]) {
      $("div#vh-graph").show();

      plotAbstractDateCore("湿度(VH)",
                           "vh-graph",
                           info,
                           "v/h",
                           "%{y:.1f}",
                           "g/m\u00b3",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "v/h", "min"]),
                           _.get(graphConfig, ["range", "v/h", "max"]),
                           VH_OPT_SHAPES);

    } else {
      $("div#vh-graph").hide();
    }

    /*
     *  気圧
     */
    if (info["a/p"]) {
      $("div#air-graph").show();

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

    } else {
      $("div#air-graph").hide();
    }

    postPlotGraph(info);
  }

  function plotAbstractWeekCore(name, targ, info, key, fmt,
                                suffix, xMin, xMax, yMin, yMax,
                                optShapes) {
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
    var shapes;

    min    = _.min(info[key]["min"]);
    max    = _.max(info[key]["max"]);
    dtMin  = info["date"][_.indexOf(info[key]["min"], min)];
    dtMax  = info["date"][_.indexOf(info[key]["max"], max)];

    trace1 = {
      name:          "平均",
      type:          "scatter",
      mode:          "lines",
      line:          {shape:"spline"},
      x:             _.map(info["week"], (s) => {
                      return moment(s).add(2, "days").format("YYYY-MM-DD");
                    }),
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
    shapes = [
      {
        type:     "line",
        xref:     "paper",
        x0:       0.0,
        y0:       min,
        x1:       1.0,
        y1:       min,
        opacity:  0.5,
        line:     {color:"blue", dash:"dashdot", width:0.5}
      },{        
        type:     "line",
        xref:     "paper",
        x0:       0.0,
        y0:       max,
        x1:       1.0,
        y1:       max,
        opacity:  0.5,
        line:     {color:"red", dash:"dashdot", width:0.5}
      }
    ];

    if (optShapes) {
      shapes = _.concat(optShapes, ...shapes);
    }

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
      shapes:       shapes,
    };

    $(`div#${targ}`)
      .on("plotly_relayout", (e) => {
        console.log(e);
      });

    Plotly.newPlot(targ, data, layout);
  }

  function plotAbstractWeekData(info, span) {
    var date;
    var head;
    var tail;
    var chams;

    date   = targetDate || today;
    head   = moment(date).subtract(span - 1, "days").format("YYYY-MM-DD");
    tail   = moment(date).add(1, "days").format("YYYY-MM-DD");

    /*
     * 欠損部分のマーキング(週別データ)
     */
    chams  = checkChasmByWeek(info["week"], head, tail);
    _.each(chams, (tm) => {
      let i;

      i = _.sortedIndex(info["week"], tm);

      info["week"].splice(i, 0, tm);

      if (_.isArray(_.get(info, ["temp", "avg"]))) {
        info["temp"]["avg"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["r/h", "avg"]))) {
        info["r/h"]["avg"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["v/h", "avg"]))) {
        info["v/h"]["avg"].splice(i, 0, null);
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

      if (_.isArray(_.get(info, ["r/h", "avg"]))) {
        info["r/h"]["min"].splice(i, 0, null);
        info["r/h"]["max"].splice(i, 0, null);
      }

      if (_.isArray(_.get(info, ["v/h", "avg"]))) {
        info["v/h"]["min"].splice(i, 0, null);
        info["v/h"]["max"].splice(i, 0, null);
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
      $("div#temp-graph").show();

      plotAbstractWeekCore("気温",
                           "temp-graph",
                           info,
                           "temp",
                           "%{y:.1f}",
                           "\u00B0C",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "temp", "min"]),
                           _.get(graphConfig, ["range", "temp", "max"]));

    } else {
      $("div#temp-graph").hide();
    }

    /*
     * 相対湿度
     */
    if (info["r/h"]) {
      $("div#rh-graph").show();

      plotAbstractWeekCore("湿度(RH)",
                           "rh-graph",
                           info,
                           "r/h",
                           "%{y:.1f}",
                           "%",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "r/h", "min"]),
                           _.get(graphConfig, ["range", "r/h", "max"]));

    } else {
      $("div#rh-graph").hide();
    }

    /*
     *  絶対湿度(容積)
     */
    if (info["v/h"]) {
      $("div#vh-graph").show();

      plotAbstractWeekCore("湿度(VH)",
                           "vh-graph",
                           info,
                           "v/h",
                           "%{y:.1f}",
                           "g/m\u00b3",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "v/h", "min"]),
                           _.get(graphConfig, ["range", "v/h", "max"]),
                           VH_OPT_SHAPES);

    } else {
      $("div#vh-graph").hide();
    }

    /*
     *  気圧
     */
    if (info["a/p"]) {
      $("div#air-graph").show();

      plotAbstractWeekCore("気圧",
                           "air-graph",
                           info,
                           "a/p",
                           "%{y:.0f}",
                           "hpa",
                           head,
                           tail,
                           _.get(graphConfig, ["range", "a/p", "min"]),
                           _.get(graphConfig, ["range", "a/p", "max"]));

    } else {
      $("div#air-graph").hide();
    }

    postPlotGraph(info);
  }

  function lockUpdate () {
    $('input#target-date').prop("disabled", true)
    $('div.pretty > input').prop("disabled", true);
    $('input#auto-update').prop("disabled", true)
    updateGraph.locked = true;
  }

  function unlockUpdate() {
    updateGraph.locked = false;
    $('input#target-date').prop("disabled", false);
    $('div.pretty > input').prop("disabled", false);

    if (targetDate) {
      $('input#auto-update').prop("disabled", true)
    }
  }

  function updateGraph() {
    if (!updateGraph.locked) {
      lockUpdate();

      switch ($('input[name=mode]:checked').val()) {
      case "day":
        session.getDayData(sensorId, targetDate || today)
          .then((info) => {
            plotDayData(info);
            unlockUpdate();
          });
        break;

      case "week":
        session.getWeekData(sensorId, targetDate || today)
          .then((info) => {
            plotAbstractHourData(info, 14);
            unlockUpdate();
          });
        break;

      case "1month":
        session.getMonthData(sensorId, targetDate || today)
          .then((info) => {
            plotAbstractHourData(info, 30)
            unlockUpdate();
          });
        break;

      case "3months":
        session.getSeasonData(sensorId, targetDate || today)
          .then((info) => {
            plotAbstractDateData(info, 90)
            unlockUpdate();
          });
        break;

      case "year":
        session.getYearData(sensorId, targetDate || today)
          .then((info) => {
            plotAbstractWeekData(info, 365)
            unlockUpdate();
          });
        break;

      default:
        unlockUpdate();
        throw("Really?");
      }
    }
  }

  function setupForm() {
    $('input[name=mode]')
      .on('click', () => updateGraph());

    $('input#target-date')
      .on('keydown', (e) => false)
      .val(today)
      .pikaday({
        i18n: {
          previousMonth: '前の月',
          nextMonth:     '次の月',

          months: [
            '1月', '2月', '3月',  '4月',  '5月',  '6月',
            '7月', '8月', '9月',' 10月', '11月', '12月',
          ],

          weekdays: [
            '日曜日','月曜日','火曜日','水曜日','木曜日','金曜日','土曜日'
          ],

          weekdaysShort : [
            '日', '月', '火', '水', '木', '金', '土'
          ]
        },

        yearSuffix: '年',
        showMonthAfterYear: true,

        onSelect: (d) => {
          date = moment(d).format("YYYY-MM-DD");

          if (date != today) {
            $('input#auto-update')
              .prop("disabled", true)
              .prop("checked", false);
            targetDate = date;

          } else {
            $('input#auto-update').prop('disabled', false);
            targetDate = null;
          }

          updateGraph();
        },
      });

    $('button#date-select')
      .on('click', (e) => {
        e.preventDefault();
        $('input#target-date').eq(0).pikaday('show');
      });
  }

  function startSession() {
    session
      .on('update_sensor', (id) => {
        if (id == sensorId) {
          session.getLatestSensorValue(sensorId)
            .then((info) => setSensorValue(info));

          if ($('input#auto-update').is(":checked")) {
            today = moment().format("YYYY-MM-DD");
            if (!targetDate) {
              $('input#target-date').val(today);
            }

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
        updateGraph();
        $('body').show();

        return session.addNotifyRequest("update_sensor");
      })
      .fail((error) => {
        Utils.showAbortShield(error);
      });
  }

  function initialize() {
    session    = new Session(WEBSOCK_URL);
    sensorId   = window.location.pathname.split('/')[2];
    today      = moment().format("YYYY-MM-DD");
    targetDate = null;

    setupForm();

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
      "/css/pikaday.css",
      "/css/bootstrap-icons.css",

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
      "/js/pikaday.js",
      "/js/pikaday.jquery.js",

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
