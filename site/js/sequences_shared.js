// Catálogo + helpers compartilhados entre sequences.html (lista) e sequence.html
// (detalhe). Fonte única dos 24 padrões com os valores BAKED dos .tres como
// fallback — os valores reais vêm do servidor (get_attack_patterns).

const ENDPOINT = "https://mlykeulezzfwljriytuf.supabase.co/functions/v1/caipora-api";
const ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1seWtldWxlenpmd2xqcml5dHVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyNTIzMTksImV4cCI6MjA5NTgyODMxOX0.i9jQGbtQrxbcyR4M-XNZpwPYwJ_GcxrP-VE4Gniamqg";
const ADMIN_USER = "baltz";
const LS_KEY = "caipora_admin_hash";

// Default da janela de transição global (= COMBAT_LOADER_FINAL_HOLD no arena_manager).
const TRANSITION_DEFAULT = 0.50;

// Glyphs para cada direção de input.
const DIR_GLYPH = { ui_up: "↑", ui_down: "↓", ui_left: "←", ui_right: "→" };

// Catálogo fixo. cooldown_duration alimenta o default de next_turn_delay; is_special
// vem do .tres (RemotePatterns não sobrescreve is_special).
const PATTERNS = [
  { key:"assobio_pattern",              group:"Assombração", label:"Assombração — Assobio",          wind_up_duration:0.9,  attack_duration:0.45, strike_count:1, strike_delay:0.0,  cooldown_duration:2.5, damage_multiplier:3.0, is_special:false, input_sequence:[], display_name:"Assovio da Cova", audio_event:"mv_assovio_cova", vfx_id:"assovio_cova" },
  { key:"assombracao_pattern",          group:"Assombração", label:"Assombração — Duplo",            wind_up_duration:0.35, attack_duration:0.9,  strike_count:2, strike_delay:0.35, cooldown_duration:1.8, damage_multiplier:1.0, is_special:false, input_sequence:[], display_name:"Mãos do Além", audio_event:"mv_maos_alem", vfx_id:"maos_alem" },
  { key:"rastro_pattern",               group:"Assombração", label:"Assombração — Rastro",           wind_up_duration:0.5,  attack_duration:0.7,  strike_count:4, strike_delay:0.35, cooldown_duration:2.0, damage_multiplier:2.5, is_special:true,  input_sequence:["ui_right","ui_left","ui_right","ui_left"], display_name:"Procissão das Almas", audio_event:"mv_procissao_almas", vfx_id:"procissao_almas" },
  { key:"criatura_pattern",             group:"Criatura",    label:"Criatura — Base",                wind_up_duration:0.25, attack_duration:1.0,  strike_count:1, strike_delay:0.4,  cooldown_duration:2.0, damage_multiplier:1.0, is_special:false, input_sequence:[], display_name:"Dilacerar", audio_event:"mv_dilacerar", vfx_id:"dilacerar" },
  { key:"criatura_double_block_pattern",group:"Criatura",    label:"Criatura — Duplo Bloqueio",      wind_up_duration:0.25, attack_duration:0.85, strike_count:2, strike_delay:0.4,  cooldown_duration:2.0, damage_multiplier:1.0, is_special:false, input_sequence:[], display_name:"Mordida Dobrada", audio_event:"mv_mordida_dobrada", vfx_id:"mordida_dobrada" },
  { key:"boss_pattern",                 group:"Criatura",    label:"Criatura Boss — Triplo",         wind_up_duration:0.15, attack_duration:0.8,  strike_count:3, strike_delay:0.4,  cooldown_duration:1.5, damage_multiplier:1.0, is_special:false, input_sequence:[], display_name:"Fúria da Carniça", audio_event:"mv_furia_carnica", vfx_id:"furia_carnica" },
  { key:"boss_double_pattern",          group:"Criatura",    label:"Criatura Boss — Duplo",          wind_up_duration:0.35, attack_duration:0.8,  strike_count:2, strike_delay:0.3,  cooldown_duration:1.2, damage_multiplier:1.0, is_special:false, input_sequence:[], display_name:"Investida", audio_event:"mv_investida", vfx_id:"investida" },
  { key:"boss_double_block_pattern",    group:"Criatura",    label:"Criatura Boss — Duplo Bloqueio", wind_up_duration:0.2,  attack_duration:1.05, strike_count:2, strike_delay:0.3,  cooldown_duration:1.5, damage_multiplier:1.0, is_special:false, input_sequence:[], display_name:"Esmaga-Ossos", audio_event:"mv_esmaga_ossos", vfx_id:"esmaga_ossos" },
  { key:"boss_special_pattern",         group:"Criatura",    label:"Criatura Boss — Especial",       wind_up_duration:0.5,  attack_duration:1.0,  strike_count:4, strike_delay:0.5,  cooldown_duration:2.0, damage_multiplier:2.0, is_special:true,  input_sequence:["ui_right","ui_left","ui_right","ui_left"], display_name:"Frenesi", audio_event:"mv_frenesi", vfx_id:"frenesi" },
  { key:"mula_galope_pattern",          group:"Mula",        label:"Mula — Galope",                  wind_up_duration:0.4,  attack_duration:0.85, strike_count:2, strike_delay:0.5,  cooldown_duration:2.0, damage_multiplier:1.5, is_special:false, input_sequence:[], display_name:"Galope sem Cabeça", audio_event:"mv_galope_sem_cabeca", vfx_id:"galope_sem_cabeca" },
  { key:"mula_cabecada_pattern",        group:"Mula",        label:"Mula — Cabeçada",                wind_up_duration:0.5,  attack_duration:0.85, strike_count:2, strike_delay:0.45, cooldown_duration:2.0, damage_multiplier:1.5, is_special:true,  input_sequence:["ui_down","ui_up"], display_name:"Coice em Brasa", audio_event:"mv_coice_brasa", vfx_id:"coice_brasa" },
  { key:"boitata_chama_pattern",        group:"Boitatá",     label:"Boitatá — Chama",                wind_up_duration:0.2,  attack_duration:1.0,  strike_count:1, strike_delay:0.0,  cooldown_duration:1.8, damage_multiplier:1.0, is_special:false, input_sequence:[], display_name:"Brasa Rasteira", audio_event:"mv_brasa_rasteira", vfx_id:"brasa_rasteira" },
  { key:"boitata_labareda_pattern",     group:"Boitatá",     label:"Boitatá — Labareda",             wind_up_duration:0.4,  attack_duration:0.85, strike_count:2, strike_delay:0.4,  cooldown_duration:2.0, damage_multiplier:1.5, is_special:true,  input_sequence:["ui_down","ui_up"], display_name:"Labareda Viva", audio_event:"mv_labareda_viva", vfx_id:"labareda_viva" },
  { key:"boitata_chama_falsa_pattern",  group:"Boitatá",     label:"Boitatá — Chama Falsa",          wind_up_duration:0.5,  attack_duration:0.75, strike_count:3, strike_delay:0.4,  cooldown_duration:2.0, damage_multiplier:2.0, is_special:true,  input_sequence:["ui_up","ui_up","ui_down"], display_name:"Fogo-Fátuo", audio_event:"mv_fogo_fatuo", vfx_id:"fogo_fatuo" },
  { key:"boitata_white_special_pattern",group:"Boitatá",     label:"Boitatá — Especial White",       wind_up_duration:0.5,  attack_duration:0.75, strike_count:4, strike_delay:0.35, cooldown_duration:2.0, damage_multiplier:3.0, is_special:true,  input_sequence:["ui_up","ui_up","ui_down","ui_down"], display_name:"Cobra-de-Fogo", audio_event:"mv_cobra_fogo", vfx_id:"cobra_fogo" },
  { key:"curupira_mata_pattern",        group:"Curupira",    label:"Curupira — Mata",                wind_up_duration:0.35, attack_duration:0.85, strike_count:2, strike_delay:0.4,  cooldown_duration:2.0, damage_multiplier:1.5, is_special:true,  input_sequence:["ui_up","ui_right"], display_name:"Pé-Virado", audio_event:"mv_pe_virado", vfx_id:"pe_virado" },
  { key:"curupira_trilha_pattern",      group:"Curupira",    label:"Curupira — Trilha",              wind_up_duration:0.5,  attack_duration:0.75, strike_count:3, strike_delay:0.4,  cooldown_duration:2.0, damage_multiplier:2.0, is_special:true,  input_sequence:["ui_left","ui_up","ui_right"], display_name:"Trilha Falsa", audio_event:"mv_trilha_falsa", vfx_id:"trilha_falsa" },
  { key:"saci_assovio_pattern",         group:"Saci",        label:"Saci — Assobio",                 wind_up_duration:0.85, attack_duration:0.4,  strike_count:1, strike_delay:0.0,  cooldown_duration:2.5, damage_multiplier:2.5, is_special:false, input_sequence:[], display_name:"Assovio do Mato", audio_event:"mv_assovio_mato", vfx_id:"assovio_mato" },
  { key:"saci_pula_pattern",            group:"Saci",        label:"Saci — Pula",                    wind_up_duration:0.4,  attack_duration:0.75, strike_count:3, strike_delay:0.3,  cooldown_duration:2.0, damage_multiplier:2.0, is_special:true,  input_sequence:["ui_up","ui_down","ui_up"], display_name:"Redemoinho", audio_event:"mv_redemoinho", vfx_id:"redemoinho" },
  { key:"saci_pirulito_pattern",        group:"Saci",        label:"Saci — Pirulito",                wind_up_duration:0.5,  attack_duration:0.65, strike_count:4, strike_delay:0.3,  cooldown_duration:2.0, damage_multiplier:3.0, is_special:true,  input_sequence:["ui_up","ui_right","ui_down","ui_left"], display_name:"Travessura", audio_event:"mv_travessura", vfx_id:"travessura" },
  { key:"saci_rastro_pattern",          group:"Saci",        label:"Saci — Rastro",                  wind_up_duration:0.5,  attack_duration:0.65, strike_count:4, strike_delay:0.25, cooldown_duration:2.0, damage_multiplier:2.5, is_special:true,  input_sequence:["ui_right","ui_left","ui_right","ui_left"], display_name:"Ventania", audio_event:"mv_ventania", vfx_id:"ventania" },
  { key:"jesuita_cruz_pattern",         group:"Jesuíta",     label:"Jesuíta — Cruz",                 wind_up_duration:0.35, attack_duration:0.7,  strike_count:3, strike_delay:0.3,  cooldown_duration:2.0, damage_multiplier:2.5, is_special:true,  input_sequence:["ui_up","ui_down","ui_right"], display_name:"Catequese", audio_event:"mv_catequese", vfx_id:"catequese" },
  { key:"jesuita_espada_pattern",       group:"Jesuíta",     label:"Jesuíta — Espada",               wind_up_duration:0.4,  attack_duration:0.65, strike_count:4, strike_delay:0.25, cooldown_duration:2.0, damage_multiplier:3.5, is_special:true,  input_sequence:["ui_up","ui_right","ui_down","ui_right"], display_name:"Espada da Fé", audio_event:"mv_espada_fe", vfx_id:"espada_fe" },
  { key:"cacador_special_pattern",      group:"Caçador",     label:"Caçador — Especial",             wind_up_duration:0.4,  attack_duration:0.85, strike_count:2, strike_delay:0.45, cooldown_duration:2.0, damage_multiplier:1.5, is_special:true,  input_sequence:["ui_down","ui_up"], display_name:"Emboscada", audio_event:"mv_emboscada", vfx_id:"emboscada" },
];

