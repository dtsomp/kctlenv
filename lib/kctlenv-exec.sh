#!/usr/bin/env bash

set -uo pipefail;

function kctlenv-exec() {
  for _arg in ${@:1}; do
    if [[ "${_arg}" == -chdir=* ]]; then
      log 'debug' "Found -chdir arg. Setting KCTLENV_DIR to: ${_arg#-chdir=}";
      export KCTLENV_DIR="${PWD}/${_arg#-chdir=}";
    fi;
  done;

  log 'debug' 'Getting version from kctlenv-version-name';
  KCTLENV_VERSION="$(kctlenv-version-name)" \
    && log 'debug' "KCTLENV_VERSION is ${KCTLENV_VERSION}" \
    || {
      # Errors will be logged from kctlenv-version name,
      # we don't need to trouble STDERR with repeat information here
      log 'debug' 'Failed to get version from kctlenv-version-name';
      return 1;
    };
  export KCTLENV_VERSION;

  if [ ! -d "${KCTLENV_CONFIG_DIR}/versions/${KCTLENV_VERSION}" ]; then
  if [ "${KCTLENV_AUTO_INSTALL:-true}" == "true" ]; then
    if [ -z "${KCTLENV_KUBECTL_VERSION:-""}" ]; then
      KCTLENV_VERSION_SOURCE="$(kctlenv-version-file)";
    else
      KCTLENV_VERSION_SOURCE='KCTLENV_KUBECTL_VERSION';
    fi;
      log 'info' "version '${KCTLENV_VERSION}' is not installed (set by ${KCTLENV_VERSION_SOURCE}). Installing now as KCTLENV_AUTO_INSTALL==true";
      kctlenv-install;
    else
      log 'error' "version '${KCTLENV_VERSION}' was requested, but not installed and KCTLENV_AUTO_INSTALL is not 'true'";
    fi;
  fi;

  TF_BIN_PATH="${KCTLENV_CONFIG_DIR}/versions/${KCTLENV_VERSION}/kubectl";
  export PATH="${TF_BIN_PATH}:${PATH}";
  log 'debug' "TF_BIN_PATH added to PATH: ${TF_BIN_PATH}";
  log 'debug' "Executing: ${TF_BIN_PATH} $@";

  exec "${TF_BIN_PATH}" "$@" \
  || log 'error' "Failed to execute: ${TF_BIN_PATH} $*";

  return 0;
};
export -f kctlenv-exec;
