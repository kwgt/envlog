/*
 * Environemnt data logger 
 *
 *   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
 */

(function () {
  var session;

  function updateSensorRow(id) {
    session.getLatestSensorValue(id)
      .then((info) => {
        $('table#sensor-table > tbody')
          .find(`tr[data-sensor-id=${id}]`)
            .find('td.last-update')
              .text(info["time"])
            .end()
            .find('td.temperature')
              .text(sprintf("%4.1f", info["temp"]))
            .end()
            .find('td.humidity')
              .text(sprintf("%4.1f", info["hum"]))
            .end()
            .find('td.air-pressure')
              .text(sprintf("%4d", info["a/p"]))
            .end()
            .find('td.vbat')
              .text(sprintf("%4.2f", info["vbat"]))
            .end()
            .find('td.vbus')
              .text(sprintf("%4.2f", info["vbus"]))
            .end();
      });
  }

  function setSensorTable(list) {
    list.forEach((info) => {
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
            .text(info["state"])
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
