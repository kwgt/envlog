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

      case "NORMAL":
        ret = "state-normal";
        break;

      case "DEAD-BATTERY":
        ret = "state-dead-battery";
        break;

      case "STALL":
        ret = "state-stall";
        break;

      case "CLOSED":
        ret = "state-closed";
        break;

      default:
        throw("really?");
        break;
    }

    return ret;
  }

  function updateSensorRow(id) {
    session.getLatestSensorValue(id)
      .then((info) => {
        $('table#sensor-table > tbody')
          .find(`tr[data-sensor-id=${info["id"]}]`)
            .find('td.last-update')
              .text(info["time"])
            .end()
            .find('td.temperature')
              .text(info["temp"])
            .end()
            .find('td.humidity')
              .text(info["hum"])
            .end()
            .find('td.air-pressure')
              .text(info["a/p"])
            .end()
            .find('td.vbat')
              .text(info["vbat"])
            .end()
            .find('td.vbus')
              .text(info["vbus"])
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
      let $state;


      $('table#sensor-table > tbody')
        .append($('<tr>')
          .attr("data-sensor-id", info["id"])
          .append($('<td>')
            .addClass('sensor-num')
            .append($('<a>')
              .attr('href', `sensor/${info["id"]}`)
            )
          )
          .append($('<td>')
            .addClass('last-update')
            .text(info["mtime"])
          )
          .append($('<td>')
            .addClass('temperature')
            .text(sprintf("%4.1f", info["temp"]))
          )
          .append($('<td>')
            .addClass('humidity')
            .text(sprintf("%4.1f", info["hum"]))
          )
          .append($('<td>')
            .addClass('air-pressure')
            .text(sprintf("%4d", info["a/p"]))
          )
          .append($('<td>')
            .addClass('vbat')
            .text(sprintf("%4.2f", info["vbat"]))
          )
          .append($('<td>')
            .addClass('vbus')
            .text(sprintf("%4.2f", info["vbus"]))
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
