#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: community-scripts ORG
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://supabase.com/ | Github: https://github.com/supabase/supabase

APP="Supabase"
var_tags="${var_tags:-database;backend;docker}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-50}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"
var_nesting="${var_nesting:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/supabase/docker-compose.yml || ! -f /opt/supabase/.env ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "supabase" "supabase/supabase"; then
    msg_info "Creating Backup"
    cp /opt/supabase/.env "/opt/supabase.env.bak_$(date +%Y%m%d_%H%M%S)"
    cp /opt/supabase/docker-compose.yml "/opt/supabase_docker-compose.yml.bak_$(date +%Y%m%d_%H%M%S)"
    msg_ok "Created Backup"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "supabase" "supabase/supabase" "tarball" "latest" "/opt/supabase-src"

    msg_info "Updating Docker Files"
    find /opt/supabase-src/docker -mindepth 1 -maxdepth 1 ! -name ".env" ! -name "volumes" -exec cp -a -t /opt/supabase {} +
    msg_ok "Updated Docker Files"

    msg_info "Restoring Auth Key Configuration"
    sed -i \
      -e '/^[[:space:]]*#GOTRUE_JWT_KEYS:/ s/#//' \
      -e '/^[[:space:]]*#API_JWT_JWKS:/ s/#//' \
      -e '/^[[:space:]]*#JWT_JWKS:/ s/#//' \
      /opt/supabase/docker-compose.yml
    msg_ok "Restored Auth Key Configuration"

    msg_info "Pulling Latest Images"
    cd /opt/supabase
    $STD docker compose pull
    msg_ok "Pulled Latest Images"

    msg_info "Restarting Supabase"
    $STD docker compose up -d --remove-orphans
    msg_ok "Restarted Supabase"

    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8000${CL}"
