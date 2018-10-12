#!/bin/bash

ceph auth get client.admin
# [client.admin]
#         key = AQAm4L5b60alLhAARxAgr9jQDLopr9fbXfm87w==
#         caps mds = "allow *"
#         caps mgr = "allow *"
#         caps mon = "allow *"
#         caps osd = "allow *"

ceph fs authorize cephfs client.fs-test-1 / r /test_1 rw
# [client.fs-test-1]
#         key = AQA0Cr9b9afRDBAACJ0M8HxsP41XmLhbSxWkqA==