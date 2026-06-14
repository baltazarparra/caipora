(function () {
  'use strict';

  var STORAGE_KEY = 'caipora_lang';
  var _current = 'pt';
  var _dict = {};

  function _fetch(lang, cb) {
    var url = './js/i18n/' + lang + '.json';
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);
    xhr.responseType = 'json';
    xhr.onload = function () {
      if (xhr.status === 200 && xhr.response) {
        _dict = xhr.response;
        if (cb) cb();
      }
    };
    xhr.send();
  }

  function _apply() {
    document.documentElement.lang = _current === 'en' ? 'en-US' : 'pt-BR';

    if (_dict['meta.title']) {
      document.title = _dict['meta.title'];
    }
    var metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc && _dict['meta.description']) {
      metaDesc.setAttribute('content', _dict['meta.description']);
    }

    var nodes = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var key = el.getAttribute('data-i18n');
      if (_dict[key] !== undefined) {
        el.textContent = _dict[key];
      }
    }

    var toggle = document.getElementById('lang-toggle');
    if (toggle && _dict['lang.toggle'] !== undefined) {
      toggle.textContent = _dict['lang.toggle'];
      toggle.setAttribute('aria-label', _current === 'en' ? 'Mudar para Português' : 'Switch to English');
      toggle.setAttribute('lang', _current === 'en' ? 'pt-BR' : 'en-US');
    }
  }

  function setLang(lang) {
    if (lang !== 'en' && lang !== 'pt') return;
    if (lang === _current) return;
    localStorage.setItem(STORAGE_KEY, lang);
    if (lang === 'pt') {
      location.reload();
      return;
    }
    _fetch('en', function () {
      _current = 'en';
      _apply();
    });
  }

  function current() {
    return _current;
  }

  function init() {
    var saved = localStorage.getItem(STORAGE_KEY);
    if (saved === 'en') {
      _current = 'en';
      _fetch('en', _apply);
    } else {
      _current = 'pt';
      _fetch('pt', function () {
        var toggle = document.getElementById('lang-toggle');
        if (toggle && _dict['lang.toggle'] !== undefined) {
          toggle.textContent = _dict['lang.toggle'];
        }
      });
    }
  }

  window.CaiporaI18n = { init: init, setLang: setLang, current: current };
})();
