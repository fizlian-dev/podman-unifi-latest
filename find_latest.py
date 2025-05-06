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
    # Target URL (UniFi Network Server specific download page)
    scrape_url = "https://ui.com/download/releases/network-server"
    # Regex to find links matching the known download pattern and extract the version
    # Example: https://dl.ui.com/unifi/9.1.120/unifi_sysvinit_all.deb
    # Pattern captures the version X.Y.Z
    deb_url_pattern = re.compile(r"(https://dl\.ui\.com/unifi/(\d+\.\d+\.\d+)/unifi_sysvinit_all\.deb)")

    latest_found_version = version.parse("0.0.0")
    latest_url = None
    found_candidates = []

    print(f"--- Fetching {scrape_url} ---")
    sys.stdout.flush()
    headers = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
    response = requests.get(scrape_url, timeout=30, headers=headers)
    print(f"--- Fetch status code: {response.status_code} ---")
    sys.stdout.flush()
    response.raise_for_status() # Check for HTTP errors
    html_text = response.text
    print(f"--- HTML fetched, length: {len(html_text)} characters ---")
    sys.stdout.flush()

    soup = BeautifulSoup(html_text, 'lxml')
    print("--- HTML parsed with BeautifulSoup (lxml) ---")
    sys.stdout.flush()

    # Find all 'a' tags
    links = soup.find_all('a')
    print(f"--- Found {len(links)} total 'a' tags ---")
    print(f"--- Searching for href matching pattern: '{deb_url_pattern.pattern}' ---")
    sys.stdout.flush()

    for link in links:
        href = link.get('href', '')
        match = deb_url_pattern.search(href)
        if match:
            full_url = match.group(1)
            version_str = match.group(2)
            try:
                current_version = version.parse(version_str)
                print(f"  +++ Found candidate: Version {version_str}, URL {full_url}")
                sys.stdout.flush()
                found_candidates.append({'version': current_version, 'url': full_url})
            except version.InvalidVersion:
                print(f"  --- Skipping URL with invalid version format: {href}")
                sys.stdout.flush()

    if not found_candidates:
        print(f"ERROR: No download links matching the expected URL pattern found.")
        sys.stdout.flush()
        sys.exit(1)

    # Find the candidate with the highest version number
    latest_candidate = max(found_candidates, key=lambda x: x['version'])
    latest_version = latest_candidate['version']
    latest_url = latest_candidate['url']

    print(f"--- Selected latest version: {latest_version} ---")
    print(f"--- Selected URL: {latest_url} ---")
    sys.stdout.flush()

    # Final print for capture by shell
    print(latest_url, end='')
    sys.exit(0) # Exit successfully

except Exception as e:
    print(f"--- PYTHON EXCEPTION ---")
    print(f"ERROR: An exception occurred: {e}")
    import traceback
    traceback.print_exc()
    sys.stdout.flush()
    sys.exit(1)
