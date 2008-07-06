#!/usr/bin/python

"""
Python bindings for the Moira library

Moira is the Athena Service Management system.  It serves as the
central repository for information about users, groups hosts, print
queues, and several other aspects of the Athena environment.
"""

import _moira
from _moira import connect, disconnect, auth, host, motd, noop

import re

help_re = re.compile('([a-z0-9_, ]*) \(([a-z0-9_, ]*)\)(?: => ([a-z0-9_, ]*))?',
                     re.I)

class __Handler(object):
    def __init__(self, handle, *args, **kwargs):
        self.handle = handle
        self.args = args
        self.kwargs = kwargs
        self.results = []
        
        self.setup()
        _moira._query(handle, self.callback, *self.args)
        self.cleanup()
    
    def callback(self, result):
        self.results.append(result)
    
    def cleanup(self):
        pass
    def setup(self):
        pass

class __SmartHandler(__Handler):
    # Because these variables aren't redefined by __init__, they are
    # shared by all instances of __SmartHandler
    arg_cache = dict()
    return_cache = dict()
    
    def setup(self):
        if self.handle not in self.return_cache or \
                self.return_cache[self.handle] is None:
            self.__load_help()
        if self.kwargs != dict():
            self.args = tuple(self.kwargs.get(i, '*') \
                                  for i in self.arg_cache[self.handle])
    
    def __load_help(self):
        help_string = ', '.join(_list_query('_help', self.handle)[0]).strip()
        
        handle_str, arg_str, return_str = help_re.match(help_string).groups('')
        
        handles = handle_str.split(', ')
        args = arg_str.split(', ')
        returns = return_str.split(', ')
        
        for h in handles:
            self.arg_cache[h] = args
            self.return_cache[h] = returns
    
    def callback(self, result):
        dict_result = dict()
        map(dict_result.__setitem__, self.return_cache[self.handle], result)
        self.results.append(dict_result)

def _list_query(*args, **kwargs):
    """
    Execute a Moira query and return the result as a list of tuples.
    
    This bypasses the tuple -> dict conversion done in moira.query()
    """
    return __Handler(*args, **kwargs).results

def query(*args, **kwargs):
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
    if args[0] == '_help':
        return _list_query(*args, **kwargs)
    else:
        return __SmartHandler(*args, **kwargs).results

__all__ = ['connect', 'disconnect', 'auth', 'host', 'motd', 'noop', 'query',
           '_list_query']
