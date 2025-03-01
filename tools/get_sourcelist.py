import json
import re

import requests
from bs4 import BeautifulSoup


def sanitize_key(key):
    # Replace any sequence of non-alphanumeric characters with a single underscore
    sanitized = re.sub(r"[^A-Za-z0-9]+", "_", key)
    return sanitized.strip("_").lower()


def scrape_packages_from_url(url, patch=False):
    response = requests.get(url)
    response.raise_for_status()  # Raise an error if the request failed
    soup = BeautifulSoup(response.text, "html.parser")
    packages = {}

    # Process each package defined in a <dt> element
    for dt in soup.find_all("dt"):
        term_span = dt.find("span", class_="term")
        if not term_span:
            continue

        # Example term text: "Autoconf (2.72) - 1,360 KB:"
        term_text = term_span.get_text(strip=True)
        # Extract package name: take the text before the first '('
        if "(" in term_text:
            pkg_name = term_text.split("(")[0].strip()
        else:
            pkg_name = term_text.split()[0].strip()

        if patch:
            pkg_name += "_patch"

        # Sanitize the package name (replace spaces & special characters with underscore)
        key = sanitize_key(pkg_name)

        # Get the corresponding <dd> element for package details
        dd = dt.find_next_sibling("dd")
        if not dd:
            continue

        # Find the paragraph that starts with "Download:" and extract the URL
        download_url = None
        for p in dd.find_all("p"):
            if p.get_text(strip=True).startswith("Download:"):
                a_tag = p.find("a", href=True)
                if a_tag:
                    download_url = a_tag["href"]
                break

        if key and download_url:
            packages[key] = download_url

    return packages


if __name__ == "__main__":
    # These URLs are not version controlled and represent the latest packages listed/available for
    # the current stable release for systemd
    packages_url = "https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter03/packages.html"
    patches_url = "https://www.linuxfromscratch.org/lfs/view/stable-systemd/chapter03/patches.html"

    packages = scrape_packages_from_url(packages_url)
    patches = scrape_packages_from_url(patches_url, patch=True)
    final_data = {**packages, **patches}
    print(json.dumps(final_data, indent=4))

    with open("../lfs_source.json", "w", encoding="utf-8") as outfile:
        json.dump(final_data, outfile, indent=4)

    print("Data written to lfs_source.json")
