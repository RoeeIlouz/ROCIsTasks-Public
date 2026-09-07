"""
Upload an Android App Bundle (AAB) to Google Play Console Internal Testing track.
Uses the same service account credentials as upload_to_playstore.py.

Usage:
    python scripts/upload_aab_internal.py [--aab PATH] [--credentials PATH]
"""
import os
import sys
import glob
import json
import time
import base64
import argparse
import requests

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.serialization import load_pem_private_key

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
DEFAULT_PACKAGE_NAME = "com.rocisapps.tasks"
DEFAULT_AAB_PATH = os.path.join(
    PROJECT_ROOT, "build", "app", "outputs", "bundle", "release", "app-release.aab"
)


def find_credentials():
    env_path = os.environ.get("PLAY_STORE_CREDENTIALS")
    if env_path and os.path.exists(env_path):
        return env_path
    candidates = glob.glob(os.path.join(PROJECT_ROOT, "ignored", "*.json"))
    for c in candidates:
        try:
            with open(c, "r", encoding="utf-8") as f:
                data = json.load(f)
                if "client_email" in data and "private_key" in data:
                    return c
        except Exception:
            pass
    return None


def get_access_token(credentials_path):
    with open(credentials_path, "r", encoding="utf-8") as f:
        creds = json.load(f)

    client_email = creds["client_email"]
    private_key_pem = creds["private_key"].encode("utf-8")
    token_uri = creds.get("token_uri", "https://oauth2.googleapis.com/token")

    now = int(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    payload = {
        "iss": client_email,
        "scope": "https://www.googleapis.com/auth/androidpublisher",
        "aud": token_uri,
        "exp": now + 3600,
        "iat": now,
    }

    def b64_url(b):
        return base64.urlsafe_b64encode(b).decode("utf-8").rstrip("=")

    seg1 = b64_url(json.dumps(header).encode("utf-8"))
    seg2 = b64_url(json.dumps(payload).encode("utf-8"))
    to_sign = f"{seg1}.{seg2}".encode("utf-8")

    private_key = load_pem_private_key(private_key_pem, password=None)
    sig = private_key.sign(to_sign, padding.PKCS1v15(), hashes.SHA256())
    jwt = f"{seg1}.{seg2}.{b64_url(sig)}"

    resp = requests.post(
        token_uri,
        data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": jwt},
        timeout=30,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"Failed to get OAuth2 token: {resp.status_code} - {resp.text}")

    return resp.json()["access_token"]


def main():
    parser = argparse.ArgumentParser(description="Upload AAB to Google Play Internal Testing track.")
    parser.add_argument("--aab", default=DEFAULT_AAB_PATH, help="Path to the AAB file")
    parser.add_argument("--credentials", help="Path to service account JSON key")
    parser.add_argument("--package-name", default=DEFAULT_PACKAGE_NAME, help="Android package name")
    parser.add_argument("--track", default="internal", help="Track to upload to (default: internal)")
    args = parser.parse_args()

    aab_path = args.aab
    if not os.path.exists(aab_path):
        print(f"[ERROR] AAB file not found: {aab_path}")
        sys.exit(1)

    creds_path = args.credentials or find_credentials()
    if not creds_path:
        print("[ERROR] Could not find Google Play Service Account JSON credentials.")
        sys.exit(1)

    aab_size_mb = os.path.getsize(aab_path) / (1024 * 1024)

    print("=" * 60)
    print("ROCIs Tasks — AAB Internal Testing Upload")
    print("=" * 60)
    print(f"  Package:     {args.package_name}")
    print(f"  AAB:         {aab_path}")
    print(f"  AAB Size:    {aab_size_mb:.1f} MB")
    print(f"  Track:       {args.track}")
    print(f"  Credentials: {creds_path}")
    print("=" * 60)

    # 1. Authenticate
    print("\n[1/5] Authenticating...")
    token = get_access_token(creds_path)
    headers = {"Authorization": f"Bearer {token}"}
    print("[OK] Authenticated.")

    # 2. Open Edit
    print("\n[2/5] Creating edit session...")
    base_url = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{args.package_name}"
    edit_resp = requests.post(f"{base_url}/edits", headers=headers, timeout=30)
    if edit_resp.status_code != 200:
        print(f"[ERROR] Create edit failed: {edit_resp.status_code} - {edit_resp.text}")
        sys.exit(1)
    edit_id = edit_resp.json()["id"]
    print(f"[OK] Edit ID: {edit_id}")

    # 3. Upload AAB
    print(f"\n[3/5] Uploading AAB ({aab_size_mb:.1f} MB)...")
    upload_url = (
        f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/"
        f"applications/{args.package_name}/edits/{edit_id}/bundles"
        f"?uploadType=media"
    )
    with open(aab_path, "rb") as f:
        aab_data = f.read()

    upload_resp = requests.post(
        upload_url,
        headers={**headers, "Content-Type": "application/octet-stream"},
        data=aab_data,
        timeout=300,
    )
    if upload_resp.status_code not in [200, 201]:
        print(f"[ERROR] Upload failed: {upload_resp.status_code} - {upload_resp.text}")
        requests.delete(f"{base_url}/edits/{edit_id}", headers=headers, timeout=30)
        sys.exit(1)

    version_code = upload_resp.json().get("versionCode")
    print(f"[OK] Uploaded successfully. Version code: {version_code}")

    # 4. Assign to track
    print(f"\n[4/5] Assigning to '{args.track}' track...")
    track_url = f"{base_url}/edits/{edit_id}/tracks/{args.track}"
    track_body = {
        "track": args.track,
        "releases": [
            {
                "versionCodes": [str(version_code)],
                "status": "completed",
            }
        ],
    }
    track_resp = requests.put(
        track_url,
        headers={**headers, "Content-Type": "application/json"},
        json=track_body,
        timeout=30,
    )
    if track_resp.status_code not in [200, 201]:
        print(f"[ERROR] Track assignment failed: {track_resp.status_code} - {track_resp.text}")
        requests.delete(f"{base_url}/edits/{edit_id}", headers=headers, timeout=30)
        sys.exit(1)
    print(f"[OK] Assigned to '{args.track}' track.")

    # 5. Commit
    print("\n[5/5] Committing edit...")
    commit_resp = requests.post(f"{base_url}/edits/{edit_id}:commit", headers=headers, timeout=60)
    if commit_resp.status_code in [200, 201]:
        print(f"\n{'=' * 60}")
        print(f"[SUCCESS] AAB v{version_code} published to '{args.track}' track!")
        print(f"{'=' * 60}")
    else:
        print(f"[ERROR] Commit failed: {commit_resp.status_code} - {commit_resp.text}")
        requests.delete(f"{base_url}/edits/{edit_id}", headers=headers, timeout=30)
        sys.exit(1)


if __name__ == "__main__":
    main()

