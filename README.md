# gitlab-clone

Clone repositories from one or more GitLab groups (or specific repos) while preserving the group/subgroup directory structure on disk.

By default, `glab repo clone -g` dumps all repos into a flat directory. This script mirrors the GitLab namespace hierarchy so you get a local tree that matches your GitLab groups.

## Prerequisites

- [glab](https://gitlab.com/gitlab-org/cli) - GitLab CLI, authenticated (`glab auth login`)
- [jq](https://jqlang.github.io/jq/) - JSON processor

## Installation

```bash
make install                        # installs to ~/.local/bin/gitlab-clone
make install PREFIX=/usr/local      # or to /usr/local/bin/
make uninstall                      # remove
```

Make sure the install directory is in your `$PATH` (e.g. `export PATH="$HOME/.local/bin:$PATH"` in your shell rc file).

## Usage

```
gitlab-clone [OPTIONS] <target> [<target>...]
```

### Arguments

| Argument | Description |
|----------|-------------|
| `<target>` | One or more group paths (e.g. `mygroup/infra`) or specific repos (e.g. `mygroup/infra/some-repo`). Can be mixed freely. |

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-d, --dest DIR` | Base directory for clones | `.` (current directory) |
| `-p, --protocol PROTO` | Clone protocol: `ssh` or `https` | `ssh` |
| `-s, --ssh-host HOST` | Override SSH host for clone URLs | from glab config |
| `-a, --archived` | Include archived repos | skip archived |
| `-u, --update` | Pull latest changes for already cloned repos | skip existing |
| `-n, --dry-run` | Show what would be done without cloning/pulling | |
| `-h, --help` | Show help | |

## Examples

```bash
# Clone all repos from a group (including subgroups)
gitlab-clone mygroup

# Clone multiple groups at once
gitlab-clone mygroup/infra mygroup/platform

# Clone a specific repo
gitlab-clone mygroup/infra/some-repo

# Mix groups and specific repos
gitlab-clone mygroup/infra mygroup/platform/some-repo

# Clone to a specific directory
gitlab-clone -d ~/repos mygroup/infra

# Preview what would be cloned
gitlab-clone -n mygroup

# Clone and later update existing repos
gitlab-clone -d ~/repos mygroup
gitlab-clone -d ~/repos -u mygroup

# Use HTTPS instead of SSH
gitlab-clone -p https mygroup

# Override SSH host (for self-hosted GitLab)
gitlab-clone -s git.example.com mygroup
```

## How it works

1. Fetches all repos you have access to via `glab repo list --member`
2. Filters repos matching the given targets (exact match for repos, prefix match for groups)
3. Creates directories matching the GitLab group hierarchy
4. Clones each repo into its corresponding directory
5. Skips repos that already exist locally (or pulls with `-u`)

### Example output structure

```
~/repos/
  mygroup/
    infra/
      service-a/
      service-b/
      monitoring/
        extensions/
          metrics-collector/
          log-aggregator/
    testing/
      integration-test-001/
      integration-test-002/
    platform/
      tools/
        deployment-tool/
        analysis-tool/
```
