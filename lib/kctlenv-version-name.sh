#!/usr/bin/env bash

set -uo pipefail;

function kctlenv-version-name() {
  if [[ -z "${KCTLENV_KUBECTL_VERSION:-""}" ]]; then
    log 'debug' 'We are not hardcoded by a KCTLENV_KUBECTL_VERSION environment variable';

    KCTLENV_VERSION_FILE="$(kctlenv-version-file)" \
      && log 'debug' "KCTLENV_VERSION_FILE retrieved from kctlenv-version-file: ${KCTLENV_VERSION_FILE}" \
      || log 'error' 'Failed to retrieve KCTLENV_VERSION_FILE from kctlenv-version-file';

    KCTLENV_VERSION="$(cat "${KCTLENV_VERSION_FILE}" || true)" \
      && log 'debug' "KCTLENV_VERSION specified in KCTLENV_VERSION_FILE: ${KCTLENV_VERSION}";

    KCTLENV_VERSION_SOURCE="${KCTLENV_VERSION_FILE}";

  else
    KCTLENV_VERSION="${KCTLENV_KUBECTL_VERSION}" \
      && log 'debug' "KCTLENV_VERSION specified in KCTLENV_KUBECTL_VERSION environment variable: ${KCTLENV_VERSION}";

    KCTLENV_VERSION_SOURCE='KCTLENV_KUBECTL_VERSION';
  fi;

  local auto_install="${KCTLENV_AUTO_INSTALL:-true}";

  if [[ "${KCTLENV_VERSION}" == "min-required" ]]; then
    log 'debug' 'KCTLENV_VERSION uses min-required keyword, looking for a required_version in the code';

    local potential_min_required="$(kctlenv-min-required)";
    if [[ -n "${potential_min_required}" ]]; then
      log 'debug' "'min-required' converted to '${potential_min_required}'";
      KCTLENV_VERSION="${potential_min_required}" \
      KCTLENV_VERSION_SOURCE='kubectl{required_version}';
    else
      log 'error' 'Specifically asked for min-required via kubectl{required_version}, but none found';
    fi;
  fi;

  if [[ "${KCTLENV_VERSION}" =~ ^latest.*$ ]]; then
    log 'debug' "KCTLENV_VERSION uses 'latest' keyword: ${KCTLENV_VERSION}";

    if [[ "${KCTLENV_VERSION}" == latest-allowed ]]; then
        KCTLENV_VERSION="$(kctlenv-resolve-version)";
        log 'debug' "Resolved latest-allowed to: ${KCTLENV_VERSION}";
    fi;

    if [[ "${KCTLENV_VERSION}" =~ ^latest\:.*$ ]]; then
      regex="${KCTLENV_VERSION##*\:}";
      log 'debug' "'latest' keyword uses regex: ${regex}";
    else
      regex="^[0-9]\+\.[0-9]\+\.[0-9]\+$";
      log 'debug' "Version uses latest keyword alone. Forcing regex to match stable versions only: ${regex}";
    fi;

    declare local_version='';
    if [[ -d "${KCTLENV_CONFIG_DIR}/versions" ]]; then
      local_version="$(\find "${KCTLENV_CONFIG_DIR}/versions/" -type d -exec basename {} \; \
        | tail -n +2 \
        | sort -t'.' -k 1nr,1 -k 2nr,2 -k 3nr,3 \
        | grep -e "${regex}" \
        | head -n 1)";

      log 'debug' "Resolved ${KCTLENV_VERSION} to locally installed version: ${local_version}";
    elif [[ "${auto_install}" != "true" ]]; then
      log 'error' 'No versions of kubectl installed and KCTLENV_AUTO_INSTALL is not true. Please install a version of kubectl before it can be selected as latest';
    fi;

    if [[ "${auto_install}" == "true" ]]; then
      log 'debug' "Using latest keyword and auto_install means the current version is whatever is latest in the remote. Trying to find the remote version using the regex: ${regex}";
      remote_version="$(kctlenv-list-remote | grep -e "${regex}" | head -n 1)";
      if [[ -n "${remote_version}" ]]; then
          if [[ "${local_version}" != "${remote_version}" ]]; then
            log 'debug' "The installed version '${local_version}' does not much the remote version '${remote_version}'";
            KCTLENV_VERSION="${remote_version}";
          else
            KCTLENV_VERSION="${local_version}";
          fi;
      else
        log 'error' "No versions matching '${requested}' found in remote";
      fi;
    else
      if [[ -n "${local_version}" ]]; then
        KCTLENV_VERSION="${local_version}";
      else
        log 'error' "No installed versions of kubectl matched '${KCTLENV_VERSION}'";
      fi;
    fi;
  else
    log 'debug' 'KCTLENV_VERSION does not use "latest" keyword';

    # Accept a v-prefixed version, but strip the v.
    if [[ "${KCTLENV_VERSION}" =~ ^v.*$ ]]; then
      log 'debug' "Version Requested is prefixed with a v. Stripping the v.";
      KCTLENV_VERSION="${KCTLENV_VERSION#v*}";
    fi;
  fi;

  if [[ -z "${KCTLENV_VERSION}" ]]; then
    log 'error' "Version could not be resolved (set by ${KCTLENV_VERSION_SOURCE} or kctlenv use <version>)";
  fi;

  if [[ "${KCTLENV_VERSION}" == min-required ]]; then
    KCTLENV_VERSION="$(kctlenv-min-required)";
  fi;

  if [[ ! -d "${KCTLENV_CONFIG_DIR}/versions/${KCTLENV_VERSION}" ]]; then
    log 'debug' "version '${KCTLENV_VERSION}' is not installed (set by ${KCTLENV_VERSION_SOURCE})";
  fi;

  echo "${KCTLENV_VERSION}";
};
export -f kctlenv-version-name;

