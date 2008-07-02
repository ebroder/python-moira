cdef extern from "moira/moira.h":
    int mr_krb5_auth(char * prog)
    int mr_auth(char * prog)
    int mr_connect(char * server)
    int mr_disconnect()
    int mr_host(char * host_buf, int buf_size)
    int mr_motd(char ** motd)
    int mr_noop()
    int mr_query(char * handle, int argc, char ** argv,
                 int (*callback)(int, char **, object), object callarg)

cdef extern from "stdlib.h":
    ctypedef unsigned long size_t
    void * malloc(size_t size)
    void free(void * ptr)

class MoiraException(Exception):
    pass

__connected = False

def connect(server=''):
    """
    Establish a connection to a Moira server.
    
    A server may be specified, but it is optional. If specified, it
    should be of the form hostname:portname. Portname will be looked
    up in /etc/services if specified, but it is optional as well.
    
    If no server is specified, the server will be found from the
    MOIRASERVER environment variable, Hesiod, or a compiled in default
    (in that order).
    
    This function raises a MoiraException if the connection is
    not successful.
    """
    global __connected
    
    if __connected:
        disconnect()
    
    status = mr_connect(server)
    if status != 0:
        raise MoiraException, status
    else:
        __connected = True

def disconnect():
    """
    Disconnect from the active Moira server
    """
    global __connected
    if __connected:
        mr_disconnect()
    __connected = False

def auth(program, krb4=False):
    """
    Authenticate to the Moira server with Kerberos tickets. If krb4 is
    True, then Kerberos version 4 will be used. Otherwise, Kerberos
    version 5 is used.
    
    The program argument identifies the connecting program to the
    Moira server. This is used for setting the modwith field when
    modifications are made.
    
    Note that the use of Kerberos version 4 is deprecated and highly
    discouraged
    """
    if krb4:
        status = mr_auth(program)
    else:
        status = mr_krb5_auth(program)
    if status != 0:
        raise MoiraException, status

def host():
    """
    Return the name of the host the client is connected to.
    """
    cdef char buffer[512]
    status = mr_host(buffer, 512)
    if status != 0:
        raise MoiraException, status
    return buffer

def motd():
    """
    Retrieve the current message of the day from the server.
    """
    cdef char * motd
    status = mr_motd(&motd)
    if status != 0:
        raise MoiraException, status
    if motd != NULL:
        return motd

def noop():
    """
    Does "no operation" to the server, just making sure it's still
    there
    """
    status = mr_noop()
    if status:
        raise MoiraException, status

cdef int _query_callback(int argc, char ** argv, object results):
    result = []
    cdef int i
    for i in xrange(argc):
        result.append(argv[i])
    results.append(tuple(result))
    return 0

def query(handle, *args):
    """
    Execute a Moira query and return the result as a list of tuples.
    
    All of the real work of Moira is done in queries. There are over
    100 queries, each of which requires different arguments. The
    arguments to the queries should be passed as separate arguments to
    the function.
    """
    cdef int argc, i
    argc = len(args)
    cdef char ** argv
    argv = <char **>malloc(argc * sizeof(char *))
    
    if argv != NULL:
        for i in xrange(argc):
            argv[i] = args[i]
        
        result = []
        status = mr_query(handle, argc, argv, _query_callback, result)
        free(argv)
        
        if status:
            raise MoiraException, status
        return result
