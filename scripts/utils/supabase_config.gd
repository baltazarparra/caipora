class_name SupabaseConfig
extends RefCounted

## Config do backend caipora (Supabase Edge Function `caipora-api`). A anon key é
## pública por design — o schema `caipora` é oculto da Data API, então a chave no
## bundle web não dá acesso às tabelas (tudo passa pela Edge Function validada).
## Primeiro ponto de rede do jogo; reusado por futuros leaderboard/cloud save.

const URL := "https://mlykeulezzfwljriytuf.supabase.co"
const ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1seWtldWxlenpmd2xqcml5dHVmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyNTIzMTksImV4cCI6MjA5NTgyODMxOX0.i9jQGbtQrxbcyR4M-XNZpwPYwJ_GcxrP-VE4Gniamqg"
const API_PATH := "/functions/v1/caipora-api"

static func endpoint() -> String:
	return URL + API_PATH

## Headers para POST autenticado (verify_jwt exige o anon JWT em Authorization + apikey).
static func headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + ANON_KEY,
		"apikey: " + ANON_KEY,
	])
