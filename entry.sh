mkdir -p "${STEAMAPPDIR}" || true  

bash "${STEAMCMDDIR}/steamcmd.sh" +force_install_dir "${STEAMAPPDIR}" \
				+login anonymous \
				+app_update "${STEAMAPPID}" \
				+quit

# We assume that if the Get5 config is missing, that this is a fresh container
if [ ! -f "${STEAMAPPDIR}/${STEAMAPP}/cfg/sourcemod/get5.cfg" ];
	then
		# Base cfg layout from bundled ESL configs (replaces deprecated cfg.tar.gz download)
		mkdir -p "${STEAMAPPDIR}/${STEAMAPP}/cfg"
		cp -a "${HOMEDIR}/esl_configs/"*.cfg "${STEAMAPPDIR}/${STEAMAPP}/cfg/"

		# Download metamod (32-bit CS:GO server – remove linux64 so engine loads bin/ only)
		LATESTMM=$(wget -qO- https://mms.alliedmods.net/mmsdrop/"${METAMOD_VERSION}"/mmsource-latest-linux)
		wget -qO- https://mms.alliedmods.net/mmsdrop/"${METAMOD_VERSION}"/"${LATESTMM}" | tar xvzf - -C "${STEAMAPPDIR}/${STEAMAPP}"
		rm -rf "${STEAMAPPDIR}/${STEAMAPP}/addons/metamod/bin/linux64"

		# Download sourcemod (same: 32-bit server, remove linux64)
		LATESTSM=$(wget -qO- https://sm.alliedmods.net/smdrop/"${SOURCEMOD_VERSION}"/sourcemod-latest-linux)
		wget -qO- https://sm.alliedmods.net/smdrop/"${SOURCEMOD_VERSION}"/"${LATESTSM}" | tar xvzf - -C "${STEAMAPPDIR}/${STEAMAPP}"
		rm -rf "${STEAMAPPDIR}/${STEAMAPP}/addons/sourcemod/bin/linux64"

		# Download get5
		wget -O latest-get5.zip https://github.com/splewis/get5/releases/download/v0.15.0/get5-v0.15.0.zip
		unzip latest-get5.zip -d "${STEAMAPPDIR}/${STEAMAPP}/"
		cp -r "${STEAMAPPDIR}/${STEAMAPP}/get5"/* "${STEAMAPPDIR}/${STEAMAPP}/"
		chmod -R 777 "${STEAMAPPDIR}/${STEAMAPP}/"
		rm -rf latest-get5.zip "${STEAMAPPDIR}/${STEAMAPP}/get5/"

		# Ensure target directories exist before copying (fix missing dirs on first run)
		mkdir -p "${STEAMAPPDIR}/${STEAMAPP}/cfg" \
			"${STEAMAPPDIR}/${STEAMAPP}/cfg/get5" \
			"${STEAMAPPDIR}/${STEAMAPP}/addons/sourcemod/configs/get5"

		# Replace current server.cfg with template file
		cp -r custom_server_template.cfg "${STEAMAPPDIR}/${STEAMAPP}/cfg/server.cfg"
		cp -r structured_match_config.cfg "${STEAMAPPDIR}/${STEAMAPP}/cfg/match.cfg"
		cp -r scrim_match_config.cfg "${STEAMAPPDIR}/${STEAMAPP}/addons/sourcemod/configs/get5/scrim_template.cfg"
		cp -a get5_configs/. "${STEAMAPPDIR}/${STEAMAPP}/cfg/get5/"
fi

if [ "${SCRIM:-true}" = 'true' ]
then
    echo "Configuring server for SCRIM setup"
	# Alter values in Get5 config to be configured for scrim
	sed -i -e 's/get5_check_auths "1"/get5_check_auths "0"/g' "${STEAMAPPDIR}/${STEAMAPP}/cfg/sourcemod/get5.cfg"
	sed -i -e 's/get5_kick_when_no_match_loaded "1"/get5_kick_when_no_match_loaded "0"/g' "${STEAMAPPDIR}/${STEAMAPP}/cfg/sourcemod/get5.cfg"
else
    echo "Configuring server for STRUCTURED setup"
	# Alter values in Get5 config to be configured for structured match config
	sed -i -e 's/get5_check_auths "0"/get5_check_auths "1"/g' "${STEAMAPPDIR}/${STEAMAPP}/cfg/sourcemod/get5.cfg"
	sed -i -e 's/get5_kick_when_no_match_loaded "0"/get5_kick_when_no_match_loaded "1"/g' "${STEAMAPPDIR}/${STEAMAPP}/cfg/sourcemod/get5.cfg"
fi

# CS:GO dedicated server is 32-bit – remove 64-bit addon bins so engine loads 32-bit (fixes "wrong ELF class: ELFCLASS64")
rm -rf "${STEAMAPPDIR}/${STEAMAPP}/addons/metamod/bin/linux64" "${STEAMAPPDIR}/${STEAMAPP}/addons/sourcemod/bin/linux64" 2>/dev/null || true

# Believe it or not, if you don't do this srcds_run shits itself
cd ${STEAMAPPDIR}

# Use system lib32 libgcc (has GCC_7.0.0); game's bundled libgcc_s.so.1 is older and causes "version GCC_7.0.0 not found"
# LD_LIBRARY_PATH has STEAMAPPDIR/bin first, then STEAMAPPDIR – remove both possible locations
rm -f "${STEAMAPPDIR}/bin/libgcc_s.so.1" "${STEAMAPPDIR}/${STEAMAPP}/bin/libgcc_s.so.1" 2>/dev/null || true

# VAC / Steam auth: token must be set and created with App ID 4465480; set SRCDS_NET_PUBLIC_ADDRESS to your server's public IP if behind NAT/Docker so Steam and clients can connect
if [ -z "${SRCDS_TOKEN}" ] || [ "${SRCDS_TOKEN}" = "0" ]; then
	echo "WARNING: SRCDS_TOKEN is not set or is 0 - server will not be VAC secured and may not be joinable. Create a token at https://steamcommunity.com/dev/managegameservers with App ID 4465480 and set SRCDS_NET_PUBLIC_ADDRESS to this server's public IP if behind NAT."
fi
PUBLIC_ADDR="${SRCDS_NET_PUBLIC_ADDRESS:-0}"
echo "Reporting to Steam as public address: ${PUBLIC_ADDR} (set SRCDS_NET_PUBLIC_ADDRESS to your server's public IP if VAC stays off or players cannot connect)"
if [ -z "${SRCDS_NET_PUBLIC_ADDRESS}" ] || [ "${SRCDS_NET_PUBLIC_ADDRESS}" = "0" ]; then
	echo "WARNING: SRCDS_NET_PUBLIC_ADDRESS is 0 or unset - set it to this machine's public IP (e.g. SRCDS_NET_PUBLIC_ADDRESS=1.2.3.4) so Steam and clients can reach the server; otherwise VAC may not activate and the server may be unjoinable."
fi

# Pass SRCDS_* env vars on command line so they override server.cfg (like CM2Walki/CSGO)
bash "${STEAMAPPDIR}/srcds_run" -game "${STEAMAPP}" -console -autoupdate \
			-steam_dir "${STEAMCMDDIR}" \
			-steamcmd_script "${HOMEDIR}/${STEAMAPP}_update.txt" \
			-usercon \
			+fps_max "${SRCDS_FPSMAX:-300}" \
			+tickrate "${SRCDS_TICKRATE:-128}" \
			-port "${SRCDS_PORT}" \
			+tv_port "${SRCDS_TV_PORT}" \
			-clientport "${SRCDS_CLIENT_PORT}" \
			-sport "${SRCDS_STEAM_PORT:-26900}" \
			-maxplayers_override "${SRCDS_MAXPLAYERS:-14}" \
			+game_type "${SRCDS_GAMETYPE:-0}" \
			+game_mode "${SRCDS_GAMEMODE:-1}" \
			+mapgroup "${SRCDS_MAPGROUP:-mg_active}" \
			+map "${SRCDS_STARTMAP:-de_mirage}" \
			+sv_region "${SRCDS_REGION:-3}" \
			+net_public_adr "${SRCDS_NET_PUBLIC_ADDRESS:-0}" \
			-ip "${SRCDS_IP:-0}" \
			+sv_lan "${SRCDS_LAN:-0}" \
			+hostname "${SRCDS_HOSTNAME:-CS:GO Server}" \
			+rcon_password "${SRCDS_RCONPW:-}" \
			+sv_password "${SRCDS_PW:-}" \
			+host_workshop_collection "${SRCDS_HOST_WORKSHOP_COLLECTION:-0}" \
			+workshop_start_map "${SRCDS_WORKSHOP_START_MAP:-0}" \
			-authkey "${SRCDS_WORKSHOP_AUTHKEY:-}" \
			+sv_setsteamaccount "${SRCDS_TOKEN}"
