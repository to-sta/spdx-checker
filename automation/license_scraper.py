import json
import pathlib
from typing import TypedDict

import httpx

"""
http://spdx.org/licenses/ offers machine-readable data for the SPDX License list,
in various formats.
"""


class LicenseData(TypedDict):
    """
    TypedDict for license data structure.
    """

    refernce: str
    isDeprecatedLicenseId: bool
    detailsUrl: str
    referenceNumber: int
    name: str
    licenseId: str
    seeAlso: list[str]
    isOsiApproved: bool


class SPDXLicenseDict(TypedDict):
    """
    TypedDict for the machine-readable SPDX license data.
    This structure is used to represent the JSON data fetched from the SPDX license list.
    """

    licenseListVersion: str
    licenses: list[LicenseData]


def fetch_license_data_json(url: str):
    """
    Fetches license data from a given URL and returns the response as JSON.

    Parameters
    ----------
    url : str
        The URL from which to fetch the license data.

    Returns
    -------
    dict
        The JSON-decoded response from the URL.

    Raises
    ------
    RuntimeError
        If the HTTP request fails or returns a non-200 status code.

    Notes
    -----
    Uses an HTTP client with retries and a timeout for robustness.
    """
    transport = httpx.HTTPTransport(retries=3)
    with httpx.Client(transport=transport, timeout=15) as client:
        response = client.get(url)
        if not response.status_code == 200:
            raise RuntimeError(
                f"Failed to fetch license data: {response.status_code} {response.reason_phrase}"
            )
    return response.json()


def flatten_license_data(data: dict) -> list[str]:
    """
    Reduces the license data dictionary down to a list of license IDs.
    """
    return [license_data["licenseId"] for license_data in data["licenses"]]


def update_zig_license_list(file_path: str, license_list: list[str]) -> None:
    """
    Updates a Zig source file with a list of license identifiers.
    This function writes the provided list of license identifiers to the specified file
    in a format compatible with Zig source code. The output will be a Zig array of string
    identifiers.
    Parameters
    ----------
    file_path : str
        The path to the Zig source file to be updated.
    license_list : list of str
        A list of license identifier strings to be written to the file.
    Returns
    -------
    None

    """
    with open(file_path, "w", encoding="utf-8") as file:
        file.write("pub const licensesIdentfiers = [_][]const u8{\n")
        for license_id in license_list:
            file.write(f'\t"{license_id}",\n')
        file.write("};")


def main():
    license_data = fetch_license_data_json(
        url="https://raw.githubusercontent.com/spdx/license-list-data/refs/heads/main/json/licenses.json"
    )
    licenses_list = flatten_license_data(data=license_data)
    update_zig_license_list(
        file_path=pathlib.Path(__file__).parent.parent / "extension" / "licenses.zig",
        license_list=licenses_list,
    )


if __name__ == "__main__":
    main()
