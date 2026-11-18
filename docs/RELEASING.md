# Releasing

This checklist keeps the repository, the Omarchy plugin manifest, and the
marketplace listing in sync.

## 1. Bump the version

Use semantic versioning. For `x.y.z`:

- `manifest.json` → `"version": "x.y.z"`
- `bin/vpn-switch` → `VPN_SWITCH_VERSION="x.y.z"`
- `CHANGELOG.md` → add a dated `## [x.y.z]` section
- `README.md` → update any version-specific notes

## 2. Validate

```bash
./scripts/validate.sh
omarchy plugin validate .
```

`validate.sh` also accepts `--tag vX.Y.Z` to check that the tag matches the
manifest version. A real Omarchy session is the final check: install the repo as
a plugin, open the panel, toggle a provider, and confirm no QML warnings appear
in the shell log.

## 3. Commit and tag

```bash
git add -A
git commit -m "release: vX.Y.Z"
git tag -a vX.Y.Z -m "vpn-switch vX.Y.Z"
git push origin main
git push origin vX.Y.Z
```

Pushing the `v*` tag runs `.github/workflows/release.yml`, which:

- reruns validation with the tag check;
- builds `vpn-switch-vX.Y.Z.tar.gz` and `.zip` from the exact commit;
- creates a GitHub Release with generated notes and the archives attached.

If the workflow is unavailable, create the release by hand from the tag and
attach the same `git archive` outputs.

## 4. Marketplace listing (first release)

The marketplace requires one public repository with `manifest.json` at the root,
a root README with install/remove instructions, a root license, and a globally
unique plugin ID. This repo uses `io.github.shawnicsc.vpn`, outside the reserved
`omarchy.*` namespace. `preview.png` is the marketplace preview.

Prepare the submission issue body (keep headings and checklist text exactly as
the marketplace specifies):

```markdown
### Repository URL

https://github.com/Shawnicsc/vpn-switch

### Category

System

### Tags

bar, quickshell, system

### Suggest a missing tag

_No response_

### Maintainer notes

VPN Switch keeps compatible VPNs/proxies online together and blocks conflicting
route/proxy combinations. The plugin itself needs no elevated privileges and has
no network code. `install.sh` is an optional full-install helper; the default
`omarchy plugin add` path uses only the bundled widget and CLI.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
```

Review every checklist item before submitting, and submit only after the owner
confirms ownership and the remaining statements. Then create the issue:

```bash
gh auth login
gh issue create \
  --repo omacom/omarchy-plugin-marketplace \
  --title "[Plugin]: VPN Switch" \
  --body-file /tmp/omarchy-plugin-submission.md
```

Allowed categories are Appearance, Desktop, Developer Tools, Hardware, Kids,
Productivity, System, Widgets, Other. Allowed tags include `bar`, `quickshell`,
`system`, and `security`. Adjust the category/tags if the listing better fits a
different allowed value; do not invent values.

### Expected security baseline result

The repository contains an installer and a small CLI that calls `ip`, `pgrep`,
`pkill`, and `tailscale`/`clash`-style commands. The marketplace baseline may
report `review-required` because of the `installer` capability. That is expected
and is not a finding. The project intentionally has:

- no download-to-shell paths;
- no remote Git execution;
- no passwordless privilege rules;
- no privileged process control from shared temporary state;
- no service-management calls.

Keep it that way when changing the script, or document the new capability in the
review notes.

## 5. Updating the listing

For a new release, use the marketplace verification form and select
**Verify and publish a newer upstream commit**. Enter:

- plugin ID: `io.github.shawnicsc.vpn`
- repository root URL
- the full 40-character SHA of the new `HEAD`

Compatibility validation and the security baseline run against that exact
commit. The listed snapshot stays unchanged until a maintainer approves it.

## 6. Post-release sanity check

- `omarchy plugin add https://github.com/Shawnicsc/vpn-switch.git --enable`
  works on a clean machine.
- `vpn-switch version` matches the tag.
- The panel shows only installed providers and conflict hints.
- The release notes mention user-visible changes and any provider-specific
  caveats (for example, detection-only WireGuard/OpenVPN/v2rayA support).
