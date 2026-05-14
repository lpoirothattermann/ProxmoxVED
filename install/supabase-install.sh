#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: community-scripts ORG
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://supabase.com/ | Github: https://github.com/supabase/supabase

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y openssl
msg_ok "Installed Dependencies"

NODE_VERSION="22" setup_nodejs
DOCKER_SKIP_UPDATES="true" USE_DOCKER_REPO="true" setup_docker

fetch_and_deploy_gh_release "supabase" "supabase/supabase" "tarball" "latest" "/opt/supabase-src"

msg_info "Installing Docker Files"
mkdir -p /opt/supabase
cp -a /opt/supabase-src/docker/. /opt/supabase/
msg_ok "Installed Docker Files"

msg_info "Configuring Supabase"
cp /opt/supabase/.env.example /opt/supabase/.env
cd /opt/supabase
$STD sh utils/generate-keys.sh --update-env
$STD sh utils/add-new-auth-keys.sh --update-env
sed -i \
  -e "s|^DASHBOARD_PASSWORD=.*|DASHBOARD_PASSWORD=supa$(openssl rand -hex 14)|" \
  -e "s|^SUPABASE_PUBLIC_URL=.*|SUPABASE_PUBLIC_URL=http://${LOCAL_IP}:8000|" \
  -e "s|^API_EXTERNAL_URL=.*|API_EXTERNAL_URL=http://${LOCAL_IP}:8000|" \
  -e "s|^SITE_URL=.*|SITE_URL=http://${LOCAL_IP}:3000|" \
  -e "s|^POOLER_TENANT_ID=.*|POOLER_TENANT_ID=supabase$(openssl rand -hex 4)|" \
  -e "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=|" \
  /opt/supabase/.env
sed -i \
  -e '/^[[:space:]]*#GOTRUE_JWT_KEYS:/ s/#//' \
  -e '/^[[:space:]]*#API_JWT_JWKS:/ s/#//' \
  -e '/^[[:space:]]*#JWT_JWKS:/ s/#//' \
  /opt/supabase/docker-compose.yml
chmod 600 /opt/supabase/.env
msg_ok "Configured Supabase"

msg_info "Pulling Supabase Images"
cd /opt/supabase
$STD docker compose pull
msg_ok "Pulled Supabase Images"

msg_info "Starting Supabase"
$STD docker compose up -d
msg_ok "Started Supabase"

echo ""
msg_ok "Supabase is reachable at: ${BL}http://${LOCAL_IP}:8000${CL}"
echo -e "${INFO}${YW} Dashboard credentials:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Username: $(sed -n 's|^DASHBOARD_USERNAME=||p' /opt/supabase/.env | head -n1)${CL}"
echo -e "${TAB}${GATEWAY}${BGN}Password: $(sed -n 's|^DASHBOARD_PASSWORD=||p' /opt/supabase/.env | head -n1)${CL}"
echo -e "${INFO}${YW} Supabase keys and database credentials are stored in:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}/opt/supabase/.env${CL}"

motd_ssh
customize
cleanup_lxc
