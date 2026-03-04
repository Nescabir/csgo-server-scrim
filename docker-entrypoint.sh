#!/bin/bash
# Fix volume ownership when mount is root-owned (e.g. Coolify / host bind mount).
# Then run the real entry script as the steam user.
set -e
STEAMAPPDIR="${STEAMAPPDIR:-/home/steam/csgo-dedicated}"
if [ -d "$STEAMAPPDIR" ] && [ -w "/" ]; then
  chown -R steam:steam "$STEAMAPPDIR" 2>/dev/null || true
fi
# Pass through env vars required by entry.sh (runuser may not inherit)
exec runuser -u steam -- env \
  HOMEDIR="${HOMEDIR}" \
  STEAMAPPDIR="${STEAMAPPDIR}" \
  STEAMAPP="${STEAMAPP}" \
  STEAMAPPID="${STEAMAPPID}" \
  STEAMCMDDIR="${STEAMCMDDIR}" \
  SRCDS_PORT="${SRCDS_PORT}" \
  SRCDS_TV_PORT="${SRCDS_TV_PORT}" \
  SRCDS_CLIENT_PORT="${SRCDS_CLIENT_PORT}" \
  SRCDS_TOKEN="${SRCDS_TOKEN}" \
  METAMOD_VERSION="${METAMOD_VERSION}" \
  SOURCEMOD_VERSION="${SOURCEMOD_VERSION}" \
  SCRIM="${SCRIM}" \
  bash "${HOMEDIR}/entry.sh"
