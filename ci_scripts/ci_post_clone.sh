#!/bin/sh
#
# Xcode Cloud post-clone step.
#
# Sets the app's build number (CFBundleVersion) to the Xcode Cloud build number
# so every TestFlight upload is unique — a static build number would collide on
# the second archive and TestFlight would reject it.
#
# This runs ONLY in the ephemeral Xcode Cloud checkout; it never touches the real
# repo or a local build. Because the project uses GENERATE_INFOPLIST_FILE = YES,
# CFBundleVersion is derived from the CURRENT_PROJECT_VERSION build setting, so
# rewriting that setting is all that's needed. It also runs during the PR CI
# (test) workflow, where a bumped build number is harmless.
#
set -e

if [ -z "$CI_BUILD_NUMBER" ]; then
  echo "ci_post_clone: CI_BUILD_NUMBER not set; leaving build number unchanged."
  exit 0
fi

PBXPROJ="$CI_PRIMARY_REPOSITORY_PATH/Jackdaw.xcodeproj/project.pbxproj"
echo "ci_post_clone: setting CURRENT_PROJECT_VERSION to $CI_BUILD_NUMBER"
/usr/bin/sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" "$PBXPROJ"
