#!/usr/bin/env bash
#
# check-publication.sh — Validation de cohérence avant push radiobot.fm
#
# Usage :
#   ./check-publication.sh             → prend la date du jour
#   ./check-publication.sh 2026-04-23  → date explicite
#
# Vérifications :
#   1. Les 8 MP3 (matinale/flash-ia/edito/billet × fr+en) existent dans episodes/
#   2. Les 2 MP4 Twitter existent dans assets/
#   3. Le hero player-ep cite bien la date du jour (FR + EN)
#   4. Le hero heroAudio data-src-{fr,en} pointe vers la date du jour
#   5. Les cartes sched-card du programme pointent vers la date du jour
#
# Si un check échoue : exit 1 (bloque le pre-push hook).
#

set -e

DATE="${1:-$(date +%Y-%m-%d)}"
FR_DATE_FR=$(python3 -c "import datetime; d=datetime.date.fromisoformat('${DATE}'); m=['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'][d.month-1]; print(f'{d.day} {m} {d.year}')")
EN_DATE_EN=$(python3 -c "import datetime; d=datetime.date.fromisoformat('${DATE}'); m=['January','February','March','April','May','June','July','August','September','October','November','December'][d.month-1]; print(f'{m} {d.day}, {d.year}')")

SITE_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX="$SITE_DIR/index.html"
ERRORS=0

say_ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
say_fail() { printf "  \033[31m✗\033[0m %s\n" "$1"; ERRORS=$((ERRORS+1)); }

echo "=== check-publication.sh — date=${DATE} ==="
echo ""

# ─── 1. MP3 dans episodes/ ────────────────────────────────────
echo "[1] MP3 episodes/"
for lang in fr en; do
  for seg in matinale flash-ia edito billet; do
    f="$SITE_DIR/episodes/${DATE}-${seg}-${lang}.mp3"
    if [ -f "$f" ] && [ "$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f")" -gt 10000 ]; then
      say_ok "${DATE}-${seg}-${lang}.mp3"
    else
      say_fail "MANQUE ou vide : ${DATE}-${seg}-${lang}.mp3"
    fi
  done
done
echo ""

# ─── 2. MP4 Twitter dans assets/ ──────────────────────────────
echo "[2] MP4 Twitter assets/"
for lang in fr en; do
  f="$SITE_DIR/assets/${DATE}-radiobot-daily-${lang}.mp4"
  if [ -f "$f" ] && [ "$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f")" -gt 1000000 ]; then
    say_ok "${DATE}-radiobot-daily-${lang}.mp4"
  else
    say_fail "MANQUE ou vide : ${DATE}-radiobot-daily-${lang}.mp4"
  fi
done
echo ""

# ─── 3. Hero player-ep (titre visible) ────────────────────────
echo "[3] Hero player-ep cite la date du jour"
if grep -q "player-ep.*${FR_DATE_FR}" "$INDEX"; then
  say_ok "FR : \"${FR_DATE_FR}\" présent dans player-ep"
else
  say_fail "FR : \"${FR_DATE_FR}\" INTROUVABLE dans player-ep (ligne ~117)"
  echo "       → le hero affiche probablement les sujets d'un jour antérieur"
fi
if grep -q "player-ep.*${EN_DATE_EN}" "$INDEX"; then
  say_ok "EN : \"${EN_DATE_EN}\" présent dans player-ep"
else
  say_fail "EN : \"${EN_DATE_EN}\" INTROUVABLE dans player-ep (ligne ~117)"
fi
echo ""

# ─── 4. Hero heroAudio pointe vers le bon MP3 ─────────────────
echo "[4] Hero heroAudio pointe vers ${DATE}"
if grep -q "data-src-fr=\"episodes/${DATE}-matinale-fr.mp3\"" "$INDEX"; then
  say_ok "data-src-fr → ${DATE}-matinale-fr.mp3"
else
  say_fail "data-src-fr ne pointe PAS vers ${DATE}-matinale-fr.mp3"
fi
if grep -q "data-src-en=\"episodes/${DATE}-matinale-en.mp3\"" "$INDEX"; then
  say_ok "data-src-en → ${DATE}-matinale-en.mp3"
else
  say_fail "data-src-en ne pointe PAS vers ${DATE}-matinale-en.mp3"
fi
echo ""

# ─── 5. Cartes sched-card du programme ────────────────────────
echo "[5] Cartes sched-card (programme du jour)"
sched_refs=$(grep -c "sched-card.*episodes/${DATE}-" "$INDEX" || true)
if [ "$sched_refs" -ge 4 ]; then
  say_ok "$sched_refs références ${DATE} dans sched-card (attendu : ≥ 4)"
else
  say_fail "seulement $sched_refs références ${DATE} dans sched-card (attendu : ≥ 4)"
  echo "       → attendu : matinale FR, matinale EN, edito FR+EN, billet FR+EN"
fi
echo ""

# ─── Bilan ────────────────────────────────────────────────────
if [ "$ERRORS" -gt 0 ]; then
  printf "\033[31m=== %d ERREUR(S) — push bloqué ===\033[0m\n" "$ERRORS"
  exit 1
else
  printf "\033[32m=== OK — publication cohérente ===\033[0m\n"
  exit 0
fi
