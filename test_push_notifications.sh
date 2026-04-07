#!/usr/bin/env bash
# ============================================================
#  test_push_notifications.sh
#  Simule toutes les actions qui déclenchent des notifications push.
#
#  Usage avec tokens :
#    TOKEN_A="..." TOKEN_B="..." USER_A_ID=1 USER_B_ID=48 \
#    USER_A_LOGIN="calyps" ./test_push_notifications.sh
#
#  Usage avec login/mdp :
#    USER_A_LOGIN="calyps" USER_A_PASS="mdp" \
#    USER_B_LOGIN="alber" USER_B_PASS="mdp" \
#    ./test_push_notifications.sh
# ============================================================

BASE_URL="${BASE_URL:-https://api.militant.revlibertaire.com}"
API="$BASE_URL/v1"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN} $1${NC}"; }
fail() { echo -e "  ${RED} $1${NC}"; }
info() { echo -e "  ${BLUE}ℹ  $1${NC}"; }
sep()  { echo -e "\n${BOLD}══════════════════════════════════════════${NC}"; }

call() {
  local method="$1" endpoint="$2" token="$3" body="${4:-}"
  local auth=(); [[ -n "$token" ]] && auth=(-H "Authorization: Bearer $token")
  local data=(); [[ -n "$body" ]] && data=(-d "$body" -H "Content-Type: application/json")
  curl -s -X "$method" "$API$endpoint" "${auth[@]}" "${data[@]}" -H "Accept: application/json" --max-time 15
}

field() { echo "$1" | python3 -c "import sys,json; d=json.load(sys.stdin); print($2)" 2>/dev/null || true; }

sep
echo -e "${BOLD} Authentification${NC}"

# ── Si tokens fournis directement ──────────────────────────
TOKEN_A="${TOKEN_A:-}"
TOKEN_B="${TOKEN_B:-}"
USER_A_ID="${USER_A_ID:-}"
USER_B_ID="${USER_B_ID:-}"
USER_A_LOGIN="${USER_A_LOGIN:-}"

if [[ -n "$TOKEN_A" && -n "$TOKEN_B" ]]; then
  ok "Tokens fournis directement — login ignoré"
  # Récupérer les IDs si pas fournis
  if [[ -z "$USER_A_ID" ]]; then
    resp=$(call GET "/users.php" "$TOKEN_A"); USER_A_ID=$(field "$resp" "d.get('id','')")
  fi
  if [[ -z "$USER_B_ID" ]]; then
    resp=$(call GET "/users.php" "$TOKEN_B"); USER_B_ID=$(field "$resp" "d.get('id','')")
  fi
  if [[ -z "$USER_A_LOGIN" ]]; then
    resp=$(call GET "/users.php" "$TOKEN_A"); USER_A_LOGIN=$(field "$resp" "d.get('username','')")
  fi
  USER_B_LOGIN="${USER_B_LOGIN:-$(field "$(call GET '/users.php' "$TOKEN_B")" "d.get('username','alber')")}"
else
  # ── Login interactif ────────────────────────────────────
  [[ -z "${USER_A_LOGIN:-}" ]] && { read -rp "Compte A login : " USER_A_LOGIN; }
  [[ -z "${USER_A_PASS:-}" ]]  && { read -rsp "Compte A mdp : " USER_A_PASS; echo ""; }
  [[ -z "${USER_B_LOGIN:-}" ]] && { read -rp "Compte B login : " USER_B_LOGIN; }
  [[ -z "${USER_B_PASS:-}" ]]  && { read -rsp "Compte B mdp : " USER_B_PASS; echo ""; }

  resp=$(call POST "/auth.php?action=login" "" "{\"username\":\"$USER_A_LOGIN\",\"password\":\"$USER_A_PASS\"}")
  TOKEN_A=$(field "$resp" "d.get('token','')")
  USER_A_ID=$(field "$resp" "str(d.get('user_id',''))")
  [[ -z "$TOKEN_A" ]] && { fail "Login A échoué: $resp"; exit 1; }

  resp=$(call POST "/auth.php?action=login" "" "{\"username\":\"$USER_B_LOGIN\",\"password\":\"$USER_B_PASS\"}")
  TOKEN_B=$(field "$resp" "d.get('token','')")
  USER_B_ID=$(field "$resp" "str(d.get('user_id',''))")
  [[ -z "$TOKEN_B" ]] && { fail "Login B échoué: $resp"; exit 1; }
fi

ok "Compte A : $USER_A_LOGIN (ID=$USER_A_ID)"
ok "Compte B : $USER_B_LOGIN (ID=$USER_B_ID)"
sleep 1

# ── Test 1 : Push système ──────────────────────────────────
sep; echo -e "${BOLD} Test 1 — Push système (OneSignal direct)${NC}"
resp=$(call POST "/notifications.php?action=test" "$TOKEN_A" '{}')
push_ok=$(field "$resp" "d.get('push_ok',False)")
notif_id=$(field "$resp" "d.get('notification_id','?')")
[[ "$push_ok" == "True" ]] && ok "Push envoyé ! (id=$notif_id)" || { fail "Push échoué"; echo "  $resp"; }
sleep 2