// Janela de reação por fase (espelha Constants.timing_window_for_phase):
// max(attack_duration - reduction[phase], TIMING_WINDOW_MIN) + TOUCH_BONUS.
const PHASE_REDUCTION = { 1:0, 2:0.1, 3:0.15, 4:0.3, 5:0.3 };
const TIMING_WINDOW_MIN = 0.2;
const TOUCH_BONUS = 0.2;
const PHASES = [1, 2, 3, 4, 5];

function reactionWindow(attackDuration, phase) {
  return +(Math.max(attackDuration - (PHASE_REDUCTION[phase] || 0), TIMING_WINDOW_MIN) + TOUCH_BONUS).toFixed(2);
}
function defaultActionWindows(attackDuration) {
  const out = {};
  for (const p of PHASES) out[String(p)] = reactionWindow(attackDuration, p);
  return out;
}

function num(v, d) { const n = Number(v); return Number.isFinite(n) ? n : d; }
function intOr(v, d) { const n = Math.round(Number(v)); return Number.isFinite(n) ? n : d; }
function patternByKey(key) { return PATTERNS.find((p) => p.key === key) || null; }

// Ajusta o array de intervalos para ter exatamente `len` itens, preservando os
// existentes e preenchendo os novos com `fill`.
function fitIntervals(arr, len, fill) {
  const out = (arr || []).slice(0, Math.max(0, len));
  while (out.length < len) out.push(fill);
  return out.map((x) => num(x, fill));
}

