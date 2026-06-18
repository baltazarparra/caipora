## Dicionário de strings pt-BR. Carregado por Lang autoload.
## NÃO instanciar diretamente — acessar via Lang.t() / Lang.tf().

const STRINGS: Dictionary = {
	# Options Panel
	&"options.title":           "OPÇÕES",
	&"options.close":           "Fechar",
	&"options.language":        "Idioma",
	&"options.touch":           "Controles Touch",
	&"options.touch.auto":      "Auto",
	&"options.touch.always":    "Sempre",
	&"options.touch.never":     "Nunca",
	&"options.reset":           "Apagar progresso",
	&"options.reset.confirm":   "Confirmar? Apaga tudo.",
	&"options.reset.done":      "Progresso apagado",
	&"options.audio.master":    "Geral",
	&"options.audio.sfx":       "Efeitos",
	&"options.audio.music":     "Música",
	&"options.audio.ambience":  "Ambiência",

	# Hub Shop
	&"hub.fragments":           "Fragmentos: %d",
	&"hub.track.furia":         "FÚRIA · dano",
	&"hub.track.cura":          "CURA · vida",
	&"hub.options.btn":         "Opções",
	&"hub.track.complete":      "trilha completa",
	&"hub.next.phase":          "próxima: %s — Fase %d",
	&"hub.next.fire":           "próxima: %s — na próxima fogueira",

	# Hub Card
	&"card.cost":               "%d fragmentos",
	&"card.cost.short":         "%d frag",
	&"card.effect.dmg":         "Dano +%d/hit (total %d)",
	&"card.effect.hp":          "+%d HP (total %d)",
	&"card.effect.dmg.short":   "+%d dano",
	&"card.effect.hp.short":    "+%d HP",

	# HUD
	&"hud.player":              "CAIPORA",
	&"hud.enemy":               "CRIATURA",
	&"hud.chama":               "CHAMA!",
	&"hud.herb":                "HP máx.",
	&"hud.fragment.s":          "+%s fragmento",
	&"hud.fragment.pl":         "+%s fragmentos",

	# End Screen
	&"end.hint.touch.won":      "Toque para inserir suas iniciais",
	&"end.hint.key.won":        "Espaço para inserir suas iniciais",
	&"end.hint.touch.lost":     "Toque para voltar ao menu",
	&"end.hint.key.lost":       "Espaço para voltar ao menu",
	&"win.title":               "A CRIATURA TOMBOU",
	&"gameover.title":          "... E desperta de outra premonição ...",

	# Ending Screen (canônico)
	&"ending.sky":              "a floresta segue respirando",
	&"ending.menu_btn":         "Menu Principal",

	# Ending Sacrifice Screen
	&"sacrifice.msg1":          "a caipora não respira mais",
	&"sacrifice.msg2":          "a floresta virou cristã",
	&"sacrifice.menu_btn":      "Menu Principal",

	# Final Choice Screen
	&"choice.question":         "Poupar ele?",
	&"choice.spare":            "SIM",
	&"choice.kill":             "NÃO",

	# Boss Intro Screen
	&"boss_intro.subtitle":     "— CHEFE —",

	# Main Menu
	&"menu.start":              "Iniciar",
	&"menu.quit":               "Sair",
	&"menu.update":             "⟳  Novo balanceamento — Atualizar",
	&"menu.podio":              "Pódio",

	# Initials Screen
	&"initials.title":          "PODIO",
	&"initials.sub":            "INSIRA SUAS INICIAIS",
	&"initials.confirm":        "CONFIRMAR",
	&"initials.skip":           "PULAR",
	&"initials.sending":        "ENVIANDO...",
	&"initials.saved":          "SALVO!",
	&"initials.error":          "ERRO AO SALVAR",

	# Dialogues — nomes próprios idênticos em ambas as línguas
	&"dialogue.caipora":        "CAIPORA",
	&"boss.mula.name":          "MULA SEM CABEÇA",
	&"boss.boitata.name":       "BOITATÁ",
	&"boss.curupira.name":      "CURUPIRA",
	&"boss.saci.name":          "SACI",
	&"boss.jesuita.name":       "JESUÍTA BANDEIRANTE CATEQUIZADOR",

	&"dlg.mula.1":              "Vim terminar o que comecei.",
	&"dlg.mula.2":              "...",
	&"dlg.boitata.1":           "Você nos traiu...",
	&"dlg.boitata.2":           "Vocês me abandonaram!",
	&"dlg.curupira.1":          "ninguém te deixou...",
	&"dlg.curupira.2":          "isso pouco importa agora",
	&"dlg.saci.1":              "Vou salvar nossa casa",
	&"dlg.saci.2":              "Não pertenço mais...",
	&"dlg.jesuita.intro.1":     "converti todos eles com espelhos e água benta. a floresta pertence ao vaticano.",
	&"dlg.jesuita.intro.2":     "teus santos viram húmus na minha mata.",

	# Cortejo dos Encantados — tela de unlock pós-boss
	&"cortejo.unlock.title":           "CORTEJO DOS ENCANTADOS",
	&"cortejo.unlock.subtitle.first":  "OBTIDO!",
	&"cortejo.unlock.subtitle.hit":    "GOLPE LIBERADO!",
	&"cortejo.unlock.desc.first":      "Às vezes, no seu turno: quando o anel fechar, TOQUE no tempo. Acertar = todos os espíritos libertados desabam de uma vez. Errar = contra-ataque.",
	&"cortejo.unlock.desc.hit":        "O Cortejo agora desaba %d espíritos de uma vez.",
	&"cortejo.unlock.hint":            "pressione para continuar",

	# Hub Manager — ritos de chegada
	&"rite.1":                  "a mula descansa. o fogo dela é teu agora.",
	&"rite.2":                  "a luz do boitatá ronda a clareira. nada atravessa.",
	&"rite.3":                  "o parente mais antigo vigia. a mata volta a crescer.",
	&"rite.4":                  "o vento entrou no acampamento. o saci fuma em silêncio.",
}
