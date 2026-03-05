#####################################################################
# Dockerfile that builds a CSGO Gameserver - modified from original #
#####################################################################
FROM cm2network/steamcmd:root

ENV STEAMAPPID 740
ENV STEAMAPP csgo
ENV STEAMAPPDIR "${HOMEDIR}/${STEAMAPP}-dedicated"

# Build args (Coolify "Build Variables") – defaults used if not set
ARG METAMOD_VERSION=1.12
ARG SOURCEMOD_VERSION=1.12
ENV METAMOD_VERSION=${METAMOD_VERSION}
ENV SOURCEMOD_VERSION=${SOURCEMOD_VERSION}

# Copy across template config, ESL configs, and entry script
COPY entry.sh ${HOMEDIR}/entry.sh
COPY docker-entrypoint.sh ${HOMEDIR}/docker-entrypoint.sh
COPY custom_server_template.cfg ${HOMEDIR}/custom_server_template.cfg
COPY structured_match_config.cfg ${HOMEDIR}/structured_match_config.cfg
COPY scrim_match_config.cfg ${HOMEDIR}/scrim_match_config.cfg
COPY get5_configs ${HOMEDIR}/get5_configs
COPY esl_configs ${HOMEDIR}/esl_configs

# Create autoupdate config
# Add entry script & ESL config
# Remove packages and tidy up
RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends --no-install-suggests \
		wget \
		ca-certificates \
		lib32z1 \
		lib32stdc++6 \
		lib32gcc-s1 \
		gcc-multilib \
		unzip \
	&& mkdir -p "${STEAMAPPDIR}" \
	&& { \
		echo '@ShutdownOnFailedCommand 1'; \
		echo '@NoPromptForPassword 1'; \
		echo 'force_install_dir '"${STEAMAPPDIR}"''; \
		echo 'login anonymous'; \
		echo 'app_update '"${STEAMAPPID}"''; \
		echo 'quit'; \
	   } > "${HOMEDIR}/${STEAMAPP}_update.txt" \
	&& chmod +x "${HOMEDIR}/entry.sh" "${HOMEDIR}/docker-entrypoint.sh" \
	&& chown -R "${USER}:${USER}" "${HOMEDIR}/entry.sh" "${HOMEDIR}/docker-entrypoint.sh" "${HOMEDIR}/get5_configs" "${HOMEDIR}/esl_configs" "${HOMEDIR}/custom_server_template.cfg" "${HOMEDIR}/structured_match_config.cfg" "${STEAMAPPDIR}" "${HOMEDIR}/${STEAMAPP}_update.txt" \
	&& rm -rf /var/lib/apt/lists/*

ENV SRCDS_PORT=27015 \
	SRCDS_TV_PORT=27020 \
	SRCDS_CLIENT_PORT=27005 \
	SRCDS_TOKEN=0 \
	SRCDS_FPSMAX=300 \
	SRCDS_TICKRATE=128 \
	SRCDS_MAXPLAYERS=14 \
	SRCDS_NET_PUBLIC_ADDRESS="0" \
	SRCDS_IP="0" \
	SRCDS_LAN="0" \
	SRCDS_RCONPW="changeme" \
	SRCDS_PW="changeme" \
	SRCDS_HOSTNAME="CS:GO Server" \
	SRCDS_STARTMAP="de_mirage" \
	SRCDS_REGION=3 \
	SRCDS_MAPGROUP="mg_active" \
	SRCDS_GAMETYPE=0 \
	SRCDS_GAMEMODE=1 \
	SRCDS_HOST_WORKSHOP_COLLECTION=0 \
	SRCDS_WORKSHOP_START_MAP=0 \
	SRCDS_WORKSHOP_AUTHKEY=""

# Expose ports
EXPOSE 27015/tcp \
	27015/udp \
	27020/udp

VOLUME ${STEAMAPPDIR}

WORKDIR ${HOMEDIR}

# Run as root so entrypoint can chown the volume; it then drops to steam for entry.sh
USER root
CMD ["bash", "-c", "exec bash \"${HOMEDIR}/docker-entrypoint.sh\""]
