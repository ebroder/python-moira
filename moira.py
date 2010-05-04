"""
Python bindings for the Moira library

Moira is the Athena Service Management system.  It serves as the
central repository for information about users, groups hosts, print
queues, and several other aspects of the Athena environment.
"""

import os
import re

import _moira
from _moira import (auth, host, motd, noop, proxy, MoiraException)


help_re = re.compile('([a-z0-9_, ]*) \(([a-z0-9_, ]*)\)(?: => ([a-z0-9_, ]*))?',
                     re.I)
et_re = re.compile(r'^\s*#\s*define\s+([A-Za-z0-9_]+)\s+.*?([0-9]+)')


_arg_cache = {}
_return_cache = {}
_et_cache = {}


def _clear_caches():
    """Clear query caches.

    Clears all caches that may only be accurate for a particular Moira
    server or query version.
    """
    _arg_cache.clear()
    _return_cache.clear()


def connect(server=''):
    _moira.connect(server)
    version(-1)
connect.__doc__ = _moira.connect.__doc__


def disconnect():
    """Disconnect from the active Moira server"""
    _moira.disconnect()
    _clear_caches()


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


def _parse_args(handle, args, kwargs):
    """
    Convert a set of arguments into the canonical Moira list form.

    Both query and access accept either positional arguments or
    keyword arguments, cross-referenced against the argument names
    given by the "_help" query.

    This function takes the args and kwargs as they're provided to
    either of those functions and returns a list of purely positional
    arguments that can be passed to the low-level Moira query
    function.
    """
    if (handle not in _return_cache or
        not _return_cache[handle]):
        _load_help(handle)

    if kwargs:
        return tuple(kwargs.get(i, '*')
                     for i in _arg_cache[handle])
    else:
        return args


def query(handle, *args, **kwargs):
    """
    Execute a Moira query and return the result as a list of dicts.
    
    Arguments can be specified either as positional or keyword
    arguments. If specified by keyword, they are cross-referenced with
    the argument name given by the query "_help handle".
    
    All of the real work of Moira is done in queries. There are over
    100 queries, each of which requires different arguments. The
    arguments to the queries should be passed as separate arguments to
    the function.
    """
    if handle.startswith('_'):
        return _list_query(handle, *args)
    else:
        fmt = kwargs.pop('fmt', dict)

        args = _parse_args(handle, args, kwargs)

        plain_results = _list_query(handle, *args)
        results = []

        for r in plain_results:
            results.append(fmt(zip(_return_cache[handle], r)))

        return results


def access(handle, *args, **kwargs):
    """
    Determine if the user has the necessary access to perform a query.

    As with moira.query, arguments can be specified either as
    positional or keyword arguments. If specified as keywords, they
    are cross-referenced with the argument names given by the "_help"
    query.

    This function returns True if the user, as currently
    authenticated, would be allowed to perform the query with the
    given arguments, and False otherwise.
    """
    args = _parse_args(handle, args, kwargs)

    try:
        _moira._access(handle, *args)
        return True
    except MoiraException, e:
        if e.code != errors()['MR_PERM']:
            raise
        return False


def version(ver):
    # Changing the Moira version can change a query's arguments and
    # return values
    _clear_caches()
    return _moira.version(ver)
version.__doc__ = _moira.version.__doc__


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
                        _et_cache[errname] = int(errcode)

    return _et_cache


__all__ = ['connect', 'disconnect', 'auth', 'host', 'motd', 'noop', 'query',
           'proxy', 'version', 'access', 'errors', '_list_query',
           'MoiraException']