# ── Test 2 : Message privé ─────────────────────────────────
sep; echo -e "${BOLD} Test 2 — Message privé${NC}"
resp=$(call POST "/messages.php" "$TOKEN_B" "{\"recipient_id\":$USER_A_ID,\"content\":\"🧪 Test push message – $(date +%H:%M:%S)\"}")
msg_id=$(field "$resp" "d.get('id','?')")
[[ -n "$msg_id" && "$msg_id" != "?" ]] && ok "Message envoyé (id=$msg_id)" || { fail "Échoué"; echo "  $resp"; }
sleep 2

# ── Test 3 : Post de A (récupérer ou créer) ───────────────
sep; echo -e "${BOLD} Récupération d'un post de $USER_A_LOGIN${NC}"
resp=$(call GET "/posts.php?user_id=$USER_A_ID&per_page=1" "$TOKEN_B")
POST_ID=$(echo "$resp" | python3 -c "
import sys,json; d=json.load(sys.stdin)
posts=d.get('posts') or d.get('data') or (d if isinstance(d,list) else [])
if isinstance(posts,dict): posts=posts.get('posts',[])
print(posts[0]['id'] if posts else '')
" 2>/dev/null || true)

if [[ -z "$POST_ID" ]]; then
  info "Création d'un post de test..."
  resp=$(call POST "/posts.php" "$TOKEN_A" "{\"content\":\"🧪 Post test notifications – $(date +%H:%M:%S)\"}")
  POST_ID=$(field "$resp" "d.get('post',d).get('id','')")
fi
[[ -n "$POST_ID" ]] && ok "Post id=$POST_ID" || { fail "Pas de post disponible"; }
sleep 1

# ── Test 4 : Réaction ─────────────────────────────────────
sep; echo -e "${BOLD} Test 3 — Réaction/Like${NC}"
resp=$(call POST "/reactions.php" "$TOKEN_B" "{\"post_id\":$POST_ID,\"reaction_type\":\"like\"}")
ok_val=$(field "$resp" "d.get('success',False)")
[[ "$ok_val" == "True" ]] && ok "Réaction envoyée → push 'like'" || { fail "Déjà liké ou erreur"; echo "  $resp"; }
sleep 2

# ── Test 5 : Commentaire ──────────────────────────────────
sep; echo -e "${BOLD} Test 4 — Commentaire${NC}"
resp=$(call POST "/comments.php" "$TOKEN_B" "{\"post_id\":$POST_ID,\"content\":\"🧪 Test commentaire push – $(date +%H:%M:%S)\"}")
cid=$(field "$resp" "d.get('comment',d.get('data',d)).get('id','?')")
[[ -n "$cid" && "$cid" != "?" ]] && ok "Commentaire posté (id=$cid) → push 'comment'" || { fail "Échoué"; echo "  $resp"; }
sleep 2

# ── Test 6 : Mention ──────────────────────────────────────
sep; echo -e "${BOLD} Test 5 — Mention @$USER_A_LOGIN${NC}"
resp=$(call POST "/comments.php" "$TOKEN_B" "{\"post_id\":$POST_ID,\"content\":\"🧪 @$USER_A_LOGIN mention push – $(date +%H:%M:%S)\"}")
cid=$(field "$resp" "d.get('comment',d.get('data',d)).get('id','?')")
[[ -n "$cid" && "$cid" != "?" ]] && ok "Mention postée → push 'mention'" || { fail "Échoué"; echo "  $resp"; }
sleep 2

# ── Test 7 : Abonnement ───────────────────────────────────
sep; echo -e "${BOLD} Test 6 — Abonnement/Follow${NC}"
# Désabonner d'abord au cas où, puis réabonner
call DELETE "/follows.php?user_id=$USER_A_ID" "$TOKEN_B" > /dev/null 2>&1 || true
sleep 1
resp=$(call POST "/follows.php" "$TOKEN_B" "{\"user_id\":$USER_A_ID}")
ok_val=$(field "$resp" "d.get('success',d.get('followed',False))")
[[ "$ok_val" == "True" ]] && ok "Abonnement → push 'follow'" || { fail "Erreur abonnement"; echo "  $resp"; }
sleep 2

# ── Test 8 : Demande d'ami ────────────────────────────────
sep; echo -e "${BOLD} Test 7 — Demande d'ami${NC}"
# Supprimer une éventuelle demande existante puis renvoyer
call DELETE "/friends.php?user_id=$USER_A_ID" "$TOKEN_B" > /dev/null 2>&1 || true
sleep 1
resp=$(call POST "/friends.php" "$TOKEN_B" "{\"action\":\"send\",\"user_id\":$USER_A_ID}")
ok_val=$(field "$resp" "d.get('success',False)")
[[ "$ok_val" == "True" ]] && ok "Demande d'ami → push 'friend_request'" || { fail "Déjà amis ou erreur"; echo "  $resp"; }
sleep 2

# ── Bilan ─────────────────────────────────────────────────
sep
echo -e "${BOLD} BILAN — $USER_A_LOGIN devrait avoir reçu sur son Pixel :${NC}"
echo ""
echo "  1.  Notification système"
echo "  2.  Message privé de $USER_B_LOGIN"
echo "  3.  Réaction sur son post"
echo "  4.  Commentaire sur son post"
echo "  5.  Mention @$USER_A_LOGIN"
echo "  6.  Abonnement de $USER_B_LOGIN"
echo "  7.  Demande d'ami de $USER_B_LOGIN"
echo ""
echo -e "${YELLOW}Si certaines manquent → Paramètres → Notifications → vérifier les toggles${NC}"
sep
