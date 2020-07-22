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

  function setSensorRowValue(info) {
    let foo;

    foo = stringifyValues(info);

    $(`table#sensor-table > tbody > tr[data-sensor-id=${info["id"]}]`)
      .find('td.last-update')
        .text(info["mtime"])
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
      .end()
      .find('td.description')
        .text(info["descr"])
      .end();
  }

  function createNewRow(id) {
    var $ret;

    $ret = $('<tr>')
      .attr("data-sensor-id", id)
      .append($('<td>')
        .addClass('sensor-num')
        .append($('<a>')
          .attr('href', `sensor/${id}`)
        )
      )
      .append($('<td>')
        .addClass('last-update')
      )
      .append($('<td>')
        .addClass('temperature')
      )
      .append($('<td>')
        .addClass('humidity')
      )
      .append($('<td>')
        .addClass('air-pressure')
      )
      .append($('<td>')
        .addClass('vbat')
      )
      .append($('<td>')
        .addClass('vbus')
      )
      .append($('<td>')
        .addClass('state')
      )
      .append($('<td>')
        .addClass('description')
      )
      .append($('<td>')
        .addClass('control')
        .append($('<button>')
          .addClass("btn btn-dark btn-sm")
          .html(icon("info"))
          .on('click', () => {
            DeviceInfo.showModal(id)
              .then((operation) => {
                switch (operation) {
                case "UPDATE":
                  updateSensorRow(id);
                  break;

                case "REMOVE":
                  removeSensorRow(id);
                  break;

                default:
                  throw(`really? (${operation})`);
                  break;
                }
              })
          })
        )
      );

    return $ret;
  }

  function appendSensorRow(id) {
    $('table#sensor-table > tbody').append(createNewRow(id));
    updateSensorRow(id);
  }

  function updateSensorRow(id) {
    var args;

    args = [session.getSensorInfo(id),
            session.getLatestSensorValue(id)];

    $.when(...args)
      .then((si, lv) => {
        let info;

        info = {
          id:    id,
          ctime: si["ctime"],
          mtime: lv["time"],
          descr: si["descr"],
          state: si["state"],
          temp:  lv["temp"],
          hum:   lv["hum"],
          "a/p": lv["a/p"],
          rssi:  lv["rssi"],
          vbat:  lv["vbat"],
          vbus:  lv["vbus"],
        }

        setSensorRowValue(info);
        $('table#sensor-table').trigger('update');
      });
  }

  function removeSensorRow(id) {
    $(`table#sensor-table > tbody > tr[data-sensor-id=${id}]`).remove();
  }

  function icon(name) {
    var ret;

    ret = '<svg class="bi">' +
          `<use xlink:href="/icons/bootstrap-icons.svg#${name}"/>` +
          '</svg>';

    return ret;
  }

  function setSensorTable(list) {
    list.forEach((info) => {
      $('table#sensor-table > tbody').append(createNewRow(info["id"]));
      setSensorRowValue(info)
    });

    $('table#sensor-table')
      .tablesorter({
        sortList: [[1, 1]],
        resort:   true,
      });
  }

  function startSession() {
    session
      .on('add_sensor', (id) => {
        appendSensorRow(id);
      })
      .on('update_sensor', (id) => {
        updateSensorRow(id);
      })
      .on('remove_sensor', (id) => {
        removeSensorRow(id);
      })
      .on('session_closed', () => {
        Utils.showAbortShield("session closed");
      });

    session.start()
      .then(() => {
        return session.getSensorList()
      })
      .then((list) => {
        let args;

        setSensorTable(list);

        args = [
          "update_sensor",
          "add_sensor",
          "remove_sensor"
        ];

        return session.addNotifyRequest(...args);
      })
      .then(() => {
        $('body').show();
      })
      .fail((error) => {
        Utils.showAbortShield(error);
      });
  }

  function initialize() {
    session = new Session(WEBSOCK_URL);

    LoadingShield.initialize();
    ErrorModal.initialize();
    ConfirmModal.initialize();
    DeviceInfo.initialize(session);

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
      "/css/bootstrap-icons.css",

      "/js/popper.min.js",
      "/js/bootstrap.min.js",
      "/js/msgpack.min.js",
      "/js/jquery.nicescroll.min.js",
      "/js/ion.rangeSlider.min.js",
      "/js/sprintf.min.js",
      "/js/moment.min.js",
      "/js/lodash.min.js",
      "/js/jquery.tablesorter.min.js",

      "/css/main/style.scss",
      "/js/msgpack-rpc.js",
      "/js/session.js",
      "/js/loading_shield.js",
      "/js/misc/dialog/device_info.js",
      "/js/error_modal.js",
      "/js/confirm_modal.js",
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
