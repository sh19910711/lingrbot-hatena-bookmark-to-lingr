var CSRF_TOKEN = '';
var FLAG_LOGIN_OK = false;
var PJAX_CONTAINER_ID = '#container';

function notificate(message) {
  $('#notifications').prepend(function() {
    var element = $('<div></div>');
    element.addClass('notification').css({opacity: 0}).animate({
      opacity: 1
    }, {
      duration: 250 
    });
    element.html(message);
    setTimeout(function() {
      element.animate({
        opacity: 0
      }, {
        duration: 250,
        complete: function() {
          element.remove();
        }
      });
    }, 2000);
    return element;
  });
}

function post_request(url, params) {
  var data = {
    "csrf_token": CSRF_TOKEN
  };
  $.extend(data, params);
  return $.ajax({
    type: 'POST',
    url: url,
    data: data
  });
}

function show_with_pjax(path) {
  notificate("ページを切り替えています...<br>Path: " + path);
  $.pjax({
    url: path,
    container: PJAX_CONTAINER_ID
  }).done(function() {
    notificate("ページを表示しました！<br>Path: " + path);
    check_event(path);
  });
}

function check_event(path) {
  if ( path == "/page/user_hatena_bookmark_settings" ) {
    post_request('/api/get_user_bookmark_tags').done(function(res) {
      set_bookmark_tags(JSON.parse(res));
      post_request('/api/get_user_watching_tags').done(function(res) {
        set_watching_tags(JSON.parse(res));
      })
    });
  }
}

$.fn.extend({
  enable_tag_button: function() {
    $(this)
      .removeClass('btn-success')
      .addClass('btn-primary');
    $(this).data('post-req-target', '/api/set_user_watching_tag');
    $(this).data('action-ok', 'set_user_watching_tag_ok');
  },
  disable_tag_button: function() {
    $(this)
      .removeClass('btn-primary')
      .addClass('btn-success');
    $(this).data('post-req-target', '/api/reset_user_watching_tag');
    $(this).data('action-ok', 'reset_user_watching_tag_ok');
  }
});

function set_bookmark_tags(tags) {
  var container = $('div#hatena_bookmark_tags');
  container.empty();
  (function loop() {
    if ( tags.length > 0 ) {
      for ( var i = 0; i < 100 && tags.length > 0; ++ i ) {
        var tag_info = tags.shift();
        container.append(function() {
          return '<button class="btn-tag btn btn-primary btn-xs"'
          + ' data-tag="' + tag_info.tag + '"'
          + ' data-action-ok="set_user_watching_tag_ok"'
          + ' data-post-req-target="/api/set_user_watching_tag"'
          + ' data-params=\'' + JSON.stringify({tag: tag_info.tag}) + '\''
          + '>'
          + tag_info.tag
          + '</button>'
        });
      }
      setTimeout(loop, 0);
    }
  }).call(this);
}

function set_watching_tags(tags) {
  tags.forEach(function(tag) {
    $('button[data-tag="' + tag + '"]').disable_tag_button();
  });
}

function show_not_login_menu() {
  $.pjax({
    url: '/page/not_login_menu',
    container: PJAX_CONTAINER_ID
  });
}

function show_hatena_bookmark_settings() {
  $.pjax({
    url: '/page/user_hatena_bookmark_settings',
    container: PJAX_CONTAINER_ID
  });
}

// ログアウト
function do_logout() {
  $.ajax({
    type: 'POST',
    url: '/logout',
    data: {
      "csrf_token": CSRF_TOKEN
    }
  }).done(function() {
    show_with_pjax('/page/not_login_menu');
  }).fail(function() {
    // TODO: ログイン失敗
  });
}

// はてなアカウントでログイン
function do_hatena_oauth_login() {
  $.ajaxSubmit({
    type: 'POST',
    url: '/hatena_oauth_login',
    data: {
      "csrf_token": CSRF_TOKEN
    }
  }).done(function() {
    show_with_pjax('/page/login_menu');
  }).fail(function() {
    // TODO: ログイン失敗
  });
}

//
// イベント関連
//
$(function() {
  CSRF_TOKEN = $('meta[csrf_token]').attr('csrf_token');
  FLAG_LOGIN_OK = $('meta[flag_login_ok]').attr('flag_login_ok') == 'true' ? true : false;

  if ( location.pathname != '/' ) {
    if ( FLAG_LOGIN_OK ) {
      show_with_pjax(location.pathname);
    } else {
      show_with_pjax('/page/not_login_menu');
    }
  } else {
    if ( FLAG_LOGIN_OK ) {
      show_with_pjax('/page/login_menu');
    } else {
      show_with_pjax('/page/not_login_menu');
    }
  }
});

$(document).on('click', 'button[data-show-with-pjax]', function() {
  var show_id = $(this).data('show-with-pjax');
  show_with_pjax('/page/' + show_id);
});

$(document).on('click', 'button[data-post-req-target]', function() {
  var path = $(this).data('post-req-target');
  var data = {
    csrf_token: CSRF_TOKEN
  };
  if ( $(this).data('params') ) {
    data = $.extend(data, $(this).data('params'));
  }
  notificate("リクエストを送信中です...<br>Path: " + path);
  var deferred = $.ajax({
    type: 'post',
    url: path,
    data: data
  });
  var action_ok_name = $(this).data('action-ok');
  deferred.done(function() {
    notificate("リクエストの実行に成功しました！<br>Path: " + path);
    if ( action_ok_name && typeof actions[action_ok_name] == 'function' ) {
      actions[action_ok_name].call(this);
    }
  }.bind(this));
  var action_ng_name = $(this).data('action-ng');
  deferred.fail(function() {
    notificate("リクエストの実行に失敗しました...<br>Path: " + path);
    if ( action_ng_name && typeof actions[action_ng_name] == 'function' ) {
      actions[action_ng_name].call(this);
    }
  }.bind(this));
});

$(document).on('click', 'button#logout', do_logout);
$(document).on('click', 'button#hatena_oauth_login', do_hatena_oauth_login);

//
// アクション [contextはイベントを発生させたタグにすること]
//
var actions = {};

$.extend(actions, {
  "update_bookmark_tags_ok": function(body) {
    notificate("タグ一覧を更新しました");
    var tags = JSON.parse(body);
    set_bookmark_tags(tags);
  }
});

$.extend(actions, {
  "set_user_watching_tag_ok": function() {
    $(this).disable_tag_button();
  }
});

$.extend(actions, {
  "reset_user_watching_tag_ok": function() {
    $(this).enable_tag_button();
  }
});

$.fn.extend({
  "disable_watching_button": function() {
    $(this)
      .removeClass('btn-success')
      .addClass('btn-danger')
      .data('action-ok', 'disable_watching_ok')
      .data('post-req-target', '/api/disable_watching')
      .text('監視設定を無効にする');
  },
  "enable_watching_button": function() {
    $(this)
      .removeClass('btn-danger')
      .addClass('btn-success')
      .data('action-ok', 'enable_watching_ok')
      .data('post-req-target', '/api/enable_watching')
      .text('監視設定を有効にする');
  }
});

$.extend(actions, {
  "enable_watching_ok": function() {
    $(this).disable_watching_button();;
  }
});

$.extend(actions, {
  "disable_watching_ok": function() {
    $(this).enable_watching_button();;
  }
});

