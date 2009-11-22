"""
Python bindings for the Moira library

Moira is the Athena Service Management system.  It serves as the
central repository for information about users, groups hosts, print
queues, and several other aspects of the Athena environment.
"""

import os
import re

import _moira
from _moira import (connect, disconnect, auth, host, motd, noop,
                    MoiraException)


help_re = re.compile('([a-z0-9_, ]*) \(([a-z0-9_, ]*)\)(?: => ([a-z0-9_, ]*))?',
                     re.I)
et_re = re.compile(r'^\s*#\s*define\s+([A-Za-z0-9_]+)\s+.*?([0-9]+)')


_arg_cache = {}
_return_cache = {}
_et_cache = {}


def _load_help(handle):
    """Fetch info about the arguments and return values for a query.

    This uses the "_help" Moira query to retrieve names for the
    arguments and return values to and from a particular Moira
    query. These values are cached and used for translating arguments
    and return values into and out of dictionaries and into and out of
    tuples.
    """
    help_string = ', '.join(query('_help', handle)[0]).strip()

    handle_str, arg_str, return_str = help_re.match(help_string).groups('')

    handles = handle_str.split(', ')
    args = arg_str.split(', ')
    returns = return_str.split(', ')

    for h in handles:
        _arg_cache[h] = args
        _return_cache[h] = returns


def _list_query(handle, *args):
    """
    Execute a Moira query and return the result as a list of tuples.
    
    This bypasses the tuple -> dict conversion done in moira.query()
    """
    results = []
    _moira._query(handle, results.append, *args)
    return results


def query(handle, *args, **kwargs):
    """
    Execute a Moira query and return the result as a list of dicts.
    
    Arguments can be specified either as positional or keyword
    arguments. If specified by keyword, they are crossreferenced with
    the argument name given by the query "_help handle".
    
    All of the real work of Moira is done in queries. There are over
    100 queries, each of which requires different arguments. The
    arguments to the queries should be passed as separate arguments to
    the function.
    """
    if handle.startswith('_'):
        return _list_query(handle, *args)
    else:
        if handle not in _return_cache or \
                not _return_cache[handle]:
            _load_help(handle)

        fmt = kwargs.pop('fmt', dict)

        if kwargs:
            args = tuple(kwargs.get(i, '*') \
                             for i in _arg_cache[handle])

        plain_results = _list_query(handle, *args)
        results = []

        for r in plain_results:
            results.append(fmt(zip(_return_cache[handle], r)))

        return results


def errors():
    """
    Return a dict of Moira error codes.

    This function parses error codes out of the Moira header files and
    returns a dictionary of those error codes.

    The value that's returned should be treated as immutable. It's a
    bug that it isn't.
    """
    if not _et_cache:
        for prefix in ('/usr/include',
                       '/sw/include'):
            header = os.path.join(prefix, 'moira/mr_et.h')
            if os.path.exists(header):
                for line in open(header):
                    m = et_re.search(line)
                    if m:
                        errname, errcode = m.groups()
                        _et_cache[errname] = errcode

    return _et_cache


__all__ = ['connect', 'disconnect', 'auth', 'host', 'motd', 'noop', 'query',
           '_list_query', 'MoiraException']
