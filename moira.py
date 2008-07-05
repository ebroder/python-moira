#!/usr/bin/python

"""
Python bindings for the Moira library

Moira is the Athena Service Management system.  It serves as the
central repository for information about users, groups hosts, print
queues, and several other aspects of the Athena environment.
"""

import _moira
from _moira import connect, disconnect, auth, host, motd, noop, query
