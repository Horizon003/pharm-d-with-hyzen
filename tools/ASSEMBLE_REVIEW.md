> 2026-10-26 continuation: see `docs/handoff/QUIZ_DUEL_RELEASE_CONTINUATION.md` for the new default-off gameplay/client and canonical release changes. Earlier checkpoints below are historical.

# Reproducible source assembly

Run from a checkout of the review branch with the actual base ZIP and overlays:

```sh
python3 tools/assemble_review.py --repo . --output hyzen-review-source
python3 tools/assemble_review.py --repo . --output hyzen-debug-test-source --debug-tests
python3 -m unittest discover -s tools/tests -v
```

Python3.11+ standard library only. The tool installs nothing and never builds, signs, merges or deploys the app. Use a fresh output name: existing outputs are rejected, including empty directories. Do not point output into source lib/android/assets. Failure may leave a newly created partial output for inspection; input files remain unchanged.

The order matches the existing review workflow: base PharmD_With_Hyzen_Source_1.3.3.zip → root lib/android → legacy1.4.0–1.4.3 overlays → phases01–05 → camera → phase06 → phase07 → phase02 assets. Actual file bytes, including binary fonts/images, are retained. The optional debug-tests mode changes only testBuildType to debug in the assembled copy; release signing guards and input files remain intact.

Guards reject absolute/traversal/ambiguous paths, ZIP/source symlinks, duplicate ZIP entries, unexpected archive roots, signing/key-properties patch targets, invalid patch values and oversized extraction inventories. No user folder is cleared or overwritten. Only a newly created output receives generated files.

review_assembly_manifest.json records ordered overlays, SHA-256 digests of the base ZIP and each patch, every assembled output file, review-only status and test mode. It contains filenames/digests, not file contents or credentials. Identical inputs yield identical manifests. Final overlay hashes are verified after asset copying so a later copy cannot silently replace application source.

The source-tools CI runs synthetic security/parity regressions and also assembles the actual repository inputs. Its artifact contains the manifest only. Passing assembly does not prove Flutter/native/device/backend acceptance. The production release workflow remains unchanged and does not automatically consume these review overlays; rollout integration and authorization remain separate release gates.

