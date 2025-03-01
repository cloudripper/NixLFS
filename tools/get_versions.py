import json
import re

# Input and output file names
input_file = "../lfs_sources.json"
output_file = "../lfs_src_versions.json"


# Function to extract version number from URL
def extract_version(url):
    match = re.search(r"(?<=\D)([0-9]+\.[0-9]+(?:\.[0-9]+)*)", url)
    return match.group(1) if match else "unknown"


# Read the input JSON file
with open(input_file, "r") as file:
    data = json.load(file)

# Process the data to extract version numbers
# versions = {key: extract_version(url) for key, url in data.items()}
versions = {
    key: "patch" if "_patch" in key else extract_version(url)
    for key, url in data.items()
}


# Write the output JSON file
with open(output_file, "w") as file:
    json.dump(versions, file, indent=4)

print(f"Version information saved to {output_file}")
