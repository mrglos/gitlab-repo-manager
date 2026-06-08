#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] <group>

Clone all repos from a GitLab group, preserving the group/subgroup directory structure.

Arguments:
  <group>             GitLab group path (e.g. "mygroup" or "mygroup/infrastructure")

Options:
  -d, --dest DIR      Base directory for clones (default: current directory)
  -p, --protocol      Clone protocol: ssh or https (default: ssh)
  -s, --ssh-host HOST Override SSH host (default: read from glab config)
  -a, --archived      Include archived repos (default: skip)
  -u, --update        Pull latest changes for already cloned repos (default: skip)
  -n, --dry-run       Show what would be done without cloning/pulling
  -h, --help          Show this help

Examples:
  $(basename "$0") mygroup
  $(basename "$0") -d ~/repos -u mygroup/infrastructure
  $(basename "$0") -p https -n mygroup
  $(basename "$0") -s git.example.com mygroup
EOF
  exit 0
}

DEST="."
PROTOCOL="ssh"
SSH_HOST=""
INCLUDE_ARCHIVED=false
UPDATE=false
DRY_RUN=false
GROUP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dest)      DEST="$2"; shift 2 ;;
    -p|--protocol)  PROTOCOL="$2"; shift 2 ;;
    -s|--ssh-host)  SSH_HOST="$2"; shift 2 ;;
    -a|--archived)  INCLUDE_ARCHIVED=true; shift ;;
    -u|--update)    UPDATE=true; shift ;;
    -n|--dry-run)   DRY_RUN=true; shift ;;
    -h|--help)      usage ;;
    -*)             echo "Unknown option: $1" >&2; exit 1 ;;
    *)              GROUP="$1"; shift ;;
  esac
done

if [[ -z "$GROUP" ]]; then
  echo "Error: group argument is required" >&2
  usage
fi

if ! command -v glab &>/dev/null; then
  echo "Error: glab CLI not found. Install it: https://gitlab.com/gitlab-org/cli" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq not found. Install it: brew install jq" >&2
  exit 1
fi

get_clone_url() {
  local path_with_ns="$1"
  local ssh_url="$2"
  local http_url="$3"

  if [[ "$PROTOCOL" == "https" ]]; then
    echo "$http_url"
    return
  fi

  if [[ -n "$SSH_HOST" ]]; then
    echo "git@${SSH_HOST}:${path_with_ns}.git"
  else
    echo "$ssh_url"
  fi
}

echo "Fetching repos ..."

PAGE=1
PER_PAGE=100
ALL_REPOS="[]"

while true; do
  RESPONSE=$(glab repo list --member -F json -P "$PER_PAGE" -p "$PAGE" 2>/dev/null)

  COUNT=$(echo "$RESPONSE" | jq 'length')
  if [[ "$COUNT" -eq 0 ]]; then
    break
  fi

  ALL_REPOS=$(echo "$ALL_REPOS $RESPONSE" | jq -s 'add')

  if [[ "$COUNT" -lt "$PER_PAGE" ]]; then
    break
  fi

  ((PAGE++))
done

ALL_REPOS=$(echo "$ALL_REPOS" | jq --arg group "$GROUP" '[.[] | select(.path_with_namespace | startswith($group + "/"))]')

if [[ "$INCLUDE_ARCHIVED" == "false" ]]; then
  ALL_REPOS=$(echo "$ALL_REPOS" | jq '[.[] | select(.archived == false)]')
fi

TOTAL=$(echo "$ALL_REPOS" | jq 'length')
echo "Found $TOTAL repos."

if [[ "$TOTAL" -eq 0 ]]; then
  exit 0
fi

CLONED=0
UPDATED=0
SKIPPED=0
FAILED=0

while IFS=$'\t' read -r path_with_ns ssh_url http_url default_branch; do
  parent_dir=$(dirname "$path_with_ns")
  target_dir="${DEST}/${path_with_ns}"
  clone_url=$(get_clone_url "$path_with_ns" "$ssh_url" "$http_url")

  if [[ -d "$target_dir/.git" ]]; then
    if [[ "$UPDATE" == "true" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[dry-run] git -C ${target_dir} pull origin ${default_branch}"
        continue
      fi
      echo "[update] ${path_with_ns}"
      if git -C "$target_dir" pull --quiet origin "$default_branch"; then
        ((UPDATED++)) || true
      else
        echo "[fail-update] ${path_with_ns}" >&2
        ((FAILED++)) || true
      fi
    else
      echo "[skip] ${path_with_ns} (already exists)"
      ((SKIPPED++)) || true
    fi
    continue
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] mkdir -p ${DEST}/${parent_dir}"
    echo "[dry-run] git clone ${clone_url} ${target_dir}"
    continue
  fi

  mkdir -p "${DEST}/${parent_dir}"

  echo "[clone] ${path_with_ns}"
  if git clone --quiet "$clone_url" "$target_dir"; then
    ((CLONED++)) || true
  else
    echo "[fail] ${path_with_ns}" >&2
    ((FAILED++)) || true
  fi
done < <(echo "$ALL_REPOS" | jq -r '.[] | "\(.path_with_namespace)\t\(.ssh_url_to_repo)\t\(.http_url_to_repo)\t\(.default_branch)"')

if [[ "$DRY_RUN" == "false" ]]; then
  echo ""
  echo "Done. Cloned: $CLONED, Updated: $UPDATED, Skipped: $SKIPPED, Failed: $FAILED"
fi
