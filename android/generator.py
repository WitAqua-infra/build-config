#!/usr/bin/env python

from datetime import datetime
import os
import random
import sys
import uuid

import yaml

def main():
    targets = sys.stdin.read()
    pipeline = {"steps": []}
    today = datetime.today()
    ship = os.getenv("SHIP")

    for line in targets.split("\n"):
        if not line or line.startswith("#"):
            continue

        parts = line.split()
        device, build_type, version, cadence = parts[:4]
        upload_files = ""
        if len(parts) >= 5:
            upload_files = parts[4]

        env_vars = {
            'DEVICE': device,
            'RELEASE_TYPE': 'nightly',
            'TYPE': build_type,
            'VERSION': version,
            'BUILD_UUID': uuid.uuid4().hex,
        }

        if upload_files:
            env_vars['UPLOAD_FILES'] = upload_files

        pipeline['steps'].append({
            'label': '{} {}'.format(device, today.strftime("%Y%m%d")),
            'trigger': 'android',
            'build': {
                'env': env_vars,
                'branch': version
            },
        })
    print(yaml.dump(pipeline))

if __name__ == '__main__':
    main()
