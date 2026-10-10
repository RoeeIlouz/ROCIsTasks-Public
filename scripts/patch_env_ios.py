#!/usr/bin/env python3
"""
Fill the FIREBASE_IOS_* entries in .env from ios/Runner/GoogleService-Info.plist.

FirebaseConfig reads the iOS options from .env, so the iOS build needs real
values there. Running this keeps the plist as the single source of truth
instead of duplicating the keys in the ENV_FILE_BASE64 secret.
"""

import plistlib
import re
import sys

PLIST_PATH = "ios/Runner/GoogleService-Info.plist"
ENV_PATH = ".env"
# Optional: the iOS app registered in the rocis-schedule project, used by
# ScheduleFirebaseOptions.ios to read ROCIs Schedule data.
SCHEDULE_PLIST_ARG = "--schedule-plist"


def main():
    with open(PLIST_PATH, "rb") as f:
        plist = plistlib.load(f)

    values = {
        "FIREBASE_IOS_API_KEY": plist["API_KEY"],
        "FIREBASE_IOS_APP_ID": plist["GOOGLE_APP_ID"],
        "FIREBASE_IOS_CLIENT_ID": plist["CLIENT_ID"],
        "FIREBASE_IOS_BUNDLE_ID": plist["BUNDLE_ID"],
    }

    if SCHEDULE_PLIST_ARG in sys.argv:
        schedule_path = sys.argv[sys.argv.index(SCHEDULE_PLIST_ARG) + 1]
        with open(schedule_path, "rb") as f:
            schedule = plistlib.load(f)
        values["FIREBASE_SCHEDULE_IOS_APP_ID"] = schedule["GOOGLE_APP_ID"]
        values["FIREBASE_SCHEDULE_IOS_API_KEY"] = schedule["API_KEY"]

    with open(ENV_PATH, encoding="utf-8") as f:
        env = f.read()

    for key, value in values.items():
        env, count = re.subn(rf"^{key}=.*$", f"{key}={value}", env, flags=re.M)
        if not count:
            env = env.rstrip("\n") + f"\n{key}={value}\n"

    # A placeholder RevenueCat key makes Purchases.configure fail; an empty one
    # takes the "subscriptions not configured" path in SubscriptionService.
    env = re.sub(r"^REVENUECAT_API_KEY_IOS=your-.*$", "REVENUECAT_API_KEY_IOS=", env, flags=re.M)

    with open(ENV_PATH, "w", encoding="utf-8") as f:
        f.write(env)

    print(f"Patched {', '.join(values)} in {ENV_PATH}")


if __name__ == "__main__":
    sys.exit(main())
