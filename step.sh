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
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' \
          -e 's/"/\\"/g' \
          -e ':a;N;$!ba;s/\n/\\n/g' \
          -e 's/\r/\\r/g' \
          -e 's/\t/\\t/g'
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

require_env jira_base_url
require_env jira_issue_key
require_env jira_api_token
require_env jira_comment
require_env jira_rest_path

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
