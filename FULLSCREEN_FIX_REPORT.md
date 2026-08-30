# Phase Zero 6.0.4 — Full-Screen Metadata Repair

The launch storyboard itself was not the remaining problem. The 6.0.3 log shows that Xcode compiled and linked it correctly, but omitted the launch-screen reference and orientation arrays from the processed app plist.

The cloud build now repairs the unsigned app's final plist before packaging. A later signing service signs that already-repaired bundle. The IPA is then reopened and checked again, so the workflow only succeeds when the metadata and resources survive the entire packaging path.
