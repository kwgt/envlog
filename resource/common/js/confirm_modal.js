(function (){
  ConfirmModal = class {
    static initialize() {
      this.$modal = $('div#confirm-modal');

      this.$modal
        .find('div.modal-footer')
          .find("button.btn-primary")
            .on('click', () => {
              this.$df.resolve();
            })
          .end()
          .find("button.btn-secondary")
            .on('click', () => {
              this.$df.reject();
            })
          .end()
        .end();
    }

    static showModal(param) {
      this.$df = new $.Deferred();

      this.$modal
        .find('span#header-text')
          .text(_.get(param, "title") || "CONFIRM")
        .end()
        .find('p#confirm-text')
          .html(_.get(param, "text"))
        .end()
        .find('span#yes-label')
          .text(_.get(param, "yes") || "YES")
        .end()
        .find('span#no-label')
          .text(_.get(param, "no") || "NO")
        .end()
        .modal('show');

      return this.$df.promise();
    }
  }
})();
