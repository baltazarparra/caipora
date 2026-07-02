/**
 * Caipora Landing Page — Interactions
 * Native JS. Zero frameworks.
 */
(function () {
  'use strict';

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ----------------------------------------------------------
  // Embers
  // ----------------------------------------------------------
  const embersContainer = document.querySelector('.embers');

  function spawnEmber() {
    if (!embersContainer || prefersReducedMotion) return;
    const ember = document.createElement('span');
    ember.className = 'ember';
    ember.style.left = Math.random() * 100 + 'vw';
    ember.style.animationDuration = (4 + Math.random() * 6) + 's';
    ember.style.setProperty('--drift', (Math.random() * 40 - 20) + 'px');
    const size = 2 + Math.random() * 3;
    ember.style.width = size + 'px';
    ember.style.height = size + 'px';
    ember.style.opacity = 0.5 + Math.random() * 0.5;
    embersContainer.appendChild(ember);

    ember.addEventListener('animationend', function () {
      ember.remove();
    });
  }

  if (embersContainer && !prefersReducedMotion) {
    // Spawn initial batch
    for (let i = 0; i < 18; i++) {
      setTimeout(spawnEmber, Math.random() * 3000);
    }
    // Keep spawning
    setInterval(spawnEmber, 350);
  }

  // ----------------------------------------------------------
  // Hero — Caipora idle viva (espelha caipora.gd): 5 quadros a
  // 5fps em loop eterno; a cada 3–6,5s os olhos apagam (2 quadros
  // "dim" a 12fps) e reacendem. A tira tem 7 células; sem JS ou
  // com reduced-motion fica o 1º quadro (pose canônica).
  // ----------------------------------------------------------
  const heroSprite = document.querySelector('.hero-caipora-sprite');

  if (heroSprite && !prefersReducedMotion) {
    const IDLE_FRAMES = 5;
    const LAST_FRAME = 6; // índice da última célula da tira
    const IDLE_MS = 1000 / 5;
    const BLINK_MS = 1000 / 12;
    const BLINK_MIN_MS = 3000;
    const BLINK_MAX_MS = 6500;

    let idleFrame = 0;
    let blinkAt = 0;

    function showFrame(idx) {
      heroSprite.style.backgroundPositionX = (idx / LAST_FRAME) * 100 + '%';
    }

    function scheduleBlink() {
      blinkAt = Date.now() + BLINK_MIN_MS + Math.random() * (BLINK_MAX_MS - BLINK_MIN_MS);
    }

    function playIdle() {
      if (Date.now() >= blinkAt) {
        playBlink();
        return;
      }
      showFrame(idleFrame);
      idleFrame = (idleFrame + 1) % IDLE_FRAMES;
      setTimeout(playIdle, IDLE_MS);
    }

    function playBlink() {
      showFrame(5);
      setTimeout(function () {
        showFrame(6);
        setTimeout(function () {
          scheduleBlink();
          playIdle();
        }, BLINK_MS);
      }, BLINK_MS);
    }

    scheduleBlink();
    playIdle();
  }

  // ----------------------------------------------------------
  // Nav glassmorphism on scroll
  // ----------------------------------------------------------
  const nav = document.getElementById('nav');
  let navScrolled = false;

  function updateNav() {
    const scrolled = window.scrollY > 20;
    if (scrolled !== navScrolled) {
      nav.classList.toggle('is-scrolled', scrolled);
      navScrolled = scrolled;
    }
  }

  let ticking = false;
  window.addEventListener('scroll', function () {
    if (!ticking) {
      window.requestAnimationFrame(function () {
        updateNav();
        ticking = false;
      });
      ticking = true;
    }
  }, { passive: true });

  updateNav();

  // ----------------------------------------------------------
  // Scroll-reveal via IntersectionObserver
  // ----------------------------------------------------------
  const revealElements = document.querySelectorAll('.section-reveal');

  if ('IntersectionObserver' in window) {
    const revealObserver = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            revealObserver.unobserve(entry.target);
          }
        });
      },
      {
        root: null,
        rootMargin: '0px 0px -60px 0px',
        threshold: 0.1,
      }
    );

    revealElements.forEach(function (el) {
      revealObserver.observe(el);
    });
  } else {
    revealElements.forEach(function (el) {
      el.classList.add('is-visible');
    });
  }

  // ----------------------------------------------------------
  // Smooth scroll for anchor links
  // ----------------------------------------------------------
  document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
    anchor.addEventListener('click', function (e) {
      const targetId = this.getAttribute('href');
      if (targetId === '#') return;
      const target = document.querySelector(targetId);
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  // ----------------------------------------------------------
  // Boss cards: swap idle -> windup on hover/focus
  // ----------------------------------------------------------
  const bossCards = document.querySelectorAll('.boss-card');

  bossCards.forEach(function (card) {
    const frame = card.querySelector('.boss-card-frame');
    const idle = card.querySelector('.boss-idle');
    const windup = card.querySelector('.boss-windup');

    if (!idle || !windup) return;

    function showWindup() {
      idle.style.opacity = '0';
      idle.style.transform = 'scale(0.95)';
      windup.style.opacity = '1';
      windup.style.transform = 'scale(1)';
    }

    function showIdle() {
      idle.style.opacity = '1';
      idle.style.transform = 'scale(1)';
      windup.style.opacity = '0';
      windup.style.transform = 'scale(1.05)';
    }

    frame.addEventListener('mouseenter', showWindup);
    frame.addEventListener('mouseleave', showIdle);
    frame.addEventListener('focusin', showWindup);
    frame.addEventListener('focusout', showIdle);
    frame.setAttribute('tabindex', '0');
  });

  // ----------------------------------------------------------
  // Clips — sprite-strip player (gameplay real capturado do jogo)
  // Lê assets/clips/clips.json e configura cada [data-clip]:
  //  --frames / aspect-ratio na hora; a imagem (pesada) só entra quando
  //  o elemento chega perto da viewport (lazy load).
  // ----------------------------------------------------------
  const clipEls = document.querySelectorAll('[data-clip]');

  if (clipEls.length) {
    fetch('./assets/clips/clips.json')
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (manifest) {
        if (!manifest) return;

        const pending = [];
        clipEls.forEach(function (el) {
          const meta = manifest[el.dataset.clip];
          if (!meta) return;
          el.style.setProperty('--frames', meta.frames);
          el.style.setProperty('--cell-w', meta.cell_w);
          el.style.setProperty('--cell-h', meta.cell_h);
          el.dataset.clipSrc = 'assets/clips/' + meta.file;
          pending.push(el);
        });

        function applySrc(el) {
          // background-image inline (no elemento), NÃO via custom property:
          // url() dentro de var() resolve relativo ao .css (/css/), quebrando o
          // caminho. Inline no elemento resolve relativo ao documento (e ao
          // subpath do GitHub Pages).
          el.style.backgroundImage = "url('" + el.dataset.clipSrc + "')";
        }

        // Clipes próximos da viewport carregam JÁ (não dependem do IO disparar);
        // o resto fica lazy. Strips repetidos (ex. combat) compartilham 1 download.
        function isNear(el) {
          const r = el.getBoundingClientRect();
          return r.top < window.innerHeight * 1.5;
        }

        if ('IntersectionObserver' in window) {
          const clipObserver = new IntersectionObserver(
            function (entries) {
              entries.forEach(function (entry) {
                if (entry.isIntersecting) {
                  applySrc(entry.target);
                  clipObserver.unobserve(entry.target);
                }
              });
            },
            { root: null, rootMargin: '300px 0px', threshold: 0 }
          );
          pending.forEach(function (el) {
            if (isNear(el)) applySrc(el);
            else clipObserver.observe(el);
          });
        } else {
          pending.forEach(applySrc);
        }
      })
      .catch(function () { /* sem clips: cai no fundo escuro da moldura */ });
  }

  // ----------------------------------------------------------
  // Scroll-scrub: a ROLAGEM controla o quadro do clipe.
  // Progresso pela trilha alta (.scrollscene, ~250vh) -> índice de
  // quadro -> background-position-x. Rolar p/ baixo avança 0→100%,
  // p/ cima reverte; velocidade/direção seguem o scroll (frame-accurate,
  // sem o jank de <video>.currentTime no mobile).
  // ----------------------------------------------------------
  const scrubEls = document.querySelectorAll('[data-scrub]');

  if (scrubEls.length && !prefersReducedMotion) {
    let scrubTicking = false;

    function paintScrub() {
      scrubTicking = false;
      scrubEls.forEach(function (el) {
        const sec = el.closest('.scrollscene');
        if (!sec) return;
        const range = sec.offsetHeight - window.innerHeight; // px de scrub
        const progressed = Math.min(Math.max(-sec.getBoundingClientRect().top, 0), range);
        const p = range > 0 ? progressed / range : 0;
        const frames = parseInt(getComputedStyle(el).getPropertyValue('--frames'), 10) || 26;
        const idx = Math.min(frames - 1, Math.floor(p * frames));
        el.style.backgroundPositionX = frames > 1 ? (idx / (frames - 1)) * 100 + '%' : '0%';
      });
    }

    function onScrub() {
      if (!scrubTicking) {
        scrubTicking = true;
        requestAnimationFrame(paintScrub);
      }
    }

    window.addEventListener('scroll', onScrub, { passive: true });
    window.addEventListener('resize', onScrub);
    paintScrub(); // estado inicial
  }

  // ----------------------------------------------------------
  // Hero parallax (mouse)
  // ----------------------------------------------------------
  const heroBackdrop = document.querySelector('.hero-backdrop');

  if (heroBackdrop && !prefersReducedMotion && !window.matchMedia('(pointer: coarse)').matches) {
    const layers = heroBackdrop.querySelectorAll('.hero-boss');

    document.querySelector('.hero').addEventListener('mousemove', function (e) {
      const cx = window.innerWidth / 2;
      const cy = window.innerHeight / 2;
      const dx = (e.clientX - cx) / cx;
      const dy = (e.clientY - cy) / cy;

      layers.forEach(function (layer) {
        const factor = parseFloat(layer.dataset.parallax) || 0.05;
        const x = dx * factor * -40;
        const y = dy * factor * -30;
        layer.style.transform = 'translate(' + x + 'px, ' + y + 'px)';
      });
    });
  }
})();
