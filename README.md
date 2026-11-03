# Splunk Devcontainer

This is a [devcontainer](https://code.visualstudio.com/docs/devcontainers/containers) image for local Splunk development. A slimmer (but certainly not slim) alternative to [Splunk's official image](https://github.com/splunk/docker-splunk) that doesn't include unnecessary tools like Ansible.

## Quick Start

Add to your `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/sondreomar/splunk-devcontainer:latest"
}
```

The default password is `splunkdev`, which can be changed by passing `SPLUNK_PASSWORD` in `containerEnv`. See the [devcontainer spec](https://containers.dev/implementors/spec/) for more details on how to customize your devcontainer.

By using the image you accept the [Splunk General Terms](https://www.splunk.com/en_us/legal/splunk-general-terms.html).

## Features

Based on buildpack-deps:bookworm-curl. The devcontainer includes Splunk Enterprise, git, zsh (with [Oh My Zsh!](https://ohmyz.sh/)), and a non-root `splunk` user with sudo access.
The image can also be extended with additional devcontainer features, for example from [devcontainers/features](https://github.com/devcontainers/features).

## Available Variants

| Image                                           | Description                                     | Version suffix | Latest Version                                       |
| ----------------------------------------------- | ----------------------------------------------- | -------------- | ---------------------------------------------------- |
| [splunk](./src/splunk/)                         | Splunk Enterprise                               |                | `ghcr.io/sondreomar/splunk-devcontainer:latest`      |
| [splunk](./src/splunk/)                         | Splunk Enterprise without rarely used apps      | -slim          | `ghcr.io/sondreomar/splunk-devcontainer:latest-slim` |
| [universalforwarder](./src/universalforwarder/) | Splunk Universal Forwarder                      | -uf            | `ghcr.io/sondreomar/splunk-devcontainer:latest-uf`   |

The slim image leaves out the apps listed in [splunk_exclude](./src/splunk/.devcontainer/splunk_exclude) to reduce the image size, and removes them from Splunk's manifest so the file integrity check doesn't report them as missing.

## Image Tags

Images are tagged with both the Splunk version and the devcontainer image version. This allows you to pin to a specific Splunk version while also controlling devcontainer updates.

**Tag formats:**

- `<splunk-version>` - Latest devcontainer image for a specific Splunk version (e.g., `10.2.0`)
- `<splunk-version>-v<image-version>` - Pinned to specific devcontainer image version (e.g., `10.2.0-v1.0.0`)
- `<splunk-major>` - Latest Splunk patch version for a major release (e.g., `10`)
- `<splunk-minor>` - Latest Splunk patch version for a minor release (e.g., `10.2`)
- `<splunk-patch>` - Latest Splunk maintenance version for a patch release (e.g., `10.6.1` for `10.6.1.1`)
- `latest` - Latest supported Splunk version with latest devcontainer image

For the slim image or the Universal Forwarder, add `-slim` or `-uf` after the Splunk version (e.g., `10.2.0-slim`, `10.2.0-uf-v1.0.0`, `latest-uf`).

## Example Usage

- [**standalone**](./examples/standalone/) - Basic Splunk Enterprise setup
- [**standalone-with-app**](./examples/standalone-with-app/) - Splunk with a custom app mounted
- [**standalone-with-terraform**](./examples/standalone-with-terraform/) - Splunk managed with Terraform provider
- [**docker-compose**](./examples/docker-compose/) - Multi-instance Splunk environment
- [**spl-notebooks**](./examples/spl-notebooks/) - Use SPL and SPL2 Notebooks with the [Splunk Extension](https://marketplace.visualstudio.com/items?itemName=Splunk.splunk)

## Building from Source

To build the image devcontainer from source, simply use the `devcontainer.json` in [**./src/splunk**](./src/splunk) or [**./src/universalforwarder**](./src/universalforwarder) and supply build arguments for the desired Splunk version. See [splunk-versions.json](./.github/splunk-versions.json) for build arguments for supported versions, or [Splunk's previous releases](https://www.splunk.com/en_us/download/previous-releases.html) for other versions. Set `SPLUNK_SLIM=true` to build the slim Splunk Enterprise image.
