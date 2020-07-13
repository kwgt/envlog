(function (){
  LoadingShield = class {
    static initialize() {
      this.$shield  = $('div#loading-shield');
      this.$message = this.$shield.find('div#shield-message');
    }

    static show(msg) {
      this.$message.text(msg);
      this.$shield.show();
      this.$shield.fadeIn('slow');
    }

    static hide() {
      this.$shield.fadeOut('slow');
    }

    static hideFast() {
      this.$shield.hide();
    }
  }
})();
