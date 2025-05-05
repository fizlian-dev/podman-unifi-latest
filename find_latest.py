#!/usr/bin/env python3
import requests
import re
from bs4 import BeautifulSoup
from packaging import version

# Target URL provided by user
url = "https://ui.com/download/releases/network-server"
# Base URL for constructing download links if needed (seems hrefs are absolute now)
# base_dl_url = "https://dl.ui.com"
# Expected filename pattern
filename_pattern = "unifi_sysvinit_all" # Part of the expected .deb filename

latest_version = version.parse("0.0.0")
latest_url = None

print(f"Fetching release list from {url}...")

try:
    response = requests.get(url, timeout=30)
    response.raise_for_status() # Raise an exception for bad status codes
    soup = BeautifulSoup(response.text, 'lxml') # Use lxml parser

    # Find all links with a title matching the expected pattern
    # Example title: "Download v 9.1.120 (Linux)"
    version_pattern = re.compile(r"Download v (\d+\.\d+\.\d+) \(Linux\)")
    links = soup.find_all('a', title=version_pattern)

    if not links:
        print("ERROR: No links matching the title pattern found.")
        exit(1)

    print(f"Found {len(links)} potential download links...")

    for link in links:
        match = version_pattern.search(link.get('title', ''))
        href = link.get('href', '')

        if match and href and filename_pattern in href and href.endswith(".deb"):
            current_version_str = match.group(1)
            current_version = version.parse(current_version_str)
            print(f"  Found version {current_version_str} with URL {href}")

            # Check if this version is newer than the latest found so far
            if current_version > latest_version:
                latest_version = current_version
                latest_url = href
                print(f"    -> New latest version found: {latest_version}")

    if latest_url:
        print(f"Selected latest version: {latest_version}")
        print(f"Selected URL: {latest_url}")
        # Write the final URL to stdout for the Dockerfile RUN command
        print(latest_url, end='') # Print only the URL for capture
        exit(0)
    else:
        print("ERROR: Could not determine the latest valid download URL from found links.")
        exit(1)

except requests.exceptions.RequestException as e:
    print(f"ERROR: Failed to fetch URL {url}: {e}")
    exit(1)
except Exception as e:
    print(f"ERROR: An unexpected error occurred during parsing: {e}")
    exit(1)
