/*
 * Environemnt data logger 
 *
 *   Copyright (C) 2020 Hiroshi Kuwagata <kgt9221@gmail.com>
 */
(function () {
  const setupHandler        = Symbol('setupHandler');
  const onChangeDescription = Symbol('onChangeDescription');
  const onChangePowerSource = Symbol('onChangePowerSource');
  const onClickRemove       = Symbol('ClickRemove');
  const onClickActivate     = Symbol('onClickActivate');
  const onClickPause        = Symbol('onClickPause');
  const onClickResume       = Symbol('onClickResume');
  const callRemote          = Symbol('callRemote');
  const reload              = Symbol('reload');
  const createConfirmText   = Symbol('createConfirmText');

  DeviceInfo = class {
    static initialize(session) {
      this.$modal  = $('div#device-info-dialog');
      this.session = session;

      this.$modal
        .find('[data-toggle="tooltip"]')
          .tooltip({trigger:"focus"})
        .end()
        .on('hidden.bs.modal', () => {
          this.$df.resolve(this.operation);
        });

      this[setupHandler]();
    }

    static [callRemote](meth) {
      var $df;
      var args;
      var tmo;

      $df  = new $.Deferred();
      args = Array.prototype.slice.call(arguments, 1);

      tmo  = setTimeout(() => {
        LoadingShield.show("Please wait...")
      }, 500);

      this.session[meth](...args)
        .then((result) => {
          $df.resolve(result);
        })
        .fail((error) => {
          ErrorModal.showModal(error);
        })
        .always(() => {
          clearTimeout(tmo);
          LoadingShield.hideFast();
        });

      return $df.promise();
    }

    static [setupHandler]() {
      this.$modal
        .find('input#device-location')
          .on('change', (e) => this[onChangeDescription]($(e.target)))
        .end()
        .find('div#device-power-source-menu > a.dropdown-item')
          .on('click', (e) => this[onChangePowerSource]($(e.target)))
        .end()
        .find('div.modal-footer')
          .find('button.btn-danger')
            .on('click', (e) => this[onClickRemove]($(e.target)))
          .end()
          .find('button.btn-primary.activate')
            .on('click', (e) => this[onClickActivate]($(e.target)))
          .end()
          .find('button.btn-primary.pause')
            .on('click', (e) => this[onClickPause]($(e.target)))
          .end()
          .find('button.btn-primary.resume')
            .on('click', (e) => this[onClickResume]($(e.target)))
          .end()
        .end();
    }

    static [onChangeDescription]($e) {
      this[callRemote]("setDescription", this.address, $e.val())
        .then(() => {
          return this[reload]()
        })
        .then(() => {
          this.operation = "UPDATE";
        });
    }

    static [onChangePowerSource]($e) {
      this[callRemote]("setPowerSource", this.address, $e.data("value"))
        .then(() => {
          this[reload]();
        })
        .then(() => {
          this.operation = "UPDATE";

          this.$modal
            .find('div.modal-footer button.btn-primary.activate')
              .prop("disabled", false)
            .end();
        });
    }

    static [createConfirmText]() {
      var $ret;

      $ret = $('<span>')
        .attr("id", "remove-confirm-text")
        .append($('<span>')
          .text('When you click "YES" this sensor')
        )
        .append($('<span>')
          .addClass('sensor-address')
          .text(this.address)
        )
        .append($('<span>')
          .text(`(${this.descr}) `)
        )
        .append($('<span>')
          .append('will be removed.')
        )
        .append($('<br>'))
        .append($('<span>')
          .append('Are you sure?')
        )

      return $ret;
    }

    static [onClickRemove]($e) {
      var param;

      param = {
        title: "Do you want to remove?",
        text:  this[createConfirmText]()
      };

      this.$modal.hide();

      ConfirmModal.showModal(param)
        .then(() => {
          return this[callRemote]("removeDevice", this.address);
        })
        .then(() => {
          this.operation = "REMOVE";
          this.$modal.modal('hide');
        })
        .fail(() => {
          this.$modal.show();
        });
    }

    static [onClickActivate]($e) {
      this[callRemote]("activate", this.address)
        .then(() => {
          this[reload]();
        })
        .then(() => {
          this.operation = "UPDATE";
        });
    }

    static [onClickPause]($e) {
      this[callRemote]("pause", this.address)
        .then(() => {
          this[reload]();
        })
        .then(() => {
          this.operation = "UPDATE";
        });
    }

    static [onClickResume]($e) {
      this[callRemote]("resume", this.address)
        .then(() => {
          this[reload]();
        })
        .then(() => {
          this.operation = "UPDATE";
        });
    }

    static [reload]() {
      var $df;
      var button;

      $df = new $.Deferred();

      this[callRemote]("getSensorInfo", this.sensorId)
        .then((info) => {
          this.address = info["addr"];
          this.descr   = info["descr"];

          this.$modal
            .find('input#device-address')
              .val(info["addr"])
            .end()
            .find('input#device-ctime')
              .val(moment(info["ctime"],"YYYY-MM-DD HH:mm:ss").format("lll"))
            .end()
            .find('input#device-state')
              .val(info["state"])
            .end()
            .find('input#device-location')
              .val(info["descr"])
            .end()
            .find('div.modal-footer')
              .find('button.activate, button.pause, button.resume')
                .hide()
              .end()
            .end();

          switch (info["state"]) {
          case "UNKNOWN":
            button = "button.activate";
            break;

          case "READY":
            break;

          case "NORMAL":
          case "DEAD-BATTERY":
            button = "button.pause";
            break;

          case "PAUSE":
            button = "button.resume";
            break;
          }

          if (button) {
            this.$modal.find(`div.modal-footer ${button}`).show();
          }

          switch (info["psrc"]) {
          case "STABLE":
          case "BATTERY":
          case "NONE":
            this.$modal
              .find('button#device-power-source')
                .text(info["psrc"])
              .end();
            break;

          default:
            this.$modal
              .find('button#device-power-source')
                .text("NOT SET")
              .end()
              .find('div.modal-footer button.btn-primary')
                .prop("disabled", true)
              .end();
            break;
          }

          $df.resolve();
        });

      return $df.promise();
    }

    static showModal(id) {
      this.sensorId  = id;
      this.$df       = new $.Deferred();
      this.operation = null;

      this[reload]()
        .then(() => {
          this.$modal.modal('show');
        })

      return this.$df.promise();
    }
  };
})();

