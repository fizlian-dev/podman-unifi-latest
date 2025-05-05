#!/usr/bin/env python3
print("--- Python script start ---")
import sys
import requests
import re
from bs4 import BeautifulSoup
from packaging import version
sys.stdout.flush()

try:
    print("--- Importing complete ---")
    sys.stdout.flush()
    url = "https://ui.com/download/releases/network-server"
    # Regex to find title like "v 9.1.120 (Linux)" and extract version
    version_pattern_in_title = re.compile(r"v (\d+\.\d+\.\d+) \(Linux\)")
    base_dl_url = "https://dl.ui.com/unifi"
    filename = "unifi_sysvinit_all.deb"

    latest_found_version = version.parse("0.0.0")
    found_versions = []

    print(f"--- Fetching {url} ---")
    sys.stdout.flush()
    headers = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
    response = requests.get(url, timeout=30, headers=headers)
    print(f"--- Fetch status code: {response.status_code} ---")
    sys.stdout.flush()
    response.raise_for_status()
    html_text = response.text
    print(f"--- HTML fetched, length: {len(html_text)} characters ---")
    sys.stdout.flush()

    soup = BeautifulSoup(html_text, 'lxml')
    print("--- HTML parsed with BeautifulSoup (lxml) ---")
    sys.stdout.flush()

    # Find H6 tags potentially containing the version in the title
    h6_tags = soup.find_all('h6')
    print(f"--- Found {len(h6_tags)} total 'h6' tags ---")
    print(f"--- Searching H6 tags for title pattern: '{version_pattern_in_title.pattern}' ---")
    sys.stdout.flush()

    for tag in h6_tags:
        title = tag.get('title', '')
        match = version_pattern_in_title.search(title)
        if match:
            current_version_str = match.group(1)
            try:
                current_version = version.parse(current_version_str)
                print(f"  Found candidate version in title: {current_version_str}")
                sys.stdout.flush()
                found_versions.append(current_version)
            except version.InvalidVersion:
                print(f"  Skipping invalid version format in title: {current_version_str}")
                sys.stdout.flush()

    if not found_versions:
        print(f"ERROR: Could not parse any valid versions from matching h6 tags.")
        sys.stdout.flush()
        sys.exit(1)

    # Find the highest version among candidates
    latest_found_version = max(found_versions)
    print(f"--- Determined latest version: {latest_found_version} ---")
    sys.stdout.flush()

    # Construct the final URL
    latest_url = f"{base_dl_url}/{latest_found_version}/{filename}"
    print(f"--- Constructed URL: {latest_url} ---")
    sys.stdout.flush()

    # Final print for capture by shell
    print(latest_url, end='')
    sys.exit(0)

except Exception as e:
    print(f"--- PYTHON EXCEPTION ---")
    print(f"ERROR: An exception occurred: {e}")
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    sys.exit(1)
