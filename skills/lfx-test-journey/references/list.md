<!-- Copyright The Linux Foundation and each contributor to LFX. -->
<!-- SPDX-License-Identifier: MIT -->

# List

Quick manifest-based overview. **No git calls**, this should be fast.

## Step 1: Find Journeys

```bash
find ~/.lfx-journeys -maxdepth 2 -name manifest.yaml 2>/dev/null
```

If no journeys found: "No active journeys. Use `/lfx-skills:lfx-test-journey create` to start one."

## Step 2: Read Each Manifest

For each manifest, extract: name, repo count, total branch count, last_refreshed timestamp.

## Step 3: Render List

```
Active journeys:
  committee-onboarding   2 repos, 5 branches   refreshed 4 hours ago
  meeting-redesign       1 repo, 3 branches     refreshed 2 days ago
```
