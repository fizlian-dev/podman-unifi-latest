#!/usr/bin/env python3
import requests
import re
from bs4 import BeautifulSoup
from packaging import version
import sys

# Target URL
url = "https://ui.com/download/releases/network-server"
# Regex to find title and extract version X.Y.Z
title_pattern = re.compile(r"Download v (\d+\.\d+\.\d+) \(Linux\)")
# Base URL pattern for download links to verify href
href_base_pattern = "https://dl.ui.com/unifi/"
# Expected filename
filename = "unifi_sysvinit_all.deb"

latest_version = version.parse("0.0.0")
latest_url = None

print(f"Attempting to fetch and parse {url}...")

try:
    # Add a common User-Agent header
    headers = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
    response = requests.get(url, timeout=30, headers=headers)
    response.raise_for_status() # Check for HTTP errors
    soup = BeautifulSoup(response.text, 'lxml') # Use lxml parser

    links = soup.find_all('a') # Find all links

    if not links:
        print(f"ERROR: No 'a' tags found on the page {url}.")
        sys.exit(1)

    print(f"Found {len(links)} total 'a' tags. Searching for latest Linux .deb download link...")
    found_candidates = []

    for link in links:
        link_title = link.get('title', '')
        href = link.get('href', '')

        # Check if title attribute matches the desired pattern
        title_match = title_pattern.search(link_title)

        # Check if title matched AND href seems valid
        if title_match and href and href.startswith(href_base_pattern) and href.endswith(filename):
            current_version_str = title_match.group(1)
            try:
                current_version = version.parse(current_version_str)
                print(f"  Found candidate: Version {current_version_str}, URL {href}")
                found_candidates.append({'version': current_version, 'url': href})
            except version.InvalidVersion:
                print(f"  Skipping link with invalid version format in title: {link_title}")

    if not found_candidates:
        print(f"ERROR: No valid download links found matching the pattern.")
        sys.exit(1)

    # Find the candidate with the highest version number
    latest_candidate = max(found_candidates, key=lambda x: x['version'])
    latest_version = latest_candidate['version']
    latest_url = latest_candidate['url']

    print(f"Selected latest version: {latest_version}")
    print(f"Selected URL: {latest_url}")
    # Print *only* the final URL to stdout for the Containerfile
    print(latest_url, end='')
    sys.exit(0) # Exit successfully

except requests.exceptions.RequestException as e:
    print(f"ERROR: Failed to fetch URL {url}: {e}")
    sys.exit(1)
except ImportError:
    print("ERROR: Required Python libraries (requests, bs4, packaging, lxml) not found.")
    sys.exit(1)
except Exception as e:
    print(f"ERROR: An unexpected error occurred: {e}")
    sys.exit(1)
