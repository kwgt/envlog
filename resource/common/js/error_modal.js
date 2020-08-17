(function (){
  ErrorModal = class {
    static initialize() {
      this.$modal = $('div#error-modal');
    }

    static showModal(msg) {
      this.$modal
        .find('div.modal-content div.modal-body textarea')
          .val(msg)
        .end()
        .modal('show');
    }
  }
})();
