# workspace

<img width="1024" height="559" alt="playground" src="/.github/assets/codespaces.png" />

## Devcontainer Features

<!-- base -->

<details name="features" open>

<summary>base</summary>
<br />

Core system utilities (curl, tar, git, jq), optional build tools and GoReleaser

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/aleogr/workspace/features/base:1": {}
  }
}
```

> **`goreleaserVersion`** · `latest` · GoReleaser version ('latest' resolves the newest stable release)

> **`installBuildTools`** · `true` · Install build-essential (C toolchain, required for CGO)

</details>


<!-- claude -->

<details name="features">

<summary>claude</summary>
<br />

Claude Code CLI, by default locked into a "<a href="https://github.com/aleogr/workspace/blob/main/devcontainers/features/src/claude/assets/CLAUDE.md">mentor mode</a>" that teaches but never writes code

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/aleogr/workspace/features/claude:1": {}
  }
}
```

> **`version`** · `stable` · Claude Code release channel or version (stable, latest, or e.g. 2.0.14)

> **`teacherMode`** · `true` · Apply the mentor guardrails described below; false installs the plain CLI

</details>


<!-- go -->

<details name="features">

<summary>go</summary>
<br />

Go toolchain and golangci-lint, with VS Code Go settings

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/aleogr/workspace/features/go:1": {}
  }
}
```

> **`goVersion`** · `latest` · Go version ('latest' resolves the newest stable release)

> **`lintVersion`** · `latest` · golangci-lint version ('latest' resolves the newest stable release)

</details>


<!-- vscode -->

<details name="features">

<summary>vscode</summary>
<br />

Shared VS Code extensions and editor defaults

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/aleogr/workspace/features/vscode:1": {}
  }
}
```

</details>

---

> [!IMPORTANT]
> Copy your chosen template to `.devcontainer/devcontainer.json`.*

> [!TIP]
> The `:1` tag tracks the latest release of major version 1; pin `:1.0.0` for full reproducibility.
