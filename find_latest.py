#!/usr/bin/env python3
print("--- Python script start ---")
import sys
import requests
import re
from bs4 import BeautifulSoup
from packaging import version
sys.stdout.flush() # Force flush after imports

try:
    print("--- Importing complete ---")
    sys.stdout.flush()
    url = "https://ui.com/download/releases/network-server"
    title_pattern = re.compile(r"Download v (\d+\.\d+\.\d+) \(Linux\)")
    href_base_pattern = "https://dl.ui.com/unifi/"
    filename = "unifi_sysvinit_all.deb"
    latest_version = version.parse("0.0.0")
    latest_url = None

    print(f"--- Fetching {url} ---")
    sys.stdout.flush()
    headers = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36'}
    response = requests.get(url, timeout=30, headers=headers)
    print(f"--- Fetch status code: {response.status_code} ---")
    sys.stdout.flush()
    response.raise_for_status()
    html_text = response.text
    print(f"--- HTML fetched, length: {len(html_text)} characters ---")
    # print(f"--- HTML start: {html_text[:500]} ---") # Optional: uncomment to see start of HTML
    sys.stdout.flush()

    soup = BeautifulSoup(html_text, 'lxml')
    print("--- HTML parsed with BeautifulSoup (lxml) ---")
    sys.stdout.flush()

    links = soup.find_all('a')
    print(f"--- Found {len(links)} total 'a' tags ---")
    sys.stdout.flush()

    if not links:
        print("ERROR: No 'a' tags found.")
        sys.stdout.flush()
        sys.exit(1)

    found_candidates = []
    print("--- Searching for links matching title and href patterns ---")
    sys.stdout.flush()
    for link in links:
        link_title = link.get('title', '')
        href = link.get('href', '')
        # DEBUG: Print all links being checked
        # print(f"  DEBUG: Checking link: title='{link_title}', href='{href}'")
        # sys.stdout.flush()

        title_match = title_pattern.search(link_title)

        if title_match and href and href.startswith(href_base_pattern) and href.endswith(filename):
            current_version_str = title_match.group(1)
            try:
                current_version = version.parse(current_version_str)
                print(f"  +++ Found candidate: Version {current_version_str}, URL {href}")
                sys.stdout.flush()
                found_candidates.append({'version': current_version, 'url': href})
            except version.InvalidVersion:
                print(f"  --- Skipping link with invalid version format in title: {link_title}")
                sys.stdout.flush()
        # else: # DEBUG: Optionally print why a link didn't match
            # if not title_match: print(f"  --- Title mismatch: '{link_title}'")
            # if not href: print(f"  --- Href missing")
            # if not href.startswith(href_base_pattern): print(f"  --- Href base mismatch: '{href}'")
            # if not href.endswith(filename): print(f"  --- Href filename mismatch: '{href}'")
            # sys.stdout.flush()


    if not found_candidates:
        print("ERROR: No valid download links found matching ALL patterns.")
        sys.stdout.flush()
        sys.exit(1)

    latest_candidate = max(found_candidates, key=lambda x: x['version'])
    latest_version = latest_candidate['version']
    latest_url = latest_candidate['url']

    print(f"--- Selected latest version: {latest_version} ---")
    print(f"--- Selected URL: {latest_url} ---")
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
