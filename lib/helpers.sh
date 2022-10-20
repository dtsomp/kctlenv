#!/usr/bin/env bash

set -uo pipefail;

if [ -z "${KCTLENV_ROOT:-""}" ]; then
  # http://stackoverflow.com/questions/1055671/how-can-i-get-the-behavior-of-gnus-readlink-f-on-a-mac
  readlink_f() {
    local target_file="${1}";
    local file_name;

    while [ "${target_file}" != "" ]; do
      cd "${target_file%/*}" || early_death "Failed to 'cd \$(${target_file%/*})' while trying to determine KCTLENV_ROOT";
      file_name="${target_file##*/}" || early_death "Failed to '\"${target_file##*/}\"' while trying to determine KCTLENV_ROOT";
      target_file="$(readlink "${file_name}")";
    done;

    echo "$(pwd -P)/${file_name}";
  };
  KCTLENV_SHIM=$(readlink_f "${0}")
  KCTLENV_ROOT="${KCTLENV_SHIM%/*/*}";
  [ -n "${KCTLENV_ROOT}" ] || early_death "Failed to determine KCTLENV_ROOT";
else
  KCTLENV_ROOT="${KCTLENV_ROOT%/}";
fi;
export KCTLENV_ROOT;

if [ -z "${KCTLENV_CONFIG_DIR:-""}" ]; then
  KCTLENV_CONFIG_DIR="$KCTLENV_ROOT";
else
  KCTLENV_CONFIG_DIR="${KCTLENV_CONFIG_DIR%/}";
fi
export KCTLENV_CONFIG_DIR;

if [ "${KCTLENV_DEBUG:-0}" -gt 0 ]; then
  # Only reset DEBUG if KCTLENV_DEBUG is set, and DEBUG is unset or already a number
  if [[ "${DEBUG:-0}" =~ ^[0-9]+$ ]] && [ "${DEBUG:-0}" -gt "${KCTLENV_DEBUG:-0}" ]; then
    export DEBUG="${KCTLENV_DEBUG:-0}";
  fi;
  if [[ "${KCTLENV_DEBUG}" -gt 2 ]]; then
    export PS4='+ [${BASH_SOURCE##*/}:${LINENO}] ';
    set -x;
  fi;
fi;

function load_bashlog () {
  source "${KCTLENV_ROOT}/lib/bashlog.sh";
};
export -f load_bashlog;

if [ "${KCTLENV_DEBUG:-0}" -gt 0 ] ; then
  # our shim below cannot be used when debugging is enabled
  load_bashlog;
else
  # Shim that understands to no-op for debug messages, and defers to
  # full bashlog for everything else.
  function log () {
    if [ "$1" != 'debug' ] ; then
      # Loading full bashlog will overwrite the `log` function
      load_bashlog;
      log "$@";
    fi;
  };
  export -f log;
fi;

# Curl wrapper to switch TLS option for each OS
function curlw () {
  local TLS_OPT="--tlsv1.2";

  # Check if curl is 10.12.6 or above
  if [[ -n "$(command -v sw_vers 2>/dev/null)" && ("$(sw_vers)" =~ 10\.12\.([6-9]|[0-9]{2}) || "$(sw_vers)" =~ 10\.1[3-9]) ]]; then
    TLS_OPT="";
  fi;

  if [[ ! -z "${KCTLENV_NETRC_PATH:-""}" ]]; then
    NETRC_OPT="--netrc-file ${KCTLENV_NETRC_PATH}";
  else
    NETRC_OPT="";
  fi;

  curl ${TLS_OPT} ${NETRC_OPT} "$@";
};
export -f curlw;

function check_active_version() {
  local v="${1}";
  local maybe_chdir=;
  if [ -n "${2:-}" ]; then
      maybe_chdir="-chdir=${2}";
  fi;

  local active_version="$(${KCTLENV_ROOT}/bin/kubectl ${maybe_chdir} version | grep '^Kubectl')";

  if ! grep -E "^Kubectl v${v}((-dev)|( \([a-f0-9]+\)))?( is already installed)?\$" <(echo "${active_version}"); then
    log 'debug' "Expected version ${v} but found ${active_version}";
    return 1;
  fi;

  log 'debug' "Active version ${v} as expected";
  return 0;
};
export -f check_active_version;

function check_installed_version() {
  local v="${1}";
  local bin="${KCTLENV_CONFIG_DIR}/versions/${v}/kubectl";
  [ -n "$(${bin} version | grep -E "^Kubectl v${v}((-dev)|( \([a-f0-9]+\)))?$")" ];
};
export -f check_installed_version;

function check_default_version() {
  local v="${1}";
  local def="$(cat "${KCTLENV_CONFIG_DIR}/version")";
  [ "${def}" == "${v}" ];
};
export -f check_default_version;

function cleanup() {
  log 'info' 'Performing cleanup';
  local pwd="$(pwd)";
  log 'debug' "Deleting ${pwd}/version";
  rm -rf ./version;
  log 'debug' "Deleting ${pwd}/versions";
  rm -rf ./versions;
  log 'debug' "Deleting ${pwd}/.kubectl-version";
  rm -rf ./.kubectl-version;
  log 'debug' "Deleting ${pwd}/latest_allowed.tf";
  rm -rf ./latest_allowed.tf;
  log 'debug' "Deleting ${pwd}/min_required.tf";
  rm -rf ./min_required.tf;
  log 'debug' "Deleting ${pwd}/chdir-dir";
  rm -rf ./chdir-dir;
};
export -f cleanup;

function error_and_proceed() {
  errors+=("${1}");
  log 'warn' "Test Failed: ${1}";
};
export -f error_and_proceed;

function check_dependencies() {
  if [[ $(uname) == 'Darwin' ]] && [ $(which brew) ]; then
    if ! [ $(which ggrep) ]; then
      log 'error' 'A metaphysical dichotomy has caused this unit to overload and shut down. GNU Grep is a requirement and your Mac does not have it. Consider "brew install grep"';
    fi;

    shopt -s expand_aliases;
    alias grep=ggrep;
  fi;
};
export -f check_dependencies;

source "$KCTLENV_ROOT/lib/kctlenv-exec.sh";
source "$KCTLENV_ROOT/lib/kctlenv-min-required.sh";
source "$KCTLENV_ROOT/lib/kctlenv-version-file.sh";
source "$KCTLENV_ROOT/lib/kctlenv-version-name.sh";

export KCTLENV_HELPERS=1;
