/* eslint-disable func-names, space-before-function-paren, wrap-iife, no-var, no-use-before-define, prefer-arrow-callback, no-else-return, consistent-return, prefer-template, quotes, one-var, one-var-declaration-per-line, no-unused-vars, no-return-assign, comma-dangle, quote-props, no-unused-expressions, no-sequences, object-shorthand, max-len */
(function() {
  gl.ImageFile = (function() {
    var prepareFrames;

    // Width where images must fits in, for 2-up this gets divided by 2
    ImageFile.availWidth = 900;

    ImageFile.viewModes = ['two-up', 'swipe'];

    function ImageFile(file) {
      this.file = file;
      this.requestImageInfo($('.two-up.view .frame.deleted img', this.file), (function(_this) {
        // Determine if old and new file has same dimensions, if not show 'two-up' view
        return function(deletedWidth, deletedHeight) {
          return _this.requestImageInfo($('.two-up.view .frame.added img', _this.file), function(width, height) {
            if (width === deletedWidth && height === deletedHeight) {
              return _this.initViewModes();
            } else {
              return _this.initView('two-up');
            }
          });
        };
      })(this));
    }

    ImageFile.prototype.initViewModes = function() {
      var viewMode;
      viewMode = ImageFile.viewModes[0];
      $('.view-modes', this.file).removeClass('hide');
      $('.view-modes-menu', this.file).on('click', 'li', (function(_this) {
        return function(event) {
          if (!$(event.currentTarget).hasClass('active')) {
            return _this.activateViewMode(event.currentTarget.className);
          }
        };
      })(this));
      return this.activateViewMode(viewMode);
    };

    ImageFile.prototype.activateViewMode = function(viewMode) {
      $('.view-modes-menu li', this.file).removeClass('active').filter("." + viewMode).addClass('active');
      return $(".view:visible:not(." + viewMode + ")", this.file).fadeOut(200, (function(_this) {
        return function() {
          $(".view." + viewMode, _this.file).fadeIn(200);
          return _this.initView(viewMode);
        };
      })(this));
    };

    ImageFile.prototype.initView = function(viewMode) {
      return this.views[viewMode].call(this);
    };

    ImageFile.prototype.initDraggable = function($el, padding, callback) {
      var dragging = false;
      var $body = $('body');
      var $offsetEl = $el.parent();

      $el.off('mousedown').on('mousedown', function() {
        dragging = true;
        $body.css('user-select', 'none');
      });

      $body.off('mouseup').off('mousemove').on('mouseup', function() {
        dragging = false;
        $body.css('user-select', '');
      })
      .on('mousemove', function(e) {
        var left;
        if (!dragging) return;

        left = e.pageX - ($offsetEl.offset().left + padding);

        callback(e, left);
      });
    };

    prepareFrames = function(view) {
      var maxHeight, maxWidth;
      maxWidth = 0;
      maxHeight = 0;
      $('.frame', view).each((function(_this) {
        return function(index, frame) {
          var height, width;
          width = $(frame).width();
          height = $(frame).height();
          maxWidth = width > maxWidth ? width : maxWidth;
          return maxHeight = height > maxHeight ? height : maxHeight;
        };
      })(this)).css({
        width: maxWidth,
        height: maxHeight
      });
      return [maxWidth, maxHeight];
    };

    ImageFile.prototype.views = {
      'two-up': function() {
        return $('.two-up.view .wrap', this.file).each((function(_this) {
          return function(index, wrap) {
            $('img', wrap).each(function() {
              var currentWidth;
              currentWidth = $(this).width();
              if (currentWidth > ImageFile.availWidth / 2) {
                return $(this).width(ImageFile.availWidth / 2);
              }
            });
            return _this.requestImageInfo($('img', wrap), function(width, height) {
              $('.image-info .meta-width', wrap).text(width + "px");
              $('.image-info .meta-height', wrap).text(height + "px");
              return $('.image-info', wrap).removeClass('hide');
            });
          };
        })(this));
      },
      'swipe': function() {
        var maxHeight, maxWidth;
        maxWidth = 0;
        maxHeight = 0;
        return $('.swipe.view', this.file).each((function(_this) {
          return function(index, view) {
            var $swipeWrap, $swipeBar, $swipeFrame, wrapPadding, ref;
            ref = prepareFrames(view), maxWidth = ref[0], maxHeight = ref[1];
            $swipeFrame = $('.swipe-frame', view);
            $swipeWrap = $('.swipe-wrap', view);
            $swipeBar = $('.swipe-bar', view);

            $swipeFrame.css({
              width: maxWidth + 16,
              height: maxHeight + 28
            });
            $swipeWrap.css({
              width: maxWidth + 1,
              height: maxHeight + 2
            });
            $swipeBar.css({
              left: 0
            });

            wrapPadding = parseInt($swipeWrap.css('right').replace('px', ''), 10);

            _this.initDraggable($swipeBar, wrapPadding, function(e, left) {
              if (left > 0 && left < $swipeFrame.width() - (wrapPadding * 2)) {
                $swipeWrap.width((maxWidth + 1) - left);
                $swipeBar.css('left', left);
              }
            });
          };
        })(this));
      },
      'onion-skin': function() {
        var dragTrackWidth, maxHeight, maxWidth;
        maxWidth = 0;
        maxHeight = 0;
        dragTrackWidth = $('.drag-track', this.file).width() - $('.dragger', this.file).width();
        return $('.onion-skin.view', this.file).each((function(_this) {
          return function(index, view) {
            var $frame, $track, $dragger, $frameAdded, framePadding, ref, dragging = false;
            ref = prepareFrames(view), maxWidth = ref[0], maxHeight = ref[1];
            $frame = $('.onion-skin-frame', view);
            $frameAdded = $('.frame.added', view);
            $track = $('.drag-track', view);
            $dragger = $('.dragger', $track);

            $frame.css({
              width: maxWidth + 16,
              height: maxHeight + 28
            });
            $('.swipe-wrap', view).css({
              width: maxWidth + 1,
              height: maxHeight + 2
            });
            $dragger.css({
              left: dragTrackWidth
            });

            framePadding = parseInt($frameAdded.css('right').replace('px', ''), 10);

            _this.initDraggable($dragger, framePadding, function(e, left) {
              var opacity = left / dragTrackWidth;

              if (opacity >= 0 && opacity <= 1) {
                $dragger.css('left', left);
                $frameAdded.css('opacity', opacity);
              }
            });
          };
        })(this));
      }
    };

    ImageFile.prototype.requestImageInfo = function(img, callback) {
      var domImg;
      domImg = img.get(0);
      if (domImg) {
        if (domImg.complete) {
          return callback.call(this, domImg.naturalWidth, domImg.naturalHeight);
        } else {
          return img.on('load', (function(_this) {
            return function() {
              return callback.call(_this, domImg.naturalWidth, domImg.naturalHeight);
            };
          })(this));
        }
      }
    };

    return ImageFile;
  })();
}).call(window);
