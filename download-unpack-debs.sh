#!/bin/sh
# Copyright 2024 Damian Peckett <damian@pecke.tt>
#
# Licensed under the Immutos Community Edition License, Version 1.0 
# (the "License"); you may not use this file except in compliance with 
# the License. You may obtain a copy of the License at
#
# http://immutos.com/licenses/LICENSE-1.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -e

# ARCH specifies the target architecture (e.g., amd64, arm64).
ARCH="${ARCH:-amd64}"

# RELEASE specifies the Debian release version to use (e.g., bullseye, buster, bookworm).
RELEASE="${RELEASE:-bookworm}"

# EXTRA_PACKAGES allows the user to specify additional packages to include.
# It should be a space-separated list of package names.
EXTRA_PACKAGES="${EXTRA_PACKAGES:-}"

# OMIT_REQUIRED, when set to true, skips downloading priority "required" packages.
# This can create a leaner filesystem by omitting default required packages.
OMIT_REQUIRED=${OMIT_REQUIRED:-false}

# MIRROR specifies the primary Debian mirror URL to use.
# This is the base URL for downloading Debian packages.
MIRROR="${MIRROR:-http://deb.debian.org/debian}"

# EXTRA_MIRRORS allows adding additional Debian mirror URLs.
# Use a space-separated list of URLs to include extra mirrors.
EXTRA_MIRRORS="${EXTRA_MIRRORS:-}"

# COMPONENTS defines the repository sections to include, such as "main", "contrib", and "non-free".
# Use a space-separated list to include multiple components.
COMPONENTS="${COMPONENTS:-main}"

APT_CACHE_DIR="/cache"
ROOT_DIR="/rootfs"

APT_OPTIONS="-o Debug::NoLocking=1 \
  -o Dir::Log=${APT_CACHE_DIR}/var/log/apt \
  -o Dir::State=${APT_CACHE_DIR}/var/lib/apt \
  -o Dir::State::Lists=${APT_CACHE_DIR}/var/lib/apt/lists \
  -o Dir::State::extended_states=${APT_CACHE_DIR}/var/lib/apt/lists/extended_states \
  -o Dir::State::status=${APT_CACHE_DIR}/statefile \
  -o Dir::Cache=${APT_CACHE_DIR}/var/cache/apt \
  -o Dir::Cache::Archives=${APT_CACHE_DIR}/var/cache/apt/archives \
  -o Dir::Etc=${APT_CACHE_DIR}/etc/apt \
  -o Dir::Etc::Parts=${APT_CACHE_DIR}/etc/apt/apt.conf.d \
  -o Dir::Etc::PreferencesParts=${APT_CACHE_DIR}/etc/apt/preferences.d \
  -o APT::Install-Recommends=0 \
  -o APT::Install-Suggests=0 \
  -o Acquire::gzipIndexes=false \
  -o APT::Architecture=${ARCH} \
  -o APT::Default-Release=${RELEASE}"

# Create the apt cache directory structure.
mkdir -p \
  "${APT_CACHE_DIR}/var/cache/apt/archives" \
  "${APT_CACHE_DIR}/var/lib/apt/lists" \
  "${APT_CACHE_DIR}/etc/apt/preferences.d" \
  "${APT_CACHE_DIR}/etc/apt/trusted.gpg.d" \
  "${APT_CACHE_DIR}/var/lib/dpkg"

# Create sources.list file with the primary mirror and release.
cat <<EOF > "${APT_CACHE_DIR}/etc/apt/sources.list"
deb ${MIRROR} ${RELEASE} ${COMPONENTS}
deb ${MIRROR} ${RELEASE}-updates ${COMPONENTS}
deb ${MIRROR}-security ${RELEASE}-security ${COMPONENTS}
EOF

# Add any extra mirrors if specified.
for EXTRA_MIRROR in ${EXTRA_MIRRORS}; do
  echo "deb ${EXTRA_MIRROR} ${RELEASE} ${COMPONENTS}" >> "${APT_CACHE_DIR}/etc/apt/sources.list"
done

# Copy trusted GPG keys.
cp /etc/apt/trusted.gpg.d/* "${APT_CACHE_DIR}/etc/apt/trusted.gpg.d/"

# Update the apt cache.
# shellcheck disable=SC2086
apt update ${APT_OPTIONS}

# Get the list of required packages if OMIT_REQUIRED is not set to true.
REQUIRED_PACKAGES=""
if [ "$OMIT_REQUIRED" = "false" ]; then
  # shellcheck disable=SC2231
  for PACKAGES_FILE in ${APT_CACHE_DIR}/var/lib/apt/lists/*_Packages; do
    # shellcheck disable=SC2086
    REQUIRED_PACKAGES="${REQUIRED_PACKAGES} $(awk '/^Package:/ {pkg=$2} /^Priority: required/ {print pkg}' "${PACKAGES_FILE}")"
  done
fi

# Get the names and versions of the required packages (and their transitive dependencies).
# shellcheck disable=SC2086
PACKAGE_VERSIONS=$(apt install ${APT_OPTIONS} --simulate ${REQUIRED_PACKAGES} ${EXTRA_PACKAGES} | awk '/^Inst / {gsub(/[()]/, "", $3); print $2"="$3}')

# Download the required packages (and their transitive dependencies).
# shellcheck disable=SC2086
apt install ${APT_OPTIONS} -y --download-only ${PACKAGE_VERSIONS}

# Create the rootfs directory structure.
rm -rf "${ROOT_DIR:?}/*"
mkdir -p "${ROOT_DIR}/var/lib/dpkg/info"

# Create a reusable temporary control directory.
TMP_CONTROL=$(mktemp -d)

# Extract the downloaded packages.
# shellcheck disable=SC2231
for ARCHIVE in ${APT_CACHE_DIR}/var/cache/apt/archives/*.deb; do
  echo "Unpacking $(basename "${ARCHIVE}")"

  # Get the package name from the archive.
  # shellcheck disable=SC2016
  PACKAGE_NAME=$(dpkg-deb --showformat='${Package}' --show "${ARCHIVE}")

  # Extract the package contents.
  dpkg-deb -x "${ARCHIVE}" "${ROOT_DIR}"

  # Extract control files.
  rm -rf "${TMP_CONTROL:?}"/*
  dpkg-deb --control "${ARCHIVE}" "${TMP_CONTROL}"

  # Add the package to the status file.
  cat "${TMP_CONTROL}/control" >> "${ROOT_DIR}/var/lib/dpkg/status"
  printf "Status: install ok unpacked\n\n" >> "${ROOT_DIR}/var/lib/dpkg/status"
  rm -f "${TMP_CONTROL}/control"

  # Move control files to the info directory.
  for CONTROL_FILE in "${TMP_CONTROL}"/*; do
    mv "${CONTROL_FILE}" "${ROOT_DIR}/var/lib/dpkg/info/${PACKAGE_NAME}.$(basename "${CONTROL_FILE}")"
  done

  # Only create .list file if the package is not empty.
  PACKAGE_FILES=$(dpkg-deb -c "${ARCHIVE}")
  if [ -n "${PACKAGE_FILES}" ]; then
    echo "${PACKAGE_FILES}" | awk '{print substr($6, 2)}' > "${ROOT_DIR}/var/lib/dpkg/info/${PACKAGE_NAME}.list"
  fi
done

# Clean up the temporary control directory.
rm -rf "${TMP_CONTROL}"
