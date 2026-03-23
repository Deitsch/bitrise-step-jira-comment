# Jira Comment (Step)

Post a comment to your Jira instance.

## Important notes about this Step

This step posts a comment to a Jira issue via Jira REST API.

Supported setups:
- Jira instances that accept Bearer token authentication

## 🧩 Get started

Add the step to your `bitrise.yml`:

```yaml
workflows:
  primary:
    steps:
      - path: .
          inputs:
            - jira_base_url: $JIRA_BASE_URL
            - jira_api_token: $JIRA_API_TOKEN
            - jira_comment: "Build #$BITRISE_BUILD_NUMBER finished successfully."
            - jira_rest_path: /rest/api/2
```

## ⚙️ Configuration

<details>
<summary>Inputs</summary>

| Key | Description | Flags | Default |
| --- | --- | --- | --- |
| `jira_base_url` | Base URL of the Jira instance (for example: `https://your-company.atlassian.net`) | required | - |
| `jira_issue_key` | Jira issue key. Optional when commit subject starts with `ISSUEKEY-123` (with or without `:`) | optional | - |
| `jira_api_token` | Jira Bearer token for the `Authorization` header | required, sensitive | - |
| `jira_comment` | The comment text to post | required | - |
| `jira_rest_path` | Jira REST API base path | required | `/rest/api/2` |
</details>

## Commit Prefix Auto-Detection

If `jira_issue_key` is empty, the step will derive it from the commit subject start.

Examples:
- `EXAMPLE-123: some commit text` -> `EXAMPLE-123`
- `OTHER-456 another commit text` -> `OTHER-456`

The step reads commit subject from:
- `BITRISE_GIT_MESSAGE`
- `GIT_CLONE_COMMIT_MESSAGE_SUBJECT`
- `git log -1 --pretty=%s` (fallback)

<details>
<summary>Outputs</summary>

| Key | Description |
| --- | --- |
| `JIRA_COMMENT_ID` | ID of the created Jira comment (when returned/parsable from Jira response) |

</details>

## 🛠️ Troubleshooting

- Verify issue key and token are correct.
- Ensure the account behind the token has permission to comment on the issue.
- If your Jira instance uses another API version/path, set `jira_rest_path` accordingly (for example `/rest/api/3` or `/rest/api/latest`).

## 🙋 Contributing

Issues and pull requests are welcome:
- https://github.com/deitsch/bitrise-step-jira-comment/issues
