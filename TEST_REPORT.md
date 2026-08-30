# Phase Zero 6.0.4 static verification

- Parsed `project.yml` as YAML.
- Parsed both app plist sources and the privacy manifest.
- Parsed all Asset Catalog JSON files.
- Parsed every Swift file with the available Swift compiler frontend.
- Extracted and syntax-checked the embedded JavaScript.
- Checked the cloud build shell script with `bash -n`.
- Unit-tested `repair_built_info_plist.py` against a synthetic binary plist missing launch, orientation, MusicKit, and motion metadata.
- Confirmed the repair preserves expanded Bundle ID and version values.
- Confirmed the full and hotfix ZIPs preserve hidden `.github` paths.

Final Xcode 26 compilation and iPhone behavior still require GitHub Actions and the target device.
