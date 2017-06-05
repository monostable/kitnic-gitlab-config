import $ from 'jquery';

// bootstrap jQuery plugins
import 'bootstrap-sass/assets/javascripts/bootstrap/affix';
import 'bootstrap-sass/assets/javascripts/bootstrap/alert';
import 'bootstrap-sass/assets/javascripts/bootstrap/dropdown';
import 'bootstrap-sass/assets/javascripts/bootstrap/modal';
import 'bootstrap-sass/assets/javascripts/bootstrap/tab';
import 'bootstrap-sass/assets/javascripts/bootstrap/transition';
import 'bootstrap-sass/assets/javascripts/bootstrap/tooltip';

// custom jQuery functions
$.fn.extend({
  disable() { return $(this).attr('disabled', 'disabled').addClass('disabled'); },
  enable() { return $(this).removeAttr('disabled').removeClass('disabled'); },
});
