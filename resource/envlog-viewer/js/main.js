/*
 * Environemnt data logger 
 *
 *   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
 */

(function () {
  var session;

  function lookupStateClass(val) {
    var ret;

    switch (val) {
    case "READY":
      ret = "state-ready";
      break;

    case "UNKNOWN":
      ret = "state-unknown";
      break;

    case "NORMAL":
      ret = "state-normal";
      break;

    case "DEAD-BATTERY":
      ret = "state-dead-battery";
      break;

    case "STALL":
      ret = "state-stall";
      break;

    case "PAUSE":
      ret = "state-pause";
      break;

    default:
      throw("really?");
      break;
    }

    return ret;
  }

  function stringifyValues(src) {
    var ret;

    switch (src["state"]) {
    case "NORMAL":
    case "DEAD-BATTERY":
      ret = {
        "temp": sprintf("%4.1f", src["temp"]),
        "hum":  sprintf("%4.1f", src["hum"]),
        "a/p":  sprintf("%4d",   src["a/p"]),
        "vbat": sprintf("%4.2f", src["vbat"]),
        "vbus": sprintf("%4.2f", src["vbus"]),
      };
      break;

    case "UNKNOWN":
    case "READY":
    case "STALL":
    case "PAUSE":
        ret = {
          "temp": " \u{2014} ",
          "hum":  " \u{2014} ",
          "a/p":  " \u{2014} ",
          "vbat": " \u{2014} ",
          "vbus": " \u{2014} ",
        };
      break;
    }

    return ret;
  }

  function updateSensorRow(id) {
    session.getLatestSensorValue(id)
      .then((info) => {
        let foo;

        foo = stringifyValues(info);

        $('table#sensor-table > tbody')
          .find(`tr[data-sensor-id=${id}]`)
            .find('td.last-update')
              .text(info["time"])
            .end()
            .find('td.temperature')
              .text(foo["temp"])
            .end()
            .find('td.humidity')
              .text(foo["hum"])
            .end()
            .find('td.air-pressure')
              .text(foo["a/p"])
            .end()
            .find('td.vbat')
              .text(foo["vbat"])
            .end()
            .find('td.vbus')
              .text(foo["vbus"])
            .end()
            .find('td.state')
              .removeClass()
              .addClass('state')
              .addClass(lookupStateClass(info["state"]))
            .end();
      });
  }

  function setSensorTable(list) {
    list.forEach((info) => {
      let foo;
      let $a;

      foo = stringifyValues(info);

      if (info["state"] == "UNKNOWN" || info["state"] == "READY") {
        $a = $('<a>').addClass("disabled");
      } else {
        $a = $('<a>').attr('href', `sensor/${info["id"]}`)
      }

      $('table#sensor-table > tbody')
        .append($('<tr>')
          .attr("data-sensor-id", info["id"])
          .append($('<td>')
            .addClass('sensor-num')
            .append($a)
          )
          .append($('<td>')
            .addClass('last-update')
            .text(info["mtime"])
          )
          .append($('<td>')
            .addClass('temperature')
            .text(foo["temp"])
          )
          .append($('<td>')
            .addClass('humidity')
            .text(foo["hum"])
          )
          .append($('<td>')
            .addClass('air-pressure')
            .text(foo["a/p"])
          )
          .append($('<td>')
            .addClass('vbat')
            .text(foo["vbat"])
          )
          .append($('<td>')
            .addClass('vbus')
            .text(foo["vbus"])
          )
          .append($('<td>')
            .addClass('state')
            .addClass(lookupStateClass(info["state"]))
          )
          .append($('<td>')
            .addClass('description')
            .text(info["descr"])
          )
        );
    });
  }

  function pollSensor()
  {
    session.pollSensor()
      .then((info) => {
        console.log(info);
      });
  }

  function startSession() {
    session
      .on('update_sensor', (id) => {
        updateSensorRow(id);
      })
      .on('session_closed', () => {
        Utils.showAbortShield("session closed");
      });

    session.start()
      .then(() => {
        return session.getSensorList()
      })
      .then((list) => {
        setSensorTable(list);

        return session.addNotifyRequest("update_sensor");
      })
      .fail((error) => {
        Utils.showAbortShield(error);
      });
  }

  function initialize() {
    session = new Session(WEBSOCK_URL);

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

      "/css/main/style.scss",
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