// Funde o valor do servidor (sv) sobre o default baked do catálogo (p),
// resolvendo TODOS os campos do modelo novo.
function resolveEntry(p, sv) {
  sv = sv || {};
  const attack_duration = num(sv.attack_duration, p.attack_duration);
  const strike_count = Math.max(1, intOr(sv.strike_count, p.strike_count));
  const strike_delay = num(sv.strike_delay, p.strike_delay);
  const action_windows = (sv.action_windows && typeof sv.action_windows === "object")
    ? Object.assign(defaultActionWindows(attack_duration), sv.action_windows)
    : defaultActionWindows(attack_duration);
  const strike_intervals = fitIntervals(
    Array.isArray(sv.strike_intervals) ? sv.strike_intervals : null,
    strike_count - 1,
    strike_delay
  );
  return {
    key: p.key,
    group: p.group,
    is_special: p.is_special,
    label: (sv.label || p.label),
    // Identidade do golpe (PRD moves nomeados): nome e som sobreponíveis pelo servidor;
    // vfx_id é baked (não entra no override remoto).
    display_name: (sv.display_name || p.display_name || ""),
    audio_event: (sv.audio_event || p.audio_event || ""),
    vfx_id: (p.vfx_id || ""),
    wind_up_duration: num(sv.wind_up_duration, p.wind_up_duration),
    attack_duration,
    strike_count,
    strike_delay,
    strike_intervals,
    next_turn_delay: num(sv.next_turn_delay, p.cooldown_duration),
    damage_multiplier: num(sv.damage_multiplier, p.damage_multiplier),
    input_sequence: Array.isArray(sv.input_sequence) ? sv.input_sequence.slice() : p.input_sequence.slice(),
    action_windows,
  };
}

async function sha256hex(s) {
  const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

async function api(action, extra) {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + ANON, "apikey": ANON },
    body: JSON.stringify(Object.assign({ action }, extra || {})),
  });
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, data };
}
