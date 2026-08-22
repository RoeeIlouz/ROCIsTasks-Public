#!/usr/bin/env python3
"""
CI Configuration Setup Helper
Safely extracts and decodes CI secrets (both Base64 and Raw strings)
with robust validation and fallback to .example template files.
"""

import os
import sys
import json
import base64
import shutil

def read_env_secret(primary_name, fallback_name=None):
    val = os.environ.get(primary_name, "")
    if not val and fallback_name:
        val = os.environ.get(fallback_name, "")
    return val.strip() if val else ""

def try_decode_base64(raw_val):
    if not raw_val:
        return None
    try:
        # Strip potential wrapping quotes or spaces
        cleaned = raw_val.strip().strip("'\"")
        decoded = base64.b64decode(cleaned, validate=True)
        return decoded
    except Exception:
        # Try without validate=True
        try:
            return base64.b64decode(raw_val.strip())
        except Exception:
            return None

def setup_file(secret_name, output_path, example_path, is_json=False, is_binary=False):
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    raw_val = read_env_secret(secret_name)
    written = False

    if raw_val:
        # Case 1: Try Base64 decode
        decoded_bytes = try_decode_base64(raw_val)
        if decoded_bytes:
            if is_json:
                try:
                    json_text = decoded_bytes.decode('utf-8')
                    parsed = json.loads(json_text)
                    if isinstance(parsed, dict) and "project_info" in parsed:
                        with open(output_path, 'wb') as f:
                            f.write(decoded_bytes)
                        print(f"[{secret_name}] Successfully decoded Base64 JSON -> {output_path}")
                        written = True
                except Exception as e:
                    print(f"[{secret_name}] Base64 decoded bytes failed JSON validation: {e}")
            elif is_binary:
                with open(output_path, 'wb') as f:
                    f.write(decoded_bytes)
                print(f"[{secret_name}] Successfully decoded Base64 binary -> {output_path}")
                written = True
            else:
                try:
                    decoded_text = decoded_bytes.decode('utf-8')
                    with open(output_path, 'w', encoding='utf-8') as f:
                        f.write(decoded_text)
                    print(f"[{secret_name}] Successfully decoded Base64 text -> {output_path}")
                    written = True
                except Exception:
                    pass

        # Case 2: Try raw string if not already written (and not binary)
        if not written and not is_binary:
            if is_json:
                try:
                    parsed = json.loads(raw_val)
                    if isinstance(parsed, dict):
                        with open(output_path, 'w', encoding='utf-8') as f:
                            json.dump(parsed, f, indent=2)
                        print(f"[{secret_name}] Successfully parsed raw JSON -> {output_path}")
                        written = True
                except Exception as e:
                    print(f"[{secret_name}] Raw text failed JSON validation: {e}")
            else:
                with open(output_path, 'w', encoding='utf-8') as f:
                    f.write(raw_val)
                print(f"[{secret_name}] Successfully wrote raw text -> {output_path}")
                written = True

    # Case 3: Fallback to example file if not written
    if not written:
        if example_path and os.path.exists(example_path):
            shutil.copyfile(example_path, output_path)
            print(f"[{secret_name}] Using fallback template: {example_path} -> {output_path}")
        else:
            print(f"[{secret_name}] No secret or fallback provided for {output_path}")

def main():
    print("=== Setting up CI/CD configuration files ===")

    # 1. .env
    setup_file("ENV_FILE_BASE64", ".env", ".env.example")

    # 2. firebase_options.dart
    setup_file("FIREBASE_OPTIONS_BASE64", "lib/firebase_options.dart", "lib/firebase_options.dart.example")

    # 3. firebase_schedule_options.dart
    if os.path.exists("lib/firebase_schedule_options.dart.example"):
        shutil.copyfile("lib/firebase_schedule_options.dart.example", "lib/firebase_schedule_options.dart")
        print("Copied lib/firebase_schedule_options.dart.example -> lib/firebase_schedule_options.dart")

    # 4. google-services.json
    setup_file("GOOGLE_SERVICES_JSON_BASE64", "android/app/google-services.json", "android/app/google-services.json.example", is_json=True)

    # 5. Keystore & key.properties
    setup_file("KEYSTORE_BASE64", "android/app/upload-keystore.jks", None, is_binary=True)
    setup_file("KEY_PROPERTIES_BASE64", "android/key.properties", None)

    # Final sanity check on google-services.json
    gs_path = "android/app/google-services.json"
    if os.path.exists(gs_path):
        try:
            with open(gs_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            print(f"Sanity Check: {gs_path} is valid JSON (project: {data.get('project_info', {}).get('project_id')})")
        except Exception as e:
            print(f"Sanity Check FAILED on {gs_path}: {e}. Restoring example fallback!")
            shutil.copyfile("android/app/google-services.json.example", gs_path)

    print("=== Configuration setup completed successfully ===")

if __name__ == "__main__":
    main()
