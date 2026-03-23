#!/usr/bin/env bash
set -euo pipefail

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

require_env() {
  local key="$1"
  local value="${!key:-}"
  if [ -z "$value" ]; then
    log_error "Missing required input: $key"
    exit 1
  fi
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

export_output() {
  local key="$1"
  local value="$2"

  if command -v envman >/dev/null 2>&1; then
    envman add --key "$key" --value "$value" >/dev/null
  else
    export "$key=$value"
  fi
}

resolve_issue_key() {
  if [ -n "${jira_issue_key:-}" ]; then
    printf '%s' "$jira_issue_key"
    return
  fi

  local commit_subject="${BITRISE_GIT_MESSAGE:-${GIT_CLONE_COMMIT_MESSAGE_SUBJECT:-}}"

  if [ -z "$commit_subject" ] && command -v git >/dev/null 2>&1; then
    commit_subject="$(git log -1 --pretty=%s 2>/dev/null || true)"
  fi

  if [ -z "$commit_subject" ]; then
    log_error "Missing issue key. Set jira_issue_key, BITRISE_GIT_MESSAGE, or GIT_CLONE_COMMIT_MESSAGE_SUBJECT."
    return 1
  fi

  local derived_key=""
  # Use bash regex here for portability (GNU/BSD sed differ in alternation support).
  if [[ "$commit_subject" =~ ^[[:space:]]*([A-Z][A-Z0-9]*-[0-9]+)([[:space:]]*:[[:space:]]*.*|[[:space:]]+.*)?$ ]]; then
    derived_key="${BASH_REMATCH[1]}"
  fi

  if [ -z "$derived_key" ]; then
    log_error "Could not derive issue key from commit subject: $commit_subject"
    log_error "Expected start format: ISSUEKEY-123: commit message or ISSUEKEY-123 commit message"
    return 1
  fi

  log_info "Derived Jira issue key from commit subject: $derived_key" >&2
  printf '%s' "$derived_key"
}

require_env jira_base_url
require_env jira_api_token
require_env jira_comment
require_env jira_rest_path

if ! jira_issue_key="$(resolve_issue_key)"; then
  exit 1
fi

base_url="${jira_base_url%/}"
rest_path="/${jira_rest_path#/}"
comment_endpoint="$base_url$rest_path/issue/$jira_issue_key/comment"

escaped_comment="$(json_escape "$jira_comment")"
payload="{\"body\":\"$escaped_comment\"}"

log_info "Posting comment to issue: $jira_issue_key"

curl_args=(
  --silent
  --show-error
  --location
  --request POST
  --url "$comment_endpoint"
  --header "Authorization: Bearer $jira_api_token"
  --header 'Accept: application/json'
  --header 'Content-Type: application/json'
  --data "$payload"
)

response_file="$(mktemp)"
status_code="$(curl "${curl_args[@]}" --output "$response_file" --write-out '%{http_code}')"
response_body="$(cat "$response_file")"
rm -f "$response_file"

if [ "$status_code" -lt 200 ] || [ "$status_code" -ge 300 ]; then
  log_error "Jira API request failed with status code: $status_code"
  if [ -n "$response_body" ]; then
    log_error "Response: $response_body"
  fi
  exit 1
fi

comment_id="$(printf '%s' "$response_body" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"

if [ -n "$comment_id" ]; then
  export_output "JIRA_COMMENT_ID" "$comment_id"
  log_info "Comment posted successfully. Comment ID: $comment_id"
else
  log_info "Comment posted successfully."
fi
